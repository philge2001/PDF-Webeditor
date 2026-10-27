#!/usr/bin/env bash
# Lädt die Oberflächenschrift Inter (SIL OFL 1.1) nach vendor/ui-font/. Portal und Hausbuch nutzen
# San Francisco bzw. Inter als Ersatz; egui zeichnet Text selbst und braucht dafür die .ttf-Datei.
# Im Browser steckt sie nicht im WebAssembly, web/index.html lädt sie aus dist/fonts/ui/ nach.
# Quelle: offizielles Release von rsms/inter, geprüft per SHA-256.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/vendor/ui-font"
VERSION=4.1
SHA256=9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e
URL="https://github.com/rsms/inter/releases/download/v$VERSION/Inter-$VERSION.zip"

if [[ "$(cat "$DEST/VERSION" 2>/dev/null)" == "$VERSION" ]]; then
  echo "Inter $VERSION liegt schon in $DEST"
  exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Lade Inter $VERSION …"
curl -fsSL --retry 3 -o "$TMP/inter.zip" "$URL"
echo "$SHA256  $TMP/inter.zip" | sha256sum -c --quiet -
rm -rf "$DEST"
mkdir -p "$DEST"
# Nur der normale Schnitt: egui kennt keine Schriftstärken (fett = hellere Farbe).
unzip -q -j "$TMP/inter.zip" extras/ttf/Inter-Regular.ttf LICENSE.txt -d "$DEST"
mv "$DEST/LICENSE.txt" "$DEST/OFL-Inter.txt"
echo "$VERSION" > "$DEST/VERSION"
echo "Inter $VERSION nach $DEST geladen"
