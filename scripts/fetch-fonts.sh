#!/usr/bin/env bash
# Lädt die Liberation-Schriften (SIL OFL 1.1) nach vendor/fonts/. Im Browser stecken sie nicht im
# WebAssembly, sondern werden nach dem Start aus dist/fonts/ nachgeladen (schnellerer Start).
# Quelle: das PDF-Tool-Repository im selben Stand wie die Git-Abhängigkeit in Cargo.toml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/vendor/fonts"
REV="$(grep -oP 'PDF-Tool", rev = "\K[0-9a-f]+' "$ROOT/Cargo.toml")"
BASE="https://raw.githubusercontent.com/philge2001/PDF-Tool/$REV/assets/fonts"
NAMES=(Sans Serif Mono)
STYLES=(Regular Bold Italic BoldItalic)

if [[ "$(cat "$DEST/REV" 2>/dev/null)" == "$REV" ]]; then
  echo "Schriften (PDF-Tool $REV) liegen schon in $DEST"
  exit 0
fi
rm -rf "$DEST"
mkdir -p "$DEST"
for n in "${NAMES[@]}"; do
  for s in "${STYLES[@]}"; do
    curl -fsSL --retry 3 -o "$DEST/Liberation$n-$s.ttf" "$BASE/liberation/Liberation$n-$s.ttf"
  done
done
curl -fsSL --retry 3 -o "$DEST/COPYRIGHT-Liberation.txt" "$BASE/liberation/COPYRIGHT"
curl -fsSL --retry 3 -o "$DEST/OFL.txt" "$BASE/OFL.txt"
echo "$REV" > "$DEST/REV"
echo "Liberation-Schriften (PDF-Tool $REV) nach $DEST geladen"
