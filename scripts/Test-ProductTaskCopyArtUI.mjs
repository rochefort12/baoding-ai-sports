// Targeted visual supplement. Read actual local services without login or business mutations.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const publicOnly = process.argv.includes('--public-only');
const root = process.cwd(), output = path.join(root, '.local/product-release-20261011', 'task-art-ui-' + Date.now());
const runtime = JSON.parse(fs.readFileSync(path.join(root, '.local/phase1-implementation/verification-runtime.json'), 'utf8'));
const session = JSON.parse(fs.readFileSync(path.join(root, '.local/phase1-implementation/verification-session.json'), 'utf8'));
assert.equal(runtime.port, 8082); assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/); assert.equal(session.database, runtime.database);
fs.mkdirSync(output, { recursive: true });
// This exact POST is a SELECT-only preview; its HTTP verb does not make it a save.
// No other POST preview, confirm, execution, auth or model request is permitted here.
const readOnlyPreviewPath = '/dev-api/sports/platform/actions/growth.policy.save/preview';
const readOnlyPreviewSources = [
  'backend/aisports-domains/d10/aisports-table-growth-policy/src/main/java/org/dromara/sports/tables/d10/growth_policy/GrowthPolicies.java',
  'backend/aisports-platform/executor/src/main/java/org/dromara/sports/platform/executor/BusinessExecutor.java',
  'backend/aisports-platform/core/src/main/java/org/dromara/sports/platform/core/ScopedJdbc.java'
].map(file => ({ file, sha256: createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex') }));
const report = { timestamp: new Date().toISOString(), scope: publicOnly ? 'Anonymous main auth and unavailable venue entry only; static artwork read checks. No login/model/SMS or business writes.' : 'Targeted real local UI: task copy and small artwork on auth, admission, government/review and event overview. Isolated fictional role sessions in memory, no API rewriting, login/model/SMS or business writes. Only the exact SELECT-only growth-policy POST preview is allowed; executor binds an empty business-write scope. This does not claim a database read-only transaction.', checks: [], screenshots: [], blockedWrites: 0, blockedRequests: [], readOnlyPosts: [], readOnlyPreviewSources, passed: false };
const check = (name, value) => { assert.ok(value, name); report.checks.push({ name, passed: true }); };
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
async function read(actor, endpoint) {
  const response = await fetch('http://127.0.0.1:8082' + endpoint, { headers: { Authorization: 'Bearer ' + actor.token, clientid: 'e5cd7e4891bf95d1d19206ce24a7b32e' } });
  assert.equal(response.status, 200, 'Actual isolated GET response'); const data = await response.json(); assert.equal(data.code, 200, 'Actual role can read the requested resource'); return data.data;
}
function routeOf(rows, component, prefix = '') {
  for (const row of rows) { const full = ((row.path.startsWith('/') ? '' : prefix + '/') + row.path).replace(/\/+/g, '/'); if (row.component === component) return full; if (row.children) { const result = routeOf(row.children, component, full); if (result) return result; } }
}
let page;
try {
  for (const name of ['court-paper.webp', 'motion-ribbon.webp']) {
    const file = path.join(root, 'plus-ui/public/images/sports/art', name); check(name + ' is a nonempty real local asset', fs.statSync(file).size > 1000);
    const response = await fetch('http://127.0.0.1:5190/images/sports/art/' + name); check(name + ' is served as WebP on main', response.status === 200 && response.headers.get('content-type')?.includes('image/webp'));
  }
  const governmentRoutes = publicOnly ? [] : await read(session.government, '/system/menu/getRouters'), adminRoutes = publicOnly ? [] : await read(session.admin, '/system/menu/getRouters');
  const governmentPath = routeOf(governmentRoutes, 'sports/government/index'), reviewPath = routeOf(governmentRoutes, 'sports/organization/review'), platformPath = routeOf(adminRoutes, 'sports/platform/index');
  if (!publicOnly) check('Actual ordinary government and platform menu paths are available', governmentPath && reviewPath && platformPath);
  const pages = [
    { key: 'login-main', base: 'http://127.0.0.1:5190', route: '/portal/login?returnTo=/portal/rooms', heading: '欢迎回来', art: '.sport-auth-form' },
    { key: 'admission', actor: session.people[0], route: '/portal/organization', heading: '我要办赛', art: '.sport-art-paper' },
    { key: 'government', actor: session.government, route: governmentPath, heading: '主办方管理', art: '.sport-art-paper' },
    { key: 'review', actor: session.government, route: reviewPath, heading: '入驻审核', art: '.sport-art-paper' },
    { key: 'platform', actor: session.admin, route: platformPath, heading: '平台工作台' },
    { key: 'organizer', actor: session.organizer, route: '/org-desk/home', heading: '赛事与待办' },
    { key: 'overview', actor: session.organizer, route: '/org-desk/workspace/' + session.eventId + '?task=overview', art: '.sport-art-ribbon' },
    { key: 'future-main', base: 'http://127.0.0.1:5190', route: '/portal/future/venues', heading: '场馆服务' }
  ];
  for (const width of [390, 1440]) {
    for (const target of pages.filter(target => !publicOnly || !target.actor)) {
      const context = await browser.newContext({ viewport: { width, height: 1000 }, reducedMotion: 'reduce' });
      if (target.actor) await context.addInitScript(token => { localStorage.setItem('Admin-Token', token); localStorage.setItem('Platform-Token', token); }, target.actor.token);
      await context.route('**/dev-api/**', async route => {
        const method = route.request().method(), endpoint = new URL(route.request().url()).pathname;
        if (method === 'GET') return route.continue();
        if (target.key === 'platform' && method === 'POST' && endpoint === readOnlyPreviewPath) {
          report.readOnlyPosts.push({ page: target.key, width, method, path: endpoint });
          return route.continue();
        }
        report.blockedWrites++;
        report.blockedRequests.push({ page: target.key, width, method, path: endpoint });
        await route.abort();
      });
      page = await context.newPage(); const errors = [], failedArts = [];
      const previewResponses = [];
      page.on('pageerror', () => errors.push('page script error'));
      page.on('response', response => { if (response.url().includes('/images/sports/art/') && response.status() !== 200) failedArts.push('art response failed'); });
      page.on('response', response => {
        if (new URL(response.url()).pathname === readOnlyPreviewPath)
          previewResponses.push(response.json().then(body => ({ status: response.status(), code: body.code })).catch(() => ({ status: response.status() })));
      });
      await page.goto((target.base || 'http://127.0.0.1:5192') + target.route);
      if (target.heading) await page.getByRole('heading', { name: target.heading, exact: true }).waitFor();
      if (target.art) await page.locator(target.art).first().waitFor();
      await page.waitForTimeout(400);
      const name = target.key + '-' + width;
      check(name + ' has no script error', errors.length === 0);
      check(name + ' has no horizontal document overflow', await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
      check(name + ' omits fixed slogan/configuration text', !/今天，从这里推进赛事|集中在一个工作空间|后续规划|尚未配置|让热爱成为行动/.test(await page.locator('body').innerText()));
      check(name + ' fixed assistant marks remain bounded and non-draggable', await page.locator('img.sport-assistant-mark').evaluateAll(images => images.every(image => { const box = image.getBoundingClientRect(), style = getComputedStyle(image); return box.width <= 32.5 && box.height <= 32.5 && image.draggable === false && style.pointerEvents === 'none'; })));
      if (target.art) {
        const result = await page.locator(target.art).first().evaluate(element => { const art = getComputedStyle(element, '::before'), box = element.getBoundingClientRect(); return { image: art.backgroundImage, opacity: Number(art.opacity), width: parseFloat(art.width), height: parseFloat(art.height), hostWidth: box.width, pointer: art.pointerEvents }; });
        check(name + ' artwork is small, subdued and non-interactive', result.image.includes('/images/sports/art/') && result.opacity > 0 && result.opacity <= .16 && result.width <= Math.max(result.hostWidth * .3, 92) && result.height <= 144 && result.pointer === 'none');
        check(name + ' artwork responses succeed', failedArts.length === 0);
      }
      if (target.key === 'login-main') check(name + ' form inputs remain independent and readable', await page.locator('.sport-field-control input').evaluateAll(inputs => inputs.length >= 2 && inputs.every(input => input.getBoundingClientRect().width >= 130 && getComputedStyle(input).backgroundColor === 'rgba(0, 0, 0, 0)')));
      if (target.key === 'platform') {
        check(name + ' object table has no construction maturity column', !await page.getByText('建设状态', { exact: true }).count());
        const responses = await Promise.all(previewResponses);
        check(name + ' exact read-only policy preview succeeds', responses.length === 1 && responses.every(response => response.status === 200 && response.code === 200));
      }
      await page.evaluate(() => window.scrollTo(0, 0)); const file = name + '.png'; await page.screenshot({ path: path.join(output, file), fullPage: true }); report.screenshots.push(file);
      await context.close(); page = undefined;
    }
  }
  check('No business-write or other non-GET request occurred', report.blockedWrites === 0); report.passed = true;
} catch (error) {
  report.error = String(error.message).slice(0, 220); process.exitCode = 1;
  if (page) await page.screenshot({ path: path.join(output, 'failed.png'), fullPage: true }).catch(() => {});
} finally {
  await browser.close(); const file = path.join(output, 'receipt.json'), descriptor = fs.openSync(file, 'wx');
  try { fs.writeFileSync(descriptor, JSON.stringify(report, null, 2) + '\n'); fs.fsyncSync(descriptor); } finally { fs.closeSync(descriptor); }
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, error: report.error, report: path.relative(root, file).replaceAll('\\', '/') }));
}
