// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import Foundation
import Observation

/// Estado de la app: qué servidor está elegido, qué se ha leído de él y cada
/// cuánto se vuelve a preguntar.
@MainActor
@Observable
final class Cerebro {
    enum Sitio: String, CaseIterable, Identifiable {
        static var visibles: [Sitio] { allCases }

        case tablero, archivos, contenedores, servicios, guiones, instalar, actualizaciones, servidores
        var id: String { rawValue }
        var icono: String {
            switch self {
            case .tablero: "gauge.with.dots.needle.33percent"
            case .archivos: "folder"
            case .instalar: "square.and.arrow.down.on.square"
            case .contenedores: "shippingbox"
            case .servicios: "gearshape.2"
            case .guiones: "terminal"
            case .actualizaciones: "arrow.down.circle"
            case .servidores: "server.rack"
            }
        }
    }

    var perfiles: [Perfil] = Almacen.perfiles
    var elegido: Perfil?
    /// Se recuerda dónde estabas: al volver a abrir, la app aparece en la
    /// misma sección en la que la dejaste.
    var sitio: Sitio = Sitio(rawValue: UserDefaults.standard.string(forKey: "sitio") ?? "") ?? .tablero {
        didSet { UserDefaults.standard.set(sitio.rawValue, forKey: "sitio") }
    }
    var conectado = false
    var fallo: String?
    var primeraVisita = false
    /// Al salir de la bienvenida sin ningún servidor, se abre sola la hoja de añadir.
    var pedirPrimerServidor = false

    var lectura: Lectura?
    var series: [String: [Double]] = [:]
    var contenedores: [Contenedor] = []
    var servicios: [Servicio] = []
    var guiones: [Guion] = []
    var paquetes: [Paquete] = []
    var transferencias: [Transferencia] = []

    /// La conexión viva, para lo que necesita hablar con SFTP directamente.
    var conexionViva: Conexion? { conexion }

    private var conexion: Conexion?
    private var recolector: Recolector?
    private var tareaVivo: Task<Void, Never>?
    private var tareaListas: Task<Void, Never>?

    var intervalo: Double {
        get { max(2, UserDefaults.standard.double(forKey: "intervalo")) }
        set { UserDefaults.standard.set(newValue, forKey: "intervalo") }
    }

    init() {
        if Demo.activo {
            perfiles = [Demo.perfil]
            elegido = Demo.perfil
            return
        }
        if let id = Almacen.ultimo, let p = perfiles.first(where: { $0.id == id }) {
            elegido = p
        } else {
            elegido = perfiles.first
        }
    }

    func conecta(a perfil: Perfil) {
        if Demo.activo { arrancaDemo(); return }
        para()
        elegido = perfil
        Almacen.ultimo = perfil.id
        let c = Conexion(perfil: perfil)
        conexion = c
        recolector = Recolector(conexion: c)
        primeraVisita = !c.estaEnKnownHosts
        lectura = nil
        contenedores = []; servicios = []; guiones = []; paquetes = []
        series = [:]
        arranca()
    }

