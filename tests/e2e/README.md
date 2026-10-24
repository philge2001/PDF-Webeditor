# Browser-Tests (Playwright)

Werkzeug zum Durchklicken der Webapp. egui zeichnet alles in ein `<canvas>` – es gibt keine
HTML-Elemente zum Anklicken, deshalb arbeitet `drive.js` mit Bildschirmkoordinaten (Fenster 1400 × 850)
und Screenshots.

```bash
cd tests/e2e && npm install && npx playwright install chromium   # einmalig
bash ../../scripts/build.sh && python3 -m http.server 8080 -d ../../dist &   # Webapp bereitstellen
node drive.js "open beispiel.pdf; c 34 238; c 950 600; t Hallo; c 833 603; k Control+s; w 1500; s ergebnis"
```

Aktionen (durch `;` getrennt): `open DATEI` (über „Datei öffnen“ der Startseite), `pick X Y DATEI[,DATEI]`
(Klick, der einen Dateidialog öffnet), `c X Y` / `rc X Y` / `dc X Y` (Klick, Rechtsklick, Doppelklick),
`d X1 Y1 X2 Y2` (Ziehen), `t TEXT` (Tippen, `_` = Leerzeichen), `k TASTE` (z. B. `Enter`, `Control+s`),
`w MS` (warten), `s NAME` (Screenshot `NAME.png`). Downloads landen als `dl_<Dateiname>` im aktuellen Ordner.

Hinweis: Dateidialoge werden dauerhaft abgefangen (`page.on('filechooser')`) – sonst bricht der
Headless-Browser sie zwischen zwei Aufrufen gelegentlich selbst ab. Die „Seite verlassen?“-Rückfrage zeigt
Headless-Chromium nicht an (im echten Browser schon).
