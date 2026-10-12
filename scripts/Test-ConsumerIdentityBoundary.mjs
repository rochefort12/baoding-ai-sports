// Actual isolated login/restore regression. Credentials stay in memory and
// evidence contains only route names, response codes and observed assertions.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const state = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json', 'utf8'));
const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8'));
assert.equal(runtime.port, 8082);
assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/);
assert.equal(runtime.database, state.database);
const out = path.resolve('.local/product-release-20261011/identity-boundary-' + Date.now());
fs.mkdirSync(out, { recursive: true });
const report = { timestamp: new Date().toISOString(), scope: 'Actual ordinary government and participant login, plus work/participant token restoration in isolated 5192/8082. No response interception, model requests or business mutations.', checks: [], failures: [], pageErrors: [], writeRequests: [], passed: false };
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const base = 'http://127.0.0.1:5192';
const participantOnly = new Set(['/dev-api/sports/display', '/dev-api/sports/c/notices', '/dev-api/sports/c/organization/application']);
let current;
function check(name, actual) { assert.ok(actual, name); report.checks.push(name); }
async function open(actor, participant = false) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, reducedMotion: 'reduce' });
  if (actor) await context.addInitScript(({ token, participant }) => { localStorage.setItem('Admin-Token', token); if (participant) localStorage.setItem('Platform-Token', token); }, { token: actor.token, participant });
  const page = await context.newPage(), requests = [], responses = [];
  page.on('pageerror', () => report.pageErrors.push('Page script error'));
  page.on('request', request => { const pathname = new URL(request.url()).pathname; if (pathname.startsWith('/dev-api/')) { requests.push(pathname); if (request.method() !== 'GET') report.writeRequests.push({ path: pathname, method: request.method() }); } });
  page.on('response', async response => { const pathname = new URL(response.url()).pathname; if (pathname.startsWith('/dev-api/')) { try { const value = await response.json(); responses.push({ path: pathname, code: value.code }); } catch { /* Binary/avatar/captcha response is not parsed into evidence. */ } } });
  current = { context, page, requests, responses }; return current;
}
async function close() { await current.context.close(); current = undefined; }
try {
  let scene = await open();
  await scene.page.goto(base + '/login?redirect=/index');
  await scene.page.getByPlaceholder('请输入工作账号', { exact: true }).fill('phase1-government');
  await scene.page.getByPlaceholder('请输入密码', { exact: true }).fill(state.password);
  await scene.page.getByRole('button', { name: '登录工作台', exact: true }).click();
  await scene.page.waitForURL('**/index');
  await scene.page.getByRole('heading', { name: '主办方管理', exact: true }).waitFor();
  await scene.page.waitForTimeout(650);
  check('普通政府通过真实工作登录表单进入政府工作台', new URL(scene.page.url()).pathname === '/index');
  check('工作登录写token到页面跳转期间没有参赛者外壳读取', scene.requests.filter(value => participantOnly.has(value)).length === 0);
  check('工作登录保留后台实际身份读取', scene.responses.some(value => value.path === '/dev-api/system/user/getInfo' && value.code === 200));
  check('政府工作台没有误身份或误权限提示', await scene.page.getByText('请使用参赛者账号登录', { exact: true }).count() === 0 && await scene.page.getByText('当前操作没有权限', { exact: true }).count() === 0);
  await scene.page.screenshot({ path: path.join(out, 'ordinary-government-after-login.png'), fullPage: true });
  await close();

  for (const [name, actor] of [['government', state.government], ['administrator', state.admin]]) {
    scene = await open(actor);
    await scene.page.goto(base + '/public/events');
    await scene.page.getByRole('heading', { name: '查找赛事', exact: true }).waitFor();
    await scene.page.waitForTimeout(600);
    check(name + '已登录公开页面恢复实际身份', scene.responses.some(value => value.path === '/dev-api/system/user/getInfo' && value.code === 200));
    check(name + '浏览公开赛事不读取参赛者私有信息', scene.requests.filter(value => participantOnly.has(value)).length === 0);
    await close();
  }

  scene = await open();
  await scene.page.goto(base + '/portal/login?returnTo=/portal/home');
  await scene.page.getByRole('textbox', { name: '手机号', exact: true }).fill(state.people[0].phone);
  await scene.page.getByPlaceholder('请输入密码', { exact: true }).fill(state.password);
  const displayResponse = scene.page.waitForResponse(response => new URL(response.url()).pathname === '/dev-api/sports/display');
  await scene.page.getByRole('button', { name: '登录', exact: true }).click();
  await scene.page.waitForURL('**/portal/home');
  const display = await (await displayResponse).json();
  check('普通参赛者真实登录后回到原首页任务', new URL(scene.page.url()).pathname === '/portal/home');
  check('参赛者首页身份守卫允许本人实际资料读取', display.code === 200 && display.data.accountId === state.people[0].id);
  await scene.page.waitForTimeout(500);
  check('本人站内信仍通过实际接口读取', scene.responses.some(value => value.path === '/dev-api/sports/c/notices' && value.code === 200));
  check('本人主办方申请入口仍通过实际接口读取', scene.responses.some(value => value.path === '/dev-api/sports/c/organization/application' && value.code === 200));
  const reloadIdentity = scene.page.waitForResponse(response => new URL(response.url()).pathname === '/dev-api/sports/display');
  await scene.page.reload();
  check('首页刷新重新识别参赛者后恢复真实头像资料', (await (await reloadIdentity).json()).data.accountId === state.people[0].id);
  const denied = await scene.page.request.get(base + '/dev-api/sports/platform/management', { headers: { Authorization: 'Bearer ' + state.people[0].token, clientid: state.people[0].clientId } });
  check('没有隐藏或放宽普通参赛者真实后台权限拒绝', (await denied.json()).code === 403);
  await scene.page.screenshot({ path: path.join(out, 'ordinary-participant-home.png'), fullPage: true });
  await close();
  check('补验没有新增业务写入或模型请求', report.writeRequests.every(value => value.path === '/dev-api/auth/login'));
  check('页面无脚本错误', report.pageErrors.length === 0);
  report.passed = true;
} catch (error) {
  report.failures.push({ type: error.name, message: error.name === 'AssertionError' ? error.message : 'Verification did not complete; original credential diagnostics omitted' });
  process.exitCode = 1;
  if (current) { await current.page.locator('input[type="password"]').evaluateAll(inputs => inputs.forEach(input => input.value = '')).catch(() => {}); await current.page.screenshot({ path: path.join(out, 'failure.png'), fullPage: true }).catch(() => {}); }
} finally {
  await browser.close();
  const file = path.join(out, 'receipt.json'), fd = fs.openSync(file, 'wx');
  try { fs.writeFileSync(fd, JSON.stringify(report, null, 2) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failures: report.failures, report: path.relative(process.cwd(), file).replaceAll('\\', '/') }));
}
