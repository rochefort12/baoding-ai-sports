// Read-only current main layout/art checks; capability activation is not inferred.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const out = path.resolve('.local/product-release-20261011/main-' + Date.now());
fs.mkdirSync(out, { recursive: true });
const checks = [], errors = [], writes = [];
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
try {
  for (const [device, viewport] of [['desktop', { width: 1440, height: 1000 }], ['mobile', { width: 390, height: 844 }]]) {
    const context = await browser.newContext({ viewport, reducedMotion: 'reduce' });
    const page = await context.newPage();
    page.on('pageerror', () => errors.push(device + ' page script error'));
    page.on('request', r => { if (new URL(r.url()).pathname.startsWith('/dev-api/') && r.method() !== 'GET') writes.push(r.method()); });
    await page.goto('http://127.0.0.1:5190/portal/home', { waitUntil: 'domcontentloaded' });
    await page.getByRole('heading', { name: '找到下一场比赛', exact: true }).waitFor();
    await page.waitForTimeout(450);
    assert.equal(await page.locator('vite-error-overlay').count(), 0);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false);
    checks.push(device + ' main home uses current product layout without overflow');
    await page.screenshot({ path: path.join(out, device + '-home.png'), fullPage: true });
    const assistant = page.getByRole('button', { name: '打开体育 AI 助手', exact: true });
    await assistant.click();
    await page.getByRole('dialog', { name: 'AI 参赛助手', exact: true }).waitFor();
    assert.ok(await page.locator('.c-ai-welcome-orb').isVisible());
    const panel = await page.locator('.c-assistant').boundingBox();
    assert.ok(panel.width <= viewport.width && panel.x >= 0 && panel.x + panel.width <= viewport.width + 1);
    const image = page.locator('.c-ai-welcome-orb');
    assert.equal(await image.getAttribute('draggable'), 'false');
    assert.equal(await image.evaluate(el => el.draggable), false);
    assert.equal(await page.getByText('同意将问题、必要赛事信息和本人报名状态发送至', {exact:false}).count(), 0);
    assert.ok(await page.getByRole('textbox', {name:'发给 AI 的消息'}).isVisible());
    checks.push(device + ' chat fits viewport and art cannot create a native drag ghost');
    await page.screenshot({ path: path.join(out, device + '-assistant.png'), fullPage: true });
    await page.keyboard.press('Escape');
    await page.getByRole('dialog', { name: 'AI 参赛助手', exact: true }).waitFor({ state: 'hidden' });
    checks.push(device + ' generated assistant asset opens real panel and Escape closes it');
    await page.goto('http://127.0.0.1:5190/portal/rooms');
    await page.waitForURL('**/portal/login**');
    assert.equal(new URL(page.url()).searchParams.get('returnTo'), '/portal/rooms');
    await page.getByRole('button', { name: '登录', exact: true }).waitFor();
    assert.equal(await page.locator('.header-ai-entry,.c-ai-launcher,.consumer-mobile-ai,.auth-brand .assistant').count(), 0);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false);
    checks.push(device + ' private room redirects to usable login with original task');
    await page.screenshot({ path: path.join(out, device + '-login.png'), fullPage: true });
    await context.close();
  }
  const assets = ['docs/05-ui/assets-20261011/assets.json','docs/05-ui/assets-20261011-v2/assets.json'].flatMap(file => { const manifest=JSON.parse(fs.readFileSync(file,'utf8')); return Array.isArray(manifest)?manifest:manifest.assets; });
  for (const item of assets) {
    const name = (item.path || item.file || item.output).replaceAll('\\','/').split('/images/sports/').at(-1);
    const response = await fetch('http://127.0.0.1:5190/images/sports/' + name);
    assert.equal(response.status, 200);
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.equal(createHash('sha256').update(bytes).digest('hex'), item.sha256);
    checks.push('main serves verified static asset ' + name);
  }
  for (const [category,names] of [['frames',['bronze','silver','gold','platinum','diamond','stellar','king']],['titles',['first_checkin','first_finish','regular','team_first','team_partners','team_veterans']]]) {
    for (const name of names) { const filename=category+'/'+name+'.svg'; const response=await fetch('http://127.0.0.1:5190/images/sports/'+filename); assert.equal(response.status,200); assert.deepEqual(Buffer.from(await response.arrayBuffer()),fs.readFileSync('plus-ui/public/images/sports/'+filename)); checks.push('main serves native identity artwork '+filename); }
  }
  for (const endpoint of ['/sports/display', '/sports/display/avatar/1', '/sports/b/events/1/materials', '/sports/platform/management', '/sports/agents/runs/1']) {
    const response = await fetch('http://127.0.0.1:8080' + endpoint, { headers: { clientid: 'e5cd7e4891bf95d1d19206ce24a7b32e' } });
    const body = await response.json();
    assert.equal(body.code, 401);
    checks.push('main refuses anonymous private endpoint ' + endpoint);
  }
  assert.deepEqual(errors, []);
  assert.deepEqual(writes, []);
  console.log(checks.map(x => 'PASS ' + x).join('\n'));
} catch (error) {
  errors.push(String(error.message).slice(0, 600));
  console.log(errors.at(-1)); process.exitCode = 1;
} finally {
  const receipt = { timestamp: new Date().toISOString(), scope: 'Anonymous read-only actual main service/layout/assets; capability activation and ordinary-role business acceptance are separate', passed: errors.length === 0, checks, errors, writes };
  fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(receipt, null, 2), { flag: 'wx' });
  console.log('Evidence: ' + path.relative(process.cwd(), out));
  await browser.close();
}
