// Existing ordinary sessions, real date controls and GET-only browser traffic.
// Opening an unsaved event editor does not create or change any business object.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const state = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json', 'utf8'));
const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8'));
assert.equal(runtime.port, 8082);
assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/);
assert.equal(runtime.database, state.database);
assert.ok(state.people?.[0]?.token && state.organizer?.token);
const base = 'http://127.0.0.1:5192';
const participantOnly = process.argv.includes('--ParticipantOnly');
const out = path.resolve('.local/product-release-20261011', 'sport-date-focus-' + Date.now());
fs.mkdirSync(out, { recursive: true });
const report = { timestamp: new Date().toISOString(), scope: participantOnly ? 'Actual isolated ordinary participant birth-date input at 390/1440. No forced clicks, model, API substitution, form save or business write. Teleported datetime text editor and range-editor are outside this run.' : 'Actual isolated ordinary participant birth-date input and ordinary organizer unsaved event datetime input, including teleported date/time editors, at 390/1440. No forced clicks, model, API substitution, form save or business write. Range-editor focus receives source coverage only.', passed: false, checks: [], failures: [], blockedWrites: [], pageErrors: [], screenshots: [], sourceFiles: [] };
for (const file of ['scripts/Test-SportDateFocusUi.mjs', 'plus-ui/src/assets/styles/sport-controls.scss', 'plus-ui/src/assets/styles/index.scss', 'plus-ui/src/views/portal/identity.vue', 'plus-ui/src/views/sports/event/index.vue']) report.sourceFiles.push({ path: file, sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') });
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
let page, phase = 'start';
function check(name, result) { assert.ok(result, name); report.checks.push(name); }
function neutral(color) { const values = (color.match(/[\d.]+/g) || []).slice(0, 3).map(Number); return values.length === 3 && Math.max(...values) - Math.min(...values) < 65; }
async function focusCheck(label, input, wrapper) {
  await input.focus(); await input.press('ArrowLeft');
  check(label + ' keyboard input focus is actual', await input.evaluate(el => el === document.activeElement && el.matches(':focus-visible')));
  // ElementPlus transitions its existing stroke. Observe the actual final
  // appearance instead of reading the previous idle color on the first frame.
  await wrapper.evaluate(el => new Promise(resolve => { const started = performance.now(); const poll = () => { if (getComputedStyle(el).boxShadow === 'rgb(117, 128, 107) 0px 0px 0px 1px inset' || performance.now() - started > 1200) resolve(); else requestAnimationFrame(poll); }; poll(); }));
  report.lastFocus = { label, wrapper: await wrapper.evaluate(el => { const c = getComputedStyle(el); return { classes: el.className, border: c.borderTopWidth, borderColor: c.borderTopColor, outline: c.outlineStyle, shadow: c.boxShadow, keyboardColor: c.getPropertyValue('--s-control-keyboard'), activeInside: el.contains(document.activeElement), keyboardInside: el.matches(':has(:focus-visible)'), scopeAncestor: el.closest('.consumer-app,.business-app,.product-admin,.sport-work-login,.el-dialog,.el-drawer,.el-message-box,.el-popper')?.className || null }; }), input: await input.evaluate(el => { const c = getComputedStyle(el); return { classes: el.className, border: c.borderTopWidth, outline: c.outlineStyle, shadow: c.boxShadow }; }) };
  report.focusLayers ||= [];
  report.focusLayers.push({ label, layers: await input.evaluate(el => { const boundary = el.closest('.el-date-editor') || el.closest('.el-input'), layers = []; for (let node = el; node; node = node.parentElement) { const c = getComputedStyle(node); layers.push({ classes: node.className, border: c.borderTopWidth, borderColor: c.borderTopColor, outline: c.outlineStyle, shadow: c.boxShadow }); if (node === boundary) break; } return layers; }) });
  check(label + ' every actual ancestor exposes exactly one focus boundary', report.focusLayers.at(-1).layers.filter(layer => parseFloat(layer.border) > 0 || layer.outline !== 'none' || layer.shadow !== 'none').length === 1);
  check(label + ' keyboard focus is one neutral inset boundary without inner or outer frames', await wrapper.evaluate(el => getComputedStyle(el).outlineStyle === 'none' && getComputedStyle(el).boxShadow === 'rgb(117, 128, 107) 0px 0px 0px 1px inset') && await input.evaluate(el => getComputedStyle(el).outlineStyle === 'none' && getComputedStyle(el).boxShadow === 'none' && getComputedStyle(el).borderTopWidth === '0px'));
}
async function shot(name) { const file = path.join(out, name + '.png'); await page.screenshot({ path: file, fullPage: false }); report.screenshots.push({ path: path.relative(process.cwd(), file).replaceAll('\\', '/'), sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') }); }
try {
  for (const width of [390, 1440]) for (const kind of participantOnly ? ['participant'] : ['participant', 'organizer']) {
    const actor = kind === 'participant' ? state.people[0] : state.organizer;
    const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 1000 }, reducedMotion: 'reduce' });
    await context.addInitScript(token => { localStorage.setItem('Admin-Token', token); localStorage.setItem('Platform-Token', token); }, actor.token);
    await context.route('**/*', route => { if (!['GET', 'HEAD'].includes(route.request().method())) { report.blockedWrites.push({ path: new URL(route.request().url()).pathname, method: route.request().method() }); return route.abort('blockedbyclient'); } return route.continue(); });
    page = await context.newPage(); page.setDefaultTimeout(30000); page.on('pageerror', () => report.pageErrors.push('Page script error'));
    const label = width + '/' + kind;
    phase = label + ' verify existing identity';
    const identity = await context.request.get(base + '/dev-api/system/user/getInfo', { headers: { Authorization: 'Bearer ' + actor.token, clientid: actor.clientId || 'e5cd7e4891bf95d1d19206ce24a7b32e' } });
    check(label + ' existing session returns actual identity', identity.ok() && (await identity.json()).code === 200);
    phase = label + ' open actual route';
    await page.goto(base + (kind === 'participant' ? '/portal/identity' : '/org-desk/events'), { waitUntil: 'domcontentloaded' });
    let owner;
    if (kind === 'organizer') { phase = label + ' open unsaved event editor'; await page.locator('.b-heading').getByRole('button', { name: '＋ 手动创建赛事', exact: true }).click(); owner = page.getByRole('dialog', { name: '新建赛事', exact: true }); await owner.waitFor(); }
    else { owner = page.locator('.profile-form'); await owner.waitFor(); }
    const editor = owner.locator('.el-date-editor').first(), input = editor.locator('input').first(), wrapper = editor.locator('.el-input__wrapper').first();
    phase = label + ' focus real date field'; await focusCheck(label + ' real date field', input, wrapper);
    await input.click();
    const popup = page.locator('.el-popper').filter({ has: page.locator('.el-date-picker') }).filter({ visible: true });
    await popup.waitFor();
    await page.waitForFunction(() => [...document.querySelectorAll('.el-popper')].some(el => el.querySelector('.el-date-picker') && el.getClientRects().length && getComputedStyle(el).opacity === '1'));
    check(label + ' actual calendar is teleported beyond workspace', await popup.evaluate(el => !el.closest('.consumer-app,.business-app')));
    check(label + ' actual date popper has gray-green primary accent', await popup.evaluate(el => getComputedStyle(el).getPropertyValue('--el-color-primary').trim() === '#75806b'));
    if (kind === 'participant') check(label + ' existing selected date uses gray-green marker', await popup.locator('.el-date-table td.current .el-date-table-cell__text').first().evaluate(el => getComputedStyle(el).backgroundColor === 'rgb(117, 128, 107)'));
    else check(label + ' today marker uses gray-green accent', await popup.locator('.el-date-table td.today .el-date-table-cell__text').first().evaluate(el => getComputedStyle(el).color === 'rgb(117, 128, 107)'));
    if (kind === 'organizer') {
      const panelInput = popup.locator('.el-date-picker__time-header .el-input__inner').first();
      phase = label + ' focus teleported editor'; await panelInput.waitFor();
      await focusCheck(label + ' teleported date/time panel', panelInput, popup.locator('.el-date-picker__time-header .el-input__wrapper').first());
      await wrapper.evaluate(el => new Promise(resolve => { const started = performance.now(); const poll = () => { if (getComputedStyle(el).boxShadow === 'rgb(160, 166, 155) 0px 0px 0px 1px inset' || performance.now() - started > 1200) resolve(); else requestAnimationFrame(poll); }; poll(); }));
      check(label + ' active original date owner remains neutral while focus is in popup', await wrapper.evaluate(el => getComputedStyle(el).boxShadow === 'rgb(160, 166, 155) 0px 0px 0px 1px inset') && await editor.evaluate(el => getComputedStyle(el).boxShadow === 'none' && getComputedStyle(el).outlineStyle === 'none'));
    }
    await shot(width + '-' + kind + '-date-focus');
    phase = label + ' dismiss calendar'; await input.press('Escape'); await popup.waitFor({ state: 'hidden' });
    check(label + ' Escape dismisses calendar without submitting', true);
    if (kind === 'organizer') { await owner.getByRole('button', { name: '关闭', exact: true }).click(); await owner.waitFor({ state: 'hidden' }); check(label + ' unsaved editor closes with no creation', true); }
    await context.close(); page = undefined;
  }
  check('no non-GET requests', report.blockedWrites.length === 0); check('no page script errors', report.pageErrors.length === 0); report.passed = true;
} catch (error) { report.failures.push({ type: error.name, message: error.name === 'AssertionError' ? error.message : 'Date-control verification did not complete; private details omitted', phase, path: page ? new URL(page.url()).pathname : undefined }); if (page) await shot('failure').catch(() => {}); process.exitCode = 1; }
finally { await browser.close(); const file = path.join(out, 'receipt.json'), fd = fs.openSync(file, 'wx'); try { fs.writeFileSync(fd, JSON.stringify(report, null, 2) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); } console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failures: report.failures, report: path.relative(process.cwd(), file).replaceAll('\\', '/') })); }
