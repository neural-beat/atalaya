// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import Foundation

/// Qué partes de la app están encendidas.
///
/// La primera versión pública sale con lo que ya está probado de verdad:
/// tablero, contenedores, servicios, scripts y actualizaciones. Los ficheros
/// por SFTP, instalar cosas desde un repositorio y varios servidores a la vez
/// funcionan, pero les falta rodaje contra máquinas que no sean la nuestra, así
/// que viajan apagados hasta la 0.2.
///
/// Se compila con todo encendido así:
///     ./build.sh --completa
enum Edicion {
    #if COMPLETA
    static let completa = true
    #else
    static let completa = false
    #endif

    static var archivos: Bool { completa }
    static var instalar: Bool { completa }
    static var variosServidores: Bool { completa }

    static var nombre: String { completa ? "completa" : "pública" }
}
