#!/usr/bin/env bash
# Linux x86_64 build tools. All executable archives are verified before extraction.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/.tools"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo "Linux x86_64 required" >&2; exit 1; }
mkdir -p "$TOOLS/bin"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
download() {
  curl --proto '=https' --tlsv1.2 -fsSL "$1" -o "$tmp/$2"
  printf '%s  %s\n' "$3" "$tmp/$2" | sha256sum --check --status
}
# Pin from wasm-bindgen GitHub release asset digest, reviewed 2026-11-15.
download https://github.com/wasm-bindgen/wasm-bindgen/releases/download/0.2.129/wasm-bindgen-0.2.129-x86_64-unknown-linux-musl.tar.gz wb.tgz \
  82d12bb940e2d4e72e0d5605387fc1b8ca179044e012b620f0ce4e7440e8320e
mkdir "$tmp/wb"
tar -xzf "$tmp/wb.tgz" -C "$tmp/wb" --strip-components=1
install -m 0755 "$tmp/wb/wasm-bindgen" "$TOOLS/bin/wasm-bindgen"
# Pin from binaryen's published .sha256 file, reviewed 2026-11-15.
download https://github.com/WebAssembly/binaryen/releases/download/version_123/binaryen-version_123-x86_64-linux.tar.gz binaryen.tgz \
  e959f2170af4c20c552e9de3a0253704d6a9d2766e8fdb88e4d6ac4bae9388fe
tar -xzf "$tmp/binaryen.tgz" -C "$tmp"
install -m 0755 "$tmp/binaryen-version_123/bin/wasm-opt" "$TOOLS/bin/wasm-opt"
