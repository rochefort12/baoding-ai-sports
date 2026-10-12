// Actual formal-product interactions against the guarded local rehearsal server.
// Synthetic accounts only. No API interception, fixture replay, payment or result writes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const privateRoot = path.resolve('.local/phase1-implementation');
const runtime = JSON.parse(fs.readFileSync(path.join(privateRoot, 'verification-runtime.json'), 'utf8'));
assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/);
assert.equal(runtime.port, 8082);
const state = JSON.parse(fs.readFileSync(path.join(privateRoot, 'verification-session.json'), 'utf8'));
const fixture = JSON.parse(fs.readFileSync('.local/demo-20261011/scenario.json', 'utf8'));
const root = path.resolve('.local/product-release-20261011');
const out = path.join(root, `ui-${Date.now()}`);
fs.mkdirSync(out, { recursive: true });
const checks = [], failures = [], errors = [];
const selected = String(process.env.PRODUCT_UI_SCENARIOS || '').split(',').filter(Boolean);
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
let current;
async function open(actor, mobile = false) {
  const context = await browser.newContext({ viewport: mobile ? { width: 390, height: 844 } : { width: 1440, height: 1000 }, reducedMotion: 'reduce', acceptDownloads: true });
  if (actor) await context.addInitScript(token => localStorage.setItem('Admin-Token', token), actor.token);
  const page = await context.newPage();
  page.on('pageerror', () => errors.push('A page script error occurred'));
  current = { context, page };
  return current;
}
async function navigate(page, route) {
  await page.goto('http://127.0.0.1:5192' + route, { waitUntil: 'domcontentloaded' });
  await page.locator('h1:visible,h2:visible').first().waitFor({ timeout: 20000 });
  assert.equal(await page.locator('vite-error-overlay').count(), 0);
}
async function shot(page, name) {
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: path.join(out, name + '.png'), fullPage: true });
}
function check(name, value) { assert.ok(value, name); checks.push(name); console.log('PASS ' + name); }
async function scenario(name, run) {
  if (selected.length && !selected.includes(name)) return;
  try { await run(); }
  catch (error) {
    const reason = String(error.message).replace(/(token|Authorization|password)=[^&\s]+/gi, 'credential=[REDACTED]').slice(0, 600);
    failures.push({ name, reason }); console.log('FAIL ' + name + ': ' + reason.slice(0, 180));
    await current?.page.screenshot({ path: path.join(out, name + '-failed.png'), fullPage: true }).catch(() => {});
  } finally { await current?.context.close(); current = undefined; }
}
try {
  await scenario('login-and-avatar', async () => {
    const { page } = await open();
    await navigate(page, '/portal/login?returnTo=/portal/growth');
    await page.locator('button[type=submit]').click();
    check('Empty login focuses the first missing field', await page.locator('input[name=phone]').evaluate(e => document.activeElement === e));
    await page.getByPlaceholder('请输入手机号').fill(state.people[0].phone);
    await page.getByPlaceholder('请输入密码', { exact: true }).fill(state.password);
    await page.getByRole('button', { name: '登录', exact: true }).click();
    await page.waitForURL(url => url.pathname === '/portal/growth', { timeout: 20000 });
    check('Actual login returns to the original growth task', new URL(page.url()).pathname === '/portal/growth');
    await page.getByRole('button', { name: /上传我的头像/ }).waitFor();
    await page.locator('.sports-avatar-editor input[type=file]').setInputFiles('plus-ui/public/images/sports/badminton-hero-v1.webp');
    await page.getByRole('dialog', { name: '调整运动头像' }).waitFor();
    await page.waitForTimeout(1500);
    await page.getByRole('button', { name: '向右旋转', exact: true }).click();
    await page.getByRole('button', { name: '放大头像', exact: true }).click();
    const uploadResponse = page.waitForResponse(r => r.url().includes('/sports/display/avatar?') && r.request().method() === 'POST');
    await page.getByRole('button', { name: '保存头像', exact: true }).click();
    const result = await (await uploadResponse).json();
    check('Cropped and rotated avatar saves through the real endpoint', result.code === 200 && result.data?.fileId);
    await page.getByRole('dialog', { name: '调整运动头像' }).waitFor({ state: 'hidden', timeout: 15000 });
    await page.locator('.growth-passport .avatar-frame img').waitFor();
    await page.waitForFunction(() => { const i = document.querySelector('.growth-passport .avatar-frame img'); return i?.complete && i.naturalWidth > 0; });
    await shot(page, 'desktop-growth-avatar');
    await navigate(page, '/portal/rooms/' + state.roomA);
    await page.locator('.avatar-frame img').first().waitFor();
    check('Room title is above its actual avatar', await page.locator('.sports-avatar').first().evaluate(e => {
      const title = e.querySelector('.avatar-title')?.getBoundingClientRect(), avatar = e.querySelector('.avatar-frame')?.getBoundingClientRect();
      return title && avatar && title.bottom <= avatar.top + 2;
    }));
    await shot(page, 'desktop-room');
  });
  await scenario('materials', async () => {
    const { page } = await open(state.organizer);
    await navigate(page, `/org-desk/workspace/${fixture.eventId}?task=materials`);
    const studio = page.getByTestId('material-studio'); await studio.waitFor();
    const draftTitle = '界面演练执行策划（模拟）·' + Date.now();
    await page.getByTestId('material-title').fill(draftTitle);
    await page.getByTestId('material-content').fill('# 界面演练\n\n此稿是可编辑的模拟赛事安排，须负责人核对。');
    await page.getByTestId('material-tab-script').click();
    await page.getByRole('button', { name: '继续编辑', exact: true }).click();
    check('Changing document type preserves unsaved edits after cancelling', (await page.getByTestId('material-title').inputValue()) === draftTitle);
    const saveResponse = page.waitForResponse(r => r.url().includes('/actions/event.material.save/execute'));
    await page.getByTestId('material-save').click();
    check('Document save uses a real successful action receipt', (await (await saveResponse).json()).code === 200);
    await page.getByText('已保存到本赛事', { exact: true }).waitFor();
    const downloadPromise = page.waitForEvent('download');
    await page.getByRole('button', { name: '下载文稿', exact: true }).click();
    const download = await downloadPromise; const downloadPath = path.join(out, 'material-export.md'); await download.saveAs(downloadPath);
    check('Downloaded document contains the actual edits', fs.readFileSync(downloadPath, 'utf8').includes(draftTitle));
    await page.getByTestId('material-tab-announcement').click();
    await page.getByTestId('material-consent').check();
    const generation = page.waitForResponse(r => r.url().includes('/actions/event.material.generate/execute'), { timeout: 120000 });
    await page.getByTestId('material-generate').click();
    check('AI document generation succeeds through the actual service', (await (await generation).json()).code === 200);
    await page.locator('.studio-document-bar').getByText(/^AI草稿 · 待负责人核对/).waitFor();
    check('Generated document has actual editable content', (await page.getByTestId('material-content').inputValue()).length > 100);
    await shot(page, 'desktop-materials');
  });
  await scenario('cover', async () => {
    const { page } = await open(state.organizer);
    await navigate(page, '/org-desk/events');
    const card = page.locator('.managed-event-card').filter({ has: page.locator(`a[href="/org-desk/workspace/${fixture.eventId}"]`) });
    await card.getByRole('button', { name: '更换封面', exact: true }).click();
    const dialog = page.getByRole('dialog', { name: '赛事封面', exact: true }); await dialog.waitFor();
    await dialog.getByRole('button', { name: '使用平台运动视觉', exact: true }).click();
    await dialog.getByText('封面已选择，保存赛事后生效。', { exact: true }).waitFor();
    const saved = page.waitForResponse(r => r.url().includes('/actions/event.cover.save/execute'));
    await dialog.getByRole('button', { name: '保存封面', exact: true }).click();
    check('Platform artwork is uploaded and saved as a real cover', (await (await saved).json()).code === 200);
    await dialog.waitFor({ state: 'hidden' });
    await navigate(page, '/public/events/' + fixture.eventId);
    await page.waitForFunction(() => { const i = document.querySelector('img[src*="/media/banner"]'); return i?.complete && i.naturalWidth > 0; });
    check('Published event cover loads from its controlled public endpoint', await page.locator('img[src*="/media/banner"]').first().evaluate(i => i.complete && i.naturalWidth > 0));
    await shot(page, 'desktop-event-cover');
  });
  await scenario('desktop-materials-final', async () => {
    const { page } = await open(state.organizer);
    await navigate(page, `/org-desk/workspace/${fixture.eventId}?task=materials`);
    await page.getByTestId('material-content').waitFor();
    check('Document editor states the same 10,000 character limit as the server', await page.locator('.studio-view-switch').innerText().then(t => t.includes('10,000')));
    await shot(page, 'desktop-materials');
  });
  for (const [name, actor, route] of [
    ['home', null, '/portal/home'], ['login', null, '/portal/login?returnTo=/portal/rooms'], ['room', state.people[0], '/portal/rooms/' + state.roomA],
    ['growth', state.people[0], '/portal/growth'], ['organizer', state.organizer, '/org-desk/home'],
    ['materials', state.organizer, `/org-desk/workspace/${fixture.eventId}?task=materials`],
    ['government', state.government, '/organization-review/government'], ['platform', state.admin, '/sports-platform?tab=objects']
  ]) await scenario('mobile-' + name, async () => {
    const { page } = await open(actor, true); await navigate(page, route); await page.waitForTimeout(700);
    check('Mobile ' + name + ' has no horizontal page overflow', !await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2));
    if (name === 'room') {
      await page.getByRole('button', { name: '打开 AI 参赛助手', exact: true }).click();
      await page.getByRole('dialog', { name: '体育助手', exact: true }).waitFor();
      check('Mobile static assistant entry opens the actual assistant', await page.locator('.agent-welcome img').isVisible());
      await page.keyboard.press('Escape'); await page.getByRole('dialog', { name: '体育助手', exact: true }).waitFor({ state: 'hidden' });
      check('Mobile room has a single global assistant entry', (await page.locator('.c-ai-launcher:visible').count()) === 0);
    }
    await shot(page, 'mobile-' + name);
  });
  assert.deepEqual(errors, []);
} finally {
  await current?.context.close(); await browser.close();
  const report = { timestamp: new Date().toISOString(), frontend: 'http://127.0.0.1:5192', isolatedDatabase: runtime.database,
    scope: 'Real UI, local storage and DeepSeek text. Synthetic rehearsal accounts/event only. No intercepted data, real payment, SMS or official match acceptance.', checks, failures, pageErrors: errors };
  fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(report, null, 2), { flag: 'wx' });
  console.log('Evidence: ' + path.relative(process.cwd(), out));
  if (failures.length || errors.length) process.exitCode = 1;
}
