#!/usr/bin/env bash
# Lädt die Texterkennung für den Browser nach vendor/ocr/:
#   - tesseract.js + tesseract.js-core (Apache-2.0) aus der npm-Registry, Prüfsumme wird geprüft
#   - Sprachdaten deu/eng (tessdata_fast, Apache-2.0) aus PDF-Tool im gepinnten `rev` – dieselben
#     wie in der Desktop-App –, gzip-komprimiert (so erwartet sie tesseract.js)
# Die App ruft die Erkennung über window.pdftoolOcr auf (web/index.html).
set -euo pipefail

VERSION="7.0.0"
JS_SHA512="exPBkd+z+wM1BuMkx/Bjv43OeLBxhL5kKWsz/9JY+DXcXdiBjiAch0V49QR3oAJqCaL5qURE0vx9Eo+G5YE7mA=="
CORE_SHA512="WnNH518NzmbSq9zgTPeoF8c+xmilS8rFIl1YKbk/ptuuc7p6cLNELNuPAzcmsYw450ca6bLa8j3t0VAtq435Vw=="
LANGS=(deu eng)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/vendor/ocr"
REV="$(grep -oP 'PDF-Tool", rev = "\K[0-9a-f]+' "$ROOT/Cargo.toml")"
STAMP="$VERSION $REV"

if [[ "$(cat "$DEST/STAMP" 2>/dev/null)" == "$STAMP" ]]; then
  echo "Texterkennung (tesseract.js $VERSION, Sprachdaten PDF-Tool $REV) liegt schon in $DEST"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# npm-Paket laden und gegen die Prüfsumme aus der Registry prüfen.
fetch_npm() { # name sha512 zielordner
  local file="$tmp/$1.tgz"
  curl -fsSL --retry 3 -o "$file" "https://registry.npmjs.org/$1/-/$1-$VERSION.tgz"
  local got
  if command -v openssl >/dev/null; then
    got="$(openssl dgst -sha512 -binary "$file" | base64 | tr -d '\n')"
  else
    got="$(node -e "process.stdout.write(require('crypto').createHash('sha512').update(require('fs').readFileSync(process.argv[1])).digest('base64'))" "$file")"
  fi
  if [[ "$got" != "$2" ]]; then
    echo "Prüfsumme von $1 $VERSION stimmt nicht – Abbruch." >&2
    exit 1
  fi
  mkdir -p "$3"
  tar -xzf "$file" -C "$3"
}
fetch_npm tesseract.js "$JS_SHA512" "$tmp/js"
fetch_npm tesseract.js-core "$CORE_SHA512" "$tmp/core"

rm -rf "$DEST"
mkdir -p "$DEST/core" "$DEST/lang" "$DEST/licenses"
cp "$tmp/js/package/dist/tesseract.min.js" "$tmp/js/package/dist/worker.min.js" "$DEST/"
# Nur die LSTM-Varianten (die App nutzt nur die LSTM-Erkennung); tesseract.js wählt je nach
# Browser die schnellste (relaxed SIMD, SIMD oder ohne). Das WebAssembly steckt in der .js-Datei.
for v in lstm simd-lstm relaxedsimd-lstm; do
  cp "$tmp/core/package/tesseract-core-$v.wasm.js" "$DEST/core/"
done
cp "$tmp/js/package/LICENSE.md" "$DEST/licenses/tesseract.js.md"
cp "$tmp/core/package/LICENSE" "$DEST/licenses/tesseract.js-core.txt"

BASE="https://raw.githubusercontent.com/philge2001/PDF-Tool/$REV/assets/tessdata"
for l in "${LANGS[@]}"; do
  curl -fsSL --retry 3 -o "$tmp/$l.traineddata" "$BASE/$l.traineddata"
  gzip -9 -c "$tmp/$l.traineddata" > "$DEST/lang/$l.traineddata.gz"
done
curl -fsSL --retry 3 -o "$DEST/licenses/tessdata.txt" "$BASE/LICENSE"

echo "$STAMP" > "$DEST/STAMP"
echo "Texterkennung (tesseract.js $VERSION, Sprachdaten PDF-Tool $REV) nach $DEST geladen"
