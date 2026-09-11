// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import Charts
import SwiftUI

/// Cuánto ocupa una tarjeta, medido en columnas.
struct Ancho: LayoutValueKey {
    static let defaultValue: Int = 1
}

extension View {
    func ancho(_ columnas: Int) -> some View { layoutValue(key: Ancho.self, value: columnas) }
}

/// Rejilla de cuatro columnas donde cada tarjeta ocupa una, dos o cuatro.
/// Hace falta una disposición propia: LazyVGrid no deja que un elemento ocupe
/// varias columnas, que es justo lo que pide poder agrandar una tarjeta.
struct Rejilla: Layout {
    var columnas = 4
    var hueco: CGFloat = 14

    private func reparte(_ subvistas: Subviews, ancho: CGFloat) -> [[(Int, Int)]] {
        let unidad = (ancho - hueco * CGFloat(columnas - 1)) / CGFloat(columnas)
        var filas: [[(Int, Int)]] = [[]]
        var ocupado = 0
        for (i, sub) in subvistas.enumerated() {
            let columnas_ = min(max(sub[Ancho.self], 1), columnas)
            if ocupado + columnas_ > columnas { filas.append([]); ocupado = 0 }
            filas[filas.count - 1].append((i, columnas_))
            ocupado += columnas_
        }
        _ = unidad
        return filas
    }

    private func anchoDe(_ columnas_: Int, total: CGFloat) -> CGFloat {
        let unidad = (total - hueco * CGFloat(columnas - 1)) / CGFloat(columnas)
        return unidad * CGFloat(columnas_) + hueco * CGFloat(columnas_ - 1)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? 800
        var alto: CGFloat = 0
        for fila in reparte(subviews, ancho: ancho) {
            let altoFila = fila.map { i, c in
                subviews[i].sizeThatFits(.init(width: anchoDe(c, total: ancho), height: nil)).height
            }.max() ?? 0
            alto += altoFila + hueco
        }
        return CGSize(width: ancho, height: max(0, alto - hueco))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ancho = bounds.width
        var y = bounds.minY
        for fila in reparte(subviews, ancho: ancho) {
            var x = bounds.minX
            let altoFila = fila.map { i, c in
                subviews[i].sizeThatFits(.init(width: anchoDe(c, total: ancho), height: nil)).height
            }.max() ?? 0
            for (i, c) in fila {
                let w = anchoDe(c, total: ancho)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: .init(width: w, height: altoFila))
                x += w + hueco
            }
            y += altoFila + hueco
        }
    }
}

/// Qué tarjetas hay, en qué orden y de qué tamaño. Se guarda en el Mac.
struct Disposicion: Codable {
    var fichas: [Ficha]

    struct Ficha: Codable, Identifiable, Hashable {
        var id: String
        var ancho: Int
        var fijada: Bool? = false
        var estaFijada: Bool { fijada == true }
    }

    static let deFabrica = Disposicion(fichas: [
        .init(id: "cpu", ancho: 1), .init(id: "memoria", ancho: 1),
        .init(id: "temperatura", ancho: 1), .init(id: "encendido", ancho: 1),
        .init(id: "red", ancho: 2), .init(id: "carga", ancho: 2),
        .init(id: "discos", ancho: 2), .init(id: "contenedores", ancho: 2),
        .init(id: "servicios", ancho: 4),
    ])

    static func guardada(servidor: UUID?) -> Disposicion {
        let clave = servidor.map { "disposicion-\($0.uuidString)" } ?? "disposicion"
        guard let d = UserDefaults.standard.data(forKey: clave),
              let v = try? JSONDecoder().decode(Disposicion.self, from: d), !v.fichas.isEmpty
        else { return .deFabrica }
        // Si en una versión nueva aparecen tarjetas que antes no existían, se añaden al final.
        var fichas = v.fichas
        for f in deFabrica.fichas where !fichas.contains(where: { $0.id == f.id }) { fichas.append(f) }
        return Disposicion(fichas: fichas)
    }

    func guarda(servidor: UUID?) {
        let clave = servidor.map { "disposicion-\($0.uuidString)" } ?? "disposicion"
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: clave)
    }

    @discardableResult
    mutating func mueve(_ origen: String, antesDe destino: String) -> Bool {
        guard let desde = fichas.firstIndex(where: { $0.id == origen }),
              let hasta = fichas.firstIndex(where: { $0.id == destino }),
              desde != hasta, !fichas[desde].estaFijada, !fichas[hasta].estaFijada else { return false }
        let ficha = fichas.remove(at: desde)
        let nuevaPosicion = fichas.firstIndex(where: { $0.id == destino }) ?? fichas.endIndex
        fichas.insert(ficha, at: nuevaPosicion)
        return true
    }
}

struct Tablero: View {
    @Environment(Cerebro.self) private var cerebro
    @State private var disposicion = Disposicion.deFabrica
    @State private var arrastrada: String?

