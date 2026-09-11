// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat
//
// Modo demostración: datos inventados para las capturas del README y para
// poder enseñar la app sin tener un servidor delante. Se enciende con la
// variable de entorno ATALAYA_DEMO=1 y no toca la red para nada.
//
// Existe por una razón práctica: las capturas de un panel de servidor enseñan
// nombres de máquina, direcciones y nombres de proyectos. Con datos falsos no
// hay que difuminar nada.

import Foundation

enum Demo {
    static var activo: Bool { ProcessInfo.processInfo.environment["ATALAYA_DEMO"] == "1" }

    static let perfil: Perfil = {
        var p = Perfil()
        p.nombre = "Servidor de casa"
        p.maquina = "192.168.1.50"
        p.usuario = "usuario"
        return p
    }()

    /// El vaivén de las gráficas de ejemplo sale del reloj, no de una variable
    /// compartida: así no hay estado mutable suelto entre tareas.
    static func lectura() -> Lectura {
        let paso = Date().timeIntervalSince1970 / 3
        var l = Lectura()
        l.cpu = 22 + sin(paso) * 11 + Double.random(in: -2...2)
        l.nucleos = 8
        l.carga = (1.9 + sin(paso / 2) * 0.5, 2.1, 1.7)
        l.memoriaTotal = 32 * 1024 * 1024 * 1024
        l.memoriaUsada = (9.4 + sin(paso / 3) * 0.6) * 1024 * 1024 * 1024
        l.memoriaCache = 14.2 * 1024 * 1024 * 1024
        l.temperatura = 44 + sin(paso / 4) * 3
        l.etiquetaTemperatura = "Package id 0"
        l.bajada = (2.4 + sin(paso) * 1.8).magnitude * 1024 * 1024
        l.subida = (0.6 + cos(paso) * 0.4).magnitude * 1024 * 1024
        l.encendido = 63 * 86400 + 4 * 3600
        l.sistema = "Debian GNU/Linux 13 (trixie)"
        l.maquina = "servidor"
        l.discos = [
            .init(punto: "/", total: 480e9, usado: 191e9, libre: 289e9),
            .init(punto: "/mnt/datos", total: 4e12, usado: 3.1e12, libre: 0.9e12),
            .init(punto: "/mnt/copias", total: 2e12, usado: 0.7e12, libre: 1.3e12),
        ]
        return l
    }

    static let contenedores: [Contenedor] = [
        .init(nombre: "nextcloud", imagen: "nextcloud:30-apache", estado: "running", detalle: "Up 6 days", puertos: "8080->80/tcp"),
        .init(nombre: "postgres", imagen: "postgres:17-alpine", estado: "running", detalle: "Up 6 days (healthy)", puertos: "5432/tcp"),
        .init(nombre: "jellyfin", imagen: "jellyfin/jellyfin:latest", estado: "running", detalle: "Up 6 days", puertos: "8096->8096/tcp"),
        .init(nombre: "vaultwarden", imagen: "vaultwarden/server", estado: "running", detalle: "Up 6 days", puertos: "8222->80/tcp"),
        .init(nombre: "homeassistant", imagen: "ghcr.io/home-assistant/home-assistant", estado: "running", detalle: "Up 2 days", puertos: "8123->8123/tcp"),
        .init(nombre: "caddy", imagen: "caddy:2-alpine", estado: "running", detalle: "Up 6 days", puertos: "443->443/tcp"),
        .init(nombre: "uptime-kuma", imagen: "louislam/uptime-kuma", estado: "running", detalle: "Up 6 days", puertos: "3001->3001/tcp"),
        .init(nombre: "backup-nocturno", imagen: "restic/restic", estado: "exited", detalle: "Exited (0) 7 hours ago", puertos: ""),
    ]

    static let servicios: [Servicio] = [
        .init(nombre: "ssh", descripcion: "OpenBSD Secure Shell server", estado: "active", subestado: "running"),
        .init(nombre: "docker", descripcion: "Docker Application Container Engine", estado: "active", subestado: "running"),
        .init(nombre: "postgresql", descripcion: "PostgreSQL RDBMS", estado: "active", subestado: "running"),
        .init(nombre: "smartd", descripcion: "Self Monitoring and Reporting Technology daemon", estado: "active", subestado: "running"),
        .init(nombre: "chrony", descripcion: "chrony, an NTP client/server", estado: "active", subestado: "running"),
        .init(nombre: "fail2ban", descripcion: "Fail2Ban Service", estado: "failed", subestado: "failed"),
        .init(nombre: "cron", descripcion: "Regular background program processing daemon", estado: "active", subestado: "running"),
        .init(nombre: "tailscaled", descripcion: "Tailscale node agent", estado: "active", subestado: "running"),
        .init(nombre: "unattended-upgrades", descripcion: "Unattended Upgrades Shutdown", estado: "active", subestado: "running"),
    ]

