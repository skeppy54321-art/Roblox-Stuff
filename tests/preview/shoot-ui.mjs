// shoot-ui.mjs: renders ui.html for each UI snapshot JSON and saves PNGs.
// Usage: node shoot-ui.mjs <out_dir> <background.png|-> <snapshot.json ...>
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.dirname(new URL(import.meta.url).pathname);
const [outDir, background, ...files] = process.argv.slice(2);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.png': 'image/png', '.woff2': 'font/woff2', '.woff': 'font/woff' };
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  const file = path.join(root, decodeURIComponent(url.pathname));
  fs.readFile(file, (err, buf) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(buf);
  });
});
await new Promise(r => server.listen(0, r));
const port = server.address().port;
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || undefined });
for (const file of files) {
  const data = JSON.parse(fs.readFileSync(path.join(root, file)));
  const page = await browser.newPage({ viewport: { width: data.width, height: data.height } });
  page.on('pageerror', e => console.log('pageerror:', e.message));
  page.on('console', m => console.log('console:', m.type(), m.text()));
  page.on('requestfailed', r => console.log('requestfailed:', r.url()));
  const bg = background && background !== '-' ? `&bg=${encodeURIComponent(background)}` : '';
  await page.goto(`http://localhost:${port}/ui.html?file=${encodeURIComponent(file)}${bg}&insets=1`);
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 15000 });
  const out = path.join(outDir, file.replace(/\.json$/, '.png'));
  await page.screenshot({ path: out });
  console.log('saved', out);
  await page.close();
}
await browser.close();
server.close();
