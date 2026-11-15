# Build input updates

Rust is fixed in rust-toolchain.toml and the managed build scripts; Cargo builds use --locked.
Linux build tool archives and both PDFium archives are checked against locally pinned SHA256
values before extraction. Existing PDFium files are not trusted as a cache. The PDFium license
source is fixed to its release commit. Build environments must provision rustup and a C compiler;
the build no longer pipes a remote installer into a shell.

For an intentional update, inspect upstream release notes and provenance, obtain the archive
and checksum through independent trusted channels, verify it locally, and update the version,
URL and hash together in a reviewed change. Rust versions in CI, rust-toolchain.toml and
vercel-build.sh must agree; wasm-bindgen must match Cargo.toml and Cargo.lock.
The recorded PDFium/wasm-bindgen hashes came from GitHub release asset metadata;
the Binaryen hash came from the version_123 published .sha256 file on 2026-11-15.
These pins detect replacement after review; they do not establish upstream authorship.

Before deploying: run the CI build, test PDF open/edit/export and OCR in a browser, and verify
headers on the actual hosting layer. Vercel applies the policy in vercel.json. Other hosts
must configure equivalent response headers. The policy allows inline bootstrap/styles,
WebAssembly compilation and local blob workers required by the current app.
Container base image digests and the consuming application's source commit must be pinned
in the deployment repository. No live deployment or image verification was performed here.
