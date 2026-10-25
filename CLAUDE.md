# CLAUDE.md – PDF Webeditor

PDF Tool (https://github.com/philge2001/PDF-Tool) als Webapp: Rust → WebAssembly, läuft komplett im Browser,
kein Server. Der Nutzer ist Rust-Einsteiger: größere Schritte kurz erklären, nicht-offensichtlichen Code
kommentieren, nach jedem Meilenstein eine Test-Anleitung geben.

## Build
```bash
bash scripts/build.sh [--debug]                  # → dist/ (lädt PDFium nach vendor/)
# Windows: powershell -ExecutionPolicy Bypass -File scripts\build.ps1 [-Dev] [-Serve]  (UTF-8 mit BOM, CRLF, PS 5.1)
cargo clippy --all-targets -- -D warnings          # Ziel wasm32 ist in .cargo/config.toml voreingestellt
cargo fmt
python3 -m http.server 8080 -d dist
```
wasm-bindgen-cli muss exakt zur `wasm-bindgen`-Version in Cargo.toml passen (build.sh prüft das).

## Architektur
- Die App selbst ist `pdftool-app` (Git-Abhängigkeit mit festem `rev`, `default-features = false` = ohne OCR) aus
  PDF-Tool. Funktionen/Fehlerbehebungen gehören nach PDF-Tool (Browser-Regeln: dort CLAUDE.md, Modul `app::platform`),
  danach `rev` hier hochziehen. Lokal testen: `[patch."https://github.com/philge2001/PDF-Tool"]` mit `path` für
  pdftool-app, -core, -render, -sign (nicht committen).
- `web/index.html` lädt `pdfium/pdfium.js` (`PDFiumModule()`, Emscripten modularisiert) und `pkg/pdf_webeditor.js`
  (wasm-bindgen), ruft `initialize_pdfium_render(pdfium, rust, false)` und dann `start("app")`.
- `src/lib.rs` – `start(canvas_id)`: Panic-Hook, tracing → Browser-Konsole (tracing-wasm), `eframe::WebRunner` mit
  `PdfToolApp::new(cc, Vec::new(), None)`. Mehr Code gibt es hier nicht.

## Abhängigkeiten
Wie in PDF-Tool: keine AGPL, jede neue Crate mit einem Satz begründen.
- pdftool-app (Git), eframe 0.37 (glow, persistence), wasm-bindgen =0.2.129, wasm-bindgen-futures, web-sys,
  console_error_panic_hook, tracing-wasm (Logs in die Browser-Konsole)
- PDFium-WASM: paulocoutinhox/pdfium-lib 7902 (MIT-Build-Skripte, PDFium BSD), per `scripts/fetch-pdfium.sh`
- Liberation-Schriften (OFL) per `scripts/fetch-fonts.sh` aus PDF-Tool im gepinnten `rev` → `dist/fonts/`
  (die App lädt sie im Browser nach, siehe PDF-Tool `app::platform`). Optional `wasm-opt` (binaryen) im `PATH`.

## Meilensteine
- [x] W0 Machbarkeitstest (Öffnen, Rendern, core lesen, Notiz-Command; Speichern lokal mit web-time erprobt)
- [x] W1 Plattformneutraler Kern (PDF-Tool `core::date::system_now` über web-time, getrandom-Features, CI-Job `wasm`; Speichern als Download)
- [ ] W2 Rendern im Web Worker
- [x] W3 Desktop-App im Browser (PDF-Tool `web-w3-app`: `pdftool_app`-Bibliothek, `app::platform`, Render-Worker ohne Thread)
- [x] W4 Schriften und Ladegröße (Liberation als Schriftarten, im Browser aus `dist/fonts/` nachgeladen; `wasm-opt`)
- [ ] W5 Signaturen (.p12 im Browser, TSA-Proxy optional)
- [ ] W6 OCR (tesseract.js)
- [ ] W7 PWA und Veröffentlichung
- [ ] W8 Tests (wasm-bindgen-test, Playwright)

## Testen
`tests/e2e/drive.js` (Playwright) spielt Aktionen per Koordinate ab, siehe `tests/e2e/README.md`.
Nach Änderungen an PDF-Tool die betroffenen Abläufe damit erneut durchklicken und Ergebnisdateien mit poppler prüfen.

## Testen im Container
`python3 -m http.server 8765 -d dist` und Playwright (Chromium vorinstalliert,
`chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] })`); egui zeichnet in ein Canvas,
also per Koordinate klicken und Screenshots ansehen. Dateidialog: `page.waitForEvent('filechooser')` → `setFiles`;
Downloads: `page.on('download', d => d.saveAs(...))`, Kontext mit `acceptDownloads: true`.
Webserver mit `--directory` starten (build.sh löscht und erzeugt `dist/` neu). Nicht `pkill -f http.server` im
selben Befehl wie den Serverstart (trifft die eigene Shell).
