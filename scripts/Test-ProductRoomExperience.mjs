// Real C/D participant UI against the existing isolated rehearsal service.
// No response interception, direct SQL, registration, payment or competition writes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const privateRoot = path.resolve('.local/phase1-implementation');
const state = JSON.parse(fs.readFileSync(path.join(privateRoot, 'verification-session.json'), 'utf8'));
const runtime = JSON.parse(fs.readFileSync(path.join(privateRoot, 'verification-runtime.json'), 'utf8'));
const frontendRuntime = JSON.parse(fs.readFileSync('.local/demo-20261011/frontend-runtime.json', 'utf8'));
const fixture = JSON.parse(fs.readFileSync('.local/demo-20261011/scenario.json', 'utf8'));
assert.equal(runtime.port, 8082);
assert.match(runtime.database, /^aisports_verify_phase1_[a-f0-9]{32}$/);
assert.equal(frontendRuntime.backendPort, 8082);
assert.equal(frontendRuntime.port, 5192);
assert.equal(fixture.published, true);

const root = path.resolve('.local/product-release-20261011');
const checkpointPath = path.join(root, 'room-ui-progress.json');
fs.mkdirSync(root, { recursive: true });
const progress = fs.existsSync(checkpointPath)
  ? JSON.parse(fs.readFileSync(checkpointPath, 'utf8'))
  : { runId: crypto.randomUUID(), createdAt: new Date().toISOString(), eventId: fixture.eventId, unitId: fixture.pairUnit, checks: [], receipts: [], retryKeys: {} };
assert.equal(progress.eventId, fixture.eventId);
assert.equal(progress.unitId, fixture.pairUnit);
progress.roomName ||= '界面补验 · 双打集结（模拟） ' + progress.runId.slice(0, 6);
const out = path.join(root, `room-ui-${Date.now()}`);
fs.mkdirSync(out, { recursive: false });
const checks = [], failures = [], pageErrors = [], writes = [];
const allowedWrites = new Set(['room.create', 'room.match', 'room.stopMatch', 'room.answer', 'room.ready']);
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const actors = { C: state.people[2], D: state.people[3] };
const tabs = {};
const base = 'http://127.0.0.1:5192';

function save() {
  progress.updatedAt = new Date().toISOString();
  const temporary = checkpointPath + '.next';
  fs.writeFileSync(temporary, JSON.stringify(progress, null, 2));
  fs.renameSync(temporary, checkpointPath);
}
function check(name, actual = true) {
  assert.ok(actual, name);
  checks.push(name);
  if (!progress.checks.includes(name)) progress.checks.push(name);
  save();
  console.log('PASS ' + name);
}
async function open(label, mobile = false) {
  const context = await browser.newContext({ viewport: mobile ? { width: 390, height: 844 } : { width: 1440, height: 1000 }, reducedMotion: 'reduce' });
  await context.addInitScript(({ token, retryKeys }) => {
    localStorage.setItem('Admin-Token', token);
    for (const [key, value] of Object.entries(retryKeys)) sessionStorage.setItem(key, value);
  }, { token: actors[label].token, retryKeys: progress.retryKeys[label] || {} });
  const page = await context.newPage();
  page.on('pageerror', () => pageErrors.push(label + ' page script error'));
  page.on('request', request => {
    if (request.method() === 'GET' || request.method() === 'HEAD') return;
    const match = new URL(request.url()).pathname.match(/\/sports\/platform\/actions\/([^/]+)\/(preview|confirm|execute)$/);
    writes.push({ actor: label, action: match?.[1] || 'unexpected', operation: match?.[2] || 'unexpected' });
  });
  return { page, context, label };
}
async function read(label, endpoint) {
  const response = await tabs[label].page.request.get(base + '/dev-api' + endpoint, {
    headers: { Authorization: 'Bearer ' + actors[label].token, clientid: 'e5cd7e4891bf95d1d19206ce24a7b32e' }
  });
  const body = await response.json();
  assert.equal(body.code, 200, 'Actual participant read must succeed: ' + endpoint);
  return body.data;
}
const room = () => read('C', '/sports/rooms/' + progress.roomId);
async function navigate(tab, route) {
  await tab.page.goto(base + route, { waitUntil: 'domcontentloaded' });
  await tab.page.getByRole('heading', { name: route.includes('/rooms/') ? '参赛房间' : '找队友', exact: true }).waitFor({ timeout: 20000 });
  await tab.page.locator('.consumer-state.loading').waitFor({ state: 'hidden' }).catch(() => {});
  assert.equal(await tab.page.locator('vite-error-overlay').count(), 0);
}
async function shot(tab, name) {
  await tab.page.screenshot({ path: path.join(out, name + '.png'), fullPage: true });
}
async function action(tab, code, button, confirmed = false) {
  const pending = tab.page.waitForResponse(response => response.request().method() === 'POST' && response.url().endsWith('/actions/' + code + '/execute'), { timeout: 20000 });
  pending.catch(() => {});
  try {
    await button.click();
    if (confirmed) {
      const dialog = tab.page.getByRole('dialog', { name: '确认操作', exact: true });
      await dialog.waitFor();
      await dialog.getByRole('button', { name: '确认', exact: true }).click();
    }
    const body = await (await pending).json();
    assert.equal(body.code, 200, 'Real action must have successful receipt: ' + code + ' ' + (body.msg || ''));
    assert.ok(body.data?.receiptId, 'Business success includes an execution receipt');
    progress.receipts.push({ actor: tab.label, code, receiptId: body.data.receiptId, result: body.data.result, timestamp: new Date().toISOString() });
    save();
    return body.data;
  } finally {
    progress.retryKeys[tab.label] = await tab.page.evaluate(() => Object.fromEntries(Object.entries(sessionStorage).filter(([key]) => key.startsWith('sports-action:'))));
    save();
  }
}
async function waitRoom(predicate) {
  let current;
  await tabs.C.page.waitForTimeout(250);
  for (let attempt = 0; attempt < 12; attempt++) {
    current = await room();
    if (predicate(current)) return current;
    await tabs.C.page.waitForTimeout(250);
  }
  assert.ok(predicate(current), 'Actual room reaches the expected state');
  return current;
}

