// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct PanelArchivos: View {
    @Environment(Cerebro.self) private var cerebro
    @State private var ruta = ""
    @State private var ficheros: [Fichero] = []
    @State private var elegidos: Set<String> = []
    @State private var cargando = false
    @State private var fallo: String?
    @State private var soltando = false
    @State private var creando = false
    @State private var nombreNuevo = ""
    @State private var renombrando: Fichero?
    @State private var borrando: [Fichero] = []
    @State private var vistaRapida: URL?
    @State private var atras: [String] = []
    @State private var adelante: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            barra
            Divider()
            lista
            if !cerebro.transferencias.isEmpty {
                Divider()
                transferencias
            }
        }
        .overlay {
            if soltando {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .background(Color.accentColor.opacity(0.08))
                    .overlay(Text(t("archivos.suelta")).font(.title3).bold())
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls { cerebro.sube(url, a: ruta) }
            return true
        } isTargeted: { soltando = $0 }
        .quickLookPreview($vistaRapida)
        .task { if ruta.isEmpty { await abreDondeLoDejaste() } }
        .alert(t("archivos.nuevaCarpeta"), isPresented: $creando) {
            TextField(t("archivos.nombre"), text: $nombreNuevo)
            Button(t("cancelar"), role: .cancel) { nombreNuevo = "" }
            Button(t("conexion.guardar")) { crea() }
        }
        .alert(t("archivos.renombrar"), isPresented: .init(
            get: { renombrando != nil }, set: { if !$0 { renombrando = nil } })) {
            TextField(t("archivos.nombre"), text: $nombreNuevo)
            Button(t("cancelar"), role: .cancel) { renombrando = nil }
            Button(t("conexion.guardar")) { renombra() }
        }
        .alert(t("archivos.borrarTitulo"), isPresented: .init(
            get: { !borrando.isEmpty }, set: { if !$0 { borrando = [] } })) {
            Button(t("cancelar"), role: .cancel) { borrando = [] }
            Button(t("borrar"), role: .destructive) { borra() }
        } message: {
            Text(t("archivos.borrarAviso") + "\n\n" + borrando.map(\.nombre).joined(separator: ", "))
        }
    }

    private var barra: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button { navegaAtras() } label: { Image(systemName: "chevron.left") }
                    .disabled(atras.isEmpty)
                    .help(t("archivos.atras"))
                Button { navegaAdelante() } label: { Image(systemName: "chevron.right") }
                    .disabled(adelante.isEmpty)
                    .help(t("archivos.adelante"))
                Button { Task { await vaACasa() } } label: { Image(systemName: "house") }
                    .help(t("archivos.casa"))
                Button { Task { await entra(en: (ruta as NSString).deletingLastPathComponent) } } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(ruta == "/" || ruta.isEmpty)
                .help(t("archivos.arriba"))
                Text(ruta).font(.callout).monospaced().lineLimit(1).truncationMode(.head)
                    .textSelection(.enabled)
                if cargando { ProgressView().controlSize(.small) }
                Spacer()
                Button { Task { await recarga() } } label: { Image(systemName: "arrow.clockwise") }
            }
            HStack(spacing: 8) {
                Button(t("archivos.abrir")) { abre(elegidos) }
                    .disabled(seleccion.first?.carpeta != true)
                    .help(t("archivos.abrir.ayuda"))
                Button(t("archivos.subir")) { eligeYSube() }
                    .help(t("archivos.subir"))
                Button(t("archivos.descargar")) { descarga() }
                    .disabled(elegidos.isEmpty)
                    .help(t("archivos.descargar"))
                Button { previsualiza() } label: { Image(systemName: "eye") }
                    .disabled(elegidos.count != 1 || seleccion.first?.carpeta == true)
                    .help(t("archivos.quickLook"))
                Button(t("archivos.nuevaCarpeta")) { nombreNuevo = ""; creando = true }
                    .help(t("archivos.nuevaCarpeta"))
                Button(t("archivos.renombrar")) {
                    if let f = seleccion.first { nombreNuevo = f.nombre; renombrando = f }
                }
                .disabled(elegidos.count != 1)
                .help(t("archivos.renombrar"))
                Button(t("borrar")) { borrando = seleccion }
                    .disabled(elegidos.isEmpty)
                    .help(t("archivos.borrarAviso"))
                Spacer()
                if let fallo {
                    Text(fallo).font(.caption).foregroundStyle(Color.mal).lineLimit(1)
                }
            }
            Text(t("archivos.ayuda")).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var lista: some View {
        Table(ficheros, selection: $elegidos) {
            TableColumn(t("archivos.nombre")) { f in
                HStack(spacing: 7) {
                    Image(systemName: f.icono).foregroundStyle(f.carpeta ? Color.accentColor : .secondary)
                    Text(f.nombre).lineLimit(1)
                }
                .help(f.carpeta ? t("archivos.abrir.ayuda") : "\(f.nombre) · \(humano(Double(f.tamano)))")
                // Sin gestos propios dentro de la celda: se comen la selección
                // de la tabla y entonces un clic normal no marca nada.
            }
            TableColumn(t("archivos.tamano")) { f in
                Text(f.carpeta ? "—" : humano(Double(f.tamano)))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            .width(90)
            TableColumn(t("archivos.modificado")) { f in
                Text(f.modificado.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .width(160)
            TableColumn(t("archivos.permisos")) { f in
                Text(f.permisos).font(.caption).monospaced().foregroundStyle(.tertiary)
            }
            .width(100)
        }
        .contextMenu(forSelectionType: String.self) { _ in
            Button(t("archivos.descargar")) { descarga() }
            Button(t("borrar"), role: .destructive) { borrando = seleccion }
        } primaryAction: { ids in
            abre(ids)
        }
        .onKeyPress(.return) {
            abre(elegidos)
            return .handled
        }
        .onKeyPress(.space) {
            previsualiza()
            return .handled
        }
    }

    private var transferencias: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(cerebro.transferencias) { tr in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: tr.subiendo ? "arrow.up.circle" : "arrow.down.circle")
                        Text(tr.nombre).lineLimit(1)
                        Spacer()
                        if let error = tr.error {
                            Text(error).font(.caption).foregroundStyle(Color.mal).lineLimit(1)
                        } else if tr.terminada {
                            Text(t("archivos.hecho")).font(.caption).foregroundStyle(Color.bien)
                        } else {
                            Text("\(Int(tr.fraccion * 100)) %").font(.caption).monospacedDigit()
                        }
                    }
                    .help(tr.subiendo ? t("archivos.subir") : t("archivos.descargar"))
                    ProgressView(value: min(tr.fraccion, 1))
                        .tint(tr.error != nil ? Color.mal : (tr.terminada ? Color.bien : Color.accentColor))
                }
            }
        }
        .padding(12)
        .background(.background.secondary)
    }

    private var seleccion: [Fichero] { ficheros.filter { elegidos.contains($0.id) } }

    // Acciones

    /// Abre la carpeta marcada. Vale para el doble clic, para la tecla Intro y
    /// para el botón: no todo el mundo descubre el doble clic.
    private func abre(_ ids: Set<String>) {
        guard let f = ficheros.first(where: { ids.contains($0.id) }), f.carpeta else { return }
        Task { await entra(en: f.ruta) }
    }

    /// Vuelve a la última carpeta que se estaba mirando en ESTE servidor. Si es
    /// la primera vez, o la carpeta ya no existe, empieza en la del usuario.
    private func abreDondeLoDejaste() async {
        if let guardada = ultimaRutaGuardada, !guardada.isEmpty {
            ruta = guardada
            await recarga()
            if fallo == nil { return }
            fallo = nil
        }
        await vaACasa()
    }

    private var claveRuta: String? {
        cerebro.elegido.map { "ultimaRuta-\($0.id.uuidString)" }
    }

    private var ultimaRutaGuardada: String? {
        claveRuta.flatMap { UserDefaults.standard.string(forKey: $0) }
    }

    private func recuerdaRuta() {
        if let claveRuta { UserDefaults.standard.set(ruta, forKey: claveRuta) }
    }

    private func vaACasa() async {
        if Demo.activo { ruta = "/home/usuario"; await recarga(); return }
        guard let conexion = cerebro.conexionViva else { return }
        cargando = true
        defer { cargando = false }
        do {
            ruta = try await conexion.carpetaDeCasa()
            await recarga()
            recuerdaRuta()
        } catch { fallo = error.localizedDescription }
    }

    private func entra(en nueva: String) async {
        guard !nueva.isEmpty else { return }
        if !ruta.isEmpty, ruta != nueva { atras.append(ruta); adelante.removeAll() }
        await carga(nueva)
    }

    private func carga(_ nueva: String) async {
        ruta = nueva
        elegidos = []
        await recarga()
        if fallo == nil { recuerdaRuta() }
    }

    private func navegaAtras() {
        guard let destino = atras.popLast() else { return }
        if !ruta.isEmpty { adelante.append(ruta) }
        Task { await carga(destino) }
    }

    private func navegaAdelante() {
        guard let destino = adelante.popLast() else { return }
        if !ruta.isEmpty { atras.append(ruta) }
        Task { await carga(destino) }
    }

    private func recarga() async {
        fallo = nil
        if Demo.activo { ficheros = Demo.ficheros(en: ruta); return }
        guard let conexion = cerebro.conexionViva else { return }
        cargando = true
        defer { cargando = false }
        do { ficheros = try await conexion.lista(ruta) }
        catch { fallo = error.localizedDescription }
    }

    private func eligeYSube() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { cerebro.sube(url, a: ruta) }
    }

    private func descarga() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = t("archivos.guardarEn")
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let destino = panel.url else { return }
        for f in seleccion where !f.carpeta { cerebro.descarga(f, a: destino) }
    }

    /// Quick Look necesita un fichero local. Se baja a la caché con la misma
    /// barra de progreso y se borra en el siguiente arranque del sistema.
    private func previsualiza() {
        guard let fichero = seleccion.first, !fichero.carpeta, let conexion = cerebro.conexionViva else { return }
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("Atalaya-QuickLook", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let destino = base.appendingPathComponent(fichero.nombre)
        let tr = Transferencia(nombre: fichero.nombre, subiendo: false, total: fichero.tamano)
        cerebro.transferencias.append(tr)
        Task {
            do {
                try await conexion.descarga(fichero, a: destino) { hechos in
                    Task { @MainActor in tr.hechos = hechos }
                }
                tr.terminada = true
                vistaRapida = destino
            } catch { tr.error = error.localizedDescription }
        }
    }

    private func crea() {
        let nombre = nombreNuevo.trimmingCharacters(in: .whitespaces)
        nombreNuevo = ""
        guard !nombre.isEmpty, let conexion = cerebro.conexionViva else { return }
        Task {
            do { try await conexion.creaCarpeta("\(ruta)/\(nombre)"); await recarga() }
            catch { fallo = error.localizedDescription }
        }
    }

    private func renombra() {
        guard let f = renombrando, let conexion = cerebro.conexionViva else { return }
        let nombre = nombreNuevo.trimmingCharacters(in: .whitespaces)
        renombrando = nil
        guard !nombre.isEmpty, nombre != f.nombre else { return }
        Task {
            do {
                try await conexion.renombra(f.ruta, a: "\((f.ruta as NSString).deletingLastPathComponent)/\(nombre)")
                await recarga()
            } catch { fallo = error.localizedDescription }
        }
    }

    private func borra() {
        let lista = borrando
        borrando = []
        guard let conexion = cerebro.conexionViva else { return }
        Task {
            for f in lista {
                do { try await conexion.borra(f) }
                catch { fallo = error.localizedDescription }
            }
            elegidos = []
            await recarga()
        }
    }
}
