#!/usr/bin/env bash
# Tiny corrupt downloads must fail before an archive extractor is invoked.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/project/scripts"
cp "$ROOT/scripts/fetch-pdfium.sh" "$ROOT/scripts/install-build-tools.sh" "$tmp/project/scripts/"
cat > "$tmp/bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
while (($#)); do
  if [[ "$1" == -o ]]; then printf 'corrupt fixture' > "$2"; exit 0; fi
  shift
done
exit 1
STUB
cat > "$tmp/bin/tar" <<'STUB'
#!/usr/bin/env bash
touch "$EXTRACT_MARKER"
exit 99
STUB
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
export EXTRACT_MARKER="$tmp/extracted"
for script in fetch-pdfium.sh install-build-tools.sh; do
  if bash "$tmp/project/scripts/$script"; then
    echo "$script accepted a corrupt archive" >&2
    exit 1
  fi
  [[ ! -e "$EXTRACT_MARKER" ]] || { echo "$script extracted before verification" >&2; exit 1; }
done
echo "Corrupt downloads rejected before extraction"
