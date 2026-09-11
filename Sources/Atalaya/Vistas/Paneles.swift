// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import SwiftUI

struct Salida: Identifiable {
    let id = UUID()
    let titulo: String
    var texto: String
}

struct VistaSalida: View {
    let titulo: String
    let texto: String
    var cerrar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(titulo).bold()
                Spacer()
                Button(t("copiar")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(texto, forType: .string)
                }
                Button(t("cerrar"), action: cerrar)
            }
            .padding(12)
            Divider()
            ScrollView {
                Text(texto.isEmpty ? "…" : texto)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .frame(width: 780, height: 520)
    }
}

struct PanelContenedores: View {
    @Environment(Cerebro.self) private var cerebro
    @State private var salida: Salida?

    var body: some View {
        Table(cerebro.contenedores) {
            TableColumn(t("contenedores")) { c in
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.nombre).bold()
                    Text(c.imagen).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            TableColumn("") { c in
                HStack(spacing: 5) {
                    Circle().fill(c.vivo ? Color.bien : Color.mal).frame(width: 6, height: 6)
                    Text(c.detalle).font(.caption).lineLimit(1)
                }
            }
            TableColumn("Puertos") { c in
                Text(c.puertos.split(separator: ",").first.map(String.init) ?? "—")
                    .font(.caption).monospaced().lineLimit(1)
            }
            TableColumn(" ") { c in
                HStack(spacing: 8) {
                    Button { ver(c.nombre) } label: { Image(systemName: "text.alignleft") }
                        .help(t("registro"))
                    Button { Task { await cerebro.docker(c.nombre, "restart") } } label: { Image(systemName: "arrow.clockwise") }
                        .help(t("reiniciar"))
                    Button { Task { await cerebro.docker(c.nombre, c.vivo ? "stop" : "start") } } label: {
                        Image(systemName: c.vivo ? "stop.fill" : "play.fill")
                    }
                    .help(c.vivo ? t("parar") : t("arrancar"))
                }
                .buttonStyle(.borderless)
            }
        }
        .sheet(item: $salida) { s in VistaSalida(titulo: s.titulo, texto: s.texto) { salida = nil } }
        .overlay {
            if cerebro.contenedores.isEmpty {
                ContentUnavailableView(Lengua.compartida.idioma == .es ? "Sin contenedores" : "No containers",
                                       systemImage: "shippingbox",
                                       description: Text(Lengua.compartida.idioma == .es
                                                         ? "Este servidor no tiene Docker, o el usuario no puede usarlo."
                                                         : "This server has no Docker, or the user cannot use it."))
            }
        }
    }

    private func ver(_ nombre: String) {
        Task { salida = Salida(titulo: "\(t("registro")) · \(nombre)", texto: await cerebro.registro(contenedor: nombre)) }
    }
}

struct PanelServicios: View {
    @Environment(Cerebro.self) private var cerebro
    @State private var salida: Salida?

    var body: some View {
        List(cerebro.servicios) { s in
            HStack(alignment: .top, spacing: 12) {
                Circle().fill(s.activo ? Color.bien : Color.mal).frame(width: 7, height: 7).padding(.top, 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.nombre).bold()
                    Text(s.explicacion).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { ver(s.nombre) } label: { Image(systemName: "text.alignleft") }
                    .buttonStyle(.borderless).help(t("registro"))
                Button { Task { await cerebro.servicio(s.nombre, "restart") } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .disabled(s.nombre.hasPrefix("ssh"))
                    .help(s.nombre.hasPrefix("ssh")
                          ? (Lengua.compartida.idioma == .es ? "ssh no se toca: te quedarías fuera" : "ssh stays put: you would lock yourself out")
                          : t("reiniciar"))
            }
            .help("\(s.nombre): \(s.explicacion)")
            .padding(.vertical, 3)
        }
        .sheet(item: $salida) { s in VistaSalida(titulo: s.titulo, texto: s.texto) { salida = nil } }
    }

    private func ver(_ nombre: String) {
        Task { salida = Salida(titulo: "\(t("registro")) · \(nombre)", texto: await cerebro.registro(servicio: nombre)) }
    }
}

struct PanelGuiones: View {
    @Environment(Cerebro.self) private var cerebro
    @State private var texto = ""
    @State private var corriendo: String?
    @State private var tarea: Task<Void, Never>?

