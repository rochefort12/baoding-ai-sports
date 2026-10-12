// Read-only browser inspection of the two real local frontends. No API rewriting,
// login, SMS, model generation, registration, or tournament mutations are allowed.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const root = process.cwd();
const out = path.join(root, '.local/product-release-20261011', 'home-auth-' + Date.now());
fs.mkdirSync(out, { recursive: true });
const report = { timestamp: new Date().toISOString(), scope: 'Actual anonymous main 5190 and isolated rehearsal 5192 home/login/register/reset layouts at four widths. Read APIs only; no response substitutions or login/SMS/model/business writes.', checks: [], artifacts: [], failures: [], blockedWrites: 0 };
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
let currentPage;
const check = (name, value) => { assert.ok(value, name); report.checks.push({ name, passed: true }); };
const routes = [
  ['home', '/portal/home'],
  ['login', '/portal/login?returnTo=/portal/rooms'],
  ['register', '/portal/register?returnTo=/portal/rooms'],
  ['reset', '/portal/forgot?returnTo=/portal/rooms']
];
try {
  for (const port of [5190, 5192]) for (const width of [390, 730, 1024, 1440]) {
    const context = await browser.newContext({ viewport: { width, height: width < 800 ? 844 : 1000 }, reducedMotion: 'no-preference' });
    const page = await context.newPage(); currentPage = page;
    const errors = [];
    page.on('pageerror', () => errors.push('page script error'));
    await context.route('**/dev-api/**', async route => {
      if (route.request().method() !== 'GET') { report.blockedWrites++; await route.abort(); return; }
      await route.continue();
    });
    for (const [name, route] of routes) {
      const label = port + ' / ' + width + ' / ' + name;
      await page.goto('http://127.0.0.1:' + port + route);
      await page.locator(name === 'home' ? '.home-feature-grid' : '.sport-auth-native').waitFor();
      await page.waitForTimeout(350);
      check(label + ' renders without Vite errors', await page.locator('vite-error-overlay').count() === 0);
      check(label + ' has no document horizontal overflow', await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
      const images = await page.locator('.home-feature-art,.home-advisor img,.header-ai-entry img,.mobile-ai-symbol img,.sport-auth-image,.sport-brand-mark img').evaluateAll(elements => elements.map(image => ({ draggable: image.draggable, dragStyle: getComputedStyle(image).webkitUserDrag })));
      check(label + ' static images reject native browser dragging', images.length > 0 && images.every(image => image.draggable === false && image.dragStyle === 'none'));
      check(label + ' has no page script errors', errors.length === 0);
      check(label + ' brand mark remains visible at this width', await page.locator('.consumer-brand .sport-brand-mark').isVisible());
      if (name === 'home') {
        const loginColors = await page.locator('.header-login').evaluate(link => ({ text: getComputedStyle(link).color, backdrop: getComputedStyle(document.querySelector('.consumer-app')).backgroundColor }));
        const luminance = color => {
          const rgb = color.match(/[\d.]+/g).slice(0, 3).map(value => Number(value) / 255).map(value => value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4);
          return rgb[0] * .2126 + rgb[1] * .7152 + rgb[2] * .0722;
        };
        const foreground = luminance(loginColors.text), background = luminance(loginColors.backdrop);
        check(label + ' header login retains readable contrast', (Math.max(foreground, background) + .05) / (Math.min(foreground, background) + .05) >= 4.5);
        const alignment = await page.evaluate(() => {
          const first = document.querySelector('.home-squad').getBoundingClientRect();
          const second = document.querySelector('.home-next .c-next-step').getBoundingClientRect();
          return { first: { x: first.x, y: first.y, height: first.height }, second: { x: second.x, y: second.y, height: second.height }, sideBySide: innerWidth <= 800 };
        });
        check(label + ' two task cards have equal height', Math.abs(alignment.first.height - alignment.second.height) <= 1.5);
        check(label + ' task cards share the row/column alignment', Math.abs(alignment.sideBySide ? alignment.first.y - alignment.second.y : alignment.first.x - alignment.second.x) <= 1);
        const orbs = await page.locator('.home-advisor img,.header-ai-entry img,.mobile-ai-symbol img').evaluateAll(elements => elements.map(image => { const rect = image.getBoundingClientRect(); return { width: rect.width, height: rect.height }; }).filter(rect => rect.width > 0));
        check(label + ' assistant entry images remain small', orbs.every(rect => rect.width <= 36 && rect.height <= 36));
        await page.evaluate(() => { window.__nativeImageDragCount = 0; document.addEventListener('dragstart', event => { if (event.target instanceof HTMLImageElement && !event.defaultPrevented) window.__nativeImageDragCount++; }); });
        const art = await page.locator('.home-feature-art').boundingBox();
        await page.mouse.move(art.x + art.width * .85, art.y + 32);
        await page.mouse.down(); await page.mouse.move(art.x + art.width * .85 - 50, art.y + 90, { steps: 10 }); await page.mouse.up();
        check(label + ' actual mouse drag produces no native image ghost event', await page.evaluate(() => window.__nativeImageDragCount === 0));
      } else {
        check(label + ' auth layout has no assistant entry', await page.locator('.sport-auth-visual button,.header-ai-entry,.consumer-mobile-ai').count() === 0);
        check(label + ' obsolete vendor configuration prompt is absent', !(await page.locator('body').innerText()).includes('当前没有启用阿里云验证码'));
        check(label + ' original task stays in the return link', await page.locator('.auth-back').getAttribute('href') === '/portal/rooms');
        const inputMetrics = await page.locator('.sport-auth-native input').evaluateAll(inputs => inputs.filter(input => input.type !== 'hidden').map(input => ({ width: input.getBoundingClientRect().width, height: input.getBoundingClientRect().height })));
        check(label + ' native fields retain readable tap targets', inputMetrics.length > 0 && inputMetrics.every(input => input.width > 130 && input.height >= 44));
      }
      await page.evaluate(() => window.scrollTo(0, 0));
      const screenshot = path.join(out, port + '-' + width + '-' + name + '.png');
      await page.screenshot({ path: screenshot, fullPage: true });
      report.artifacts.push({ path: path.relative(root, screenshot).replaceAll('\\', '/'), sha256: crypto.createHash('sha256').update(fs.readFileSync(screenshot)).digest('hex') });
    }
    await context.close(); currentPage = undefined;
  }
  check('No blocked write requests were attempted by these flows', report.blockedWrites === 0);
  report.passed = true;
} catch (error) {
  report.passed = false; report.failures.push(String(error.message).slice(0, 250));
  if (currentPage) await currentPage.screenshot({ path: path.join(out, 'failed.png'), fullPage: true }).catch(() => {});
  process.exitCode = 1;
} finally {
  await browser.close();
  const reportPath = path.join(out, 'receipt.json');
  const fd = fs.openSync(reportPath, 'wx');
  try { fs.writeFileSync(fd, JSON.stringify(report, null, 2) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failure: report.failures[0], report: path.relative(root, reportPath).replaceAll('\\', '/') }));
}
