# PDF Webeditor

[PDF Tool](https://github.com/philge2001/PDF-Tool) als Webapp. Alles läuft **im Browser**
(Rust → WebAssembly): PDFs verlassen den Rechner nicht, es gibt keinen Server.

- Oberfläche: egui/eframe (wie die Desktop-App), gezeichnet in ein `<canvas>` (WebGL)
- Fachlogik: `pdftool-core` direkt aus dem PDF-Tool-Repository (Git-Abhängigkeit, fester Commit)
- Rendern: PDFium als WebAssembly ([pdfium-lib](https://github.com/paulocoutinhox/pdfium-lib)) über pdfium-render

**Stand:** W0 – Machbarkeitstest abgeschlossen (siehe unten).

## Bauen und starten

Einmalig:
```bash
rustup target add wasm32-unknown-unknown
cargo install wasm-bindgen-cli --version 0.2.129 --locked   # muss zu Cargo.toml passen
```

Bauen (lädt PDFium beim ersten Mal nach `vendor/`):
```bash
bash scripts/build.sh            # Release, ~2 min
bash scripts/build.sh --debug    # schneller gebaut, deutlich größer
```

Starten (jeder statische Webserver geht; `file://` nicht, wegen WebAssembly):
```bash
python3 -m http.server 8080 -d dist
# Browser: http://localhost:8080
```

Bedienung: „PDF öffnen…“, „Beispiel-PDF“ oder eine PDF ins Fenster ziehen; Seiten mit ◀ ▶,
Zoom per Schieberegler. Rechts stehen die Messwerte des Machbarkeitstests.

## W0 – Ergebnis des Machbarkeitstests

Getestet in Chromium (headless, Software-WebGL) mit einer 500-seitigen Text-PDF und den Fixtures von PDF Tool.

| Frage | Ergebnis |
|---|---|
| Läuft `pdftool-core` als WebAssembly? | **Ja**, ohne Änderung kompilierbar. Öffnen (lopdf) einer 500-Seiten-PDF: ~17–35 ms. Seiten, Annotationen, Formularfelder werden gelesen. |
| Läuft PDFium im Browser? | **Ja**, mit pdfium-lib 7902. Öffnen 3–11 ms, Rendern A4: ~20 ms (100 %) bis ~90 ms (400 %, 2384 × 3372 px), im Hauptthread. |
| egui im Browser? | **Ja**, Start der Seite ~0,4 s (lokal). Dateidialog und Drag & Drop liefern die Bytes. |
| Annotation anlegen (Command)? | **Ja**, über `AddAnnotation` wie in der Desktop-App. |
| Speichern? | **Noch nicht** – `pdftool-core` ruft `SystemTime::now()` auf, das in `wasm32-unknown-unknown` abstürzt. Mit `web-time` in core (lokal erprobt) klappt es: inkrementell gespeichert, als Download angeboten, Datei gültig (`pdfinfo`). Der Knopf bleibt bis W1 gesperrt (`SAVE_SUPPORTED` in `src/app.rs`). |
| Ladegröße | App-WASM 10,7 MB (gzip 2,7 MB), davon ~4,7 MB eingebaute Schriften/ICC aus core; pdfium.wasm 5,2 MB (gzip 2,4 MB). Zusammen ~5,2 MB gzip. |

Erkenntnisse für die nächsten Schritte:
1. **PDFium-Build:** Der WASM-Build von bblanchon/pdfium-binaries (Desktop-Quelle) lässt sich mit pdfium-render 0.9.4
   nicht initialisieren (`PDFium_Init` fehlt) und hat laut pdfium-render keinen wachsenden Speicher.
   Daher pdfium-lib; dessen nächster Stand nach chromium/7881 ist 7902.
2. **Zeit (W1):** `SystemTime` in `core::date`, `core::save`, `sign::cert/verify/timestamp` → Crate `web-time`
   (auf dem Desktop identisch zu `std::time`). Dateisystem (`Document::open`, `save_as`, `system_fonts`) ist im
   Browser nur „nicht verfügbar“ und stürzt nicht ab; trotzdem in W1 hinter `cfg` legen.
3. **Größe (W4):** Liberation-Schriften (PDF/A) und Noto per `include_bytes!` machen fast die Hälfte des App-WASM aus –
   im Web bei Bedarf nachladen.
4. **Rendern im Hauptthread** ist für Einzelseiten schnell genug; für Miniaturen/Vorabrendern braucht es den
   Web Worker (W2).
5. Getestet nur in Chromium; Firefox/Safari folgen mit den E2E-Tests (W8).

## Lizenz

MIT OR Apache-2.0. PDFium: BSD-3-Clause und weitere (Texte nach dem Bauen in `dist/pdfium/licenses/`).
