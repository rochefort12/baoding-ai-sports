// Real ordinary-role pages. The earlier missing-link mode preserves the pre-fix failure observation.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const contextPath = process.argv[process.argv.indexOf('--context') + 1];
assert.ok(process.argv.includes('--context')); assert.ok(path.resolve(contextPath).startsWith(path.resolve('.local/business-regression-20261011') + path.sep));
const context = JSON.parse(fs.readFileSync(contextPath, 'utf8').replace(/^\uFEFF/, ''));
assert.equal(context.frontend, 'http://127.0.0.1:5192'); assert.equal(context.backend, 'http://127.0.0.1:8082');
const owned = path.join(path.dirname(contextPath), 'governance');
const state = JSON.parse(fs.readFileSync(path.join(owned, 'checkpoint.private.json'), 'utf8'));
const out = path.join(owned, 'ui-' + crypto.randomUUID()); fs.mkdirSync(out);
const missing = process.argv.includes('--observe-missing-links');
const managementOnly = process.argv.includes('--management-only');
const report = { at: new Date().toISOString(), runId: context.runId, scope: 'Real ordinary government, approved organizer and participant UI on 5192/8082. No stub, new model call, login, administrative operation or business write.', mode: missing ? 'pre-fix-failure-observation' : 'post-fix-acceptance', passed: false, checks: [], errors: [], writes: [], screenshots: [] };
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
function check(name, ok, details = {}) { report.checks.push({ name, passed: Boolean(ok), ...details }); assert.ok(ok, name); console.log('PASS ' + name); }
async function session(actor, viewport, platformActor) {
  const browserContext = await browser.newContext({ viewport, reducedMotion: 'reduce' });
  await browserContext.addInitScript(({ token, platform }) => { localStorage.setItem('Admin-Token', token); if (platform) localStorage.setItem('Platform-Token', platform); }, { token: actor.token, platform: platformActor?.token });
  browserContext.on('request', request => { if (!['GET','HEAD'].includes(request.method())) report.writes.push({ method: request.method(), path: new URL(request.url()).pathname }); });
  const page = await browserContext.newPage(); page.on('pageerror', error => report.errors.push({ type: 'pageerror', name: error.name }));
  return { browserContext, page };
}
async function capture(page, file) { await page.evaluate(() => scrollTo(0, 0)); await page.screenshot({ path: path.join(out, file), fullPage: true }); report.screenshots.push(file); }
const fit = async page => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1);
async function api(actor, route) { const response = await fetch(context.backend + route, { headers: { Authorization: 'Bearer ' + actor.token, clientid: context.clientId } }); const body = await response.json(); assert.equal(body.code, 200, 'Real read route ' + route); return body.data; }
function routeOf(rows, component, prefix = '') { for (const row of rows) { const current = ((row.path.startsWith('/') ? '' : prefix + '/') + row.path).replace(/\/+/g, '/'); if (row.component === component) return current; const found = row.children && routeOf(row.children, component, current); if (found) return found; } }
try {
  for (const [device, viewport] of managementOnly ? [] : [['desktop',{ width: 1440, height: 1000 }],['mobile',{ width: 390, height: 844 }]]) {
    const { browserContext, page } = await session(context.people[3], viewport);
    await page.goto(context.frontend + '/portal/notices'); await page.getByRole('heading', { name: '我的消息', exact: true }).waitFor();
    const cards = page.locator('.notice-card').filter({ hasText: '问题编号 ' + state.complaintId }); await cards.first().waitFor();
    const links = cards.getByRole('button', { name: '查看处理进度', exact: false });
    check(device + ' real complaint progress notifications exist', await cards.count() >= 7);
    if (missing) { check(device + ' reproduced missing complaint task links', await links.count() === 0); await capture(page, device + '-complaint-links-missing.png'); }
    else {
      check(device + ' each progress notice exposes its own task link', await links.count() === await cards.count());
      await links.first().click(); await page.waitForURL('**/portal/issues/' + state.complaintId); await page.locator('.issue-detail').waitFor(); await page.getByText('本机合成再次结案，所有回复保留', { exact: false }).waitFor();
      check(device + ' actual click opens its own complaint detail', new URL(page.url()).pathname === '/portal/issues/' + state.complaintId && await page.getByText('本机合成再次结案，所有回复保留', { exact: false }).count() > 0);
      check(device + ' complaint detail fits viewport', await fit(page)); await capture(page, device + '-complaint-detail.png');
    }
    await browserContext.close();
    const orgAccount = await session(context.people[4], viewport); await orgAccount.page.goto(context.frontend + '/portal/notices'); await orgAccount.page.getByRole('heading', { name: '我的消息', exact: true }).waitFor();
    const qualification = orgAccount.page.locator('.notice-card').filter({ hasText: /办赛资格已暂停|办赛资格已恢复/ }); await qualification.first().waitFor();
    const orgLinks = qualification.getByRole('button', { name: '查看办赛资格', exact: false });
    check(device + ' real qualification notifications exist', await qualification.count() >= 2);
    if (missing) { check(device + ' reproduced missing organizer qualification task links', await orgLinks.count() === 0); await capture(orgAccount.page, device + '-qualification-links-missing.png'); }
    else {
      check(device + ' each qualification notice links to organizer admission task', await orgLinks.count() === await qualification.count());
      await orgLinks.first().click(); await orgAccount.page.waitForURL('**/portal/organization'); check(device + ' qualification click stays on known organizer task', new URL(orgAccount.page.url()).pathname === '/portal/organization');
      await orgAccount.page.getByRole('button', { name: '进入办赛工作台', exact: true }).waitFor();
      check(device + ' organizer admission page fits viewport', await fit(orgAccount.page)); await capture(orgAccount.page, device + '-admission-approved.png');
    }
    await orgAccount.browserContext.close();
  }
  if (!missing) {
    const routes = await api(context.government, '/system/menu/getRouters'); const governmentRoute = routeOf(routes, 'sports/government/index'); assert.ok(governmentRoute, 'Ordinary government actual menu exists');
    const { browserContext, page } = await session(context.government, { width: 1440, height: 1000 });
    await page.goto(context.frontend + governmentRoute); await page.getByRole('heading', { name: '主办方管理', exact: true }).waitFor();
    await page.getByRole('textbox', { name: '搜索管理范围内的主办方', exact: true }).fill(context.prefix + '-政府轮');
    const row = page.locator('.el-table__row').filter({ hasText: context.prefix + '-政府轮' }); await row.waitFor();
    check('ordinary government sees its granted organizer and current qualification', await row.getByText('正常', { exact: true }).count() === 1);
    check('government filter reduces to one independent organizer', await page.locator('.el-table__row').count() === 1);
    await capture(page, 'desktop-government-scoped.png');
    await page.goto(context.frontend + '/government/issues'); await page.getByRole('heading', { name: '投诉处理', exact: true }).waitFor();
    const issue = page.locator('.issue-list > a').filter({ hasText: state.complaintId }); await issue.waitFor(); await issue.click();
    let detailVisible = false; try { await page.locator('.issue-detail').waitFor({ timeout: 6000 }); detailVisible = true; } catch { await capture(page, 'desktop-government-complaint-route-failed.png'); }
    check('ordinary government actual list click opens complaint detail', detailVisible, { path: new URL(page.url()).pathname });
    check('ordinary government sees actual preserved coordination and conclusions', await page.getByText('政府协调岗位', { exact: false }).count() >= 4 && await page.getByText('重新申请处理', { exact: false }).count() > 0);
    await capture(page, 'desktop-government-complaint-history.png'); await browserContext.close();
    const organization = await session(state.organizer, { width: 390, height: 844 }, context.people[4]);
    await organization.page.goto(context.frontend + '/org-desk/issues'); await organization.page.getByRole('heading', { name: '投诉处理', exact: true }).waitFor();
    const orgIssue = organization.page.locator('.issue-list > a').filter({ hasText: state.complaintId }); await orgIssue.waitFor(); await orgIssue.click(); await organization.page.locator('.issue-detail').waitFor();
    check('ordinary organizer actual complaint list click opens its own history', new URL(organization.page.url()).pathname === '/org-desk/issues/' + state.complaintId);
    check('mobile organizer complaint detail fits viewport', await fit(organization.page)); await capture(organization.page, 'mobile-organizer-complaint-history.png'); await organization.browserContext.close();
  }
  check('no browser business write occurred', report.writes.length === 0, { count: report.writes.length });
  check('no page script error occurred', report.errors.length === 0, { count: report.errors.length });
  report.passed = true;
} catch (error) { report.failure = { name: error.name, message: String(error.message).slice(0, 700) }; process.exitCode = 1; }
finally {
  await browser.close(); report.sourceFiles = ['scripts/Test-GovernanceBusinessUi.mjs', 'plus-ui/src/views/portal/notices.vue', 'plus-ui/src/views/portal/issues.vue'].map(file => ({ path: file, sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') }));
  fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, mode: report.mode, receipt: path.relative(process.cwd(), path.join(out, 'receipt.json')).replaceAll('\\','/') }));
}
