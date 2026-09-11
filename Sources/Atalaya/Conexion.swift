@preconcurrency import Citadel
import Crypto
import Foundation
import NIOCore
import NIOSSH

/// Datos de un servidor. Es lo unico que hace falta para que la app funcione:
/// ni agente, ni panel web, ni nada instalado en la otra punta.
struct Perfil: Codable, Identifiable, Hashable {
    var id = UUID()
    var nombre: String = "Mi servidor"
    var maquina: String = ""
    var puerto: Int = 22
    var usuario: String = ""
    var usaLlave: Bool = false
    var rutaLlave: String = "~/.ssh/id_ed25519"

    var etiqueta: String { "\(usuario)@\(maquina)" }
}

/// Guarda los perfiles y sus contrasenas: los datos sueltos en las preferencias,
/// las contrasenas siempre en el llavero del Mac.
enum Almacen {
    private static let clavePerfiles = "perfiles"
    private static let claveUltimo = "ultimoPerfil"
    private static let servicio = "com.neuralbeat.atalaya"

    static var perfiles: [Perfil] {
        get {
            guard let d = UserDefaults.standard.data(forKey: clavePerfiles),
                  let p = try? JSONDecoder().decode([Perfil].self, from: d) else { return [] }
            return p
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: clavePerfiles) }
    }

    static var ultimo: UUID? {
        get { UserDefaults.standard.string(forKey: claveUltimo).flatMap(UUID.init) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: claveUltimo) }
    }

    static func guarda(_ perfil: Perfil) {
        var lista = perfiles
        if let i = lista.firstIndex(where: { $0.id == perfil.id }) { lista[i] = perfil } else { lista.append(perfil) }
        perfiles = lista
    }

    static func borra(_ perfil: Perfil) {
        perfiles = perfiles.filter { $0.id != perfil.id }
        guarda(secreto: nil, para: perfil.id, tipo: .acceso)
        guarda(secreto: nil, para: perfil.id, tipo: .sudo)
    }

    enum Tipo: String { case acceso, sudo }

    static func guarda(secreto: String?, para id: UUID, tipo: Tipo) {
        let cuenta = "\(id.uuidString)/\(tipo.rawValue)"
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ] as CFDictionary)
        guard let secreto, !secreto.isEmpty else { return }
        SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecValueData as String: Data(secreto.utf8),
        ] as CFDictionary, nil)
    }

    static func secreto(de id: UUID, tipo: Tipo) -> String? {
        var resultado: CFTypeRef?
        let estado = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: "\(id.uuidString)/\(tipo.rawValue)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ] as CFDictionary, &resultado)
        guard estado == errSecSuccess, let d = resultado as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    /// Huella de la maquina, para avisar si cambia (lo mismo que hace ssh).
    static func huella(de id: UUID) -> String? {
        UserDefaults.standard.string(forKey: "huella-\(id.uuidString)")
    }

    static func guarda(huella: String, de id: UUID) {
        UserDefaults.standard.set(huella, forKey: "huella-\(id.uuidString)")
    }
}

/// Reutiliza el known_hosts del Mac: si la máquina ya está ahí, solo se acepta
/// esa llave. Si no está, es la primera visita y se avisa en la interfaz.
enum Conocidos {
    static func llaves(maquina: String, puerto: Int) -> Set<NIOSSHPublicKey> {
        let ruta = (NSHomeDirectory() as NSString).appendingPathComponent(".ssh/known_hosts")
        guard let texto = try? String(contentsOfFile: ruta, encoding: .utf8) else { return [] }
        let buscados = puerto == 22 ? [maquina] : ["[\(maquina)]:\(puerto)", maquina]
        var llaves = Set<NIOSSHPublicKey>()
        for linea in texto.split(separator: "\n") {
            let campos = linea.split(separator: " ", maxSplits: 2).map(String.init)
            guard campos.count >= 3 else { continue }
            let anfitriones = campos[0].split(separator: ",").map(String.init)
            guard anfitriones.contains(where: { buscados.contains($0) }) else { continue }
            if let llave = try? NIOSSHPublicKey(openSSHPublicKey: "\(campos[1]) \(campos[2])") {
                llaves.insert(llave)
            }
        }
        return llaves
    }
}