    private let columnas = [GridItem(.adaptive(minimum: 300), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("guiones.ayuda")).font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: columnas, spacing: 14) {
                        ForEach(cerebro.guiones) { g in
                        VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(g.nombre).bold()
                                    Spacer()
                                    if g.necesitaRoot {
                                        Text(t("guiones.root")).font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.ojo.opacity(0.18), in: .capsule)
                                    }
                                }
                                Text(g.explicacion).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(g.ruta).font(.caption2).monospaced().foregroundStyle(.tertiary).lineLimit(1)
                                Spacer(minLength: 0)
                                Button(t("ejecutar")) { lanza(g) }
                                    .buttonStyle(.borderedProminent)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(.background.secondary, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                            .help("\(g.nombre): \(g.explicacion)")
                        }
                    }
                }
                .padding(16)
            }
            .overlay {
                if cerebro.guiones.isEmpty {
                    ContentUnavailableView(t("guiones.vacio"), systemImage: "terminal")
                }
            }

            if corriendo != nil || !texto.isEmpty {
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        Text(corriendo ?? "").bold()
                        if corriendo != nil { ProgressView().controlSize(.small) }
                        Spacer()
                        Button(t("copiar")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(texto, forType: .string)
                        }
                        Button(t("cerrar")) { tarea?.cancel(); corriendo = nil; texto = "" }
                    }
                    .padding(10)
                    ScrollViewReader { lector in
                        ScrollView {
                            Text(texto).font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10).id("fin")
                        }
                        .onChange(of: texto) { _, _ in lector.scrollTo("fin", anchor: .bottom) }
                    }
                }
                .frame(height: 240)
                .background(.background.secondary)
            }
        }
    }

    private func lanza(_ g: Guion) {
        tarea?.cancel(); texto = ""; corriendo = g.nombre
        tarea = Task {
            do {
                for try await linea in cerebro.enVivo("bash \(g.ruta)", root: g.necesitaRoot) {
                    texto += linea + "\n"
                }
            } catch { texto += "\n" + error.localizedDescription }
            corriendo = nil
        }
    }
}