    static let guiones: [Guion] = [
        .init(ruta: "/home/usuario/copia-nocturna.sh",
              explicacion: "Copia /mnt/datos al disco de copias con restic y avisa por Telegram si algo falla. No borra nada del origen."),
        .init(ruta: "/home/usuario/limpiar-espacio.sh",
              explicacion: "Borra imágenes de Docker sin usar y recorta los registros del sistema a 7 días. Enseña cuánto libera antes de tocar nada."),
        .init(ruta: "/home/usuario/renovar-certificados.sh",
              explicacion: "Renueva los certificados y recarga Caddy. Se puede lanzar cuantas veces haga falta: si no toca renovar, no hace nada."),
        .init(ruta: "/home/usuario/comprobar-discos.sh",
              explicacion: "Pasa un test corto de SMART a los tres discos y escribe el resultado en discos.log. Solo informa."),
        .init(ruta: "/home/usuario/despertar-portatil.sh",
              explicacion: "Manda el paquete de Wake on LAN al portátil de casa. Si ya está encendido, no hace nada."),
        .init(ruta: "/home/usuario/reindexar-media.sh",
              explicacion: "Pide a Jellyfin que vuelva a leer la biblioteca. Útil después de mover carpetas a mano."),
    ]

    static func ficheros(en ruta: String) -> [Fichero] {
        let ahora = Date()
        func f(_ nombre: String, _ carpeta: Bool, _ tamano: UInt64, _ dias: Double, _ permisos: String) -> Fichero {
            Fichero(nombre: nombre, ruta: "\(ruta)/\(nombre)", carpeta: carpeta, tamano: tamano,
                    modificado: ahora.addingTimeInterval(-dias * 86400), permisos: permisos)
        }
        if ruta.hasSuffix("copias") {
            return [f("2026-09-08.tar.zst", false, 41_233_000_000, 1, "-rw-r--r--"),
                    f("2026-09-07.tar.zst", false, 40_881_000_000, 2, "-rw-r--r--"),
                    f("2026-09-06.tar.zst", false, 40_102_000_000, 3, "-rw-r--r--")]
        }
        return [
            f("copias", true, 0, 1, "drwxr-xr-x"),
            f("descargas", true, 0, 0.2, "drwxr-xr-x"),
            f("documentos", true, 0, 12, "drwxr-xr-x"),
            f("copia-nocturna.sh", false, 2_140, 30, "-rwxr-xr-x"),
            f("docker-compose.yml", false, 4_820, 6, "-rw-r--r--"),
            f("informe-septiembre.pdf", false, 1_820_000, 2, "-rw-r--r--"),
            f("vacaciones.mp4", false, 2_140_000_000, 40, "-rw-r--r--"),
            f("notas.md", false, 1_200, 0.1, "-rw-r--r--"),
        ]
    }

    static let paquetes: [Paquete] = [
        .init(nombre: "openssl", version: "3.5.1-1 → 3.5.2-1", seguridad: true),
        .init(nombre: "libssh2-1", version: "1.11.1-1 → 1.11.1-2", seguridad: true),
        .init(nombre: "linux-image-amd64", version: "6.12.3-1 → 6.12.5-1", seguridad: false),
        .init(nombre: "systemd", version: "257.2-1 → 257.3-1", seguridad: false),
        .init(nombre: "docker-ce", version: "29.7.2 → 29.8.0", seguridad: false),
        .init(nombre: "postgresql-17", version: "17.2-1 → 17.3-1", seguridad: false),
        .init(nombre: "libcurl4", version: "8.11.1-1 → 8.12.0-1", seguridad: false),
        .init(nombre: "python3-requests", version: "2.32.3-1 → 2.32.4-1", seguridad: false),
        .init(nombre: "curl", version: "8.11.1-1 → 8.12.0-1", seguridad: false),
    ]
}