save();
try {
  tabs.C = await open('C'); tabs.D = await open('D', true);
  // Recover an already-created room by its durable unique name after an interrupted response.
  const homeC = await read('C', '/sports/rooms');
  const existing = homeC.rooms.find(item => item.unit_id === fixture.pairUnit && item.name === progress.roomName);
  if (existing) progress.roomId = existing.id;
  if (!progress.roomId) {
    assert.ok(!homeC.rooms.some(item => item.unit_id === fixture.pairUnit), 'C has no other active room in this rehearsal project');
    await navigate(tabs.C, '/portal/rooms?unitId=' + fixture.pairUnit);
    await tabs.C.page.getByPlaceholder('给本场房间起个名字').fill(progress.roomName);
    const receipt = await action(tabs.C, 'room.create', tabs.C.page.getByRole('button', { name: '创建双打房间', exact: true }));
    progress.roomId = receipt.result.roomId; save();
    await tabs.C.page.waitForURL('**/portal/rooms/' + progress.roomId);
  } else await navigate(tabs.C, '/portal/rooms/' + progress.roomId);

  let actualRoom = await room();
  assert.equal(actualRoom.room.unit_id, fixture.pairUnit);
  assert.equal(actualRoom.room.registration_id, null, 'This test must not create a registration');
  const cAccount = actualRoom.accountId;
  const dAccount = (await read('D', '/sports/rooms')).accountId;
  if (actualRoom.members.length === 1) {
    check('房主计入一个席位，创建后真实名单为 1/2', actualRoom.members[0].account_id === cAccount && actualRoom.room.host_account_id === cAccount);
    await tabs.C.page.getByText('羽毛球双打 · 1/2 人', { exact: true }).waitFor();
    check('房间 UI 显示房主一个席位及待补员', await tabs.C.page.locator('.sports-avatar').count() === 1 && await tabs.C.page.locator('.empty-seat').count() === 1);
    await shot(tabs.C, 'desktop-created-host-counts');

    const ownHome = await read('C', '/sports/rooms');
    if (!ownHome.requests.some(item => item.unit_id === fixture.pairUnit)) {
      await action(tabs.C, 'room.match', tabs.C.page.getByRole('button', { name: '自动匹配', exact: true }));
    }
    await tabs.C.page.getByText('正在寻找本场搭档', { exact: true }).waitFor();
    check('房间发起匹配后显示真实等待状态');
    await navigate(tabs.D, '/portal/rooms?unitId=' + fixture.pairUnit);
    let homeD = await read('D', '/sports/rooms');
    if (!homeD.offers.some(item => item.room_id === progress.roomId)) {
      await action(tabs.D, 'room.match', tabs.D.page.getByRole('button', { name: '自动匹配', exact: true }));
      homeD = await read('D', '/sports/rooms');
    }
    const offered = homeD.offers.find(item => item.room_id === progress.roomId);
    assert.ok(offered, 'D has a real offer for the C host room');
    progress.offerId = offered.id; save();
    await tabs.D.page.getByRole('heading', { name: '组队邀请', exact: true }).waitFor();
    // No reload here: the room detail must discover the offer through its actual polling.
    await tabs.C.page.getByRole('heading', { name: '组队邀请', exact: true }).waitFor({ timeout: 16000 });
    const timerBefore = Number((await tabs.C.page.locator('.offer-timer').innerText()).replace(/\D/g, ''));
    assert.ok(timerBefore > 0 && timerBefore <= 120, 'Offer countdown is a real 120-second confirmation window');
    await tabs.C.page.waitForTimeout(1200);
    const timerAfter = Number((await tabs.C.page.locator('.offer-timer').innerText()).replace(/\D/g, ''));
    check('列表与房间都显示邀请，房间倒计时实际递减', timerAfter < timerBefore && timerAfter > 0 && await tabs.D.page.locator('.offer-timer').isVisible());
    actualRoom = await room();
    check('收到邀请尚未自动入房，房主仍为 1/2', actualRoom.members.length === 1 && !(await read('D', '/sports/rooms')).rooms.some(item => item.id === progress.roomId));
    await shot(tabs.C, 'desktop-room-offer-countdown');
    await shot(tabs.D, 'mobile-list-offer-countdown');

    const cOffer = (await read('C', '/sports/rooms')).offers.find(item => item.id === progress.offerId);
    if (cOffer?.my_status !== 'accepted') {
      const receipt = await action(tabs.C, 'room.answer', tabs.C.page.getByRole('button', { name: '接受邀请', exact: true }), true);
      assert.equal(receipt.result.status, 'waiting_partner');
    }
    await tabs.C.page.getByText('你已接受，等待搭档确认', { exact: false }).waitFor();
    actualRoom = await room();
    check('房主本人接受后仍等搭档，本次邀请不代替搭档接受', actualRoom.members.length === 1 && (await read('D', '/sports/rooms')).offers.find(item => item.id === progress.offerId)?.my_status === 'pending');
    await shot(tabs.C, 'desktop-waiting-partner');
    await action(tabs.D, 'room.answer', tabs.D.page.getByRole('button', { name: '接受邀请', exact: true }), true);
    await tabs.D.page.waitForURL('**/portal/rooms/' + progress.roomId);
    actualRoom = await waitRoom(value => value.members.length === 2);
    progress.matchAccepted = true; save();
    check('双方本人接受后真实房间才组成两人', actualRoom.members.some(item => item.account_id === cAccount) && actualRoom.members.some(item => item.account_id === dAccount));
  } else {
    assert.equal(actualRoom.members.length, 2);
    check('断点恢复复用原房间，无重复创建或重发邀请', progress.matchAccepted === true || progress.receipts.some(item => item.code === 'room.answer' && item.result.roomId === progress.roomId));
    await navigate(tabs.D, '/portal/rooms/' + progress.roomId);
  }

  await tabs.C.page.getByText('羽毛球双打 · 2/2 人', { exact: true }).waitFor({ timeout: 16000 });
  await tabs.D.page.getByText('羽毛球双打 · 2/2 人', { exact: true }).waitFor();
  actualRoom = await room();
  if (!actualRoom.members.find(item => item.account_id === cAccount).ready) {
    check('集齐后准备状态分别归本人，初始双方未准备', actualRoom.members.every(item => item.ready === false));
    await tabs.C.page.getByRole('button', { name: '确认准备', exact: true }).waitFor();
    await action(tabs.C, 'room.ready', tabs.C.page.getByRole('button', { name: '确认准备', exact: true }));
    actualRoom = await waitRoom(value => value.members.find(item => item.account_id === cAccount).ready);
    check('C 准备只改变 C，本人操作不替 D 准备', actualRoom.members.find(item => item.account_id === dAccount).ready === false);
    await tabs.C.page.getByText('1 人已准备', { exact: true }).waitFor();
    check('一人准备时房主生成报名按钮不可用', await tabs.C.page.getByRole('button', { name: '生成报名', exact: true }).isDisabled());
    await shot(tabs.C, 'desktop-one-ready');
  }
  if (!actualRoom.members.find(item => item.account_id === dAccount).ready) {
    await navigate(tabs.D, '/portal/rooms/' + progress.roomId);
    await action(tabs.D, 'room.ready', tabs.D.page.getByRole('button', { name: '确认准备', exact: true }));
  }
  actualRoom = await waitRoom(value => value.members.every(item => item.ready));
  await tabs.C.page.getByText('2 人已准备', { exact: true }).waitFor({ timeout: 16000 });
  await tabs.D.page.getByText('2 人已准备', { exact: true }).waitFor();
  check('两人各自确认准备后才能由房主继续报名', actualRoom.members.length === 2 && actualRoom.room.status === 'ready' && await tabs.C.page.getByRole('button', { name: '生成报名', exact: true }).isEnabled());
  check('普通成员 UI 保留本人准备，不能代房主生成报名', await tabs.D.page.getByRole('button', { name: '取消准备', exact: true }).isVisible() && await tabs.D.page.getByRole('button', { name: '生成报名', exact: true }).count() === 0);
  check('手机房间没有横向溢出', !await tabs.D.page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2));
  check('两人准备完成仍没有创建报名、资金或比赛事实', actualRoom.room.registration_id === null && writes.every(item => allowedWrites.has(item.action)));
  await shot(tabs.C, 'desktop-two-ready');
  await shot(tabs.D, 'mobile-two-ready');
  await navigate(tabs.C, '/portal/rooms');
  const roomCard = tabs.C.page.locator('.gathering-card[href="/portal/rooms/' + progress.roomId + '"]');
  await roomCard.waitFor();
  check('房间列表读取真实 bigint 人数，满员房间提供确认准备入口', (await roomCard.innerText()).includes('确认准备'));
  await navigate(tabs.D, '/portal/rooms/' + progress.roomId);
  await tabs.D.context.setOffline(true);
  await tabs.D.page.getByText('状态同步暂时中断，请重新同步后继续操作。', { exact: false }).waitFor({ timeout: 17000 });
  check('真实网络中断后保留已加载席位并说明同步失败', await tabs.D.page.locator('.room-stage').isVisible() && await tabs.D.page.locator('.sports-avatar').count() === 2);
  check('状态同步失败时暂停准备办理，避免基于旧状态操作', await tabs.D.page.getByRole('button', { name: '取消准备', exact: true }).isDisabled());
  await shot(tabs.D, 'mobile-network-interrupted');
  await tabs.D.context.setOffline(false);
  await tabs.D.page.getByRole('button', { name: '重新同步', exact: true }).click();
  await tabs.D.page.getByText('状态同步暂时中断，请重新同步后继续操作。', { exact: false }).waitFor({ state: 'hidden', timeout: 10000 });
  check('网络恢复后真实重新同步，保留房间和本人准备状态', await tabs.D.page.locator('.room-stage').isVisible() && await tabs.D.page.getByRole('button', { name: '取消准备', exact: true }).isVisible());
  assert.deepEqual(pageErrors, []);
  progress.completed = true; progress.lastEvidence = path.relative(process.cwd(), out); save();
} catch (error) {
  failures.push(String(error.message).replace(/(token|Authorization|password)=[^&\s]+/gi, 'credential=[REDACTED]').slice(0, 700));
  console.error('FAIL ' + failures.at(-1));
  for (const [label, tab] of Object.entries(tabs)) await shot(tab, 'failed-' + label).catch(() => {});
  process.exitCode = 1;
} finally {
  for (const tab of Object.values(tabs)) await tab.context.close();
  await browser.close();
  fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify({ timestamp: new Date().toISOString(), scope: 'Actual isolated 5192/8082 C/D participant UI. Existing synthetic event. No response interception, direct database changes, registration, money or match facts.', isolatedDatabase: runtime.database, roomId: progress.roomId, eventId: fixture.eventId, unitId: fixture.pairUnit, checks, failures, pageErrors, writes }, null, 2), { flag: 'wx' });
  console.log('Evidence: ' + path.relative(process.cwd(), out));
}
