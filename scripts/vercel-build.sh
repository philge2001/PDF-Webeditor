#!/usr/bin/env bash
# Vercel provides rustup; never execute an unverified network installer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/.tools/bin:${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
command -v cc >/dev/null || { echo "Install a C compiler in the build image" >&2; exit 1; }
command -v rustup >/dev/null || { echo "Provision rustup in the trusted build image" >&2; exit 1; }
# rust-toolchain.toml selects the exact compiler without changing the global default.
rustup toolchain install 1.95.0 --profile minimal --target wasm32-unknown-unknown
bash scripts/install-build-tools.sh
bash scripts/build.sh
