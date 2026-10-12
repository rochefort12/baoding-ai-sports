// Read-only real browsers: greeting timing, bounds and interactions. No model or business writes.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { context } from './lib/BusinessRegression.mjs';
const out = path.resolve('.local/team-invite-experience-20261012/greetings-' + crypto.randomUUID());
fs.mkdirSync(out, { recursive: true });
const receipt = { at: new Date().toISOString(), passed: false, scope: 'Anonymous desktop/mobile browsers; actual greeting timers and UI only, no model call or business mutation', checks: [], screenshots: [], jarSha256: JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8').replace(/^\uFEFF/, '')).jarSHA256 };
const save = () => fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(receipt, null, 2));
function check(name, passed, details = {}) { receipt.checks.push({ name, passed: !!passed, ...details }); save(); assert.ok(passed, name); console.log('PASS ' + name); }
const { chromium } = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const loginSession = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json', 'utf8').replace(/^\uFEFF/, ''));
let active;
async function stable(page) { await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))); await page.waitForFunction(() => document.getAnimations().every(a => a.effect?.getTiming().iterations === Infinity || a.playState !== 'running')); }
async function snap(page, name) { await stable(page); const file = name + '.png'; await page.screenshot({ path: path.join(out, file) }); receipt.screenshots.push(file); save(); }
try {
  for (const [device, viewport] of [['desktop', { width: 1440, height: 1000 }], ['mobile', { width: 390, height: 844 }]]) {
    const ctx = await browser.newContext({ viewport, reducedMotion: device === 'mobile' ? 'reduce' : 'no-preference' });
    const page = await ctx.newPage(); active = page;
    const modelCalls = [];
    page.on('request', request => { if (request.method() === 'POST' && /assistant|ai\/|agent.*execute|tasks/.test(request.url())) modelCalls.push(request.url().split('?')[0]); });
    await page.goto(context.frontend + '/portal/home');
    const orb = page.locator('.assistant-bubble'), greeting = page.locator('.assistant-bubble-greeting');
    await orb.waitFor(); await greeting.waitFor({ timeout: 14000 }); await stable(page);
    check(device + ' sprite-only orb and warm first introduction', await orb.locator('img').evaluate(img => img.complete && img.naturalWidth > 0) && !(await orb.innerText()).trim() && (await greeting.innerText()).includes('你好呀'));
    const bounds = await greeting.evaluate(el => { const r = el.getBoundingClientRect(), a = document.querySelector('.assistant-bubble').getBoundingClientRect(); return { left: r.left, top: r.top, right: r.right, bottom: r.bottom, orbTop: a.top, viewportWidth: innerWidth, viewportHeight: innerHeight, fontSize: parseFloat(getComputedStyle(el.querySelector('.assistant-greeting-copy')).fontSize) }; });
    check(device + ' readable greeting stays above orb within viewport', bounds.left >= 8 && bounds.top >= 8 && bounds.right <= bounds.viewportWidth - 8 && bounds.bottom <= bounds.orbTop && bounds.fontSize >= 15, { bounds });
    await snap(page, 'greeting-' + device);
    await greeting.locator('.assistant-greeting-copy').click();
    await page.locator('.assistant-window').waitFor();
    await greeting.waitFor({ state: 'hidden' }); await stable(page);
    check(device + ' introduction opens actual chat and hides greeting', !(await greeting.isVisible()) && await page.locator('.assistant-window').isVisible());
    check(device + ' open chat hides floating icon to protect input controls', !(await orb.isVisible()));
    await page.getByRole('button', { name: '关闭聊天窗口', exact: true }).click();
    await greeting.waitFor({ timeout: 16000 });
    const first = await greeting.innerText();
    await greeting.waitFor({ state: 'hidden', timeout: 11000 });
    await greeting.waitFor({ timeout: 21000 });
    check(device + ' real time cycle introduces a different capability', (await greeting.innerText()) !== first && (await greeting.innerText()).includes('规程'));
    await page.getByRole('button', { name: '暂时收起助手提示', exact: true }).click();
    await greeting.waitFor({ state: 'hidden' });
    await orb.focus(); await page.keyboard.press('ArrowUp');
    const a = await orb.boundingBox();
    check(device + ' keyboard movement keeps icon bounded and preference persists', a.x >= 8 && a.y >= 8 && a.x + a.width <= viewport.width - 8 && await page.evaluate(() => !!localStorage.getItem('sports-assistant-bubble-position')));
    await page.reload(); await orb.waitFor(); await greeting.waitFor({ timeout: 14000 });
    await orb.focus(); await page.keyboard.press('ArrowUp'); await stable(page);
    const adjusted = await greeting.boundingBox();
    check(device + ' introduction follows restored icon without horizontal page overflow', adjusted.x >= 8 && adjusted.x + adjusted.width <= viewport.width - 8 && await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
    await page.getByRole('button', { name: '本次登录不再提示', exact: true }).click();
    await greeting.waitFor({ state: 'hidden' });
    check(device + ' login mute stores a boolean preference without identity data', await page.evaluate(() => sessionStorage.getItem('sports-assistant-greeting-muted') === '1'));
    await page.reload(); await orb.waitFor(); await page.waitForTimeout(4000);
    check(device + ' mute survives reload while icon still opens chat', !(await greeting.isVisible()));
    await orb.click(); await page.locator('.assistant-window').waitFor(); await page.getByRole('button', { name: '关闭聊天窗口', exact: true }).click();
    await page.goto(context.frontend + '/public/events'); await orb.waitFor(); await page.waitForTimeout(2500);
    check(device + ' mute survives actual page navigation', !(await greeting.isVisible()) && await page.evaluate(() => sessionStorage.getItem('sports-assistant-greeting-muted') === '1'));
    await page.goto(context.frontend + '/portal/login');
    await page.getByPlaceholder('请输入手机号').fill(loginSession.people[0].phone); await page.getByPlaceholder('请输入密码').fill(loginSession.password);
    await page.getByRole('button', { name: '登录', exact: true }).click(); await page.waitForURL(u => !u.pathname.includes('/login'));
    await page.goto(context.frontend + '/portal/home'); await greeting.waitFor({ timeout: 14000 });
    check(device + ' successful new login restores introductions', await page.evaluate(() => sessionStorage.getItem('sports-assistant-greeting-muted') === null));
    check(device + ' greeting interaction made no model calls', modelCalls.length === 0, { requestCount: modelCalls.length });
    await ctx.close();
  }
  receipt.passed = true; receipt.finishedAt = new Date().toISOString(); save(); console.log('Evidence: ' + out);
} catch (error) { receipt.failure = error.message; save(); await active?.screenshot({ path: path.join(out, 'failure.png') }).catch(() => {}); throw error; }
finally { await browser.close(); }
