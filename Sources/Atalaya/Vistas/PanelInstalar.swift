// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import SwiftUI

struct PanelInstalar: View {
    @Environment(Cerebro.self) private var cerebro
    @State private var url = ""
    @State private var analisis: AnalisisRepositorio?
    @State private var trabajando = false
    @State private var salida = ""
    @State private var fallo: String?
    @State private var confirma = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("instalar.ayuda")).foregroundStyle(.secondary)
                HStack {
                    TextField("https://github.com/usuario/proyecto", text: $url)
                        .textFieldStyle(.roundedBorder)
                        .help(t("instalar.ayuda"))
                    Button(t("instalar.analizar")) { Task { await analiza() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(url.isEmpty || trabajando || !cerebro.conectado)
                        .help(t("instalar.ayuda"))
                }
                if trabajando { ProgressView().controlSize(.small) }
                if let fallo { Text(fallo).foregroundStyle(Color.mal) }

                if let a = analisis {
                    HStack(alignment: .top, spacing: 14) {
                        resumen(t("instalar.imagenes"), a.imagenes)
                        resumen(t("instalar.puertos"), a.puertos)
                        resumen(t("instalar.ocupados"), a.ocupados, peligro: !a.ocupados.isEmpty)
                        resumen("Variables", a.variables)
                    }
                    Text(t("instalar.aviso")).font(.callout).foregroundStyle(Color.ojo)
                    GroupBox("docker compose") {
                        ScrollView([.vertical, .horizontal]) {
                            Text(a.compose).font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(minHeight: 260)
                    }
                    Button(t("instalar.levantar")) { confirma = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!a.ocupados.isEmpty || trabajando)
                        .help(a.ocupados.isEmpty ? t("instalar.levantar") : t("instalar.ocupados"))
                }
                if !salida.isEmpty {
                    GroupBox(t("registro")) {
                        Text(salida).font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.padding(16)
        }
        .alert(t("instalar.levantar"), isPresented: $confirma) {
            Button(t("cancelar"), role: .cancel) {}
            Button(t("instalar.levantar"), role: .destructive) { instala() }
        } message: { Text(t("instalar.aviso")) }
    }

    private func resumen(_ titulo: String, _ valores: [String], peligro: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.caption).foregroundStyle(.secondary)
            Text(valores.isEmpty ? "—" : valores.joined(separator: "\n"))
                .font(.caption).monospaced().foregroundStyle(peligro ? Color.mal : .primary)
        }.frame(maxWidth: .infinity, alignment: .leading).help(titulo)
    }

    private func analiza() async {
        guard let conexion = cerebro.conexionViva else { return }
        trabajando = true; fallo = nil; analisis = nil; salida = ""
        do { analisis = try await conexion.analizaRepositorio(url) }
        catch { fallo = error.localizedDescription }
        trabajando = false
    }

    private func instala() {
        guard let conexion = cerebro.conexionViva, let analisis else { return }
        trabajando = true; salida = ""
        Task {
            do { for try await linea in conexion.instala(analisis) { salida += linea + "\n" } }
            catch { fallo = error.localizedDescription }
            trabajando = false
            await cerebro.refrescaListas()
        }
    }
}
