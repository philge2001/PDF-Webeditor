// Spielt Aktionen ab: node drive.js "<aktionen>"   (Aktionen durch ; getrennt)
//   open DATEI            Datei über „Datei öffnen“ (Startseite) laden
//   pick X Y DATEI[,DATEI] Klick, der einen Dateidialog öffnet, und Datei(en) wählen
//   c X Y | rc X Y | dc X Y   Klick / Rechtsklick / Doppelklick
//   d X1 Y1 X2 Y2         Ziehen
//   t TEXT                Tippen (Unterstrich = Leerzeichen)
//   k TASTE               Taste, z. B. Enter, Control+s
//   w MS                  warten
//   s NAME                Screenshot NAME.png
const { open } = require('./lib');
(async () => {
  const { b, p } = await open();
  // Dateidialoge dauerhaft abfangen (sonst bricht der Headless-Browser sie zwischen zwei
  // waitForEvent-Aufrufen manchmal selbst ab).
  p.on('filechooser', () => {});
  p.on('download', async d => { await d.saveAs('dl_' + d.suggestedFilename()); console.log('DOWNLOAD', d.suggestedFilename()); });
  for (const raw of process.argv[2].split(';').map(s => s.trim()).filter(Boolean)) {
    const [cmd, ...a] = raw.split(/\s+/);
    const n = a.map(Number);
    switch (cmd) {
      case 'open': { const [fc] = await Promise.all([p.waitForEvent('filechooser'), p.mouse.click(1300, 91)]); await fc.setFiles(a[0]); await p.waitForTimeout(1800); break; }
      case 'pick': {
        try {
          const [fc] = await Promise.all([p.waitForEvent('filechooser', { timeout: 5000 }), p.mouse.click(n[0], n[1])]);
          await fc.setFiles(a[2].split(','));
        } catch (e) {
          await p.screenshot({ path: 'pick_fail.png' });
          console.log('PICK-FEHLER', await p.evaluate(() => [document.getElementById('rfd-overlay')?.className, navigator.userActivation.isActive]));
          throw e;
        }
        await p.waitForTimeout(1200); break; }
      case 'c': await p.mouse.click(n[0], n[1]); await p.waitForTimeout(350); break;
      case 'rc': await p.mouse.click(n[0], n[1], { button: 'right' }); await p.waitForTimeout(350); break;
      case 'dc': await p.mouse.dblclick(n[0], n[1]); await p.waitForTimeout(350); break;
      case 'd': await p.mouse.move(n[0], n[1]); await p.mouse.down(); await p.mouse.move((n[0]+n[2])/2, (n[1]+n[3])/2, { steps: 8 }); await p.mouse.move(n[2], n[3], { steps: 8 }); await p.mouse.up(); await p.waitForTimeout(400); break;
      case 't': await p.keyboard.type(a.join(' ').replace(/_/g, ' '), { delay: 10 }); await p.waitForTimeout(200); break;
      case 'k': await p.keyboard.press(a[0]); await p.waitForTimeout(300); break;
      case 'w': await p.waitForTimeout(n[0]); break;
      case 's': await p.screenshot({ path: a[0] + '.png' }); break;
      default: throw new Error('unbekannt: ' + raw);
    }
  }
  await b.close();
})().catch(e => { console.log('FEHLER', e.message); process.exit(1); });
