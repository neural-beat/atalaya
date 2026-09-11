// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import SwiftUI

/// Los colores de estado no pueden salir del acento del sistema: si alguien
/// tiene el Mac en rojo, "conectado" y "roto" se ven igual.
extension Color {
    static let bien = Color(red: 0.16, green: 0.72, blue: 0.55)
    static let ojo = Color(red: 0.72, green: 0.48, blue: 0.95)
    static let mal = Color(red: 0.90, green: 0.29, blue: 0.31)
}

@main
struct AtalayaApp: App {
    @State private var cerebro = Cerebro()
    @State private var lengua = Lengua.compartida
    @AppStorage("bienvenidaVista") private var bienvenidaVista = false

    var body: some Scene {
        Window("Atalaya", id: "principal") {
            Group {
                if !bienvenidaVista {
                    Bienvenida {
                        bienvenidaVista = true
                        cerebro.sitio = .servidores
                        cerebro.pedirPrimerServidor = cerebro.perfiles.isEmpty
                    }
                } else {
                    Principal()
                }
            }
            .environment(cerebro)
            .environment(lengua)
            .frame(minWidth: 900, minHeight: 560)
            .onAppear { if let p = cerebro.elegido { cerebro.conecta(a: p) } }
            .onAppear { if Demo.activo { bienvenidaVista = true } }
            .onAppear { Actualizador.compartido.miraSiTocaSolo() }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(t("acerca")) { AcercaDe.abre() }
            }
            CommandGroup(after: .toolbar) {
                Button(t("idioma") + ": " + (lengua.idioma == .es ? "English" : "Español")) {
                    lengua.idioma = lengua.idioma == .es ? .en : .es
                }
            }
        }

        MenuBarExtra {
            MenuBarra().environment(cerebro).environment(lengua)
        } label: {
            if let l = cerebro.lectura {
                Text("\(Int(l.cpu))% · \(Int(l.memoriaTotal > 0 ? l.memoriaUsada / l.memoriaTotal * 100 : 0))%")
            } else {
                Image(systemName: "binoculars")
            }
        }
    }
}

struct Principal: View {
    @Environment(Cerebro.self) private var cerebro

