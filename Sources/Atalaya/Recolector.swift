import Foundation

/// Saca los datos del servidor lanzando comandos por SSH. No hace falta
/// instalar nada en la otra punta: todo sale de /proc, systemd y docker.
actor Recolector {
    private let conexion: Conexion
    private var cpuPrevio: (total: Double, ocupado: Double)?
    private var redPrevia: (t: Date, rx: Double, tx: Double)?

    init(conexion: Conexion) { self.conexion = conexion }

    private static let comandoEstado = """
    echo '@@stat'; head -1 /proc/stat
    echo '@@mem'; cat /proc/meminfo
    echo '@@load'; cat /proc/loadavg
    echo '@@up'; cat /proc/uptime
    echo '@@net'; cat /proc/net/dev
    echo '@@disk'; df -B1 -x tmpfs -x devtmpfs -x overlay -x squashfs --output=target,size,used,avail 2>/dev/null | tail -n +2
    echo '@@temp'; for f in /sys/class/hwmon/hwmon*/temp*_input; do [ -r "$f" ] || continue; e="${f%_input}_label"; printf '%s|%s|%s\\n' "$(cat "$f" 2>/dev/null)" "$(cat "$e" 2>/dev/null)" "$(cat "$(dirname "$f")/name" 2>/dev/null)"; done
    echo '@@so'; . /etc/os-release 2>/dev/null; echo "$PRETTY_NAME"; uname -srm; hostname
    echo '@@nucleos'; nproc
    """

    func estado() async throws -> Lectura {
        let bruto = try await conexion.ejecuta(Self.comandoEstado)
        let partes = trocea(bruto)
        var l = Lectura()

        if let stat = partes["stat"]?.first {
            let v = stat.split(separator: " ").compactMap { Double($0) }
            if v.count >= 4 {
                let total = v.reduce(0, +), ocupado = total - v[3] - (v.count > 4 ? v[4] : 0)
                if let p = cpuPrevio, total > p.total {
                    l.cpu = max(0, min(100, (ocupado - p.ocupado) / (total - p.total) * 100))
                }
                cpuPrevio = (total, ocupado)
            }
        }
        l.nucleos = partes["nucleos"]?.first.flatMap { Int($0) } ?? 1

        var mem: [String: Double] = [:]
        for linea in partes["mem"] ?? [] {
            let t = linea.split(separator: ":")
            if t.count == 2, let kb = Double(t[1].trimmingCharacters(in: .whitespaces).split(separator: " ").first ?? "") {
                mem[String(t[0])] = kb * 1024
            }
        }
        l.memoriaTotal = mem["MemTotal"] ?? 0
        l.memoriaUsada = (mem["MemTotal"] ?? 0) - (mem["MemAvailable"] ?? 0)
        l.memoriaCache = (mem["Cached"] ?? 0) + (mem["Buffers"] ?? 0)
        l.swapUsada = (mem["SwapTotal"] ?? 0) - (mem["SwapFree"] ?? 0)

        if let carga = partes["load"]?.first?.split(separator: " ").compactMap({ Double($0) }), carga.count >= 3 {
            l.carga = (carga[0], carga[1], carga[2])
        }
        l.encendido = partes["up"]?.first?.split(separator: " ").first.flatMap { Double($0) } ?? 0

        var rx = 0.0, tx = 0.0
        for linea in (partes["net"] ?? []).dropFirst(2) {
            let t = linea.split(separator: ":")
            guard t.count == 2 else { continue }
            let iface = t[0].trimmingCharacters(in: .whitespaces)
            if iface == "lo" || iface.hasPrefix("veth") || iface.hasPrefix("br-") || iface.hasPrefix("docker") { continue }
            let c = t[1].split(separator: " ").compactMap { Double($0) }
            if c.count > 8 { rx += c[0]; tx += c[8] }
        }
        let ahora = Date()
        if let p = redPrevia {
            let dt = ahora.timeIntervalSince(p.t)
            if dt > 0 { l.bajada = max(0, (rx - p.rx) / dt); l.subida = max(0, (tx - p.tx) / dt) }
        }
        redPrevia = (ahora, rx, tx)

        l.discos = (partes["disk"] ?? []).compactMap { linea in
            let c = linea.split(separator: " ").map(String.init)
            guard c.count >= 4, let total = Double(c[1]), let usado = Double(c[2]), let libre = Double(c[3]), total > 0 else { return nil }
            return Lectura.Disco(punto: c[0], total: total, usado: usado, libre: libre)
        }
        // Fuera las particiones de arranque y cualquier cosa menor de 5 GB:
        // son ruido en un tablero que mira si se llena el disco.
        .filter { $0.total > 5_000_000_000 && !$0.punto.hasPrefix("/boot") }

        var mejor: (Int, Double, String)?
        for linea in partes["temp"] ?? [] {
            let c = linea.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard let mili = Double(c.first ?? ""), mili > 0, mili < 130_000 else { continue }
            let etiqueta = c.count > 1 ? c[1] : "", chip = c.count > 2 ? c[2] : ""
            let prioridad = etiqueta.contains("Package") ? 2 : (["coretemp", "k10temp"].contains(chip) ? 1 : 0)
            if mejor == nil || prioridad > mejor!.0 { mejor = (prioridad, mili / 1000, etiqueta.isEmpty ? chip : etiqueta) }
        }
        l.temperatura = mejor?.1
        l.etiquetaTemperatura = mejor?.2 ?? "sin sensor"

        let so = partes["so"] ?? []
        l.sistema = so.first ?? ""
        l.maquina = so.count > 2 ? so[2] : ""
        return l
    }

    func contenedores() async throws -> [Contenedor] {
        let salida = try await conexion.ejecuta(
            "command -v docker >/dev/null && docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true")
        return salida.split(separator: "\n").compactMap { linea in
            let c = linea.components(separatedBy: "\t")
            guard c.count >= 4 else { return nil }
            return Contenedor(nombre: c[0], imagen: c[1], estado: c[2], detalle: c[3], puertos: c.count > 4 ? c[4] : "")
        }
    }

    func servicios() async throws -> [Servicio] {
        let salida = try await conexion.ejecuta(
            "systemctl list-units --type=service --state=running,failed --no-legend --no-pager --plain 2>/dev/null | head -60")
        return salida.split(separator: "\n").compactMap { linea in
            let c = linea.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard c.count >= 5 else { return nil }
            let nombre = c[0].replacingOccurrences(of: ".service", with: "")
            let descripcion = c[4...].joined(separator: " ")
            return Servicio(nombre: nombre, descripcion: descripcion, estado: c[2], subestado: c[3])
        }
        .filter { !$0.nombre.hasPrefix("systemd-") && !$0.nombre.hasPrefix("user@") }
    }

    /// Busca los scripts del usuario y saca su explicación de los comentarios
    /// de las primeras líneas. Es lo que convierte los scripts en botones.
    func guiones() async throws -> [Guion] {
        let salida = try await conexion.ejecuta(#"""
        {
          find "$HOME" -maxdepth 6 -type f \
            \( -name '*.sh' -o -name '*.py' -o -name '*.rb' -o -name '*.pl' -o -perm -u+x \) \
            -not -path '*/.git/*' -not -path '*/.cache/*' \
            -not -path '*/git/*.git/*' \
            -not -path '*/node_modules/*' -not -path '*/vendor/*' \
            -not -path '*/.venv/*' -not -path '*/venv/*' \
            -not -path '*/Library/*' 2>/dev/null
          find /usr/local/bin -maxdepth 1 -type f -perm -u+x 2>/dev/null
        } | sort -u | while IFS= read -r f; do
          [ -f "$f" ] || continue
          case "$f" in
            *.sh|*.py|*.rb|*.pl) ;;
            *) grep -Iq . "$f" 2>/dev/null || continue
               case "$(head -n 1 "$f" 2>/dev/null)" in
                 '#!'*sh*|'#!'*python*|'#!'*ruby*|'#!'*perl*) ;;
                 *) continue ;;
               esac ;;
          esac
          printf '@@guion %s\n' "$f"
          head -40 "$f" | grep -E '^#' | grep -vE '^#!' | sed -E 's/^#+[[:space:]]?//' \
            | grep -viE '^(SPDX|Copyright|shellcheck|vim:|set -)' \
            | grep -vE '^[[:space:]]*[=*_·-]{3,}[[:space:]]*$' \
            | grep -vE '^[[:space:]]*$' | head -8 || true
        done
        exit 0
        """#)
        var guiones: [Guion] = []
        var ruta: String?
        var lineas: [String] = []
        func cierra() {
            if let r = ruta {
                let texto = lineas.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                guiones.append(Guion(ruta: r, explicacion: texto.isEmpty ? "Sin comentarios dentro del script." : texto))
            }
            lineas = []
        }
        for linea in salida.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if linea.hasPrefix("@@guion ") {
                cierra()
                ruta = String(linea.dropFirst(8))
            } else if !linea.trimmingCharacters(in: .whitespaces).isEmpty {
                lineas.append(linea)
            }
        }
        cierra()
        return guiones
    }

    func paquetes() async throws -> [Paquete] {
        let salida = try await conexion.ejecuta(
            "command -v apt >/dev/null && apt list --upgradable 2>/dev/null | tail -n +2 || true")
        return salida.split(separator: "\n").compactMap { linea in
            let partes = linea.split(separator: " ").map(String.init)
            guard let primera = partes.first, primera.contains("/") else { return nil }
            let nueva = partes.count > 1 ? partes[1] : ""
            // apt escribe la versión vieja al final: "[upgradable from: 1.2.3]".
            let vieja = linea.range(of: "(?<=: )[^\\]]+(?=\\])", options: .regularExpression)
                .map { String(linea[$0]) } ?? ""
            return Paquete(nombre: String(primera.split(separator: "/")[0]),
                           version: vieja.isEmpty ? nueva : "\(vieja) → \(nueva)",
                           seguridad: linea.contains("-security"))
        }
    }

    private func trocea(_ texto: String) -> [String: [String]] {
        var mapa: [String: [String]] = [:]
        var actual = ""
        for linea in texto.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if linea.hasPrefix("@@") {
                actual = String(linea.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                mapa[actual] = []
            } else if !actual.isEmpty {
                mapa[actual, default: []].append(linea)
            }
        }
        return mapa
    }
}
