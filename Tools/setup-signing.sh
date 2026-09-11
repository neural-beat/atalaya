#!/bin/zsh
# Creates a stable, self-signed code-signing identity for Atalaya in its own
# keychain. build.sh picks it up automatically.
#
# Why this exists: an ad-hoc signature changes on every build, so macOS treats
# each build as a different app and asks for Accessibility again every time.
# A stable certificate makes the designated requirement "identifier +
# certificate root", and the permission survives rebuilds.
#
# Free, offline and idempotent. It is NOT Apple notarization: builds shared
# with other people still show Gatekeeper's unverified-developer warning.
set -euo pipefail

IDENTITY="Atalaya Signing"
KC="$HOME/Library/Keychains/atalaya-signing.keychain-db"
KCPASS="atalaya-signing"

if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "✓ Signing identity already installed."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

openssl req -x509 -newkey rsa:2048 -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -days 3650 -nodes -subj "/CN=$IDENTITY" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" 2>/dev/null
openssl pkcs12 -export -legacy -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/id.p12" -passout pass:"$KCPASS" -name "$IDENTITY" 2>/dev/null

security delete-keychain "$KC" 2>/dev/null || true
security create-keychain -p "$KCPASS" "$KC"
security set-keychain-settings "$KC"                 # no auto-lock
security unlock-keychain -p "$KCPASS" "$KC"
security import "$WORK/id.p12" -k "$KC" -P "$KCPASS" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KCPASS" "$KC" >/dev/null 2>&1
EXISTING=$(security list-keychains -d user | sed 's/"//g' | xargs)
security list-keychains -d user -s "$KC" ${=EXISTING}

echo "✓ Created signing identity '$IDENTITY'."