    var body: some View {
        @Bindable var c = cerebro
        NavigationSplitView {
            List(selection: $c.sitio) {
                Section(cerebro.elegido?.nombre ?? "Atalaya") {
                    ForEach(Cerebro.Sitio.visibles) { sitio in
                        Label(t(sitio == .instalar ? "instalador" : sitio.rawValue), systemImage: sitio.icono)
                            .tag(sitio)
                            .help(t(sitio == .instalar ? "instalar.ayuda" : sitio.rawValue))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 195, ideal: 210)
            .safeAreaInset(edge: .bottom) { Pie() }
        } detail: {
            VStack(spacing: 0) {
                if Edicion.variosServidores { PestañasServidores() }
                Group {
                    switch cerebro.sitio {
                    case .tablero: Tablero()
                    case .archivos: PanelArchivos()
                    case .instalar: PanelInstalar()
                    case .contenedores: PanelContenedores()
                    case .servicios: PanelServicios()
                    case .guiones: PanelGuiones()
                    case .actualizaciones: PanelActualizaciones()
                    case .servidores: PanelServidores()
                    }
                }
            }
            .navigationTitle(t(cerebro.sitio == .instalar ? "instalador" : cerebro.sitio.rawValue))
            .toolbar {
                ToolbarItem(placement: .primaryAction) { RuedaAjustes() }
            }
        }
    }
}

/// Pestañas de servidor. Cada cambio conserva disposición y última carpeta
/// porque ambos estados se guardan con el UUID del perfil.
struct PestañasServidores: View {
    @Environment(Cerebro.self) private var cerebro

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(cerebro.perfiles) { perfil in
                    Button {
                        if cerebro.elegido?.id != perfil.id { cerebro.conecta(a: perfil) }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(cerebro.elegido?.id == perfil.id && cerebro.conectado ? Color.bien : .secondary)
                                .frame(width: 6, height: 6)
                            Text(perfil.nombre).lineLimit(1)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(cerebro.elegido?.id == perfil.id ? Color.primary.opacity(0.08) : .clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .help("\(perfil.nombre) · \(perfil.etiqueta):\(perfil.puerto)")
                }
            }.padding(.horizontal, 10).padding(.vertical, 6)
        }
        .background(.bar)
        Divider()
    }
}

struct Pie: View {
    @Environment(Cerebro.self) private var cerebro

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Divider()
            HStack(spacing: 6) {
                Circle().fill(cerebro.conectado ? Color.bien : Color.mal).frame(width: 6, height: 6)
                Text(cerebro.elegido?.etiqueta ?? "—").font(.caption).lineLimit(1)
            }
            if cerebro.primeraVisita {
                Text(t("conexion.primera")).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let fallo = cerebro.fallo, !cerebro.conectado {
                Text(fallo).font(.caption2).foregroundStyle(.red).lineLimit(3)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 10).padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MenuBarra: View {
    @Environment(Cerebro.self) private var cerebro
    @Environment(\.openWindow) private var abre

    var body: some View {
        if let l = cerebro.lectura {
            Text("\(t("cpu")) \(Int(l.cpu))% · \(t("memoria")) \(humano(l.memoriaUsada))")
            Text("\(t("encendido")) \(reloj(l.encendido))")
            Divider()
            ForEach(cerebro.contenedores.prefix(12)) { c in
                Button("\(c.vivo ? "●" : "○")  \(c.nombre)") {
                    Task { await cerebro.docker(c.nombre, c.vivo ? "stop" : "start") }
                }
            }
            Divider()
            ForEach(l.discos) { d in
                Text("\(d.nombre): \(Int(d.pct))% · \(humano(d.libre))")
            }
        } else {
            Text(t("sinDatos"))
        }
        Divider()
        Button(Lengua.compartida.idioma == .es ? "Abrir Atalaya" : "Open Atalaya") { abre(id: "principal") }
        if case .hayNueva(let version, _) = Actualizador.compartido.estado {
            Button("\(t("act.hay")): \(version)") { AcercaDe.abre() }
        }
        Button(t("acerca")) { AcercaDe.abre() }
        Toggle(t("arranque"), isOn: Binding(
            get: { Arranque.activo },
            set: { _ = Arranque.pon($0) }))
        Divider()
        Button(Lengua.compartida.idioma == .es ? "Salir" : "Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// Todo lo que no es del servidor: idioma, arranque con el sistema,
/// actualizaciones e información. Vive detrás de la rueda dentada porque se
/// toca una vez y no se vuelve a mirar.
struct RuedaAjustes: View {
    @Environment(Lengua.self) private var lengua
    @State private var abierto = false
    @State private var actualizador = Actualizador.compartido
    @State private var arranque = Arranque.activo
    @State private var falloArranque: String?

    var body: some View {
        Button { abierto.toggle() } label: { Image(systemName: "gearshape") }
            .help(t("ajustes.titulo"))
            .popover(isPresented: $abierto, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(t("idioma")).font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: Binding(get: { lengua.idioma }, set: { lengua.idioma = $0 })) {
                            ForEach(Idioma.allCases) { Text($0.nombre).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 5) {
                        Toggle(t("arranque"), isOn: Binding(
                            get: { arranque },
                            set: { nuevo in
                                falloArranque = Arranque.pon(nuevo)
                                arranque = Arranque.activo
                            }))
                        .toggleStyle(.switch)
                        .disabled(Arranque.esCopiaTemporal)
                        Text(Arranque.esCopiaTemporal ? t("arranque.copiaTemporal") : t("arranque.ayuda"))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let falloArranque {
                            Text(falloArranque).font(.caption).foregroundStyle(Color.mal)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button(t("act.buscar")) { Task { await actualizador.mira() } }
                            if case .mirando = actualizador.estado { ProgressView().controlSize(.small) }
                        }
                        switch actualizador.estado {
                        case .alDia(let v):
                            Text("\(t("act.alDia")) (\(v))").font(.caption).foregroundStyle(.secondary)
                        case .hayNueva(let version, let enlace):
                            Text("\(t("act.hay")): \(version)").font(.caption).bold()
                            Link(t("act.descargar"), destination: enlace).font(.caption)
                        case .fallo(let mensaje):
                            Text("\(t("act.fallo")): \(mensaje)").font(.caption)
                                .foregroundStyle(.secondary).lineLimit(2)
                        default:
                            Text(t("act.aviso")).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    Button(t("bienvenida.volverAVer")) {
                        abierto = false
                        UserDefaults.standard.set(false, forKey: "bienvenidaVista")
                    }
                    Button(t("acerca")) { abierto = false; AcercaDe.abre() }
                }
                .padding(16)
                .frame(width: 300)
            }
    }
}

/// Pantalla de primer arranque: qué es, qué hace y qué no hace.
struct Bienvenida: View {
    var seguir: () -> Void
    @Environment(Lengua.self) private var lengua
    @State private var arranque = Arranque.activo

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Picker("", selection: Binding(get: { lengua.idioma }, set: { lengua.idioma = $0 })) {
                    ForEach(Idioma.allCases) { Text($0.nombre).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 180)
            }
            .padding(14)

            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 46)).foregroundStyle(.tint)
                    Text(t("bienvenida.titulo")).font(.largeTitle).bold()
                    Text(t("bienvenida.lema")).font(.title3).foregroundStyle(.secondary)
                    Text(t("bienvenida.que"))
                        .multilineTextAlignment(.center).frame(maxWidth: 480)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        punto("eye", t("bienvenida.p1.titulo"), t("bienvenida.p1.texto"))
                        punto("square.grid.2x2", t("bienvenida.p2.titulo"), t("bienvenida.p2.texto"))
                        punto("terminal", t("bienvenida.p3.titulo"), t("bienvenida.p3.texto"))
                        // La edición pública todavía no trae SFTP: no se anuncia.
                        if Edicion.archivos {
                            punto("folder", t("bienvenida.p4.titulo"), t("bienvenida.p4.texto"))
                        }
                    }
                    .frame(maxWidth: 520)

                    Label(t("bienvenida.privacidad"), systemImage: "lock.shield")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: 500).multilineTextAlignment(.leading)

                    VStack(spacing: 6) {
                        Toggle(t("arranque"), isOn: Binding(
                            get: { arranque },
                            set: { nuevo in
                                _ = Arranque.pon(nuevo)
                                arranque = Arranque.activo
                            }))
                        .toggleStyle(.switch)
                        .disabled(Arranque.esCopiaTemporal)
                        if Arranque.esCopiaTemporal {
                            Text(t("arranque.copiaTemporal")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 420)

                    Button(t("bienvenida.empezar"), action: seguir)
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    Text(t("bienvenida.despues")).font(.caption).foregroundStyle(.secondary)

                    Text("\(Info.autor) · \(Info.licencia)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 40).padding(.bottom, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private func punto(_ icono: String, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icono).font(.title3).foregroundStyle(.tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).bold()
                Text(texto).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

/// Ventana de información: quién la hace, con qué licencia y dónde vive.
struct AcercaDe: View {
    @Environment(Lengua.self) private var lengua
    @State private var actualizador = Actualizador.compartido

    static func abre() {
        let ventana = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        ventana.title = ""
        ventana.titlebarAppearsTransparent = true
        ventana.isReleasedWhenClosed = false
        ventana.center()
        ventana.contentView = NSHostingView(rootView: AcercaDe().environment(Lengua.compartida))
        ventana.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "binoculars.fill").font(.system(size: 40)).foregroundStyle(.tint)
            Text(Info.nombre).font(.title).bold()
            Text(t("bienvenida.lema")).font(.callout).foregroundStyle(.secondary)

            VStack(spacing: 6) {
                fila(t("acerca.version"), "\(Info.version) (\(Info.compilacion))")
                fila(t("acerca.autor"), Info.autor)
                fila(t("acerca.licencia"), Info.licencia)
            }
            .frame(maxWidth: 300)

            Link(t("acerca.repo"), destination: Info.url)
            Text(t("acerca.gracias"))
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 320)

            Picker(t("idioma"), selection: Binding(get: { lengua.idioma }, set: { lengua.idioma = $0 })) {
                ForEach(Idioma.allCases) { Text($0.nombre).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 200)

            Divider().frame(width: 260)

            VStack(spacing: 6) {
                switch actualizador.estado {
                case .mirando:
                    ProgressView().controlSize(.small)
                case .alDia(let v):
                    Text("\(t("act.alDia")) (\(v))").font(.caption).foregroundStyle(.secondary)
                case .hayNueva(let version, let enlace):
                    Text("\(t("act.hay")): \(version)").font(.callout).bold()
                    Link(t("act.descargar"), destination: enlace)
                case .fallo(let mensaje):
                    Text("\(t("act.fallo")): \(mensaje)").font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).lineLimit(2)
                case .reposo:
                    EmptyView()
                }
                Button(t("act.buscar")) { Task { await actualizador.mira() } }
                Text(t("act.aviso")).font(.caption2).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center).frame(maxWidth: 320)
            }
        }
        .padding(26)
        .frame(width: 420, height: 520)
    }

    private func fila(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).monospaced()
        }
        .font(.caption)
    }
}
