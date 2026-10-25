#!/usr/bin/env bash
# Baut die Webapp nach dist/ (statische Dateien, direkt hostbar).
#   scripts/build.sh            Release-Build (klein, langsam zu bauen)
#   scripts/build.sh --debug    Debug-Build (schnell zu bauen, groß)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROFILE=release
CARGO_FLAGS=(--release)
if [[ "${1:-}" == "--debug" ]]; then
  PROFILE=debug
  CARGO_FLAGS=()
fi

# wasm-bindgen-cli muss exakt zur wasm-bindgen-Version in Cargo.toml passen.
WANT="$(grep -oP 'wasm-bindgen = "=\K[0-9.]+' Cargo.toml)"
HAVE="$(wasm-bindgen --version 2>/dev/null | awk '{print $2}' || true)"
if [[ "$WANT" != "$HAVE" ]]; then
  echo "wasm-bindgen-cli $WANT benötigt (gefunden: ${HAVE:-keine})."
  echo "Installieren: cargo install wasm-bindgen-cli --version $WANT --locked"
  exit 1
fi

bash scripts/fetch-pdfium.sh
bash scripts/fetch-fonts.sh
cargo build "${CARGO_FLAGS[@]}" --target wasm32-unknown-unknown

rm -rf dist
mkdir -p dist/pkg dist/pdfium
wasm-bindgen --target web --no-typescript --out-dir dist/pkg \
  "target/wasm32-unknown-unknown/$PROFILE/pdf_webeditor.wasm"

# Optional (Release): wasm-opt aus binaryen verkleinert das WebAssembly um rund ein Drittel.
if [[ "$PROFILE" == release ]] && command -v wasm-opt >/dev/null; then
  echo "wasm-opt -Oz …"
  wasm-opt -Oz --enable-bulk-memory --enable-nontrapping-float-to-int --enable-sign-ext \
    --enable-mutable-globals --enable-reference-types --enable-multivalue \
    dist/pkg/pdf_webeditor_bg.wasm -o dist/pkg/pdf_webeditor_bg.wasm
fi
cp web/index.html dist/
cp vendor/pdfium/pdfium.js vendor/pdfium/pdfium.wasm dist/pdfium/
cp -r vendor/pdfium/licenses dist/pdfium/
mkdir -p dist/fonts
cp vendor/fonts/*.ttf vendor/fonts/*.txt dist/fonts/

echo "Fertig: dist/ ($(du -sh dist | cut -f1))"
du -h dist/pkg/*.wasm dist/pdfium/pdfium.wasm
