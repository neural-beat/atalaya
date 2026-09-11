// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import ServiceManagement

/// Abrir Atalaya al iniciar sesión. Se registra con SMAppService, así que
/// aparece en Ajustes del Sistema › Elementos de inicio y la persona puede
/// quitarlo desde ahí aunque no abra la app.
enum Arranque {
    /// macOS ejecuta una app en cuarentena desde una copia de usar y tirar en
    /// AppTranslocation. Registrar eso guardaría una ruta que deja de existir,
    /// así que mejor no dejarlo y decir por qué.
    static var esCopiaTemporal: Bool {
        Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    static var activo: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func pon(_ encendido: Bool) -> String? {
        if esCopiaTemporal {
            return "Mueve Atalaya a la carpeta Aplicaciones antes de activarlo."
        }
        do {
            if encendido {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