    /// Alimenta la interfaz con datos inventados, sin tocar la red.
    private func arrancaDemo() {
        conectado = true
        contenedores = Demo.contenedores
        servicios = Demo.servicios
        guiones = Demo.guiones
        paquetes = Demo.paquetes
        tareaVivo?.cancel()
        tareaVivo = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let l = Demo.lectura()
                self.lectura = l
                self.apunta("cpu", l.cpu)
                self.apunta("memoria", l.memoriaUsada / l.memoriaTotal * 100)
                self.apunta("red", l.bajada / 1024)
                self.apunta("carga", l.carga.uno)
                self.apunta("temperatura", l.temperatura ?? 0)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func arranca() {
        guard let recolector else { return }
        tareaVivo = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let l = try await recolector.estado()
                    self.lectura = l
                    self.conectado = true
                    self.fallo = nil
                    self.apunta("cpu", l.cpu)
                    self.apunta("memoria", l.memoriaTotal > 0 ? l.memoriaUsada / l.memoriaTotal * 100 : 0)
                    self.apunta("red", l.bajada / 1024)
                    self.apunta("subida", l.subida / 1024)
                    self.apunta("temperatura", l.temperatura ?? 0)
                    self.apunta("carga", l.carga.uno)
                } catch {
                    self.conectado = false
                    self.fallo = error.localizedDescription
                    try? await Task.sleep(for: .seconds(5))
                }
                try? await Task.sleep(for: .seconds(self.intervalo))
            }
        }
        tareaListas = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refrescaListas()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func para() {
        tareaVivo?.cancel(); tareaVivo = nil
        tareaListas?.cancel(); tareaListas = nil
        let vieja = conexion
        conexion = nil; recolector = nil; conectado = false
        Task { await vieja?.desconecta() }
    }

    private func apunta(_ clave: String, _ valor: Double) {
        var serie = series[clave] ?? []
        serie.append(valor)
        if serie.count > 120 { serie.removeFirst(serie.count - 120) }
        series[clave] = serie
    }

    func refrescaListas() async {
        if Demo.activo { return }
        guard let recolector else { return }
        contenedores = (try? await recolector.contenedores()) ?? contenedores
        servicios = (try? await recolector.servicios()) ?? servicios
        if guiones.isEmpty { guiones = (try? await recolector.guiones()) ?? [] }
        paquetes = (try? await recolector.paquetes()) ?? paquetes
    }

    // Transferencias de ficheros

    func sube(_ origen: URL, a carpeta: String) {
        guard let conexion else { return }
        let tamano = (try? FileManager.default.attributesOfItem(atPath: origen.path)[.size] as? UInt64) ?? 0
        let tr = Transferencia(nombre: origen.lastPathComponent, subiendo: true, total: tamano)
        transferencias.append(tr)
        Task {
            do {
                try await conexion.sube(origen, a: carpeta) { hechos in
                    Task { @MainActor in tr.hechos = hechos }
                }
                tr.terminada = true
            } catch { tr.error = error.localizedDescription }
            limpiaTransferencias()
        }
    }

    func descarga(_ fichero: Fichero, a carpeta: URL) {
        guard let conexion else { return }
        let tr = Transferencia(nombre: fichero.nombre, subiendo: false, total: fichero.tamano)
        transferencias.append(tr)
        let destino = carpeta.appendingPathComponent(fichero.nombre)
        Task {
            do {
                try await conexion.descarga(fichero, a: destino) { hechos in
                    Task { @MainActor in tr.hechos = hechos }
                }
                tr.terminada = true
            } catch { tr.error = error.localizedDescription }
            limpiaTransferencias()
        }
    }

    /// Las terminadas se quedan un rato a la vista y luego desaparecen solas.
    private func limpiaTransferencias() {
        Task {
            try? await Task.sleep(for: .seconds(6))
            transferencias.removeAll { $0.terminada && $0.error == nil }
        }
    }

    // Órdenes

    func docker(_ nombre: String, _ accion: String) async {
        await lanza("docker \(accion) \(nombre)")
        await refrescaListas()
    }

    func servicio(_ nombre: String, _ accion: String) async {
        guard let conexion else { return }
        do { _ = try await conexion.ejecutaComoRoot("systemctl \(accion) \(nombre)") }
        catch { fallo = error.localizedDescription }
        await refrescaListas()
    }

    @discardableResult
    func lanza(_ comando: String) async -> String {
        guard let conexion else { return "" }
        do { return try await conexion.ejecuta(comando) }
        catch { fallo = error.localizedDescription; return "" }
    }

    func registro(contenedor: String) async -> String {
        await lanza("docker logs --tail 300 \(contenedor) 2>&1")
    }

    func registro(servicio: String) async -> String {
        await lanza("journalctl -u \(servicio) -n 300 --no-pager -o short-iso 2>&1 || true")
    }

    func enVivo(_ comando: String, root: Bool = false) -> AsyncThrowingStream<String, Error> {
        guard let conexion else { return AsyncThrowingStream { $0.finish() } }
        if root, let clave = Almacen.secreto(de: conexion.perfil.id, tipo: .sudo) ?? Almacen.secreto(de: conexion.perfil.id, tipo: .acceso) {
            let escapada = clave.replacingOccurrences(of: "'", with: "'\\''")
            return conexion.enVivo("printf '%s\\n' '\(escapada)' | sudo -S -p '' \(comando) 2>&1")
        }
        return conexion.enVivo(comando + " 2>&1")
    }

    // Perfiles

    func guarda(_ perfil: Perfil, clave: String?, sudo: String?) {
        Almacen.guarda(perfil)
        if let clave, !clave.isEmpty { Almacen.guarda(secreto: clave, para: perfil.id, tipo: .acceso) }
        if let sudo, !sudo.isEmpty { Almacen.guarda(secreto: sudo, para: perfil.id, tipo: .sudo) }
        perfiles = Almacen.perfiles
    }

    func borra(_ perfil: Perfil) {
        Almacen.borra(perfil)
        perfiles = Almacen.perfiles
        if elegido?.id == perfil.id {
            para()
            elegido = perfiles.first
            if let p = elegido { conecta(a: p) }
        }
    }
}