    var body: some View {
        ScrollView {
            if let l = cerebro.lectura {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("tablero.ayuda")).font(.caption).foregroundStyle(.secondary)
                    Rejilla {
                        ForEach(disposicion.fichas) { ficha in
                            tarjeta(ficha, l)
                                .ancho(ficha.ancho)
                                .opacity(arrastrada == ficha.id ? 0.35 : 1)
                                .onDrag {
                                    guard !ficha.estaFijada else { return NSItemProvider() }
                                    arrastrada = ficha.id
                                    return NSItemProvider(object: ficha.id as NSString)
                                }
                                .onDrop(of: [.text], delegate: Soltar(
                                    destino: ficha.id,
                                    servidor: cerebro.elegido?.id,
                                    disposicion: $disposicion,
                                    arrastrada: $arrastrada))
                        }
                    }
                }
                .padding(16)
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(t("sinDatos")).foregroundStyle(.secondary)
                    if let fallo = cerebro.fallo {
                        Text(fallo).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    disposicion = .deFabrica
                    disposicion.guarda(servidor: cerebro.elegido?.id)
                } label: { Label("Reiniciar tablero", systemImage: "rectangle.3.group") }
                .help(Lengua.compartida.idioma == .es ? "Volver al tablero de fábrica" : "Reset the dashboard")
            }
        }
        .onAppear { disposicion = .guardada(servidor: cerebro.elegido?.id) }
        .onChange(of: cerebro.elegido?.id) { _, id in disposicion = .guardada(servidor: id) }
    }

    @ViewBuilder
    private func tarjeta(_ ficha: Disposicion.Ficha, _ l: Lectura) -> some View {
        let grande = ficha.ancho >= 2
        switch ficha.id {
        case "cpu":
            Medida(ficha: ficha, titulo: t("cpu"), valor: String(format: "%.1f", l.cpu), unidad: "%",
                   pie: "\(l.nucleos) \(Lengua.compartida.idioma == .es ? "núcleos" : "cores")",
                   ayuda: t("cpu.ayuda"), serie: cerebro.series["cpu"] ?? [], tope: 100,
                   grafico: grande, cambia: cambia, fija: fija)
        case "memoria":
            Medida(ficha: ficha, titulo: t("memoria"), valor: humano(l.memoriaUsada), unidad: "/ \(humano(l.memoriaTotal))",
                   pie: "\(humano(l.memoriaCache)) \(Lengua.compartida.idioma == .es ? "en caché" : "cached")",
                   ayuda: t("memoria.ayuda"), serie: cerebro.series["memoria"] ?? [], tope: 100,
                   grafico: grande, cambia: cambia, fija: fija)
        case "red":
            Medida(ficha: ficha, titulo: t("red"), valor: humano(l.bajada) + "/s", unidad: "↓",
                   pie: "↑ \(humano(l.subida))/s", ayuda: t("red.ayuda"),
                   serie: cerebro.series["red"] ?? [], tope: nil, grafico: grande, cambia: cambia, fija: fija)
        case "temperatura":
            Medida(ficha: ficha, titulo: t("temperatura"),
                   valor: l.temperatura.map { String(format: "%.0f", $0) } ?? "—", unidad: "°C",
                   pie: l.etiquetaTemperatura, ayuda: t("temperatura.ayuda"),
                   serie: cerebro.series["temperatura"] ?? [], tope: 100, grafico: grande, cambia: cambia, fija: fija)
        case "carga":
            Medida(ficha: ficha, titulo: t("carga"), valor: String(format: "%.2f", l.carga.uno),
                   unidad: "/ \(l.nucleos)",
                   pie: String(format: "5 min %.2f · 15 min %.2f", l.carga.cinco, l.carga.quince),
                   ayuda: t("carga.ayuda"), serie: cerebro.series["carga"] ?? [],
                   tope: Double(l.nucleos), grafico: grande, cambia: cambia, fija: fija)
        case "encendido":
            Marco(ficha: ficha, titulo: t("encendido"), ayuda: t("encendido.ayuda"), cambia: cambia, fija: fija) {
                Text(reloj(l.encendido)).font(.system(size: 24, weight: .medium))
                Text(l.sistema).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        case "discos":
            Marco(ficha: ficha, titulo: t("discos"), ayuda: t("disco.ayuda"), cambia: cambia, fija: fija) {
                ForEach(l.discos) { d in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(d.nombre).font(.callout)
                            Spacer()
                            Text("\(humano(d.usado)) / \(humano(d.total))")
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                        ProgressView(value: min(d.pct, 100), total: 100)
                            .tint(d.pct > 90 ? Color.mal : d.pct > 75 ? Color.ojo : Color.bien)
                    }
                }
            }
        case "contenedores":
            Marco(ficha: ficha, titulo: t("contenedores"),
                  ayuda: nil, cambia: cambia, fija: fija) {
                if cerebro.contenedores.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    Text("\(cerebro.contenedores.filter(\.vivo).count) / \(cerebro.contenedores.count)")
                        .font(.system(size: 22, weight: .medium)).monospacedDigit()
                    if ficha.ancho >= 2 {
                        ForEach(cerebro.contenedores) { c in
                            HStack(spacing: 7) {
                                Circle().fill(c.vivo ? Color.bien : Color.mal).frame(width: 6, height: 6)
                                Text(c.nombre).font(.caption).lineLimit(1)
                                Spacer()
                                Text(c.detalle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
            }
        case "servicios":
            Marco(ficha: ficha, titulo: t("servicios"), ayuda: nil, cambia: cambia, fija: fija) {
                Text("\(cerebro.servicios.filter(\.activo).count) / \(cerebro.servicios.count)")
                    .font(.system(size: 22, weight: .medium)).monospacedDigit()
                if ficha.ancho >= 2 {
                    let columnas = [GridItem(.adaptive(minimum: 190), spacing: 8)]
                    LazyVGrid(columns: columnas, alignment: .leading, spacing: 3) {
                        ForEach(cerebro.servicios) { s in
                            HStack(spacing: 7) {
                                Circle().fill(s.activo ? Color.bien : Color.mal).frame(width: 6, height: 6)
                                Text(s.nombre).font(.caption).lineLimit(1)
                            }
                        }
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private func cambia(_ ficha: Disposicion.Ficha) {
        guard let i = disposicion.fichas.firstIndex(where: { $0.id == ficha.id }) else { return }
        disposicion.fichas[i].ancho = ficha.ancho >= 4 ? 1 : (ficha.ancho == 1 ? 2 : 4)
        disposicion.guarda(servidor: cerebro.elegido?.id)
    }

    private func fija(_ ficha: Disposicion.Ficha) {
        guard let i = disposicion.fichas.firstIndex(where: { $0.id == ficha.id }) else { return }
        disposicion.fichas[i].fijada = !ficha.estaFijada
        disposicion.guarda(servidor: cerebro.elegido?.id)
    }
}

/// Recibe la tarjeta arrastrada y la coloca donde se suelta.
struct Soltar: DropDelegate {
    let destino: String
    let servidor: UUID?
    @Binding var disposicion: Disposicion
    @Binding var arrastrada: String?

    /// Reordena mientras el puntero cruza cada hueco. El contenido sigue al
    /// ratón y la posición final deja de depender de acertar al soltar.
    func dropEntered(info: DropInfo) {
        guard let origen = arrastrada,
              origen != destino else { return }
        withAnimation(.snappy(duration: 0.18)) {
            _ = disposicion.mueve(origen, antesDe: destino)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { arrastrada = nil }
        disposicion.guarda(servidor: servidor)
        return true
    }
}

/// Caja común de las tarjetas: título, botón de tamaño y explicación.
struct Marco<Contenido: View>: View {
    let ficha: Disposicion.Ficha
    let titulo: String
    var ayuda: String?
    var cambia: (Disposicion.Ficha) -> Void
    var fija: (Disposicion.Ficha) -> Void
    @ViewBuilder var contenido: Contenido
    @State private var encima = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(titulo.uppercased()).font(.caption2).bold().kerning(0.6).foregroundStyle(.secondary)
                Spacer()
                Button { cambia(ficha) } label: {
                    Image(systemName: ficha.ancho >= 4 ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                }
                .buttonStyle(.borderless)
                .opacity(encima ? 1 : 0.25)
                .help(Lengua.compartida.idioma == .es ? "Cambiar el tamaño" : "Change the size")
                Button { fija(ficha) } label: {
                    Image(systemName: ficha.estaFijada ? "pin.fill" : "pin")
                }
                .buttonStyle(.borderless)
                .opacity(encima || ficha.estaFijada ? 1 : 0.25)
                .help(ficha.estaFijada
                      ? (Lengua.compartida.idioma == .es ? "Soltar tarjeta" : "Unpin card")
                      : (Lengua.compartida.idioma == .es ? "Fijar tarjeta: no se moverá" : "Pin card: it will not move"))
            }
            contenido
            if let ayuda, ficha.ancho >= 2 {
                Text(ayuda).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(encima ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: encima ? 1 : 0.5))
        .onHover { encima = $0 }
        .help(ayuda ?? titulo)
    }
}

struct Medida: View {
    let ficha: Disposicion.Ficha
    let titulo: String, valor: String, unidad: String, pie: String, ayuda: String
    let serie: [Double], tope: Double?
    let grafico: Bool
    var cambia: (Disposicion.Ficha) -> Void
    var fija: (Disposicion.Ficha) -> Void

    var body: some View {
        Marco(ficha: ficha, titulo: titulo, ayuda: ayuda, cambia: cambia, fija: fija) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(valor).font(.system(size: 26, weight: .medium)).monospacedDigit()
                Text(unidad).font(.caption).foregroundStyle(.secondary)
            }
            if grafico, serie.count > 1 {
                Chart(Array(serie.enumerated()), id: \.offset) { punto in
                    AreaMark(x: .value("t", punto.offset), y: .value("v", punto.element))
                        .foregroundStyle(.linearGradient(colors: [.accentColor.opacity(0.35), .clear],
                                                         startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("t", punto.offset), y: .value("v", punto.element))
                        .foregroundStyle(.tint)
                        .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: 0...max(tope ?? 1, (serie.max() ?? 1) * 1.15))
                .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) }
                .frame(height: ficha.ancho >= 4 ? 150 : 78)
            }
            Text(pie).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}