/// Conexion SSH viva contra un servidor. Todo lo que enseña la app sale de
/// comandos lanzados por aqui.
/// Conexión SSH viva contra un servidor. Todo lo que enseña la app sale de
/// comandos lanzados por aquí.
///
/// Es una clase y no un actor a propósito: el cliente de Citadel no es Sendable,
/// y meterlo en un actor obliga a cruzarlo entre aislamientos en cada comando.
/// La conexión se crea una sola vez con una tarea memorizada, que hace de
/// candado natural cuando dos vistas piden datos a la vez.
final class Conexion: @unchecked Sendable {
    enum Fallo: LocalizedError {
        case sinConexion, huellaCambiada, sinClave, comando(String)
        var errorDescription: String? {
            switch self {
            case .sinConexion: "No hay conexión con el servidor."
            case .huellaCambiada: "La identidad del servidor ha cambiado. Si no has reinstalado la máquina, no entres y averigua por qué."
            case .sinClave: "No encuentro la clave de acceso guardada."
            case .comando(let m): m
            }
        }
    }

    let perfil: Perfil
    /// El cliente de Citadel no es Sendable; esta caja lo cruza entre tareas
    /// bajo nuestra responsabilidad: solo lo usa esta clase.
    private struct Caja: @unchecked Sendable { let cliente: SSHClient }
    private var tarea: Task<Caja, Error>?

    init(perfil: Perfil) { self.perfil = perfil }

    /// Si la máquina está en el known_hosts del Mac, exige esa llave y nada más.
    /// Si no está, acepta la primera y la interfaz lo advierte.
    private func validador() -> SSHHostKeyValidator {
        let llaves = Conocidos.llaves(maquina: perfil.maquina, puerto: perfil.puerto)
        return llaves.isEmpty ? .acceptAnything() : .trustedKeys(llaves)
    }

    var estaEnKnownHosts: Bool {
        !Conocidos.llaves(maquina: perfil.maquina, puerto: perfil.puerto).isEmpty
    }

    private func metodo() throws -> SSHAuthenticationMethod {
        if perfil.usaLlave {
            let ruta = (perfil.rutaLlave as NSString).expandingTildeInPath
            let texto = try String(contentsOfFile: ruta, encoding: .utf8)
            let llave = try Curve25519.Signing.PrivateKey(
                sshEd25519: texto,
                decryptionKey: Almacen.secreto(de: perfil.id, tipo: .acceso).map { Data($0.utf8) })
            return .ed25519(username: perfil.usuario, privateKey: llave)
        }
        guard let clave = Almacen.secreto(de: perfil.id, tipo: .acceso) else { throw Fallo.sinClave }
        return .passwordBased(username: perfil.usuario, password: clave)
    }

    @discardableResult
    func cliente() async throws -> SSHClient {
        if let tarea {
            do { return try await tarea.value.cliente } catch { self.tarea = nil }
        }
        let nueva = Task { [perfil] in
            Caja(cliente: try await SSHClient.connect(
                host: perfil.maquina,
                port: perfil.puerto,
                authenticationMethod: try self.metodo(),
                hostKeyValidator: self.validador(),
                reconnect: .never))
        }
        tarea = nueva
        return try await nueva.value.cliente
    }

    func desconecta() async {
        let vieja = tarea
        tarea = nil
        if let caja = try? await vieja?.value { try? await caja.cliente.close() }
    }

    /// Lanza un comando y devuelve su salida. Si la conexión se cayó, reconecta
    /// una vez y lo reintenta.
    func ejecuta(_ comando: String) async throws -> String {
        do {
            return String(buffer: try await cliente().executeCommand(comando))
        } catch {
            tarea = nil
            return String(buffer: try await cliente().executeCommand(comando))
        }
    }

    /// Igual que ejecuta, pero como root. La contraseña de sudo va por la
    /// entrada estándar, nunca escrita en la línea de comandos.
    func ejecutaComoRoot(_ comando: String) async throws -> String {
        guard let clave = Almacen.secreto(de: perfil.id, tipo: .sudo)
                ?? Almacen.secreto(de: perfil.id, tipo: .acceso) else { throw Fallo.sinClave }
        let escapada = clave.replacingOccurrences(of: "'", with: "'\\''")
        return try await ejecuta("printf '%s\\n' '\(escapada)' | sudo -S -p '' \(comando) 2>&1")
    }

    /// Salida en directo, línea a línea, para las tareas largas.
    func enVivo(_ comando: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { seguidor in
            let tarea = Task {
                do {
                    let flujo = try await cliente().executeCommandStream(comando)
                    var resto = ""
                    for try await trozo in flujo {
                        let texto: String
                        switch trozo {
                        case .stdout(let b): texto = String(buffer: b)
                        case .stderr(let b): texto = String(buffer: b)
                        }
                        resto += texto
                        while let salto = resto.firstIndex(of: "\n") {
                            seguidor.yield(String(resto[resto.startIndex..<salto]))
                            resto = String(resto[resto.index(after: salto)...])
                        }
                    }
                    if !resto.isEmpty { seguidor.yield(resto) }
                    seguidor.finish()
                } catch { seguidor.finish(throwing: error) }
            }
            seguidor.onTermination = { _ in tarea.cancel() }
        }
    }
}
