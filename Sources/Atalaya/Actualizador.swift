// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import Foundation
import Observation

/// Pregunta a GitHub si hay una versión más nueva. Nunca descarga ni instala
/// nada por su cuenta: enseña qué hay y abre la página de descargas si la
/// persona quiere. Solo mira cuando se lo piden, o una vez al día.
@MainActor
@Observable
final class Actualizador {
    static let compartido = Actualizador()

    enum Estado: Equatable {
        case reposo, mirando, alDia(String), hayNueva(version: String, url: URL), fallo(String)
    }

    var estado: Estado = .reposo

    private struct Publicacion: Decodable {
        let tag_name: String
        let html_url: String
        let draft: Bool
        let prerelease: Bool
    }

    /// Mira como mucho una vez al día, para no molestar a la API de GitHub.
    func miraSiTocaSolo() {
        let clave = "ultimaComprobacion"
        let ultima = UserDefaults.standard.double(forKey: clave)
        guard Date().timeIntervalSince1970 - ultima > 86_400 else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: clave)
        Task { await mira() }
    }

    func mira() async {
        estado = .mirando
        let url = URL(string: "https://api.github.com/repos/\(Info.repositorio)/releases/latest")!
        var peticion = URLRequest(url: url)
        peticion.timeoutInterval = 15
        peticion.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never

        do {
            let (datos, respuesta) = try await URLSession(configuration: config).data(for: peticion)
            if let http = respuesta as? HTTPURLResponse, http.statusCode == 404 {
                estado = .alDia(Info.version)   // todavía no hay ninguna publicación
                return
            }
            let publicacion = try JSONDecoder().decode(Publicacion.self, from: datos)
            guard !publicacion.draft, !publicacion.prerelease else { estado = .alDia(Info.version); return }
            let nueva = publicacion.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            if esMasNueva(nueva, que: Info.version), let enlace = URL(string: publicacion.html_url) {
                estado = .hayNueva(version: nueva, url: enlace)
            } else {
                estado = .alDia(Info.version)
            }
        } catch {
            estado = .fallo(error.localizedDescription)
        }
    }

    /// Compara 1.2.10 con 1.2.9 por números, no por texto.
    private func esMasNueva(_ a: String, que b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let ai = i < x.count ? x[i] : 0, bi = i < y.count ? y[i] : 0
            if ai != bi { return ai > bi }
        }
        return false
    }
}