struct PanelActualizaciones: View {
    @Environment(Cerebro.self) private var cerebro
    @State private var marcados: Set<String> = []
    @State private var texto = ""
    @State private var instalando = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Paquete.Grupo.allCases) { grupo in
                        let lista = grupo == .seguridad
                            ? cerebro.paquetes.filter(\.seguridad)
                            : cerebro.paquetes.filter { $0.grupo == grupo && !$0.seguridad }
                        if !lista.isEmpty { caja(grupo, lista) }
                    }
                    if cerebro.paquetes.isEmpty {
                        Text(t("sinActualizaciones")).foregroundStyle(.secondary).padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
            }
            Divider()
            HStack {
                Button(marcados.isEmpty ? t("instalar") : "\(t("instalar")) (\(marcados.count))") { instala() }
                    .buttonStyle(.borderedProminent).disabled(marcados.isEmpty || instalando)
                if instalando { ProgressView().controlSize(.small) }
                Text(marcados.isEmpty ? t("nadaMarcado") : marcados.sorted().prefix(4).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button(t("buscar")) {
                    Task {
                        _ = await cerebro.lanza("sudo -n apt-get update >/dev/null 2>&1 || true")
                        await cerebro.refrescaListas()
                    }
                }
            }
            .padding(10)
            if !texto.isEmpty {
                Divider()
                ScrollView {
                    Text(texto).font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                .frame(height: 200).background(.background.secondary)
            }
        }
    }

    private func caja(_ grupo: Paquete.Grupo, _ lista: [Paquete]) -> some View {
            VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(grupo.titulo).bold()
                Text("\(lista.count)").font(.caption)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background((grupo == .seguridad ? Color.mal : Color.secondary).opacity(0.18), in: .capsule)
                Spacer()
                Button(todos(lista) ? t("quitarGrupo") : t("marcarGrupo")) {
                    if todos(lista) { lista.forEach { marcados.remove($0.nombre) } }
                    else { lista.forEach { marcados.insert($0.nombre) } }
                }
                .font(.caption)
            }
            .help("\(grupo.titulo): \(grupo.explicacion)")
            Text(grupo.explicacion).font(.caption).foregroundStyle(.secondary)
            ForEach(lista) { p in
                Toggle(isOn: Binding(
                    get: { marcados.contains(p.nombre) },
                    set: { marcado in
                        if marcado { marcados.insert(p.nombre) } else { marcados.remove(p.nombre) }
                    })) {
                    HStack {
                        Text(p.nombre).font(.callout).monospaced()
                        Text(p.version).font(.caption2).foregroundStyle(.secondary).monospaced()
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }

    private func todos(_ lista: [Paquete]) -> Bool {
        !lista.isEmpty && lista.allSatisfy { marcados.contains($0.nombre) }
    }

    private func instala() {
        instalando = true; texto = ""
        let lista = marcados.sorted().filter { $0.range(of: "^[a-z0-9][a-z0-9+.-]*$", options: .regularExpression) != nil }
        Task {
            do {
                for try await linea in cerebro.enVivo("DEBIAN_FRONTEND=noninteractive apt-get -y install --only-upgrade \(lista.joined(separator: " "))", root: true) {
                    texto += linea + "\n"
                }
            } catch { texto += "\n" + error.localizedDescription }
            marcados.removeAll()
            instalando = false
            await cerebro.refrescaListas()
        }
    }
}

struct PanelServidores: View {
    @Environment(Cerebro.self) private var cerebro
    @State private var editando: Perfil?
    @State private var nuevo = false

    var body: some View {
        List {
            ForEach(cerebro.perfiles) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.nombre).bold()
                        Text("\(p.etiqueta):\(p.puerto)").font(.caption).foregroundStyle(.secondary).monospaced()
                    }
                    Spacer()
                    if cerebro.elegido?.id == p.id {
                        Circle().fill(cerebro.conectado ? Color.bien : Color.mal).frame(width: 7, height: 7)
                    }
                    Button(cerebro.elegido?.id == p.id && cerebro.conectado ? t("conexion.conectado") : t("conexion.entrar")) {
                        cerebro.conecta(a: p)
                    }
                    .disabled(cerebro.elegido?.id == p.id && cerebro.conectado)
                    .help(cerebro.elegido?.id == p.id && cerebro.conectado ? t("conexion.conectado.ayuda") : t("conexion.entrar"))
                    Button { editando = p } label: { Image(systemName: "pencil") }.buttonStyle(.borderless)
                        .help(t("conexion.editar"))
                    Button { cerebro.borra(p) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        .help(t("conexion.borrar"))
                }
                .padding(.vertical, 3)
            }
        }
        .toolbar {
            if Edicion.variosServidores || cerebro.perfiles.isEmpty {
                ToolbarItem { Button(t("anadir")) { nuevo = true }.help(t("anadir")) }
            }
        }
        .onAppear {
            // Se llega aquí desde la bienvenida sin ningún servidor guardado:
            // mejor abrir la hoja que dejar una lista vacía y que se busque la vida.
            if cerebro.pedirPrimerServidor {
                cerebro.pedirPrimerServidor = false
                nuevo = true
            }
        }
        .sheet(isPresented: $nuevo) { HojaServidor(perfil: Perfil()) { nuevo = false } }
        .sheet(item: $editando) { p in HojaServidor(perfil: p) { editando = nil } }
        .overlay {
            if cerebro.perfiles.isEmpty {
                ContentUnavailableView {
                    Label(t("anadir"), systemImage: "server.rack")
                } description: {
                    Text(t("bienvenida.que"))
                } actions: {
                    Button(t("anadir")) { nuevo = true }.buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct HojaServidor: View {
    @Environment(Cerebro.self) private var cerebro
    @State var perfil: Perfil
    @State private var clave = ""
    @State private var sudo = ""
    var cerrar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("anadir")).font(.title3).bold()
            Form {
                TextField(t("conexion.nombre"), text: $perfil.nombre)
                TextField(t("conexion.maquina"), text: $perfil.maquina)
                TextField(t("conexion.usuario"), text: $perfil.usuario)
                TextField(t("conexion.puerto"), value: $perfil.puerto, format: .number)
                Toggle(t("conexion.llave"), isOn: $perfil.usaLlave)
                if perfil.usaLlave {
                    TextField(t("conexion.rutaLlave"), text: $perfil.rutaLlave)
                } else {
                    SecureField(t("conexion.clave"), text: $clave)
                }
                SecureField(t("conexion.sudo"), text: $sudo)
                Text(t("conexion.sudo.ayuda")).font(.caption).foregroundStyle(.secondary)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(t("cancelar"), action: cerrar)
                Button(t("conexion.guardar")) {
                    cerebro.guarda(perfil, clave: clave, sudo: sudo)
                    cerebro.conecta(a: perfil)
                    cerrar()
                }
                .buttonStyle(.borderedProminent)
                .disabled(perfil.maquina.isEmpty || perfil.usuario.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 460)
    }
}
