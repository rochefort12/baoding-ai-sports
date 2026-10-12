// Actual empty work login, with pointer/keyboard focus and blur validation only.
// Never submits credentials or changes business state; all non-GET traffic fails.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const out = path.resolve('.local/product-release-20261011', 'work-login-focus-' + Date.now()); fs.mkdirSync(out, { recursive: true });
const report = { timestamp: new Date().toISOString(), scope: 'Actual 5190/5192 empty work login at 390/1440: one field boundary, pointer/keyboard focus, normal empty blur validation and focused red errors. No login submission, credential, model, response mock, forced click or business write.', passed: false, checks: [], failures: [], blockedWrites: [], pageErrors: [], screenshots: [], sourceFiles: [] };
for (const file of ['scripts/Test-WorkLoginFocusUi.mjs', 'plus-ui/src/assets/styles/sport-controls.scss', 'plus-ui/src/assets/styles/index.scss', 'plus-ui/src/components/sport-ui/SportField.vue', 'plus-ui/src/views/login.vue']) report.sourceFiles.push({ path: file, sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') });
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' }); let page;
function check(name, value) { assert.ok(value, name); report.checks.push(name); }
async function single(wrapper, input) { return await wrapper.evaluate(el => { const c = getComputedStyle(el); return c.borderTopWidth === '1px' && c.outlineStyle === 'none' && c.boxShadow === 'none'; }) && await input.evaluate(el => { const c = getComputedStyle(el); return c.borderTopWidth === '0px' && c.outlineStyle === 'none' && c.boxShadow === 'none'; }); }
function neutral(color) { const parts = (color.match(/[\d.]+/g) || []).slice(0, 3).map(Number); return parts.length === 3 && Math.max(...parts) - Math.min(...parts) < 65; }
async function shot(name) { const file = path.join(out, name + '.png'); await page.screenshot({ path: file, fullPage: false }); report.screenshots.push({ path: path.relative(process.cwd(), file).replaceAll('\\', '/'), sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') }); }
try {
  for (const port of [5190, 5192]) for (const width of [390, 1440]) {
    const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 1000 }, reducedMotion: 'reduce' });
    await context.route('**/*', route => { if (!['GET', 'HEAD'].includes(route.request().method())) { report.blockedWrites.push({ path: new URL(route.request().url()).pathname, method: route.request().method() }); return route.abort('blockedbyclient'); } return route.continue(); });
    page = await context.newPage(); page.setDefaultTimeout(15000); page.on('pageerror', () => report.pageErrors.push('Work-login page script error'));
    await page.goto('http://127.0.0.1:' + port + '/login?redirect=/sports-platform', { waitUntil: 'domcontentloaded' });
    const label = port + '/' + width, username = page.getByPlaceholder('请输入工作账号', { exact: true }), password = page.getByPlaceholder('请输入密码', { exact: true });
    await username.waitFor(); const userControl = page.locator('.sport-field-control').filter({ has: username }), passControl = page.locator('.sport-field-control').filter({ has: password });
    check(label + ' actual empty account/password controls are present', await username.inputValue() === '' && await password.inputValue() === '');
    await username.click(); check(label + ' pointer focus has one boundary and no halo', await single(userControl, username));
    check(label + ' pointer boundary is quiet and neutral', neutral(await userControl.evaluate(el => getComputedStyle(el).borderTopColor)));
    await username.press('ArrowLeft'); check(label + ' keyboard focus remains actual and single', await username.evaluate(el => el.matches(':focus-visible') && el === document.activeElement) && await single(userControl, username));
    check(label + ' keyboard focus changes that same border to darker neutral', await userControl.evaluate(el => getComputedStyle(el).borderTopColor === 'rgb(117, 128, 107)'));
    await shot(port + '-' + width + '-account-focus');
    await password.click(); await page.locator('.sport-work-login .el-form-item.is-error').first().waitFor();
    check(label + ' real empty blur validation retains red error border', await userControl.evaluate(el => { const c = getComputedStyle(el).borderTopColor.match(/\d+/g).map(Number); return c[0] > c[1] + 30 && c[0] > c[2] + 30; }));
    check(label + ' password pointer focus has one boundary', await single(passControl, password));
    await username.click(); await username.press('ArrowLeft');
    check(label + ' focused invalid account keeps red single boundary', await single(userControl, username) && await userControl.evaluate(el => { const c = getComputedStyle(el).borderTopColor.match(/\d+/g).map(Number); return c[0] > c[1] + 30 && c[0] > c[2] + 30; }));
    await shot(port + '-' + width + '-focused-errors');
    check(label + ' no horizontal overflow', await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
    await context.close(); page = undefined;
  }
  check('zero page script errors', report.pageErrors.length === 0); check('zero non-GET requests including auth', report.blockedWrites.length === 0); report.passed = true;
} catch (error) { report.failures.push({ type: error.name, message: error.name === 'AssertionError' ? error.message : 'Work-login focus verification did not complete; private details omitted', path: page ? new URL(page.url()).pathname : undefined }); if (page) await shot('failure').catch(() => {}); process.exitCode = 1; }
finally { await browser.close(); const file = path.join(out, 'receipt.json'), fd = fs.openSync(file, 'wx'); try { fs.writeFileSync(fd, JSON.stringify(report, null, 2) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); } console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failures: report.failures, report: path.relative(process.cwd(), file).replaceAll('\\', '/') })); }
