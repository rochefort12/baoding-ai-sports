// Real LAN account navigation only. Business writes are blocked, including approvals.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const batch = '.local/three-person-test-20261012/d23b25203cba4df8b509ee77d8be1249';
const state = read(path.join(batch, 'state.private.json'));
const clientId = read('.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json').clientId;
const base = 'http://192.168.1.236:5193';
const out = path.join(batch, 'mobile-entry-' + crypto.randomUUID());
fs.mkdirSync(out);
const previewPath = '/dev-api/sports/platform/actions/growth.policy.save/preview';
const report = { at: new Date().toISOString(), base, checks: [], blockedWrites: [], readOnlyPosts: [], screenshots: [], passed: false, physicalPhones: 'NOT_RUN', previewSources: ['backend/aisports-platform/executor/src/main/java/org/dromara/sports/platform/executor/BusinessExecutor.java', 'backend/aisports-domains/d10/aisports-table-growth-policy/src/main/java/org/dromara/sports/tables/d10/growth_policy/GrowthPolicies.java'].map(file => ({ file, sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') })) };
const save = () => fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(report, null, 2));
const check = (name, ok) => { report.checks.push({ name, passed: !!ok }); save(); assert.ok(ok, name); };
const screenshot = async (page, name) => { await page.screenshot({ path: path.join(out, name) }); report.screenshots.push(name); save(); };
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
try {
  for (const width of [320, 390, 768, 1440]) {
    const ctx = await browser.newContext({ viewport: { width, height: 844 }, reducedMotion: 'reduce' });
    const page = await ctx.newPage(); page.setDefaultTimeout(20000);
    await ctx.route('**/*', route => {
      const request = route.request(), url = new URL(request.url());
      if (['GET', 'HEAD', 'OPTIONS'].includes(request.method())) return route.continue();
      if (url.origin === base && ['/dev-api/auth/login', '/dev-api/auth/logout'].includes(url.pathname)) return route.continue();
      // This exact preview loads existing rules using SELECT in an empty write scope.
      if (request.method() === 'POST' && url.origin === base && url.pathname === previewPath) { report.readOnlyPosts.push(previewPath); save(); return route.continue(); }
      report.blockedWrites.push({ method: request.method(), path: url.pathname }); save(); return route.abort();
    });
    await page.goto(base + '/portal/home');
    await page.getByRole('button', { name: '切换入口', exact: true }).click();
    await page.getByRole('menuitem', { name: '平台／政府管理', exact: true }).waitFor();
    check(width + ': management item visible without scrolling to hidden footer', await page.getByRole('menuitem', { name: '平台／政府管理', exact: true }).isVisible());
    check(width + ': header fits viewport', await page.locator('.consumer-header').evaluate(el => el.scrollWidth <= innerWidth));
    if (width === 390) await screenshot(page, 'anonymous-mobile-menu.png');
    await page.getByRole('menuitem', { name: '平台／政府管理', exact: true }).click();
    await page.waitForURL(url => url.pathname === '/login');
    await page.getByRole('button', { name: '登录工作台', exact: true }).waitFor();
    check(width + ': anonymous menu reaches work login', await page.getByRole('button', { name: '登录工作台', exact: true }).isVisible());
    await page.goto(base + '/portal/login');
    await page.getByRole('link', { name: '管理登录', exact: true }).waitFor();
    check(width + ': participant login also exposes management entry', await page.getByRole('link', { name: '管理登录', exact: true }).isVisible());
    if (width === 320 || width === 390) {
      const ordinary = state.accounts.find(a => a.code === 'A');
      await page.getByPlaceholder('请输入手机号', { exact: true }).fill(ordinary.phone);
      await page.getByPlaceholder('请输入密码', { exact: true }).fill(ordinary.password);
      await page.getByRole('button', { name: '登录', exact: true }).click();
      await page.waitForURL(url => url.pathname === '/portal/home');
      await page.getByRole('button', { name: '切换入口', exact: true }).click();
      await page.getByRole('menuitem', { name: '平台／政府管理', exact: true }).waitFor();
      check(width + ': organizer and logout choices remain available on mobile', await page.getByRole('menuitem', { name: '退出登录', exact: true }).isVisible() && await page.getByRole('menuitem', { name: /我要办赛|申请进度|办赛工作台/ }).isVisible());
      if (width === 390) await screenshot(page, 'signed-in-mobile-menu.png');
      await page.getByRole('menuitem', { name: '平台／政府管理', exact: true }).click();
      await page.waitForURL(url => url.pathname === '/login');
      check(width + ': explicit switch clears participant and saved organization tokens', await page.evaluate(() => !JSON.parse(localStorage.getItem('Admin-Token') || 'null') && !JSON.parse(localStorage.getItem('Platform-Token') || 'null')));
      const work = state.workAccounts.find(a => a.code === (width === 390 ? 'P' : 'G'));
      await page.getByPlaceholder('请输入工作账号', { exact: true }).fill(work.username);
      await page.getByPlaceholder('请输入密码', { exact: true }).fill(work.password);
      await page.getByRole('button', { name: '登录工作台', exact: true }).click();
      await page.waitForURL(url => url.pathname !== '/login');
      const routes = await page.evaluate(async clientId => {
        let token = localStorage.getItem('Admin-Token'); try { token = JSON.parse(token); } catch { /* VueUse string storage is also valid. */ }
        const response = await fetch('/dev-api/system/menu/getRouters', { headers: { Authorization: 'Bearer ' + token, clientid: clientId } });
        return (await response.json()).data;
      }, clientId);
      const findRoute = (rows, component, prefix = '') => { for (const row of rows || []) { const next = (row.path.startsWith('/') ? row.path : prefix + '/' + row.path).replace(/\/+/g, '/'); if (row.component === component) return next; const child = findRoute(row.children, component, next); if (child) return child; } };
      const target = findRoute(routes, width === 390 ? 'sports/platform/index' : 'sports/organization/review');
      check(width + ': work account has its server-authorized destination', !!target);
      await page.goto(base + target);
      report.destination = { target, reachedPath: new URL(page.url()).pathname, headings: await page.locator('h1,h2').allTextContents() }; save();
      if (width === 390) await screenshot(page, 'platform-mobile-before-tab.png');
      if (width === 390) {
        await page.getByRole('tab', { name: '政府责任分配', exact: true }).click();
        await page.getByRole('heading', { name: '政府职责分配', exact: true }).waitFor();
      } else await page.getByRole('heading', { name: '入驻审核', exact: true }).waitFor();
      check(width + ': correct working page is usable after switching', true);
      await screenshot(page, work.code + '-mobile-work-page.png');
    }
    await ctx.close();
  }
  check('No business write attempted during switching', report.blockedWrites.length === 0);
  report.passed = true;
} catch (error) {
  let message = String(error?.message || error);
  for (const account of [...state.accounts, ...state.workAccounts]) for (const secret of [account.password, account.phone, account.session?.token, account.session?.access_token].filter(Boolean)) message = message.replaceAll(String(secret), '[REDACTED]');
  report.failure = message.replace(/Bearer\s+[^\s]+/gi, 'Bearer [REDACTED]').replace(/eyJ[A-Za-z0-9_.-]*/g, '[REDACTED]').slice(0, 1000); process.exitCode = 1;
}
finally { await browser.close(); report.finishedAt = new Date().toISOString(); save(); console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failure: report.failure, evidence: out })); }
