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

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp/wasm.tgz" \
  "https://github.com/paulocoutinhox/pdfium-lib/releases/download/$VERSION/wasm.tgz"
# SHA256 from the release asset metadata, reviewed 2026-11-15.
printf '%s  %s\n' 153871da7e958a9440c84648eb45ddd9ad603efda9fcd8f021766dba5a9157a2 "$tmp/wasm.tgz" | sha256sum --check --status
tar -xzf "$tmp/wasm.tgz" -C "$tmp"

rm -rf "$DEST"
mkdir -p "$DEST/licenses"
# pdfium.js ist „modularisiert“: es definiert die Funktion PDFiumModule() (siehe web/index.html).
cp "$tmp/release/node/pdfium.js" "$tmp/release/node/pdfium.wasm" "$DEST/"

# Lizenztexte: pdfium-lib (Build-Skripte, MIT) und PDFium selbst samt Drittbibliotheken (BSD u. a.).
curl --proto '=https' --tlsv1.2 -fsSL -o "$DEST/licenses/pdfium-lib.md" \
  "https://raw.githubusercontent.com/paulocoutinhox/pdfium-lib/a566bd4c30f420c88b86a3a9d160268bcc828ea9/LICENSE.md"
curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp/bb.tgz" \
  "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7881/pdfium-wasm.tgz"
printf '%s  %s\n' added6e8ac024f71cb61cf2b77a205d178e2bdde2e4048fbcd916f68b7264d56 "$tmp/bb.tgz" | sha256sum --check --status
tar -xzf "$tmp/bb.tgz" -C "$tmp" licenses
cp "$tmp"/licenses/* "$DEST/licenses/"

echo "$VERSION" > "$DEST/VERSION"
echo "PDFium $VERSION nach $DEST geladen"
