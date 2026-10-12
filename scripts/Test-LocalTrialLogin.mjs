// Fresh ordinary-organizer login against the existing local trial. Never log credentials.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium} = require('playwright');
const state = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json', 'utf8').replace(/^\uFEFF/, ''));
const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8').replace(/^\uFEFF/, ''));
assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/);
assert.equal(runtime.port, 8082);
const username = state.people[0].phone;
assert.equal(username, '16693001000');
const accounts = fs.readFileSync('.local/demo-20261011/演示账号.txt', 'utf8');
assert.ok(accounts.includes('所有下列演示账号的密码：' + state.password));
const out = path.resolve('.local/local-trial-20261012', 'login-' + crypto.randomUUID());
fs.mkdirSync(out, {recursive: true});
const report = {at: new Date().toISOString(), scope: 'Actual ordinary-organizer form login and existing workbench; synthetic trial only. No business mutation or new model request.', username, database: runtime.database, checks: [], pageErrors: [], blockedWrites: [], passed: false};
function check(name, condition) {report.checks.push({name, passed: Boolean(condition)}); assert.ok(condition, name);}
const browser = await chromium.launch({headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
let stage = 'fresh login';
try {
  const session = await browser.newContext({viewport: {width: 1440, height: 1000}, reducedMotion: 'reduce'});
  const page = await session.newPage();
  page.setDefaultTimeout(45000);
  page.on('pageerror', () => report.pageErrors.push('Page script error'));
  await session.route('**/dev-api/**', route => {
    const req = route.request(), url = new URL(req.url());
    if (['GET', 'HEAD'].includes(req.method()) || (req.method() === 'POST' && ['/dev-api/auth/login', '/dev-api/auth/organization/enter'].includes(url.pathname))) return route.continue();
    report.blockedWrites.push({method: req.method(), path: url.pathname});
    return route.abort('blockedbyclient');
  });
  await page.goto('http://127.0.0.1:5192/portal/login?returnTo=/portal/organization', {waitUntil: 'domcontentloaded'});
  check('Fresh browser has no injected session', await page.evaluate(() => !localStorage.getItem('Admin-Token')));
  await page.getByPlaceholder('请输入手机号', {exact: true}).fill(username);
  await page.getByPlaceholder('请输入密码', {exact: true}).fill(state.password);
  const login = page.waitForResponse(r => new URL(r.url()).pathname === '/dev-api/auth/login' && r.request().method() === 'POST');
  await page.getByRole('button', {name: '登录', exact: true}).click();
  check('Current organizer account authenticates through the actual form', (await (await login).json()).code === 200);
  await page.waitForURL(url => url.pathname === '/portal/organization');
  stage = 'enter approved organization';
  const enter = page.waitForResponse(r => new URL(r.url()).pathname === '/dev-api/auth/organization/enter' && r.request().method() === 'POST');
  await page.getByRole('button', {name: '进入办赛工作台', exact: true}).first().click();
  // Entering the organization intentionally reloads the document; the old
  // response body can disappear. Check HTTP success and the authenticated page.
  check('Organization session request succeeds', (await enter).status() === 200);
  await page.waitForURL(url => url.pathname.startsWith('/org-desk/'));
  await page.goto('http://127.0.0.1:5192/org-desk/events', {waitUntil: 'domcontentloaded'});
  await page.getByRole('button', {name: '打开 AI 运营助手', exact: true}).waitFor();
  check('Organizer event workbench loads', new URL(page.url()).pathname === '/org-desk/events');
  stage = 'existing saved notice draft';
  await page.goto('http://127.0.0.1:5192/org-desk/workspace/2109434700270440450', {waitUntil: 'domcontentloaded'});
  await page.getByRole('heading', {name: '回归-a006561d-星河通知草稿验证', exact: true}).waitFor();
  check('Existing saved notice draft remains accessible', await page.getByRole('heading', {name: '回归-a006561d-星河通知草稿验证', exact: true}).isVisible());
  stage = 'AI panel';
  await page.goto('http://127.0.0.1:5192/org-desk/events', {waitUntil: 'domcontentloaded'});
  await page.getByRole('button', {name: '打开 AI 运营助手', exact: true}).click();
  await page.locator('.b-ai-window').getByRole('button', {name: '其他任务 →', exact: true}).click();
  const panel = page.locator('.product-agent.assistant-window');
  await panel.waitFor();
  check('Generic AI task panel opens for the organizer', await panel.getByRole('textbox', {name: '发给体育助手的消息'}).isVisible());
  await panel.getByRole('button', {name: '查看任务记录', exact: true}).click();
  await panel.locator('.agent-history>button').first().waitFor();
  check('Existing AI task history is retrieved', await panel.locator('.agent-history>button').count() > 0);
  check('Workbench has no script errors or attempted business writes', !report.pageErrors.length && !report.blockedWrites.length);
  await page.screenshot({path: path.join(out, 'organizer-ai.png')});
  report.passed = true;
  await session.close();
} catch (error) {
  const diagnostic = String(error.message).replaceAll(state.password, '[REDACTED]').replace(/Bearer\s+\S+/gi, 'Bearer [REDACTED]').slice(0, 500);
  report.failure = {stage, reason: 'Actual form authentication or workbench verification failed; private diagnostics omitted.', diagnostic};
  process.exitCode = 1;
} finally {
  await browser.close();
  report.finishedAt = new Date().toISOString();
  const file = path.join(out, 'receipt.json'), fd = fs.openSync(file, 'wx');
  try {fs.writeFileSync(fd, JSON.stringify(report, null, 2)); fs.fsyncSync(fd);} finally {fs.closeSync(fd);}
  console.log(JSON.stringify({passed: report.passed, checks: report.checks.length, failure: report.failure, receipt: file}));
}
