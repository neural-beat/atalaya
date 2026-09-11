import Foundation

/// Una lectura completa del servidor en un instante.
struct Lectura: Sendable {
    var cpu: Double = 0
    var nucleos: Int = 1
    var carga: (uno: Double, cinco: Double, quince: Double) = (0, 0, 0)
    var memoriaUsada: Double = 0
    var memoriaTotal: Double = 0
    var memoriaCache: Double = 0
    var swapUsada: Double = 0
    var temperatura: Double?
    var etiquetaTemperatura: String = ""
    var discos: [Disco] = []
    var bajada: Double = 0
    var subida: Double = 0
    var encendido: Double = 0
    var sistema: String = ""
    var maquina: String = ""

    struct Disco: Identifiable, Sendable {
        let punto: String
        let total: Double, usado: Double, libre: Double
        var pct: Double { total > 0 ? usado / total * 100 : 0 }
        var id: String { punto }
        var nombre: String { punto == "/" ? "sistema" : (punto as NSString).lastPathComponent }
    }
}

struct Contenedor: Identifiable, Sendable {
    let nombre: String, imagen: String, estado: String, detalle: String, puertos: String
    var id: String { nombre }
    var vivo: Bool { estado.hasPrefix("Up") || estado == "running" }
}

struct Servicio: Identifiable, Sendable {
    let nombre: String, descripcion: String, estado: String, subestado: String
    var id: String { nombre }
    var activo: Bool { estado == "active" }
    /// Explicacion en cristiano de los servicios que casi todo el mundo tiene.
    var explicacion: String {
        Servicio.conocidos.first { nombre.hasPrefix($0.key) }?.value ?? descripcion
    }

    static let conocidos: [String: String] = [
        "ssh": "El acceso por terminal. Es por donde entra esta app: no lo pares.",
        "docker": "El motor de los contenedores. Si se para, se paran todos de golpe.",
        "containerd": "La pieza de debajo de Docker que arranca los contenedores.",
        "jellyfin": "Servidor multimedia: sirve películas y series a la tele y al móvil.",
        "plex": "Servidor multimedia de Plex.",
        "mariadb": "Base de datos. Si se para, lo que dependa de ella deja de guardar.",
        "mysql": "Base de datos. Si se para, lo que dependa de ella deja de guardar.",
        "postgresql": "Base de datos PostgreSQL.",
        "redis": "Almacén rápido en memoria que usan otras aplicaciones como caché.",
        "apache2": "Servidor web: atiende los puertos 80 y 443.",
        "nginx": "Servidor web y proxy: atiende los puertos 80 y 443.",
        "caddy": "Servidor web con certificados automáticos.",
        "tailscaled": "La VPN de Tailscale. Sin ella no se llega desde fuera de casa.",
        "wg-quick": "Túnel WireGuard.",
        "netdata": "Recoge métricas finas del sistema y las enseña en su propia web.",
        "smartd": "Vigila la salud de los discos y avisa antes de que uno muera.",
        "smartmontools": "Vigila la salud de los discos y avisa antes de que uno muera.",
        "cron": "Lanza las tareas programadas a su hora.",
        "chrony": "Mantiene el reloj en hora, que importa para certificados y copias.",
        "systemd-timesyncd": "Mantiene el reloj en hora.",
        "ufw": "El cortafuegos.",
        "fail2ban": "Bloquea a quien falla la contraseña muchas veces seguidas.",
        "samba": "Comparte carpetas con Windows.",
        "smbd": "Comparte carpetas con Windows.",
        "nfs": "Comparte carpetas por NFS.",
        "cups": "El servidor de impresión.",
        "unattended-upgrades": "Instala solo las actualizaciones de seguridad.",
    ]
}

/// Un script encontrado en el servidor. La explicación sale de sus propios
/// comentarios: lo que el autor escribió arriba del todo.
struct Guion: Identifiable, Sendable {
    let ruta: String
    let explicacion: String
    var id: String { ruta }
    var nombre: String { (ruta as NSString).lastPathComponent }
    var necesitaRoot: Bool { explicacion.lowercased().contains("sudo") }
}

struct Paquete: Identifiable, Sendable {
    let nombre: String, version: String
    let seguridad: Bool
    var id: String { nombre }
    var grupo: Grupo {
        if nombre.hasPrefix("linux-") || ["systemd", "udev", "libc6", "dpkg", "apt", "grub", "base-files", "login", "passwd", "sudo", "openssh", "motd-news"].contains(where: nombre.hasPrefix) { return .nucleo }
        if ["jellyfin", "docker", "containerd", "mariadb", "mysql", "apache2", "nginx", "php", "tailscale", "netdata", "samba", "postgres", "redis"].contains(where: nombre.hasPrefix) { return .programas }
        if nombre.hasPrefix("lib") || nombre.hasPrefix("python3-") || nombre.hasPrefix("perl") { return .bibliotecas }
        return .resto
    }

    enum Grupo: String, CaseIterable, Identifiable {
        case seguridad, nucleo, programas, bibliotecas, resto
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .seguridad: "Seguridad"
            case .nucleo: "Núcleo y sistema base"
            case .programas: "Programas del servidor"
            case .bibliotecas: "Bibliotecas y dependencias"
            case .resto: "El resto"
            }
        }
        var explicacion: String {
            switch self {
            case .seguridad: "Fallos ya conocidos y parcheados. Es lo primero que conviene instalar y lo que menos suele romper."
            case .nucleo: "El sistema por dentro. Si entra un núcleo nuevo, después hay que reiniciar para usarlo."
            case .programas: "Lo que da servicio. Al actualizarlos se reinician solos y se cortan unos segundos."
            case .bibliotecas: "Piezas internas que usan los programas. Casi nunca se notan."
            case .resto: "Herramientas sueltas y utilidades de línea de comandos."
            }
        }
    }
}

func humano(_ n: Double) -> String {
    var v = n
    for u in ["B", "KB", "MB", "GB", "TB"] {
        if abs(v) < 1024 { return v >= 100 || u == "B" ? "\(Int(v)) \(u)" : String(format: "%.1f %@", v, u) }
        v /= 1024
    }
    return String(format: "%.1f PB", v)
}

func reloj(_ s: Double) -> String {
    let d = Int(s) / 86400, h = (Int(s) % 86400) / 3600, m = (Int(s) % 3600) / 60
    if d > 0 { return "\(d) d \(h) h" }
    if h > 0 { return "\(h) h \(m) min" }
    return "\(m) min"
}
