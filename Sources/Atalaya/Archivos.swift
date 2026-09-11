// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

@preconcurrency import Citadel
import Foundation
import NIOCore

/// Un fichero o carpeta del servidor, tal y como lo devuelve SFTP.
struct Fichero: Identifiable, Sendable, Hashable {
    let nombre: String
    let ruta: String
    let carpeta: Bool
    let tamano: UInt64
    let modificado: Date?
    let permisos: String
    var id: String { ruta }

    var icono: String {
        if carpeta { return "folder" }
        switch (ruta as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "heic", "webp": return "photo"
        case "mp4", "mkv", "mov", "avi": return "film"
        case "mp3", "flac", "wav", "m4a": return "music.note"
        case "pdf": return "doc.richtext"
        case "zip", "gz", "tar", "xz", "7z": return "doc.zipper"
        case "sh", "py", "js", "swift", "conf", "yml", "yaml", "json": return "doc.plaintext"
        default: return "doc"
        }
    }
}

/// Transferencia en marcha, para poder enseñar la barra de progreso.
@MainActor
@Observable
final class Transferencia: Identifiable {
    let id = UUID()
    let nombre: String
    let subiendo: Bool
    var hechos: UInt64 = 0
    var total: UInt64
    var terminada = false
    var error: String?

    init(nombre: String, subiendo: Bool, total: UInt64) {
        self.nombre = nombre
        self.subiendo = subiendo
        self.total = total
    }

    var fraccion: Double { total > 0 ? Double(hechos) / Double(total) : 0 }
}

extension Conexion {
    private static let trozo = 32 * 1024

    /// Lista una carpeta. Las entradas . y .. no se enseñan: sobran en una
    /// interfaz que ya tiene botón de subir.
    func lista(_ ruta: String) async throws -> [Fichero] {
        let sftp = try await cliente().openSFTP()
        defer { Task { try? await sftp.close() } }
        let respuesta = try await sftp.listDirectory(atPath: ruta)
        var ficheros: [Fichero] = []
        for pagina in respuesta {
            for c in pagina.components where c.filename != "." && c.filename != ".." {
                let permisos = c.attributes.permissions ?? 0
                let carpeta = c.longname.hasPrefix("d") || (permisos & 0o040000) != 0
                let base = ruta.hasSuffix("/") ? String(ruta.dropLast()) : ruta
                ficheros.append(Fichero(
                    nombre: c.filename,
                    ruta: "\(base)/\(c.filename)",
                    carpeta: carpeta,
                    tamano: c.attributes.size ?? 0,
                    modificado: c.attributes.accessModificationTime?.modificationTime,
                    permisos: String(c.longname.prefix(10))))
            }
        }
        return ficheros.sorted {
            $0.carpeta == $1.carpeta
                ? $0.nombre.localizedStandardCompare($1.nombre) == .orderedAscending
                : $0.carpeta
        }
    }

    func carpetaDeCasa() async throws -> String {
        let salida = try await ejecuta("printf '%s' \"$HOME\"")
        let ruta = salida.trimmingCharacters(in: .whitespacesAndNewlines)
        return ruta.isEmpty ? "/" : ruta
    }

    /// Descarga por trozos para poder ir contando el progreso: un fichero de
    /// varios GB no cabe entero en memoria de golpe.
    func descarga(_ fichero: Fichero, a destino: URL, avance: @escaping @Sendable (UInt64) -> Void) async throws {
        let sftp = try await cliente().openSFTP()
        defer { Task { try? await sftp.close() } }
        let remoto = try await sftp.openFile(filePath: fichero.ruta, flags: .read)
        defer { Task { try? await remoto.close() } }

        FileManager.default.createFile(atPath: destino.path, contents: nil)
        let mango = try FileHandle(forWritingTo: destino)
        defer { try? mango.close() }

        var puesto: UInt64 = 0
        while true {
            let datos = try await remoto.read(from: puesto, length: UInt32(Self.trozo))
            let bytes = Data(datos.readableBytesView)
            if bytes.isEmpty { break }
            try mango.write(contentsOf: bytes)
            puesto += UInt64(bytes.count)
            avance(puesto)
            if bytes.count < Self.trozo { break }
        }
    }

    func sube(_ origen: URL, a carpeta: String, avance: @escaping @Sendable (UInt64) -> Void) async throws {
        let sftp = try await cliente().openSFTP()
        defer { Task { try? await sftp.close() } }
        let nombre = origen.lastPathComponent
        let destino = carpeta.hasSuffix("/") ? carpeta + nombre : "\(carpeta)/\(nombre)"
        let remoto = try await sftp.openFile(filePath: destino, flags: [.write, .create, .truncate])
        defer { Task { try? await remoto.close() } }

        let mango = try FileHandle(forReadingFrom: origen)
        defer { try? mango.close() }

        var puesto: UInt64 = 0
        while let bytes = try mango.read(upToCount: Self.trozo), !bytes.isEmpty {
            var buffer = ByteBufferAllocator().buffer(capacity: bytes.count)
            buffer.writeBytes(bytes)
            try await remoto.write(buffer, at: puesto)
            puesto += UInt64(bytes.count)
            avance(puesto)
        }
    }

    func creaCarpeta(_ ruta: String) async throws {
        let sftp = try await cliente().openSFTP()
        defer { Task { try? await sftp.close() } }
        try await sftp.createDirectory(atPath: ruta)
    }

    func renombra(_ ruta: String, a nueva: String) async throws {
        let sftp = try await cliente().openSFTP()
        defer { Task { try? await sftp.close() } }
        try await sftp.rename(at: ruta, to: nueva)
    }

    /// Borra de verdad: SFTP no tiene papelera. Por eso la interfaz avisa.
    func borra(_ fichero: Fichero) async throws {
        let sftp = try await cliente().openSFTP()
        defer { Task { try? await sftp.close() } }
        if fichero.carpeta {
            try await sftp.rmdir(at: fichero.ruta)
        } else {
            try await sftp.remove(at: fichero.ruta)
        }
    }
}
