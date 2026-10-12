// Ordinary profile is read from the real isolated service. Positive podium pictures
// use separate SSR synthetic display contracts and never create honor facts.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const base = 'http://127.0.0.1:5192';
const actualOnly = process.argv.includes('--actual-only');
const fixtureDirectory = process.argv.find((value, index) => index > 1 && !value.startsWith('--'));
const output = path.resolve('.local/product-release-20261011/world-honor-ui-' + Date.now());
fs.mkdirSync(output, { recursive: true });
const report = { timestamp: new Date().toISOString(), scope: 'Actual ordinary profile GET and unsaved SportSelect interaction; separate synthetic SSR world podium display. No upload, save, submit, wear, award, model, or business write.', checks: [], failures: [], pageErrors: [], writes: [], passed: false, artifacts: [] };
const check = (name, value) => { assert.ok(value, name); report.checks.push(name); };
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
let currentPage;
const contexts = [];
async function screenshot(page, name, fullPage = true) {
  const file = path.join(output, name); await page.screenshot({ path: file, fullPage });
  report.artifacts.push({ file: name, sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') });
}
async function contextAt(width, token) {
  const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 1000 }, reducedMotion: 'reduce' });
  contexts.push(context);
  if (token) await context.addInitScript(value => { localStorage.setItem('Admin-Token', value); localStorage.setItem('Platform-Token', value); }, token);
  const page = await context.newPage(); currentPage = page;
  page.on('pageerror', () => report.pageErrors.push('Page script error'));
  page.on('request', request => { const uri = new URL(request.url()); if (uri.pathname.startsWith('/dev-api/') && request.method() !== 'GET') report.writes.push({ path: uri.pathname, method: request.method() }); });
  return page;
}
try {
  const state = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json', 'utf8'));
  const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8'));
  assert.equal(runtime.port, 8082); assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/); assert.equal(runtime.database, state.database);
  const actor = state.people[0];
  async function get(page, uri) { const response = await page.request.get(base + '/dev-api' + uri, { headers: { Authorization: 'Bearer ' + actor.token, clientid: actor.clientId } }); const body = await response.json(); assert.equal(body.code, 200, 'Actual authorized GET failed'); return body.data; }
  for (const [device, width] of [['desktop', 1440], ['mobile', 390]]) {
    const page = await contextAt(width, actor.token);
    const before = await get(page, '/sports/honors/certifications');
    const approved = await get(page, '/sports/honors/certifications/approved');
    await page.goto(base + '/portal/profile'); await page.getByRole('heading', { name: '完善资料', exact: true }).waitFor();
    const certification = page.locator('[data-testid="honor-certification"]'); await certification.waitFor();
    await page.waitForFunction(() => document.querySelector('[data-testid="honor-certification"]')?.getAttribute('aria-busy') === 'false');
    check('Actual ' + device + ': certification GET succeeded', await certification.locator('.honor-cert-error').count() === 0);
    const selectedSport = await page.locator('.profile-menu .sports-profile-card').getAttribute('data-sport-id');
    const valid = approved.filter(h => h.worn === true && h.sportId === selectedSport && h.honorId && h.title?.trim() && Number.isInteger(h.eventYear) && h.eventYear >= 1900 && h.eventYear <= new Date().getFullYear() && [1,2,3].includes(h.place));
    const frames = await page.locator('.profile-person .avatar-frame').evaluateAll(nodes => nodes.map(node => node.getAttribute('data-certified-frame')).filter(Boolean));
    check('Actual ' + device + ': world frame follows approved worn current-sport facts; empty projection cannot counterfeit a badge', JSON.stringify(frames) === JSON.stringify(valid.length === 1 ? [valid[0].honorId] : []));
    check('Actual ' + device + ': independent badges follow approved facts', JSON.stringify(await page.locator('.profile-person .certified-honor-badge').evaluateAll(nodes => nodes.map(node => node.getAttribute('data-honor-id')))) === JSON.stringify(valid.map(h => h.honorId)));
    await certification.getByRole('button', { name: '申请认证', exact: true }).click();
    const editor = certification.locator('[data-testid="honor-certification-editor"]'); await editor.waitFor();
    const sport = editor.getByRole('combobox', { name: '运动项目', exact: true }); await sport.click();
    const sportList = page.getByRole('listbox', { name: '运动项目', exact: true }); await sportList.waitFor();
    check('Actual ' + device + ': sport options are available from the real catalogue', await sportList.getByRole('option').count() > 0);
    await sportList.getByRole('option', { name: '羽毛球', exact: true }).click();
    check('Actual ' + device + ': normal pointer selection keeps the sport value', await sport.innerText() === '羽毛球' && await sport.getAttribute('aria-expanded') === 'false');
    const placement = editor.getByRole('combobox', { name: '获奖名次', exact: true }); await placement.click();
    const list = page.getByRole('listbox', { name: '获奖名次', exact: true }); await list.waitFor();
    check('Actual ' + device + ': only three claim places are selectable', await list.getByRole('option').count() === 3);
    await placement.press('ArrowDown'); await placement.press('Enter');
    check('Actual ' + device + ': keyboard selection changes champion to runner-up and closes the menu', await placement.innerText() === '亚军' && await placement.getAttribute('aria-expanded') === 'false');
    await placement.click(); await placement.press('Escape');
    check('Actual ' + device + ': Escape closes options while preserving the form', await placement.getAttribute('aria-expanded') === 'false' && await editor.isVisible());
    check('Actual ' + device + ': selecting claim fields does not grant a world badge or unlock proof upload', await editor.getByRole('button', { name: '上传证明', exact: true }).isDisabled() && await editor.locator('.certified-honor-badge').count() === 0);
    check('Actual ' + device + ': actual form fits the viewport', await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
    // A full-page capture while scrolled would paste offscreen fixed navigation
    // into the middle of the document. Preserve the user's actual form viewport.
    await screenshot(page, device + '-actual-unsaved-honor-form.png', false);
    await certification.getByRole('button', { name: '收起', exact: true }).click();
    const dialog = page.getByRole('dialog', { name: '保留修改', exact: true }); await dialog.waitFor();
    await dialog.getByRole('button', { name: '放弃修改', exact: true }).click(); await editor.waitFor({ state: 'hidden' });
    check('Actual ' + device + ': unsaved form can be discarded without creating an application', JSON.stringify(await get(page, '/sports/honors/certifications')) === JSON.stringify(before));
    await page.evaluate(() => window.scrollTo(0,0)); await screenshot(page, device + '-actual-profile.png');
  }
  if (!actualOnly) {
    assert.ok(fixtureDirectory, 'Synthetic SSR fixture directory is required');
    const resolved = path.resolve(fixtureDirectory), allowed = path.resolve('.local/product-release-20261011') + path.sep;
    assert.ok(resolved.startsWith(allowed), 'Fixture must remain in the intended private evidence directory');
    const fixture = fs.readFileSync(path.join(resolved, 'synthetic-world-honor-components.html'), 'utf8');
    check('Synthetic: fixture explicitly says its samples are not real certifications', fixture.includes('合成契约样本') && fixture.includes('不代表真实认证'));
    for (const [device, width] of [['desktop', 1440], ['mobile', 390]]) {
      const page = await contextAt(width); await page.setContent(fixture, { waitUntil: 'networkidle' });
      check('Synthetic ' + device + ': three distinct podium frames are scoped to their exact cards', await page.locator('.sample').evaluateAll(nodes => nodes.every((node, index) => node.querySelector('.avatar-frame')?.getAttribute('data-frame') === ['world-champion','world-runner-up','world-third-place'][index])));
      check('Synthetic ' + device + ': all six real raster files load and stay bounded', await page.locator('img').evaluateAll(nodes => nodes.length === 6 && nodes.every(node => node.complete && node.naturalWidth > 0 && node.getBoundingClientRect().width <= 150 && node.getBoundingClientRect().height <= 150)));
      check('Synthetic ' + device + ': artwork cannot drag or capture interactions', await page.locator('img').evaluateAll(nodes => nodes.every(node => node.draggable === false && getComputedStyle(node).pointerEvents === 'none')));
      check('Synthetic ' + device + ': growth and participation title remain independent', await page.locator('[data-growth-rank="bronze"]').count() === 3 && await page.getByText('首次完赛', { exact: true }).count() === 3);
      check('Synthetic ' + device + ': artwork fits viewport without horizontal overflow', await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
      check('Synthetic ' + device + ': reduced motion disables all decoration animation', await page.locator('.avatar-energy,.avatar-particles,.certified-honor-light').evaluateAll(nodes => nodes.length === 9 && nodes.every(node => getComputedStyle(node).animationName === 'none')));
      await screenshot(page, device + '-synthetic-podium-appearance.png');
    }
  }
  check('Global: no business or login write requests were produced', report.writes.length === 0);
  check('Global: no page script errors', report.pageErrors.length === 0); report.passed = true;
} catch (error) {
  report.failures.push({ type: error.name, message: error.name === 'AssertionError' ? error.message : 'Verification did not complete; private diagnostics omitted' }); process.exitCode = 1;
  if (currentPage) await screenshot(currentPage, 'failure.png').catch(() => {});
} finally {
  for (const context of contexts) await context.close(); await browser.close();
  const file = path.join(output, 'receipt.json'), fd = fs.openSync(file, 'wx');
  try { fs.writeFileSync(fd, JSON.stringify(report, null, 2) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failures: report.failures, receipt: path.relative(process.cwd(), file).replaceAll('\\','/'), sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') }));
}
