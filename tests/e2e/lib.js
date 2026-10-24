// Gemeinsame Helfer für die Browser-Tests: startet Chromium und öffnet die Webapp.
// Adresse über die Umgebungsvariable URL (Standard: http://localhost:8080/).
const { chromium } = require('playwright');

exports.open = async (width = 1400, height = 850) => {
  // Software-WebGL, damit es auch ohne Grafikkarte (CI, Container) läuft.
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width, height }, acceptDownloads: true });
  p.on('console', m => {
    if (!/GL Driver|willReadFrequently|GPU stall|%cDEBUG|%cINFO/.test(m.text())) {
      console.log('console:', m.type(), m.text().slice(0, 400));
    }
  });
  p.on('pageerror', e => console.log('pageerror:', e.message));
  const t0 = Date.now();
  await p.goto(process.env.URL || 'http://localhost:8080/');
  await p.waitForFunction(() => !document.getElementById('loading'), null, { timeout: 60000 });
  console.log('Start ms', Date.now() - t0);
  await p.waitForTimeout(1000);
  return { b, p };
};
