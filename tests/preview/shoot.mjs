// shoot.mjs: renders render.html from several camera views and saves PNGs.
// Usage: node shoot.mjs <out_dir> [view ...]
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.dirname(new URL(import.meta.url).pathname);
const outDir = process.argv[2] || root;
const views = process.argv.slice(3);

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json' };
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

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || undefined,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
page.on('pageerror', e => console.log('pageerror:', e.message));
for (const view of views) {
  const [viewName, file] = view.split(":");
  await page.goto(`http://localhost:${port}/render.html?view=${viewName}&file=${file || "parts.json"}`);
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 180000 });
  const stats = await page.evaluate(() => window.__stats);
  const out = path.join(outDir, `view-${viewName}${file ? "-up" : ""}.png`);
  await page.screenshot({ path: out });
  console.log("saved", out, JSON.stringify(stats));
}
await browser.close();
server.close();
