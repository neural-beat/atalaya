// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat
//
// Dibuja Atalaya.icns. El icono es la torre de vigía: una atalaya con su
// almena y una luz encendida, sobre el azul de la noche. A 16 px sigue
// leyéndose como una torre porque la silueta es maciza y el hueco de la luz
// es lo único que la rompe.

import AppKit

let tamanos = [16, 32, 64, 128, 256, 512, 1024]
let salida = "build/Atalaya.iconset"
try? FileManager.default.createDirectory(atPath: salida, withIntermediateDirectories: true)

func dibuja(tamano: Int) -> NSImage {
    let s = CGFloat(tamano)
    let imagen = NSImage(size: NSSize(width: s, height: s))
    imagen.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { imagen.unlockFocus(); return imagen }

    // Fondo: superelipse redondeada, como el resto de iconos del sistema.
    let margen = s * 0.085
    let caja = CGRect(x: margen, y: margen, width: s - margen * 2, height: s - margen * 2)
    let radio = caja.width * 0.2237
    let fondo = NSBezierPath(roundedRect: caja, xRadius: radio, yRadius: radio)

    ctx.saveGState()
    fondo.addClip()
    let cielo = [NSColor(calibratedRed: 0.09, green: 0.16, blue: 0.30, alpha: 1).cgColor,
                 NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.12, alpha: 1).cgColor]
    let degradado = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: cielo as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(degradado,
                           start: CGPoint(x: caja.minX, y: caja.maxY),
                           end: CGPoint(x: caja.maxX, y: caja.minY),
                           options: [])

    // El haz de luz sale de la ventana hacia arriba a la derecha. Es lo que
    // convierte la torre en atalaya: no solo mira, avisa.
    let haz = NSBezierPath()
    let foco = CGPoint(x: caja.midX, y: caja.minY + caja.height * 0.60)
    haz.move(to: foco)
    haz.line(to: CGPoint(x: caja.maxX, y: caja.minY + caja.height * 0.92))
    haz.line(to: CGPoint(x: caja.maxX, y: caja.minY + caja.height * 0.50))
    haz.close()
    NSColor(calibratedRed: 1, green: 0.85, blue: 0.45, alpha: 0.16).setFill()
    haz.fill()
    ctx.restoreGState()

    // La torre: tronco que se estrecha hacia arriba, con almenas.
    let anchoAbajo = caja.width * 0.46
    let anchoArriba = caja.width * 0.30
    let base = caja.minY + caja.height * 0.16
    let alto = caja.height * 0.50
    let torre = NSBezierPath()
    torre.move(to: CGPoint(x: caja.midX - anchoAbajo / 2, y: base))
    torre.line(to: CGPoint(x: caja.midX - anchoArriba / 2, y: base + alto))
    torre.line(to: CGPoint(x: caja.midX + anchoArriba / 2, y: base + alto))
    torre.line(to: CGPoint(x: caja.midX + anchoAbajo / 2, y: base))
    torre.close()
    NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
    torre.fill()

    // Almenas: tres dientes. A 16 px se funden en una franja, que sigue
    // leyéndose como el remate de una torre.
    let anchoAlmena = caja.width * 0.42
    let altoAlmena = caja.height * 0.09
    let cornisa = CGRect(x: caja.midX - anchoAlmena / 2, y: base + alto,
                         width: anchoAlmena, height: altoAlmena * 0.55)
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    NSBezierPath(rect: cornisa).fill()

    if tamano >= 32 {
        let diente = anchoAlmena / 5
        for i in 0..<3 {
            let x = cornisa.minX + diente * CGFloat(i * 2)
            NSBezierPath(rect: CGRect(x: x, y: cornisa.maxY, width: diente, height: altoAlmena * 0.7)).fill()
        }
    }

    // La ventana encendida.
    let luz = CGRect(x: caja.midX - caja.width * 0.055,
                     y: base + alto * 0.52,
                     width: caja.width * 0.11, height: caja.height * 0.13)
    NSColor(calibratedRed: 1, green: 0.80, blue: 0.35, alpha: 1).setFill()
    NSBezierPath(roundedRect: luz, xRadius: luz.width * 0.35, yRadius: luz.width * 0.35).fill()

    imagen.unlockFocus()
    return imagen
}

for tamano in tamanos {
    let imagen = dibuja(tamano: tamano)
    guard let tiff = imagen.tiffRepresentation,
          let mapa = NSBitmapImageRep(data: tiff),
          let png = mapa.representation(using: .png, properties: [:]) else { continue }
    let nombre = tamano == 1024 ? "icon_512x512@2x.png" : "icon_\(tamano)x\(tamano).png"
    try? png.write(to: URL(fileURLWithPath: "\(salida)/\(nombre)"))
    if tamano <= 512 {
        let dobles = dibuja(tamano: tamano * 2)
        if let t2 = dobles.tiffRepresentation, let m2 = NSBitmapImageRep(data: t2),
           let p2 = m2.representation(using: .png, properties: [:]) {
            try? p2.write(to: URL(fileURLWithPath: "\(salida)/icon_\(tamano)x\(tamano)@2x.png"))
        }
    }
}
print("iconset escrito en \(salida)")
