# PDF Webeditor

[PDF Tool](https://github.com/philge2001/PDF-Tool) als Webapp. Alles läuft **im Browser**
(Rust → WebAssembly): PDFs verlassen den Rechner nicht, es gibt keinen Server.

- Oberfläche: **dieselbe App wie auf dem Desktop** (`pdftool-app` aus dem PDF-Tool-Repository, egui im `<canvas>`)
- Rendern: PDFium als WebAssembly ([pdfium-lib](https://github.com/paulocoutinhox/pdfium-lib)) über pdfium-render

**Stand:** W3 – die Desktop-App läuft im Browser: Kommentieren (Notizen platzieren, Text eingeben, verschieben),
Markieren, Freitext, Zeichnen, Suche, Seiten organisieren, Formulare, Schwärzen, Text/Bilder bearbeiten,
Export, Komprimieren, PDF/A, Signieren (ohne Zeitstempel), Barrierefreiheit, Texterkennung (OCR).

### Unterschiede zur Desktop-App
- **Öffnen:** „Datei öffnen“ oder PDF ins Fenster ziehen. Die Datei bleibt im Browser, nichts wird hochgeladen.
- **Speichern:** Strg+S bzw. „Speichern“ lädt die Datei herunter (Downloads-Ordner). Es gibt keinen Speichern-Dialog;
  mehrere Dateien (Teilen, Bilder-Export) kommen als einzelne Downloads.
- **Zuletzt verwendet:** nur Dateien der aktuellen Sitzung (nach dem Neuladen der Seite ist die Liste leer).
  Einstellungen (Design, Autor, vertraute Zertifikate …) bleiben dagegen im Browser gespeichert.
- **Hintergrund-Arbeit** (Komprimieren, PDF/A, Export, Signieren) läuft im Browser ohne eigenen Thread – die
  Oberfläche hält währenddessen kurz an.
- **Schriften:** keine Systemschriften. Zur Auswahl stehen Noto Sans und Liberation Sans/Serif/Mono (metrisch gleich zu
  Arial, Times New Roman, Courier New); Liberation wird kurz nach dem Start im Hintergrund nachgeladen.
- **Texterkennung (OCR):** über tesseract.js, dieselbe Erkennung und dieselben Sprachdaten (Deutsch, Englisch) wie
  auf dem Desktop. Sie wird erst beim ersten Gebrauch geladen (≈ 4 MB Erkennung + 0,9 MB Deutsch + 2 MB Englisch, danach
  im Browser zwischengespeichert). Abbrechen greift erst nach der laufenden Seite.
- **Nicht verfügbar:** Zeitstempeldienste beim Signieren.
- Schließen oder Neuladen des Tabs mit ungespeicherten Änderungen: Der Browser fragt nach („Seite verlassen?“).

## Bauen und starten

Einmalig:
```bash
rustup target add wasm32-unknown-unknown
cargo install wasm-bindgen-cli --version 0.2.129 --locked   # muss zu Cargo.toml passen
```

**Windows (PowerShell):** Befehle einzeln eingeben – Windows PowerShell 5.1 kennt `&&` nicht. Statt `build.sh`:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Serve     # bauen und auf http://localhost:8080 starten
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Dev       # schneller Debug-Build, ohne Start
```
(`-Serve` braucht Python; ohne Python: `npx --yes http-server dist -p 8080`.)

Optional, für eine rund ein Drittel kleinere Datei: [binaryen](https://github.com/WebAssembly/binaryen/releases)
entpacken und `wasm-opt` in den `PATH` legen – die Build-Skripte nutzen es dann automatisch (nur Release).

**Linux/macOS/Git Bash** – bauen (lädt PDFium beim ersten Mal nach `vendor/`):
```bash
bash scripts/build.sh            # Release, ~2 min
bash scripts/build.sh --debug    # schneller gebaut, deutlich größer
```

Starten (jeder statische Webserver geht; `file://` nicht, wegen WebAssembly):
```bash
python3 -m http.server 8080 -d dist
# Browser: http://localhost:8080
```
Jeder Build hängt eine Kennung (`?v=<PDF-Tool-Stand>-<Uhrzeit>`) an die App-Dateien, damit der Browser nach
einem neuen Build nicht die alte Fassung aus dem Zwischenspeicher nimmt. Welche Fassung läuft, steht in der
Browser-Konsole (F12): „PDF Webeditor, Build …“.

## Erscheinungsbild wie Portal und Hausbuch

Der Webeditor sieht aus wie das [Portal](https://github.com/philge2001/portal) und das
[Hausbuch](https://github.com/philge2001/vermietung): Apple-Systemfarben (Fenstergrund `#f2f2f7`, Systemblau
`#0071e3`), Haarlinien, Glasflächen, runde Ecken, Schrift Inter.

- `web/index.html`: Titelleiste mit App-Symbol und – nur unter philippzent.com – „Zum Portal“; Ladeanzeige als
  Glaskarte über den Farbflächen des Portals, mit Fehlermeldung und „Neu laden“, falls der Start scheitert.
- PDF-Tool (`app::style`, `app::icons`, `app::home`, Branch `ui-portal-design`) bringt Farben, Formen und Layout
  selbst mit: Palette wie die CSS-Variablen des Portals, Pillen-Knöpfe, farbige Werkzeug-Symbole wie die
  Seitenleiste im Hausbuch, Startseite wie die Portal-Startseite, „Alle Werkzeuge“ in Abschnitten.
- `src/theme.rs`: Inter als UI-Schrift (nur im Browser) und `Themed`: wählt man in der App hell/dunkel, folgt die
  Titelleiste (`data-theme` an `<html>`).
- `scripts/fetch-ui-font.sh` lädt Inter 4.1 (OFL) mit Prüfsumme nach `dist/fonts/ui/` (≈ 400 KB, parallel zur App).

## W6 – Texterkennung (OCR)

Die Desktop-App bindet Tesseract als C++-Bibliothek ein, das lässt sich nicht für den Browser bauen. Im Browser
übernimmt [tesseract.js](https://github.com/naptha/tesseract.js) (Apache-2.0) – Tesseract als WebAssembly in einem
eigenen Web Worker:

- `scripts/fetch-tesseract.sh` (bzw. `build.ps1`) lädt tesseract.js und tesseract.js-core 7.0.0 aus der npm-Registry
  (Prüfsumme wird geprüft) und die Sprachdaten aus PDF-Tool im gepinnten Stand nach `dist/ocr/`.
- `web/index.html` stellt `window.pdftoolOcr(rgba, breite, höhe, sprachen)` bereit: lädt tesseract.js beim ersten Aufruf,
  erkennt mit automatischer Seitenaufteilung und 300 dpi und gibt Tesseracts TSV-Tabelle zurück.
- PDF-Tool (`app::ocr_ui`) rendert die Seite, ruft die Funktion auf und legt die Wörter wie auf dem Desktop als
  unsichtbare Textebene ab (Suchen, Markieren, Kopieren).

Getestet in Chromium: gescannte Seite → 22 Wörter erkannt (Umlaute, ß), gespeichert, mit `pdftotext -bbox` geprüft
(Text an der richtigen Stelle). Es werden nur Dateien vom eigenen Server geladen.

## Veröffentlichen auf Vercel

Vercel bringt beim Bauen nur Node mit. `scripts/vercel-build.sh` installiert deshalb Rust (rustup, minimal + wasm32),
wasm-bindgen-cli und wasm-opt als fertige Programme nach `.tools/` und ruft dann `scripts/build.sh` auf.
`vercel.json` setzt Build-Befehl und Ausgabeordner (`dist`), es gibt keinen Installationsschritt. Ein Build dauert
etwa 4–8 Minuten.

1. Auf vercel.com „Add New → Project“ wählen und dieses Repository importieren.
2. Framework Preset „Other“ lassen. Die Einstellungen kommen aus `vercel.json`, nichts überschreiben.
3. Unter Settings → Git die **Production Branch** auf den Branch mit dem gewünschten Stand setzen. Standard ist der
   Standard-Branch des Repositorys.

## W4 – Schriften und Ladegröße

- Die Liberation-Schriften (bisher nur intern für PDF/A) sind jetzt Schriftarten der App – im Browser die
  Alternative zu Systemschriften. Sie liegen nicht mehr im WebAssembly, sondern als `dist/fonts/*.ttf` daneben
  und werden nach dem Start nachgeladen (`scripts/fetch-fonts.sh` holt sie aus PDF-Tool im gepinnten Stand).
- `wasm-opt -Oz` im Build, wenn installiert.

| | vorher | nachher |
|---|---|---|
| App-WASM roh | 22 MB | 11 MB |
| App-WASM gzip | 6,9 MB | 4,0 MB |
| + pdfium.wasm gzip | 2,4 MB | 2,4 MB |
| **Laden bis zum Start (gzip)** | **9,3 MB** | **6,4 MB** |
| danach im Hintergrund: Schriften | – | 4,7 MB roh (gzip ≈ 2,5 MB) |

Ohne `wasm-opt` liegt das App-WASM bei ≈ 18 MB roh / 4,5 MB gzip.

## W3 – Desktop-App im Browser

In PDF-Tool (Branch `web-w3-app`): Die App ist zusätzlich eine Bibliothek (`pdftool_app`). Alles, was zwischen
Desktop und Browser verschieden ist, steckt im Modul `app::platform` (Dateidialoge, Lesen/Schreiben,
Hintergrund-Arbeit). Der Render-Worker läuft im Browser ohne Thread in Zeitscheiben pro Frame.
Dieses Repository startet nur noch `PdfToolApp` im Canvas (`src/lib.rs`).

Getestet in Chromium: Öffnen (Dialog), Notiz platzieren + Text (mit Umlauten) + verschieben, Kommentar-Panel,
Markieren, Freitext, Seitenminiaturen, Suche, PDF/A, Export (PNG je Seite, Word), Speichern als Download
(inkrementell, Notiztext in der Datei).

Ladegröße damals: App-WASM 22 MB (gzip 6,9 MB) + pdfium.wasm 5,2 MB (gzip 2,4 MB) – siehe W4.

## W1 – Plattformneutraler Kern

In PDF-Tool (Branch `web-w1-plattformneutral`): `core::date::system_now()` liefert die Systemzeit über die Crate
`web-time` – im Browser aus `Date.now()`, auf dem Desktop unverändert `SystemTime::now()`. Zufall kommt im Browser
aus `crypto.getRandomValues` (getrandom-Features in core/sign). Ein CI-Job prüft, dass core und sign für wasm32
kompilieren und niemand `SystemTime::now()` direkt aufruft. Dateisystem-Funktionen (`Document::open`, Systemschriften)
liefern im Browser nur Fehler, stürzen aber nicht ab – genutzt werden dort die Bytes-Varianten.

Getestet in Chromium: 500-Seiten-PDF, Notiz auf Seite 4, speichern, erneut Notiz, erneut speichern → zwei
inkrementelle Revisionen, beide Notizen mit Datum und `/NM`, Datei gültig (`pdfinfo`, `pdftoppm`).

## Durchgetestet im Browser

Mit `tests/e2e/drive.js` in Chromium durchgeklickt und die Ergebnisdateien mit poppler (`pdfinfo`, `pdftotext`,
`pdfimages`, `pdfsig`) geprüft: Kommentieren (Notiz, Markieren, Freitext), Formulare ausfüllen und gestalten,
Seiten drehen/einfügen/löschen/extrahieren/teilen, Zusammenführen, Schwärzen (Text wirklich entfernt), Passwortschutz
(AES-256, Öffnen mit Passwort), Komprimieren, PDF/A, Export (PNG, Word), Text und Bilder bearbeiten, Bild per Strg+V,
Testzertifikat erstellen und signieren (`pdfsig`: gültig), Vergleich, Barrierefreiheit prüfen und taggen,
Lesezeichen, Suche, Einstellungen nach Neuladen.

Dabei behoben (in PDF-Tool): Absturz beim Testzertifikat (versteckter `SystemTime::now()` in x509-cert),
unsichtbare Eingabefelder im hellen Design, Strg+V mit Bild, Rückfrage beim Schließen, Meldungen mit leerem
Ordnernamen; hier: Debug-Build (`--debug`/`-Dev`) war für wasm-bindgen zu groß.

## W0 – Ergebnis des Machbarkeitstests

Getestet in Chromium (headless, Software-WebGL) mit einer 500-seitigen Text-PDF und den Fixtures von PDF Tool.

| Frage | Ergebnis |
|---|---|
| Läuft `pdftool-core` als WebAssembly? | **Ja**, ohne Änderung kompilierbar. Öffnen (lopdf) einer 500-Seiten-PDF: ~17–35 ms. Seiten, Annotationen, Formularfelder werden gelesen. |
| Läuft PDFium im Browser? | **Ja**, mit pdfium-lib 7902. Öffnen 3–11 ms, Rendern A4: ~20 ms (100 %) bis ~90 ms (400 %, 2384 × 3372 px), im Hauptthread. |
| egui im Browser? | **Ja**, Start der Seite ~0,4 s (lokal). Dateidialog und Drag & Drop liefern die Bytes. |
| Annotation anlegen (Command)? | **Ja**, über `AddAnnotation` wie in der Desktop-App. |
| Speichern? | In W0 nicht – `pdftool-core` rief `SystemTime::now()` auf, das in `wasm32-unknown-unknown` abstürzt. **Seit W1 behoben.** |
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
