// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 neural-beat

import Foundation
import Observation

/// Dos idiomas, elegidos por la persona y no por el sistema: alguien puede
/// tener el Mac en inglés y pensar en español. Los textos viven en código
/// porque con dos idiomas es más fácil de leer e imposible de desincronizar.
enum Idioma: String, CaseIterable, Identifiable {
    case es, en
    var id: String { rawValue }
    var nombre: String { self == .es ? "Español" : "English" }
    static var delSistema: Idioma {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("es") ? .es : .en
    }
}

@MainActor
@Observable
final class Lengua {
    static let compartida = Lengua()
    var idioma: Idioma {
        didSet { UserDefaults.standard.set(idioma.rawValue, forKey: "idioma") }
    }
    private init() {
        idioma = UserDefaults.standard.string(forKey: "idioma").flatMap(Idioma.init) ?? .delSistema
    }
}

@MainActor
func t(_ clave: String) -> String {
    guard let par = textos[clave] else { return clave }
    return Lengua.compartida.idioma == .es ? par.0 : par.1
}

let textos: [String: (String, String)] = [
    // Navegación
    "tablero": ("Tablero", "Dashboard"),
    "contenedores": ("Contenedores", "Containers"),
    "servicios": ("Servicios", "Services"),
    "guiones": ("Scripts", "Scripts"),
    "actualizaciones": ("Actualizaciones", "Updates"),
    "servidores": ("Servidores", "Servers"),
    "archivos": ("Archivos", "Files"),
    "instalador": ("Instalar", "Install"),
    "instalar.ayuda": ("Pega la dirección de un repositorio con docker compose. Te enseña qué imágenes usa, qué puertos pide y si alguno está ocupado, antes de levantar nada.",
                       "Paste the address of a repository with a docker compose file. It shows which images it uses, which ports it wants and whether any is taken, before starting anything."),
    "instalar.analizar": ("Analizar", "Analyse"),
    "instalar.levantar": ("Instalar en el servidor", "Install on the server"),
    "instalar.aviso": ("Vas a ejecutar código de internet en tu servidor. Lee el compose antes de seguir.",
                       "You are about to run code from the internet on your server. Read the compose file first."),
    "instalar.imagenes": ("Imágenes", "Images"),
    "instalar.puertos": ("Puertos", "Ports"),
    "instalar.ocupados": ("Ya están ocupados", "Already taken"),
    "instalar.sinCompose": ("Ese repositorio no trae docker compose.", "That repository has no docker compose file."),
    "archivos.ayuda": ("Arrastra ficheros desde el Finder para subirlos. Doble clic entra en una carpeta.",
                       "Drag files from the Finder to upload them. Double-click to enter a folder."),
    "archivos.suelta": ("Suelta aquí para subir", "Drop here to upload"),
    "archivos.abrir": ("Abrir", "Open"),
    "archivos.abrir.ayuda": ("Entra en la carpeta marcada. También vale el doble clic o la tecla Intro.",
                             "Enter the selected folder. Double-click or the Return key work too."),
    "archivos.subir": ("Subir", "Upload"),
    "archivos.descargar": ("Descargar", "Download"),
    "archivos.quickLook": ("Vista rápida (barra espaciadora)", "Quick Look (Space bar)"),
    "archivos.nuevaCarpeta": ("Nueva carpeta", "New folder"),
    "archivos.renombrar": ("Renombrar", "Rename"),
    "archivos.nombre": ("Nombre", "Name"),
    "archivos.tamano": ("Tamaño", "Size"),
    "archivos.modificado": ("Modificado", "Modified"),
    "archivos.permisos": ("Permisos", "Permissions"),
    "archivos.casa": ("Ir a mi carpeta", "Go to my folder"),
    "archivos.arriba": ("Subir un nivel", "Go up one level"),
    "archivos.atras": ("Volver a la carpeta anterior", "Go back to the previous folder"),
    "archivos.adelante": ("Ir a la carpeta siguiente", "Go forward to the next folder"),
    "archivos.guardarEn": ("Guardar aquí", "Save here"),
    "archivos.hecho": ("Hecho", "Done"),
    "archivos.borrarTitulo": ("¿Borrar del servidor?", "Delete from the server?"),
    "archivos.borrarAviso": ("Esto borra en el servidor y no hay papelera: no se puede deshacer.",
                             "This deletes on the server and there is no trash: it cannot be undone."),
    "ajustes": ("Ajustes", "Settings"),

    // Bienvenida
    "bienvenida.titulo": ("Atalaya", "Atalaya"),
    "bienvenida.lema": ("Tu servidor Linux, a la vista.", "Your Linux server, in plain sight."),
    "bienvenida.que": ("Se conecta por SSH y ya está. No hay que instalar nada en el servidor: ni agente, ni panel web, ni puertos abiertos.",
                       "It connects over SSH and that is it. Nothing to install on the server: no agent, no web panel, no open ports."),
    "bienvenida.p1.titulo": ("Ves lo que pasa", "See what is going on"),
    "bienvenida.p1.texto": ("CPU, memoria, discos, temperatura y red en vivo, con contenedores y servicios.",
                            "Live CPU, memory, disks, temperature and network, plus containers and services."),
    "bienvenida.p2.titulo": ("A tu manera", "Your way"),
    "bienvenida.p2.texto": ("Arrastra las tarjetas, cámbialas de tamaño y quédate solo con lo que miras.",
                            "Drag the cards, resize them, keep only what you actually look at."),
    "bienvenida.p3.titulo": ("Tus scripts, con botón", "Your scripts, with a button"),
    "bienvenida.p4.titulo": ("Ficheros por SFTP", "Files over SFTP"),
    "bienvenida.p4.texto": ("Sube arrastrando desde el Finder, descarga con barra de progreso y ordena las carpetas del servidor.",
                            "Upload by dragging from the Finder, download with a progress bar, and tidy up the server's folders."),
    "bienvenida.p3.texto": ("Encuentra los scripts de tu carpeta y te recuerda qué hace cada uno leyendo sus comentarios.",
                            "It finds the scripts in your home folder and reminds you what each one does by reading its own comments."),
    "bienvenida.privacidad": ("Nada sale de tu Mac: la app habla solo con tu servidor. Las contraseñas van al llavero del sistema.",
                              "Nothing leaves your Mac: the app talks only to your server. Passwords go to the system keychain."),
    "bienvenida.empezar": ("Añadir mi servidor", "Add my server"),
    "bienvenida.despues": ("Todo esto se puede cambiar luego desde la rueda dentada.",
                           "All of this can be changed later from the gear menu."),
    "bienvenida.volverAVer": ("Ver la pantalla de bienvenida", "Show the welcome screen"),

    // Conexión
    "conexion.maquina": ("Servidor o IP", "Host or IP"),
    "conexion.usuario": ("Usuario", "Username"),
    "conexion.puerto": ("Puerto", "Port"),
    "conexion.clave": ("Contraseña", "Password"),
    "conexion.llave": ("Usar mi clave SSH", "Use my SSH key"),
    "conexion.rutaLlave": ("Ruta de la clave privada", "Private key path"),
    "conexion.nombre": ("Nombre para acordarte", "A name you will recognise"),
    "conexion.entrar": ("Conectar", "Connect"),
    "conexion.conectado": ("Conectado", "Connected"),
    "conexion.conectado.ayuda": ("Este servidor ya está conectado.", "This server is already connected."),
    "conexion.editar": ("Editar servidor", "Edit server"),
    "conexion.borrar": ("Borrar servidor guardado", "Delete saved server"),
    "conexion.probando": ("Conectando…", "Connecting…"),
    "conexion.guardar": ("Guardar", "Save"),
    "conexion.primera": ("Es la primera vez que te conectas a esta máquina, así que su identidad todavía no está en tu known_hosts.",
                         "This is the first time you connect to this machine, so its identity is not in your known_hosts yet."),
    "conexion.sudo": ("Contraseña para sudo (si es distinta)", "sudo password (if different)"),
    "conexion.sudo.ayuda": ("Hace falta para actualizar el sistema, reiniciar servicios o apagar. Si no la pones, se usa la de acceso.",
                            "Needed to update the system, restart services or shut down. If empty, the login password is used."),

    // Tablero
    "tablero.ayuda": ("Arrastra para reordenar. El botón de tamaño hace la tarjeta más grande, y las grandes enseñan gráfico.",
                      "Drag to reorder. The size button makes a card bigger, and big cards show a chart."),
    "cpu": ("Procesador", "CPU"),
    "cpu.ayuda": ("Cuánto trabaja ahora mismo. Si se queda alto mucho rato, algo se ha atascado.",
                  "How hard it is working right now. If it stays high for long, something is stuck."),
    "memoria": ("Memoria", "Memory"),
    "memoria.ayuda": ("Memoria en uso de verdad. La caché no cuenta: el sistema la suelta cuando hace falta.",
                      "Memory actually in use. Cache does not count: the system frees it when needed."),
    "red": ("Red", "Network"),
    "red.ayuda": ("Lo que entra y sale por segundo.", "What comes in and goes out per second."),
    "temperatura": ("Temperatura", "Temperature"),
    "temperatura.ayuda": ("Por debajo de 70 °C va sobrado; a partir de 85 °C mira los ventiladores.",
                          "Below 70 °C is comfortable; above 85 °C check the fans."),
    "carga": ("Carga", "Load"),
    "carga.ayuda": ("Procesos esperando turno. Si pasa del número de núcleos y se mantiene, el servidor va justo.",
                    "Processes waiting their turn. Above the core count for long means the server is struggling."),
    "encendido": ("Encendido", "Uptime"),
    "encendido.ayuda": ("Cuánto lleva sin reiniciarse.", "How long since the last reboot."),
    "discos": ("Discos", "Disks"),
    "disco.ayuda": ("Espacio ocupado. No dejes que el disco del sistema pase del 90 %.",
                    "Space used. Do not let the system disk go past 90 %."),
    "sinDatos": ("Conectando con el servidor…", "Connecting to the server…"),

    // Acciones comunes
    "reiniciar": ("Reiniciar", "Restart"),
    "parar": ("Parar", "Stop"),
    "arrancar": ("Arrancar", "Start"),
    "registro": ("Registro", "Log"),
    "ejecutar": ("Ejecutar", "Run"),
    "cerrar": ("Cerrar", "Close"),
    "copiar": ("Copiar", "Copy"),
    "cancelar": ("Cancelar", "Cancel"),
    "borrar": ("Borrar", "Delete"),
    "anadir": ("Añadir servidor", "Add server"),
    "instalar": ("Instalar lo marcado", "Install selected"),
    "buscar": ("Buscar novedades", "Check for updates"),
    "marcarGrupo": ("Marcar todo el grupo", "Select the whole group"),
    "quitarGrupo": ("Quitar el grupo", "Clear the group"),
    "nadaMarcado": ("Nada marcado", "Nothing selected"),
    "sinActualizaciones": ("Todo al día.", "Everything is up to date."),

    // Scripts
    "guiones.ayuda": ("Estos son los scripts que hay en tu carpeta del servidor. La explicación sale de los comentarios que escribiste dentro de cada uno.",
                      "These are the scripts in your home folder on the server. The explanation comes from the comments you wrote inside each one."),
    "guiones.vacio": ("No hay scripts en la carpeta del usuario.", "No scripts found in the user's home folder."),
    "guiones.root": ("Puede pedir sudo", "May need sudo"),

    // Acerca de
    "acerca": ("Acerca de Atalaya", "About Atalaya"),
    "acerca.autor": ("Hecho por", "Made by"),
    "acerca.licencia": ("Licencia", "Licence"),
    "acerca.repo": ("Código", "Source"),
    "acerca.version": ("Versión", "Version"),
    "acerca.gracias": ("Software libre. Si te sirve, cuéntalo; si falla, abre un issue.",
                       "Free software. If it helps you, say so; if it breaks, open an issue."),
    "idioma": ("Idioma", "Language"),
    "ajustes.titulo": ("Ajustes", "Settings"),
    "arranque": ("Abrir al iniciar sesión", "Open at login"),
    "arranque.ayuda": ("Atalaya se abrirá sola al encender el Mac. Se puede quitar también desde Ajustes del Sistema.",
                       "Atalaya will open by itself when you start the Mac. You can also remove it from System Settings."),
    "arranque.copiaTemporal": ("Mueve Atalaya a Aplicaciones para poder activarlo.",
                               "Move Atalaya to Applications to turn this on."),
    "act.buscar": ("Buscar una versión nueva", "Check for a new version"),
    "act.mirando": ("Mirando…", "Checking…"),
    "act.alDia": ("Tienes la última versión.", "You are on the latest version."),
    "act.hay": ("Hay una versión nueva", "A new version is available"),
    "act.descargar": ("Ver la descarga", "Open the download"),
    "act.fallo": ("No se pudo comprobar", "Could not check"),
    "act.aviso": ("Atalaya solo mira si hay novedades y te lleva a la página. No descarga ni instala nada por su cuenta.",
                  "Atalaya only checks and takes you to the page. It never downloads or installs anything on its own."),
]
