#!/usr/bin/env bash
# Lädt den WebAssembly-Build von PDFium nach vendor/pdfium/.
#
# Quelle: paulocoutinhox/pdfium-lib (MIT) – von pdfium-render für WASM empfohlen, weil sein
# Speicher wachsen kann. (Der WASM-Build von bblanchon/pdfium-binaries lässt sich mit
# pdfium-render 0.9.4 nicht initialisieren, siehe README.)
# Version 7902 ist der nächste verfügbare Stand nach chromium/7881 der Desktop-App.
set -euo pipefail

VERSION="7902"
DEST="$(cd "$(dirname "$0")/.." && pwd)/vendor/pdfium"

if [[ -f "$DEST/pdfium.wasm" && "$(cat "$DEST/VERSION" 2>/dev/null)" == "$VERSION" ]]; then
  echo "PDFium $VERSION liegt schon in $DEST"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/wasm.tgz" \
  "https://github.com/paulocoutinhox/pdfium-lib/releases/download/$VERSION/wasm.tgz"
tar -xzf "$tmp/wasm.tgz" -C "$tmp"

rm -rf "$DEST"
mkdir -p "$DEST/licenses"
# pdfium.js ist „modularisiert“: es definiert die Funktion PDFiumModule() (siehe web/index.html).
cp "$tmp/release/node/pdfium.js" "$tmp/release/node/pdfium.wasm" "$DEST/"

# Lizenztexte: pdfium-lib (Build-Skripte, MIT) und PDFium selbst samt Drittbibliotheken (BSD u. a.).
curl -fsSL -o "$DEST/licenses/pdfium-lib.md" \
  "https://raw.githubusercontent.com/paulocoutinhox/pdfium-lib/master/LICENSE.md"
curl -fsSL -o "$tmp/bb.tgz" \
  "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7881/pdfium-wasm.tgz"
tar -xzf "$tmp/bb.tgz" -C "$tmp" licenses
cp "$tmp"/licenses/* "$DEST/licenses/"

echo "$VERSION" > "$DEST/VERSION"
echo "PDFium $VERSION nach $DEST geladen"
