#!/usr/bin/env bash
# Build auf Vercel (oder einem anderen Rechner ohne Rust): installiert die Werkzeuge in .tools/
# und ruft dann scripts/build.sh auf. Vercel bringt nur Node mit – kein Rust, kein wasm-bindgen.
#   Vercel: Build Command = bash scripts/vercel-build.sh, Output Directory = dist (siehe vercel.json)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TOOLS="$ROOT/.tools"
mkdir -p "$TOOLS/bin"
export PATH="$TOOLS/bin:$HOME/.cargo/bin:$PATH"

# C-Compiler (Linker für Build-Skripte und Makros der Rust-Abhängigkeiten).
if ! command -v cc >/dev/null; then
  echo "Installiere gcc …"
  dnf install -y gcc >/dev/null
fi

# Rust (stabil, minimal) mit dem Ziel wasm32.
if ! command -v cargo >/dev/null; then
  echo "Installiere Rust …"
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
fi
rustup target add wasm32-unknown-unknown

# wasm-bindgen-cli als fertiges Programm (exakt die Version aus Cargo.toml; cargo install bräuchte ~5 min).
WB="$(grep -oP 'wasm-bindgen = "=\K[0-9.]+' Cargo.toml)"
if [[ "$(wasm-bindgen --version 2>/dev/null | awk '{print $2}')" != "$WB" ]]; then
  echo "Lade wasm-bindgen $WB …"
  curl -fsSL "https://github.com/wasm-bindgen/wasm-bindgen/releases/download/$WB/wasm-bindgen-$WB-x86_64-unknown-linux-musl.tar.gz" |
    tar -xz -C "$TOOLS" --strip-components=1
  mv "$TOOLS/wasm-bindgen" "$TOOLS/bin/"
fi

# wasm-opt (binaryen) – macht das WebAssembly rund ein Drittel kleiner.
if ! command -v wasm-opt >/dev/null; then
  echo "Lade binaryen …"
  curl -fsSL https://github.com/WebAssembly/binaryen/releases/download/version_123/binaryen-version_123-x86_64-linux.tar.gz |
    tar -xz -C "$TOOLS"
  ln -sf "$TOOLS/binaryen-version_123/bin/wasm-opt" "$TOOLS/bin/wasm-opt"
fi

bash scripts/build.sh
