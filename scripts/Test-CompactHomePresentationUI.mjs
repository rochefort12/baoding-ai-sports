// Real ordinary participant reads the isolated home. Login only; no business writes or mocked responses.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { context } from './lib/BusinessRegression.mjs';

const out = path.join('.local/home-compact-20261012', crypto.randomUUID());
fs.mkdirSync(out, { recursive: true });
const source = 'plus-ui/src/views/portal/home.vue';
const digest = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8').replace(/^\uFEFF/, ''));
const receipt = { at: new Date().toISOString(), passed: false, scope: 'Actual ordinary participant desktop, medium and mobile home. Existing synthetic isolated data read-only; login only. No business writes, response mocks or DOM content replacement.', database: context.database, jarSha256: runtime.jarSHA256, source, sourceSha256: digest(source), checks: [], screenshots: [], blockedWrites: 0 };
const save = () => fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(receipt, null, 2));
const check = (name, condition, detail = {}) => { receipt.checks.push({ name, passed: !!condition, ...detail }); save(); assert.ok(condition, name); };
const { chromium } = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
let page;
try {
  for (const [device, viewport] of [['desktop', { width: 1440, height: 1000 }], ['medium', { width: 1024, height: 1000 }], ['mobile', { width: 390, height: 844 }], ['narrow', { width: 320, height: 844 }]]) {
    const browserContext = await browser.newContext({ viewport, reducedMotion: 'reduce' });
    page = await browserContext.newPage(); const errors = [];
    page.on('pageerror', () => errors.push('page script error'));
    await page.goto(context.frontend + '/portal/login');
    await page.getByPlaceholder('请输入手机号').fill(context.people[0].phone);
    await page.getByPlaceholder('请输入密码').fill(context.password);
    await page.getByRole('button', { name: '登录', exact: true }).click();
    await page.waitForURL(url => !url.pathname.includes('/login'));
    await browserContext.route('**/dev-api/**', async route => { if (route.request().method() !== 'GET') { receipt.blockedWrites++; await route.abort(); } else await route.continue(); });
    const identityRead = page.waitForResponse(response => new URL(response.url()).pathname.endsWith('/sports/display') && response.status() === 200);
    await page.goto(context.frontend + '/portal/home');
    const identity = await (await identityRead).json();
    check(device + ' ordinary participant identity is verified by real display API', identity.data?.accountId === context.people[0].id);
    await page.locator('.home-feature-grid').waitFor();
    await page.locator('.home-next .c-task-card').waitFor();
    await page.waitForFunction(() => Array.from(document.querySelectorAll('.premium-home img')).every(img => img.complete));
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    await page.locator('.el-message').waitFor({ state: 'hidden' });
    const geometry = await page.evaluate(() => {
      const box = selector => { const element = document.querySelector(selector); const b = element.getBoundingClientRect(); return { x: b.x, y: b.y, width: b.width, height: b.height, right: b.right, bottom: b.bottom, scrollWidth: element.scrollWidth, clientWidth: element.clientWidth }; };
      const selectors = ['.home-feature', '.home-feature-copy', '.feature-bottom', '.home-personal', '.home-squad', '.home-next .c-next-step', '.home-services'];
      const result = Object.fromEntries(selectors.map(selector => [selector, box(selector)]));
      return { viewport: innerWidth, documentWidth: document.documentElement.scrollWidth, ...result, imageLoaded: document.querySelector('.home-feature-art').naturalWidth > 0, progressVisible: getComputedStyle(document.querySelector('.home-next .c-task-progress')).display !== 'none', membersVisible: getComputedStyle(document.querySelector('.home-next .c-task-members')).display !== 'none', links: Array.from(document.querySelectorAll('.feature-bottom a,.squad-summary a,.home-next .c-task-card>a,.home-services a')).map(el => ({ text: el.textContent.trim(), href: el.getAttribute('href'), x: el.getBoundingClientRect().x, right: el.getBoundingClientRect().right, width: el.getBoundingClientRect().width })) };
    });
    check(device + ' has no script errors', errors.length === 0);
    check(device + ' no horizontal page overflow', geometry.documentWidth <= geometry.viewport + 1, { geometry });
    check(device + ' hero illustration decodes', geometry.imageLoaded);
    const hero = geometry['.home-feature'], bottom = geometry['.feature-bottom'];
    check(device + ' hero action and fee stay inside visible hero', bottom.bottom <= hero.bottom + 1 && bottom.right <= hero.right + 1 && bottom.x >= hero.x - 1);
    check(device + ' member confirmation and all progress steps remain visible', geometry.progressVisible && geometry.membersVisible && await page.locator('.home-next .c-task-progress span').count() === 3);
    check(device + ' all home action links have visible targets and fit viewport', geometry.links.length >= 8 && geometry.links.every(link => link.href && link.width >= 36 && link.x >= -1 && link.right <= viewport.width + 1));
    if (viewport.width > 800) {
      check(device + ' balanced hero stays within 520 to 580 pixels', hero.height >= 520 && hero.height <= 580);
      check(device + ' left hero and right cards share both top and bottom edges', Math.abs(hero.y - geometry['.home-personal'].y) <= 2 && Math.abs(hero.bottom - geometry['.home-personal'].bottom) <= 2);
    }
    else check(device + ' compact mobile hero stays readable without excessive height', hero.height >= 300 && hero.height <= 460);
    for (const [name, selector] of [['top', null], ['personal', '.home-personal']]) {
      if (selector) await page.locator(selector).scrollIntoViewIfNeeded(); else await page.evaluate(() => scrollTo(0, 0));
      const file = path.join(out, device + '-' + name + '.png'); await page.screenshot({ path: file }); receipt.screenshots.push(path.resolve(file)); save();
    }
    await browserContext.close(); page = undefined;
  }
  check('No business write requests were attempted', receipt.blockedWrites === 0);
  check('Homepage source remained unchanged during observations', digest(source) === receipt.sourceSha256);
  receipt.passed = true; receipt.finishedAt = new Date().toISOString(); save();
} catch (error) {
  receipt.error = String(error.message).slice(0, 240); save(); process.exitCode = 1;
  if (page) await page.screenshot({ path: path.join(out, 'failure.png') }).catch(() => {});
} finally {
  await browser.close(); save(); console.log(JSON.stringify({ passed: receipt.passed, checks: receipt.checks.length, error: receipt.error, report: path.resolve(out, 'receipt.json') }));
}
