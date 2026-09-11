// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import Foundation

struct AnalisisRepositorio: Sendable {
    let url: String
    let nombre: String
    let carpeta: String
    let compose: String
    let imagenes: [String]
    let puertos: [String]
    let ocupados: [String]
    let variables: [String]
}

enum ValidadorRepositorio {
    enum Fallo: LocalizedError {
        case url, esquema
        var errorDescription: String? {
            switch self {
            case .url: "La dirección del repositorio no es válida."
            case .esquema: "Solo se admiten repositorios HTTPS o SSH de Git."
            }
        }
    }

    static func valida(_ texto: String) throws -> String {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty, !limpio.contains("\n"), !limpio.contains("\r") else { throw Fallo.url }
        guard limpio.hasPrefix("https://") || limpio.hasPrefix("ssh://") || limpio.hasPrefix("git@") else {
            throw Fallo.esquema
        }
        return limpio
    }

    static func nombre(de url: String) -> String {
        let final = url.split(separator: "/").last.map(String.init) ?? "repositorio"
        let sinGit = final.hasSuffix(".git") ? String(final.dropLast(4)) : final
        return sinGit.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "-", options: .regularExpression)
    }
}

extension Conexion {
    private func shell(_ valor: String) -> String {
        "'" + valor.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    func analizaRepositorio(_ entrada: String) async throws -> AnalisisRepositorio {
        let url = try ValidadorRepositorio.valida(entrada)
        let nombre = ValidadorRepositorio.nombre(de: url)
        let base = "/home/\(perfil.usuario)/.local/share/atalaya/apps"
        let carpeta = "\(base)/\(nombre)"
        let orden = """
        set -eu
        mkdir -p \(shell(base))
        if [ -d \(shell(carpeta))/.git ]; then
          git -C \(shell(carpeta)) fetch --quiet --all --prune
        else
          git clone --depth 1 -- \(shell(url)) \(shell(carpeta)) >/dev/null
        fi
        cd \(shell(carpeta))
        f=''
        for c in compose.yml compose.yaml docker-compose.yml docker-compose.yaml; do [ -f "$c" ] && f="$c" && break; done
        [ -n "$f" ] || { echo '@@ERROR no-compose'; exit 0; }
        echo '@@COMPOSE'
        cat "$f"
        echo '@@IMAGES'
        docker compose -f "$f" config --images 2>/dev/null || true
        echo '@@PORTS'
        docker compose -f "$f" config 2>/dev/null | awk '/published:/ {gsub(/[^0-9]/,"",$2); if($2!="") print $2}' | sort -un
        echo '@@VARS'
        grep -Eo '\\$\\{[A-Za-z_][A-Za-z0-9_]*(:-[^}]*)?\\}' "$f" | sed -E 's/^\\$\\{//;s/(:-[^}]*)?\\}$//' | sort -u || true
        echo '@@LISTEN'
        ss -lntH 2>/dev/null | awk '{split($4,a,":"); print a[length(a)]}' | sort -un
        """
        let salida = try await ejecuta(orden)
        if salida.contains("@@ERROR no-compose") { throw Fallo.comando("Ese repositorio no trae docker compose.") }
        let partes = secciones(salida)
        let puertos = partes["PORTS"] ?? []
        let escuchando = Set(partes["LISTEN"] ?? [])
        return AnalisisRepositorio(
            url: url,
            nombre: nombre,
            carpeta: carpeta,
            compose: (partes["COMPOSE"] ?? []).joined(separator: "\n"),
            imagenes: partes["IMAGES"] ?? [],
            puertos: puertos,
            ocupados: puertos.filter(escuchando.contains),
            variables: partes["VARS"] ?? [])
    }

    func instala(_ analisis: AnalisisRepositorio) -> AsyncThrowingStream<String, Error> {
        enVivo("cd \(shell(analisis.carpeta)) && docker compose up -d 2>&1")
    }

    private func secciones(_ texto: String) -> [String: [String]] {
        var resultado: [String: [String]] = [:]
        var actual = ""
        for linea in texto.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if linea.hasPrefix("@@") {
                actual = String(linea.dropFirst(2))
                resultado[actual] = []
            } else if !actual.isEmpty, !linea.isEmpty {
                resultado[actual, default: []].append(linea)
            }
        }
        return resultado
    }
}
