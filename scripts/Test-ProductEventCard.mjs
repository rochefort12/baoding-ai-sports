// Actual ordinary participant reads. No mocked responses, fixture writes or model calls.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const state = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json', 'utf8'));
const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8'));
const frontend = JSON.parse(fs.readFileSync('.local/demo-20261011/frontend-runtime.json', 'utf8'));
assert.equal(runtime.port, 8082);
assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/);
assert.equal(state.database, runtime.database);
assert.equal(frontend.port, 5192);
assert.equal(frontend.backendPort, 8082);
const out = path.resolve('.local/product-release-20261011', 'event-card-ui-' + Date.now());
fs.mkdirSync(out, { recursive: true });
const checks = [], failures = [], writes = [], errors = [];
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
try {
  for (const width of [360, 390, 730, 1440]) {
    const context = await browser.newContext({ viewport: { width, height: 950 }, reducedMotion: 'reduce' });
    await context.addInitScript(token => localStorage.setItem('Admin-Token', token), state.people[0].token);
    const page = await context.newPage();
    page.on('pageerror', () => errors.push('Page script error'));
    page.on('request', request => { if (!['GET', 'HEAD'].includes(request.method())) writes.push(new URL(request.url()).pathname); });
    try {
      const authorized = await page.request.get('http://127.0.0.1:5192/dev-api/sports/display', {
        headers: { Authorization: 'Bearer ' + state.people[0].token, clientid: 'e5cd7e4891bf95d1d19206ce24a7b32e' }
      });
      assert.equal((await authorized.json()).code, 200, 'Real ordinary participant session');
      for (const [route, name] of [['/portal/home', 'home'], ['/public/events', 'catalog']]) {
        await page.goto('http://127.0.0.1:5192' + route, { waitUntil: 'domcontentloaded' });
        const cards = page.locator('.premium-event-card');
        await cards.first().waitFor({ timeout: 20000 });
        await page.waitForFunction(() => [...document.querySelectorAll('.premium-event-card .event-banner')].every(image => image.complete && image.naturalWidth > 0));
        const geometry = await cards.evaluateAll(nodes => nodes.map(node => {
          const body = node.querySelector('.event-body'), cover = node.querySelector('.event-cover-media'), place = node.querySelector('.event-place'), extra = node.querySelector('.event-extra');
          return {
            cardWidth: node.getBoundingClientRect().width,
            bodyWidth: body.getBoundingClientRect().width,
            coverWidth: cover.getBoundingClientRect().width,
            coverHeight: cover.getBoundingClientRect().height,
            coverVisible: getComputedStyle(cover).display !== 'none',
            placeVisible: getComputedStyle(place).display !== 'none',
            feeVisible: getComputedStyle(extra).display !== 'none',
            imagesInert: [...node.querySelectorAll('img')].every(image => !image.draggable),
            title: node.querySelector('h3').innerText
          };
        }));
        assert.ok(geometry.length > 0);
        assert.ok(geometry.every(card => card.coverVisible && card.coverWidth >= 100 && card.coverHeight >= 120), 'Visible real/fallback cover');
        assert.ok(geometry.every(card => card.bodyWidth >= 190), 'Readable event information column');
        assert.ok(geometry.every(card => card.placeVisible && card.feeVisible && card.imagesInert), 'Location, fee and non-draggable picture');
        assert.ok(!await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), 'No horizontal overflow');
        checks.push({ width, page: name, geometry, passed: true });
        await page.screenshot({ path: path.join(out, name + '-' + width + '.png'), fullPage: true });
        await cards.first().screenshot({ path: path.join(out, name + '-card-' + width + '.png') });
        console.log('PASS actual ' + name + ' event cards at ' + width + 'px');
      }
    } catch (error) {
      failures.push({ width, reason: String(error.message).slice(0, 700) });
      await page.screenshot({ path: path.join(out, 'failure-' + width + '.png'), fullPage: true }).catch(() => {});
      console.error('FAIL ' + width + ': ' + failures.at(-1).reason);
    } finally { await context.close(); }
  }
  assert.deepEqual(writes, []);
  assert.deepEqual(errors, []);
} finally {
  await browser.close();
  fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify({ timestamp: new Date().toISOString(), scope: 'Real ordinary participant home and event catalogue, four widths; no response interception, login, model calls or business writes.', checks, failures, writes, pageErrors: errors }, null, 2), { flag: 'wx' });
  console.log('Evidence: ' + path.relative(process.cwd(), out));
  if (failures.length || writes.length || errors.length) process.exitCode = 1;
}
