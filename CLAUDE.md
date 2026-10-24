# CLAUDE.md – PDF Webeditor

PDF Tool (https://github.com/philge2001/PDF-Tool) als Webapp: Rust → WebAssembly, läuft komplett im Browser,
kein Server. Der Nutzer ist Rust-Einsteiger: größere Schritte kurz erklären, nicht-offensichtlichen Code
kommentieren, nach jedem Meilenstein eine Test-Anleitung geben.

## Build
```bash
bash scripts/build.sh [--debug]                  # → dist/ (lädt PDFium nach vendor/)
cargo clippy --all-targets -- -D warnings          # Ziel wasm32 ist in .cargo/config.toml voreingestellt
cargo fmt
python3 -m http.server 8080 -d dist
```
wasm-bindgen-cli muss exakt zur `wasm-bindgen`-Version in Cargo.toml passen (build.sh prüft das).

## Architektur
- `pdftool-core` kommt per Git-Abhängigkeit (fester `rev`) aus PDF-Tool. Änderungen an core gehören nach PDF-Tool,
  danach `rev` hier hochziehen. Lokal testen: `[patch."https://github.com/philge2001/PDF-Tool"]` mit `path`
  (nicht committen).
- `web/index.html` lädt `pdfium/pdfium.js` (`PDFiumModule()`, Emscripten modularisiert) und `pkg/pdf_webeditor.js`
  (wasm-bindgen), ruft `initialize_pdfium_render(pdfium, rust, false)` und dann `start("app")`.
- `src/pdf.rs` – `Renderer` (PDFium, `&'static Pdfium` per `Box::leak`, Dokument als `PdfDocument<'static>`)
- `src/app.rs` – egui-Oberfläche (`eframe::App::ui`, egui 0.37: `egui::Panel::top/right`)
- `src/browser.rs` – `now_ms` (performance.now), `unix_secs` (Date.now), `download` (Blob-URL)
- Kein `std::time::{Instant, SystemTime}`, kein `std::fs`, kein `std::thread` im Browser-Code.

## Abhängigkeiten
Wie in PDF-Tool: keine AGPL, jede neue Crate mit einem Satz begründen.
- pdfium-render 0.9.4 (ohne `thread_safe`), eframe 0.37 (glow), rfd 0.17 (AsyncFileDialog), wasm-bindgen =0.2.129,
  web-sys/js-sys, getrandom 0.4 `wasm_js` (Zufall für core), console_error_panic_hook, console_log
- PDFium-WASM: paulocoutinhox/pdfium-lib 7902 (MIT-Build-Skripte, PDFium BSD), per `scripts/fetch-pdfium.sh`

## Meilensteine
- [x] W0 Machbarkeitstest (Öffnen, Rendern, core lesen, Notiz-Command; Speichern lokal mit web-time erprobt)
- [ ] W1 Plattformneutraler Kern (PDF-Tool: web-time, fs hinter cfg, wasm32-Check in CI)
- [ ] W2 Rendern im Web Worker
- [ ] W3 App-Shell im Web (Desktop-UI übernehmen, Speichern/File System Access, Tabs)
- [ ] W4 Schriften und Bilder (Schriften nachladen, Zwischenablage)
- [ ] W5 Signaturen (.p12 im Browser, TSA-Proxy optional)
- [ ] W6 OCR (tesseract.js)
- [ ] W7 PWA und Veröffentlichung
- [ ] W8 Tests (wasm-bindgen-test, Playwright)

## Testen im Container
`python3 -m http.server 8765 -d dist` und Playwright (Chromium vorinstalliert,
`chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] })`); egui zeichnet in ein Canvas,
also per Koordinate klicken und Screenshots ansehen. Dateidialog: `page.waitForEvent('filechooser')` → `setFiles`.
