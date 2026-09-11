#!/bin/zsh
# Compila Atalaya.app: universal, con icono y firmada.
#
# La identidad importa: una firma ad-hoc cambia en cada compilación y macOS
# trata cada build como una app distinta, así que el llavero vuelve a pedir
# permiso cada vez. Una identidad estable hace que la firma sea "identificador
# + raíz del certificado" y los permisos sobreviven a las recompilaciones.
set -euo pipefail
cd "$(dirname "$0")"

APP="Atalaya"
BUNDLE_ID="com.neuralbeat.atalaya"
IDENTITY="Atalaya Signing"        # la crea Tools/setup-signing.sh
SIGNING_KEYCHAIN="$HOME/Library/Keychains/atalaya-signing.keychain-db"
VERSION="0.1.0"
BUILD="1"
DESTINO="build/$APP.app"
EDICION="publica"
SWIFT_FLAGS=()
if [[ "${1:-}" == "--completa" ]]; then
    EDICION="completa"
    SWIFT_FLAGS=(-Xswiftc -DCOMPLETA)
    DESTINO="build/$APP Completa.app"
fi

# Compilar para las dos arquitecturas necesita el sistema de compilación de
# Xcode, no solo las Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" ]] && [[ -d /Applications/Xcode.app ]] \
   && [[ "$(xcode-select -p 2>/dev/null)" != *"Xcode.app"* ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

echo "▸ Compilando…"
ARCOS=(--arch x86_64 --arch arm64)
if ! swift build -c release "${ARCOS[@]}" "${SWIFT_FLAGS[@]}" >/dev/null 2>&1; then
    echo "  ⚠ sin compilación cruzada: este paquete será solo $(uname -m)."
    echo "    Para publicar hace falta Xcode instalado, no bastan las Command Line Tools."
    ARCOS=()
    swift build -c release "${SWIFT_FLAGS[@]}" >/dev/null
fi
BINARIO="$(swift build -c release "${ARCOS[@]}" "${SWIFT_FLAGS[@]}" --show-bin-path)/$APP"

echo "▸ Dibujando el icono…"
swift Tools/MakeIcon.swift >/dev/null
iconutil -c icns build/$APP.iconset -o build/$APP.icns

echo "▸ Armando el paquete…"
rm -rf "$DESTINO"
mkdir -p "$DESTINO/Contents/MacOS" "$DESTINO/Contents/Resources"
cp "$BINARIO" "$DESTINO/Contents/MacOS/$APP"
cp build/$APP.icns "$DESTINO/Contents/Resources/$APP.icns"

cat > "$DESTINO/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP</string>
    <key>CFBundleDisplayName</key><string>$APP</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>CFBundleIconFile</key><string>$APP</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>GPL-3.0-or-later · neural-beat</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Para conectarse por SSH al servidor de tu red local.</string>
</dict>
</plist>
PLIST

echo "▸ Firmando…"
# El llavero de firma se bloquea solo (al dormir el Mac o pasado un rato) y
# entonces codesign pide una contraseña que no es la del usuario, sino la que
# puso Tools/setup-signing.sh al crearlo. Se abre aquí para que nadie tenga que
# escribirla, y se le quita la caducidad para que no vuelva a cerrarse.
if [[ -f "$SIGNING_KEYCHAIN" ]]; then
    security unlock-keychain -p "atalaya-signing" "$SIGNING_KEYCHAIN" 2>/dev/null \
        || echo "  ⚠ no se pudo abrir el llavero de firma; lanza Tools/setup-signing.sh"
    security set-keychain-settings "$SIGNING_KEYCHAIN" 2>/dev/null || true
fi

IDENTITY_HASH=""
if [[ -f "$SIGNING_KEYCHAIN" ]]; then
    IDENTITY_HASH="$(security find-certificate -c "$IDENTITY" -Z "$SIGNING_KEYCHAIN" 2>/dev/null | awk '/SHA-1 hash:/{print $3; exit}')"
fi
if [[ -z "$IDENTITY_HASH" ]]; then
    IDENTITY_HASH="$(security find-identity -v -p codesigning 2>/dev/null | awk -v nombre="$IDENTITY" 'index($0,nombre){print $2; exit}')"
fi
if [[ -n "$IDENTITY_HASH" ]]; then
    if [[ -f "$SIGNING_KEYCHAIN" ]]; then
        codesign --force --options runtime --strip-disallowed-xattrs --keychain "$SIGNING_KEYCHAIN" --sign "$IDENTITY_HASH" "$DESTINO"
    else
        codesign --force --options runtime --strip-disallowed-xattrs --sign "$IDENTITY_HASH" "$DESTINO"
    fi
    echo "  firmada con '$IDENTITY'"
else
    codesign --force --strip-disallowed-xattrs --sign - "$DESTINO"
    echo "  ⚠ firma ad-hoc. Lanza antes Tools/setup-signing.sh para una identidad estable."
fi
codesign --verify --strict "$DESTINO"

echo "▸ Arquitecturas:"
lipo -archs "$DESTINO/Contents/MacOS/$APP"
echo "✓ Listo: $DESTINO"
echo "  edición: $EDICION"
