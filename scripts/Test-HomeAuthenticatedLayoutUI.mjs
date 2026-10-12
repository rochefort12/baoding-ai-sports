// Supplement to the anonymous layout check: a recovered ordinary participant
// session reads the real isolated frontend. Credentials never enter evidence.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const root = process.cwd(), directory = path.join(root, '.local/product-release-20261011', 'home-authenticated-' + Date.now());
const runtime = JSON.parse(fs.readFileSync(path.join(root, '.local/phase1-implementation/verification-runtime.json'), 'utf8'));
const session = JSON.parse(fs.readFileSync(path.join(root, '.local/phase1-implementation/verification-session.json'), 'utf8'));
assert.equal(runtime.port, 8082); assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/); assert.equal(runtime.database, session.database);
const actor = session.people[0]; assert.ok(actor.token && actor.id);
fs.mkdirSync(directory, { recursive: true });
const report = { timestamp: new Date().toISOString(), scope: 'Read-only actual isolated ordinary participant home at four widths; main/rehearsal footer geometry supplement. Recovered session in memory only. No login, SMS, model or business writes.', checks: [], blockedWrites: 0, passed: false };
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const check = (name, value) => { assert.ok(value, name); report.checks.push({ name, passed: true }); };
let page;
try {
  for (const width of [390, 730, 1024, 1440]) {
    const context = await browser.newContext({ viewport: { width, height: 1000 }, reducedMotion: 'reduce' });
    await context.addInitScript(token => { localStorage.setItem('Admin-Token', token); localStorage.setItem('Platform-Token', token); }, actor.token);
    page = await context.newPage(); const errors = [];
    page.on('pageerror', () => errors.push('page script error'));
    await context.route('**/dev-api/**', async route => { if (route.request().method() !== 'GET') { report.blockedWrites++; await route.abort(); } else await route.continue(); });
    const identityRead = page.waitForResponse(response => new URL(response.url()).pathname.endsWith('/sports/display') && response.status() === 200);
    await page.goto('http://127.0.0.1:5192/portal/home');
    const response = await identityRead; const identity = await response.json();
    check(width + ' real display API verifies the ordinary fixture session', identity.data?.accountId === actor.id);
    await page.locator('.home-feature-grid').waitFor(); await page.locator('.home-next .c-task-card').waitFor(); await page.waitForTimeout(300);
    check(width + ' has no script errors', errors.length === 0);
    check(width + ' has no document horizontal overflow', await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
    const dimensions = await page.evaluate(() => {
      const first = document.querySelector('.home-squad').getBoundingClientRect(), second = document.querySelector('.home-next .c-next-step').getBoundingClientRect();
      return { heightDelta: Math.abs(first.height - second.height), alignmentDelta: Math.abs(innerWidth <= 800 ? first.y - second.y : first.x - second.x) };
    });
    check(width + ' actual participant task cards remain equal and aligned', dimensions.heightDelta <= 1.5 && dimensions.alignmentDelta <= 1);
    const eventCards = await page.locator('.premium-event-card').evaluateAll(cards => cards.map(card => ({ card: card.getBoundingClientRect().width, body: card.querySelector('.event-body').getBoundingClientRect().width, cover: card.querySelector('.event-cover').getBoundingClientRect().width })));
    check(width + ' event cards retain visible covers and readable body columns', eventCards.length > 0 && eventCards.every(card => card.cover >= 80 && card.body >= card.card * .5));
    check(width + ' reduced-motion removes page transition animation', await page.locator('.consumer-main').evaluate(element => getComputedStyle(element).animationName === 'none'));
    if (width > 800) {
      check(width + ' rehearsal footer aligns with the main content', await page.evaluate(() => Math.abs(document.querySelector('.consumer-footer').getBoundingClientRect().x - document.querySelector('.premium-home').getBoundingClientRect().x) <= 1));
    }
    await page.evaluate(() => window.scrollTo(0, 0)); await page.screenshot({ path: path.join(directory, 'participant-' + width + '.png'), fullPage: true });
    await context.close(); page = undefined;
  }
  for (const width of [1024, 1440]) {
    const context = await browser.newContext({ viewport: { width, height: 1000 } }); page = await context.newPage();
    await page.goto('http://127.0.0.1:5190/portal/home'); await page.locator('.home-feature-grid').waitFor();
    check(width + ' main footer aligns with the main content', await page.evaluate(() => Math.abs(document.querySelector('.consumer-footer').getBoundingClientRect().x - document.querySelector('.premium-home').getBoundingClientRect().x) <= 1));
    await context.close(); page = undefined;
  }
  check('Supplement attempted no write requests', report.blockedWrites === 0); report.passed = true;
} catch (error) {
  report.error = String(error.message).slice(0, 200); process.exitCode = 1;
  if (page) await page.screenshot({ path: path.join(directory, 'failed.png'), fullPage: true }).catch(() => {});
} finally {
  await browser.close();
  const file = path.join(directory, 'receipt.json'), fd = fs.openSync(file, 'wx');
  try { fs.writeFileSync(fd, JSON.stringify(report, null, 2) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, error: report.error, report: path.relative(root, file).replaceAll('\\', '/') }));
}
