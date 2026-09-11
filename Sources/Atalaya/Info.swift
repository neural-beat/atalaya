// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import Foundation

enum Info {
    static let nombre = "Atalaya"
    static let autor = "neural-beat"
    static let licencia = "GPL-3.0-or-later"
    static let repositorio = "neural-beat/atalaya"
    static var url: URL { URL(string: "https://github.com/\(repositorio)")! }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
    static var compilacion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
