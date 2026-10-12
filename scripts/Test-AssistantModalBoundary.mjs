// Real ordinary-participant modal interactions and local floating preferences.
// No mocked API, forced pointer clicks, model calls, or business writes.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const state = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json', 'utf8'));
const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8'));
assert.equal(runtime.port, 8082, 'Isolated backend port differs');
assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/, 'Isolated database identity differs');
assert.equal(runtime.database, state.database, 'Session and isolated database differ');
assert.ok(state.people?.[0]?.token && state.people[0].clientId, 'Existing ordinary participant session is required');
const base = 'http://127.0.0.1:5192';
const out = path.resolve('.local/product-release-20261011', 'assistant-modal-' + Date.now());
fs.mkdirSync(out, { recursive: true });
const report = {
  timestamp: new Date().toISOString(),
  scope: 'Actual isolated ordinary participant: growth dialog, unsaved certification message box, assistant restoration, pointer/keyboard bubble position persistence, viewport clamp and real pointer resize. GET only; no model or business mutation.',
  passed: false, checks: [], failures: [], pageErrors: [], blockedWrites: [], screenshots: [], sourceFiles: []
};
const sources = [
  'scripts/Test-AssistantModalBoundary.mjs',
  'plus-ui/src/hooks/useAssistantModalBoundary.ts',
  'plus-ui/src/components/consumer/AssistantBubble.vue',
  'plus-ui/src/components/consumer/AssistantWindow.vue',
  'plus-ui/src/components/consumer/AgentPanel.vue',
  'plus-ui/src/components/consumer/HonorCertification.vue',
  'plus-ui/src/views/portal/growth.vue'
];
for (const file of sources) {
  if (!fs.existsSync(file)) continue;
  report.sourceFiles.push({ path: file, sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') });
}
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
let current, phase = 'start';
function check(name, value) { assert.ok(value, name); report.checks.push(name); }
function samePosition(a, b) { return Math.abs(a.x - b.x) < 1.1 && Math.abs(a.y - b.y) < 1.1; }
async function fits(page, locator) {
  const box = await locator.boundingBox(), view = page.viewportSize();
  return box && box.x >= 7 && box.y >= 7 && box.x + box.width <= view.width - 7 && box.y + box.height <= view.height - 7;
}
async function topmost(locator) {
  return locator.evaluate(node => {
    const box = node.getBoundingClientRect(), target = document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2);
    return !!target && (target === node || node.contains(target));
  });
}
async function shot(page, name) {
  const file = path.join(out, name + '.png');
  await page.screenshot({ path: file, fullPage: false });
  report.screenshots.push({ path: path.relative(process.cwd(), file).replaceAll('\\', '/'), sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') });
}
async function open(width) {
  const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 1000 }, reducedMotion: 'reduce' });
  await context.addInitScript(token => {
    localStorage.setItem('Admin-Token', token);
    localStorage.setItem('Platform-Token', token);
  }, state.people[0].token);
  await context.route('**/*', route => {
    if (!['GET', 'HEAD'].includes(route.request().method())) {
      report.blockedWrites.push({ path: new URL(route.request().url()).pathname, method: route.request().method() });
      return route.abort('blockedbyclient');
    }
    return route.continue();
  });
  const page = await context.newPage();
  page.setDefaultTimeout(12000);
  page.on('pageerror', () => report.pageErrors.push('Ordinary participant page script error'));
  current = { context, page };
  const response = await context.request.get(base + '/dev-api/sports/display', { headers: { Authorization: 'Bearer ' + state.people[0].token, clientid: state.people[0].clientId } });
  const body = await response.json();
  check(width + ' ordinary session is accepted by actual display API', response.ok() && body.code === 200 && !!body.data);
  await page.goto(base + '/portal/growth', { waitUntil: 'domcontentloaded' });
  await page.getByRole('heading', { name: '成长与荣誉', exact: true }).waitFor();
  await page.locator('.rank-catalog>button').first().waitFor();
  await page.locator('.assistant-bubble').waitFor();
  return current;
}
async function openAssistant(page, text) {
  await page.locator('.assistant-bubble').click();
  const window = page.locator('.assistant-window.product-agent');
  await window.waitFor();
  // Keep a DOM locator for the same textarea after the assistant is temporarily
  // hidden; accessibility locators intentionally exclude hidden controls.
  const input = window.locator('textarea[aria-label="发给体育助手的消息"]');
  await input.fill(text);
  return { window, input };
}
async function openRank(page) {
  // Keyboard activation is a real accessible interaction even when a floating
  // chat occupies the pointer path above an underlying business card.
  const rank = page.locator('.rank-catalog>button').first();
  const name = (await rank.getAttribute('aria-label')).split('，')[0];
  await rank.focus();
  await rank.press('Enter');
  phase = 'growth dialog appears after keyboard activation';
  const dialog = page.locator('.el-overlay .el-dialog').filter({ has: page.locator('.rank-preview') });
  await dialog.waitFor();
  check('keyboard opens the selected rank business dialog', await dialog.locator('.el-dialog__title').innerText() === name + '段位');
  return dialog;
}
try {
  for (const [device, width] of [['mobile', 390], ['desktop', 1440]]) {
    const { page, context } = await open(width), bubble = page.locator('.assistant-bubble');
    // Test the initial ordinary pointer path: the former bug covered this close button.
    await page.locator('.rank-catalog>button').first().click();
    let dialog = page.locator('.el-overlay .el-dialog').filter({ has: page.locator('.rank-preview') });
    await dialog.waitFor();
    await bubble.waitFor({ state: 'hidden' });
    let close = dialog.getByRole('button', { name: '关闭', exact: true });
    check(device + ' growth footer close is topmost while assistant bubble is hidden', await topmost(close));
    await shot(page, device + '-rank-dialog');
    await close.click();
    await dialog.waitFor({ state: 'hidden' });
    await bubble.waitFor();
    check(device + ' pointer close restores the bubble without opening chat', await page.locator('.assistant-window').count() === 0 && await bubble.getAttribute('aria-expanded') === 'false');

    const draft = '仅检查业务弹窗，不发送消息';
    const assistant = await openAssistant(page, draft);
    check(device + ' actual ordinary chat is bounded before business modal', await fits(page, assistant.window));
    dialog = await openRank(page);
    phase = device + ' assistant hidden while rank dialog is open';
    await assistant.window.waitFor({ state: 'hidden' });
    await bubble.waitFor({ state: 'hidden' });
    check(device + ' open chat remains mounted with its unsent task draft during growth dialog', await assistant.window.count() === 1 && await assistant.input.inputValue() === draft && await bubble.getAttribute('aria-expanded') === 'true');
    close = dialog.getByRole('button', { name: '关闭', exact: true });
    check(device + ' business close remains topmost with chat already open', await topmost(close));
    await close.click();
    await dialog.waitFor({ state: 'hidden' });
    await assistant.window.waitFor();
    await bubble.waitFor();
    check(device + ' closing growth dialog restores the same open chat and draft', await assistant.input.inputValue() === draft && await bubble.getAttribute('aria-expanded') === 'true');
    await shot(page, device + '-chat-restored');

    const handle = assistant.window.getByRole('button', { name: '调整聊天窗口尺寸，方向键调整', exact: true });
    const beforeWindow = await assistant.window.boundingBox(), handleBox = await handle.boundingBox();
    check(device + ' pointer resize handle is topmost and usable', await topmost(handle));
    await page.mouse.move(handleBox.x + handleBox.width / 2, handleBox.y + handleBox.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox.x + handleBox.width / 2 - (width < 600 ? 24 : 80), handleBox.y + handleBox.height / 2 - 60, { steps: 10 });
    await page.mouse.up();
    const afterWindow = await assistant.window.boundingBox();
    check(device + ' actual pointer resize changes width and height without overflowing', afterWindow.width < beforeWindow.width - 15 && afterWindow.height < beforeWindow.height - 35 && await fits(page, assistant.window));
    check(device + ' resize leaves composer visible and unsent text intact', await assistant.input.isVisible() && await assistant.input.inputValue() === draft);
    await shot(page, device + '-pointer-resized');
    await assistant.window.getByRole('button', { name: '关闭聊天窗口', exact: true }).click();
    await assistant.window.waitFor({ state: 'hidden' });

    const beforeBubble = await bubble.boundingBox();
    await page.mouse.move(beforeBubble.x + 28, beforeBubble.y + 28);
    await page.mouse.down();
    await page.mouse.move(beforeBubble.x - 92, beforeBubble.y - 112, { steps: 10 });
    await page.mouse.up();
    const dragged = await bubble.boundingBox();
    check(device + ' actual bubble drag moves without reopening chat', dragged.x < beforeBubble.x - 60 && dragged.y < beforeBubble.y - 60 && !await assistant.window.isVisible());
    await bubble.focus();
    await bubble.press('ArrowRight');
    await bubble.press('ArrowDown');
    const positioned = await bubble.boundingBox();
    check(device + ' keyboard moves bubble by its documented 20 pixel step', Math.abs(positioned.x - dragged.x - 20) < 1 && Math.abs(positioned.y - dragged.y - 20) < 1);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.getByRole('heading', { name: '成长与荣誉', exact: true }).waitFor();
    await bubble.waitFor();
    check(device + ' bubble pointer and keyboard position survives reload', samePosition(positioned, await bubble.boundingBox()));
    await page.setViewportSize({ width: 320, height: 480 });
    await page.waitForFunction(() => {
      const b = document.querySelector('.assistant-bubble')?.getBoundingClientRect();
      return b && b.left >= 7 && b.top >= 7 && b.right <= innerWidth - 7 && b.bottom <= innerHeight - 7;
    });
    check(device + ' small viewport clamps bubble inside all four edges', await fits(page, bubble));
    const clamped = await bubble.boundingBox();
    await page.reload({ waitUntil: 'domcontentloaded' });
    await bubble.waitFor();
    check(device + ' clamped preference remains bounded and survives small viewport reload', await fits(page, bubble) && samePosition(clamped, await bubble.boundingBox()));
    await shot(page, device + '-position-persisted-small');
    await page.setViewportSize({ width, height: width < 600 ? 844 : 1000 });

    // The actual unsaved certification editor opens Element Plus message-box.
    // No certification record is saved, submitted, uploaded, or approved.
    await page.goto(base + '/portal/profile', { waitUntil: 'domcontentloaded' });
    await page.getByRole('heading', { name: '完善资料', exact: true }).waitFor();
    const certification = page.locator('[data-testid="honor-certification"]');
    await page.waitForFunction(() => document.querySelector('[data-testid="honor-certification"]')?.getAttribute('aria-busy') === 'false');
    await certification.getByRole('button', { name: '申请认证', exact: true }).click();
    const editor = certification.locator('[data-testid="honor-certification-editor"]'), event = editor.locator('[data-testid="honor-event"]');
    await event.fill('未保存的弹窗交互检查');
    const profileAssistant = await openAssistant(page, draft);
    const collapse = certification.getByRole('button', { name: '收起', exact: true });
    await collapse.focus();
    await collapse.press('Enter');
    const messageBox = page.getByRole('dialog', { name: '保留修改', exact: true });
    await messageBox.waitFor();
    await profileAssistant.window.waitFor({ state: 'hidden' });
    await bubble.waitFor({ state: 'hidden' });
    const continueEditing = messageBox.getByRole('button', { name: '继续编辑', exact: true });
    check(device + ' real message-box cancel is topmost while chat remains mounted', await topmost(continueEditing) && await profileAssistant.window.count() === 1);
    await shot(page, device + '-message-box');
    await continueEditing.click();
    await messageBox.waitFor({ state: 'hidden' });
    await profileAssistant.window.waitFor();
    await bubble.waitFor();
    check(device + ' message-box cancel preserves unsaved business form and assistant draft', await event.inputValue() === '未保存的弹窗交互检查' && await profileAssistant.input.inputValue() === draft && await bubble.getAttribute('aria-expanded') === 'true');
    await profileAssistant.window.getByRole('button', { name: '关闭聊天窗口', exact: true }).click();
    await profileAssistant.window.waitFor({ state: 'hidden' });
    await collapse.click();
    await messageBox.waitFor();
    await messageBox.getByRole('button', { name: '放弃修改', exact: true }).click();
    await messageBox.waitFor({ state: 'hidden' });
    await editor.waitFor({ state: 'hidden' });
    await bubble.waitFor();
    check(device + ' abandoning local editor restores assistant with no saved application', await bubble.isVisible());
    await shot(page, device + '-message-box-restored');
    await context.close();
    current = undefined;
  }
  check('zero attempted model or business write requests', report.blockedWrites.length === 0);
  check('zero page script errors', report.pageErrors.length === 0);
  report.passed = true;
} catch (error) {
  report.failures.push({ type: error.name, message: error.name === 'AssertionError' ? error.message : 'Interaction verification did not complete; private details omitted', path: current ? new URL(current.page.url()).pathname : undefined });
  report.failures.at(-1).phase = phase;
  if (current) await shot(current.page, 'failure').catch(() => {});
  process.exitCode = 1;
} finally {
  await browser.close();
  const file = path.join(out, 'receipt.json'), fd = fs.openSync(file, 'wx');
  try { fs.writeFileSync(fd, JSON.stringify(report, null, 2) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failures: report.failures, report: path.relative(process.cwd(), file).replaceAll('\\', '/') }));
}
