// Read-only ordinary-organizer UI acceptance. Run only after the owner freezes source.
// The existing candidate is never edited, sent to a model, saved or deleted.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';

const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const state = read('.local/phase1-implementation/verification-session.json');
const context = read(process.env.AISPORTS_REGRESSION_CONTEXT || '.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json');
const runtime = read('.local/phase1-implementation/verification-runtime.json');
const taskId = '2109468287808057346';
assert.equal(context.database, 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b');
assert.equal(new URL(context.frontend).hostname, '127.0.0.1');
assert.equal(new URL(context.frontend).port, '5192');
assert.ok(process.env.POSTGRES_PASSWORD && process.env.POSTGRES_USER && process.env.POSTGRES_PORT, 'Load protected Common environment before running');
const out = path.resolve('.local/assistant-action-rail-20261012', crypto.randomUUID());
fs.mkdirSync(out, { recursive: true });
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const sources = [
  'plus-ui/src/components/shared/AssistantActionRail.vue',
  'plus-ui/src/assets/styles/assistant-action-rail.scss',
  'plus-ui/src/assets/styles/business-ai.scss',
  'plus-ui/src/assets/styles/assistant-typography.scss',
  'plus-ui/src/assets/styles/readability.scss',
  'plus-ui/src/components/business/BusinessAssistant.vue',
  'plus-ui/src/components/business/AiDraftDialog.vue',
  'plus-ui/src/assets/styles/index.scss'
];
const sourceHashes = () => Object.fromEntries(sources.map(file => [file, sha256(fs.readFileSync(file))]));
const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;
function differences(before, after, prefix = '') {
  if (JSON.stringify(canonical(before)) === JSON.stringify(canonical(after))) return [];
  if (!before || !after || typeof before !== 'object' || typeof after !== 'object') return [prefix];
  return [...new Set([...Object.keys(before), ...Object.keys(after)])].flatMap(key => differences(before[key], after[key], prefix ? prefix + '.' + key : key));
}
const candidateView = task => ({ ...task, proposal: typeof task.proposal === 'string' ? JSON.parse(task.proposal) : task.proposal });
function readStoredFacts() {
  const sql = `SELECT json_build_object('taskFingerprint',md5(to_jsonb(t)::text),'status',t.status,'version',t.version,'resultObjectId',t.result_object_id,'filesCount',(SELECT count(*) FROM asp_ai_task_file WHERE task_id=t.id),'filesFingerprint',(SELECT md5(COALESCE(string_agg(to_jsonb(f)::text,'|' ORDER BY f.id),'')) FROM asp_ai_task_file f WHERE f.task_id=t.id),'linkedEventsCount',(SELECT count(*) FROM asp_event e WHERE e.id=t.result_object_id)) FROM asp_ai_task t WHERE t.id=${taskId};`;
  const result = spawnSync('C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe', ['-X', '-q', '-At', '-h', '127.0.0.1', '-p', process.env.POSTGRES_PORT, '-U', process.env.POSTGRES_USER, '-d', context.database, '-v', 'ON_ERROR_STOP=1', '-c', sql], { encoding: 'utf8', env: { ...process.env, PGPASSWORD: process.env.POSTGRES_PASSWORD, PGOPTIONS: '-c default_transaction_read_only=on' } });
  assert.equal(result.status, 0, 'Exact isolated read-only candidate facts query');
  assert.ok(result.stdout.trim(), 'Original candidate exists');
  return JSON.parse(result.stdout.trim());
}
function sanitize(error) {
  let value = String(error?.message || error);
  for (const secret of [state.password, process.env.POSTGRES_PASSWORD, ...state.people.map(person => person.phone)].filter(Boolean)) value = value.replaceAll(String(secret), '[REDACTED]');
  return value.replace(/Bearer\s+[^\s]+/gi, 'Bearer [REDACTED]').replace(/https?:\/\/[^\s)]+/g, '[URL REDACTED]').replace(/[?&](?:token|invite|shareToken|access_token)=[^\s&]+/gi, '[PRIVATE QUERY]').slice(0, 600);
}
const report = {
  at: new Date().toISOString(), taskId,
  scope: 'Actual existing candidate in a fresh ordinary organizer session; rail gestures, focus and form viewing only. All non-authentication writes intercepted.',
  runtimePorts: { frontend: 5192, backend: 8082, gateway: 8091 },
  jarSha256: runtime.jarSHA256, sourceBefore: sourceHashes(),
  checks: [], screenshots: [], blockedWrites: [], authenticationWrites: [], errors: [], boundaries: [], passed: false
};
const save = () => fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(report, null, 2));
const check = (name, value, details = {}) => { report.checks.push({ name, passed: !!value, ...details }); save(); assert.ok(value, name); };
let browser, session, page, cdp, viewBefore;
const settle = async () => { await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))); };
async function shot(file) {
  await settle();
  await page.screenshot({ path: path.join(out, file) });
  report.screenshots.push({ file, sha256: sha256(fs.readFileSync(path.join(out, file))) });
  save();
}
async function fetchIdentityAndCandidate() {
  return page.evaluate(async ({ clientId, taskId }) => {
    let token = localStorage.getItem('Admin-Token'); try { token = JSON.parse(token); } catch {}
    const headers = { Authorization: 'Bearer ' + token, clientid: clientId };
    const get = async url => { const response = await fetch(url, { headers }); if (!response.ok) throw new Error('Read-only API unavailable'); return response.json(); };
    const [info, desk, task] = await Promise.all([get('/dev-api/system/user/getInfo'), get('/dev-api/sports/b/desk/context'), get('/dev-api/sports/b/ai/tasks/' + taskId)]);
    return { userId: String(info.data?.user?.userId || info.user?.userId || ''), organizationId: String(desk.data?.organizationId || ''), task: task.data };
  }, { clientId: context.clientId, taskId });
}
const assistant = () => page.locator('.b-ai-window');
const rail = kind => assistant().locator(kind === 'shortcuts' ? '.b-ai-shortcuts' : '.b-ai-choices');
const track = kind => rail(kind).locator('.assistant-action-rail-track');
async function restoreCandidate() {
  await page.goto(context.frontend + '/org-desk/events', { waitUntil: 'domcontentloaded' });
  await page.locator('.assistant-bubble').waitFor();
  const mute = page.getByRole('button', { name: '本次登录不再提示', exact: true });
  if (await mute.isVisible()) {
    await mute.click();
    await page.locator('.assistant-bubble-greeting').waitFor({ state: 'hidden' });
  }
  if (!(await assistant().isVisible())) await page.locator('.assistant-bubble').click();
  await assistant().locator('.b-ai-draft-actions[data-task-id="' + taskId + '"]').waitFor();
  await track('shortcuts').waitFor();
  await track('suggestions').waitFor();
  await settle();
}
async function uiSnapshot() {
  const values = await assistant().evaluate(el => ({ messages: el.querySelector('.b-ai-messages')?.textContent, input: el.querySelector('textarea')?.value, task: el.querySelector('.b-ai-draft-actions')?.getAttribute('data-task-id'), suggestions: el.querySelectorAll('.b-ai-choices button').length }));
  return { hash: sha256(JSON.stringify(values)), writes: report.blockedWrites.length, authentication: report.authenticationWrites.length };
}
async function metrics(kind) {
  return rail(kind).evaluate(el => {
    const t = el.querySelector('.assistant-action-rail-track'), s = getComputedStyle(t), r = t.getBoundingClientRect();
    const buttons = [...t.querySelectorAll(':scope > button')].map(b => {
      const rect = b.getBoundingClientRect(), css = getComputedStyle(b);
      return { top: rect.top, left: rect.left, right: rect.right, width: rect.width, height: rect.height, font: parseFloat(css.fontSize), whiteSpace: css.whiteSpace, textOverflow: css.textOverflow, scrollWidth: b.scrollWidth, clientWidth: b.clientWidth, textLength: b.textContent.length };
    });
    return { width: r.width, left: r.left, right: r.right, height: r.height, clientWidth: t.clientWidth, scrollWidth: t.scrollWidth, scrollLeft: t.scrollLeft, flexWrap: s.flexWrap, overflowX: s.overflowX, before: el.classList.contains('has-before'), after: el.classList.contains('has-after'), buttons };
  });
}
async function home(kind) { await track(kind).focus(); await page.keyboard.press('Home'); await settle(); }
async function verifyLayout(label) {
  for (const kind of ['shortcuts', 'suggestions']) {
    await home(kind);
    const m = await metrics(kind), tops = m.buttons.map(b => b.top), overflow = m.scrollWidth > m.clientWidth + 1;
    check(label + ' ' + kind + ': single line, readable full labels and 36px targets', m.buttons.length > 0 && m.flexWrap === 'nowrap' && Math.max(...tops) - Math.min(...tops) <= 1 && m.buttons.every(b => b.font >= 14 && b.height >= 35.5 && b.whiteSpace === 'nowrap' && b.textOverflow !== 'ellipsis' && b.scrollWidth <= b.clientWidth + 1), { actual: m });
    check(label + ' ' + kind + ': initial edge cues match overflow', !m.before && m.after === overflow);
  }
  const geometry = await assistant().evaluate(el => {
    const r = el.getBoundingClientRect(), input = el.querySelector('.b-ai-composer textarea').getBoundingClientRect();
    return { left: r.left, right: r.right, top: r.top, bottom: r.bottom, width: innerWidth, height: innerHeight, overflow: el.scrollWidth - el.clientWidth, inputBottom: input.bottom };
  });
  check(label + ': window and composer fit viewport', geometry.left >= -1 && geometry.right <= geometry.width + 1 && geometry.top >= -1 && geometry.bottom <= geometry.height + 1 && geometry.overflow <= 1 && geometry.inputBottom <= geometry.height + 1, { actual: geometry });
  const header = await assistant().locator('.b-ai-header').evaluate(el => ({ height: el.clientHeight, titleHeight: el.querySelector('strong').getBoundingClientRect().height }));
  check(label + ': title stays one readable line and header is compact', header.titleHeight <= 32 && header.height <= 130, { actual: header });
}
async function verifyKeyboard(kind, label) {
  await home(kind);
  const first = await metrics(kind), overflow = first.scrollWidth > first.clientWidth + 1;
  await page.keyboard.press('ArrowRight'); await settle();
  const moved = await metrics(kind);
  check(label + ': ArrowRight scrolls overflowing rail', overflow ? moved.scrollLeft > first.scrollLeft : moved.scrollLeft === 0);
  await page.keyboard.press('ArrowLeft'); await settle();
  check(label + ': ArrowLeft returns to beginning', (await metrics(kind)).scrollLeft <= 1);
  await page.keyboard.press('End'); await settle();
  const end = await metrics(kind);
  check(label + ': End reveals final button and updates edges', Math.abs(end.scrollWidth - end.clientWidth - end.scrollLeft) <= 1 && !end.after && end.before === overflow && end.buttons.at(-1).right <= end.right + 1);
  await home(kind);
  for (let i = 0; i < first.buttons.length; i++) await page.keyboard.press('Tab');
  await settle();
  const tab = await metrics(kind);
  const finalFocused = await track(kind).evaluate(el => document.activeElement === el.querySelector(':scope > button:last-child'));
  check(label + ': Tab focuses and exposes final button', finalFocused && tab.buttons.at(-1).right <= tab.right + 1 && (tab.buttons.at(-1).width > tab.width || tab.buttons.at(-1).left >= tab.left - 1), { finalFocused, actual: tab });
}
async function nativeSwipe(kind, label) {
  await home(kind);
  const start = await metrics(kind);
  if (start.scrollWidth <= start.clientWidth + 1) {
    report.boundaries.push({ name: label, status: 'not-applicable', reason: 'Actual candidate rail fits without horizontal overflow at this viewport' }); save(); return;
  }
  const before = await uiSnapshot(), box = await track(kind).boundingBox();
  const x = box.x + box.width - 30, y = box.y + box.height / 2, travel = Math.min(180, box.width - 65);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y, radiusX: 2, radiusY: 2, force: 1 }] });
  for (let i = 1; i <= 8; i++) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x - travel * i / 8, y, radiusX: 2, radiusY: 2, force: 1 }] });
    await page.waitForTimeout(16);
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await page.waitForFunction(selector => document.querySelector(selector)?.scrollLeft > 8, '.b-ai-window ' + (kind === 'shortcuts' ? '.b-ai-shortcuts' : '.b-ai-choices') + ' .assistant-action-rail-track');
  await page.waitForTimeout(180); await settle();
  const after = await metrics(kind);
  check(label + ': native CDP touchscreen swipe scrolls actual rail', after.scrollLeft > 8, { before: start.scrollLeft, after: after.scrollLeft, input: 'Input.dispatchTouchEvent touchStart/touchMove/touchEnd; no synthetic DOM touch events' });
  check(label + ': swipe triggers no command, reply or write', JSON.stringify(before) === JSON.stringify(await uiSnapshot()));
}
async function mouseDrag(kind, label, terminal = 'up') {
  await home(kind);
  const initial = await metrics(kind);
  if (kind === 'suggestions' && initial.scrollWidth <= initial.clientWidth + 1) {
    report.boundaries.push({ name: label, status: 'not-applicable', reason: 'Actual candidate rail has no mouse-scroll overflow at this viewport' }); save(); return;
  }
  assert.ok(initial.scrollWidth > initial.clientWidth + 1, 'Actual shortcut rail must overflow for the 320px mouse-drag test');
  const before = await uiSnapshot(), first = await track(kind).locator(':scope > button').first().boundingBox();
  const x = first.x + Math.min(first.width / 2, 35), y = first.y + first.height / 2;
  await page.mouse.move(x, y); await page.mouse.down();
  await page.mouse.move(x - 20, y, { steps: 2 });
  if (terminal === 'lost-capture') {
    // Release actual browser pointer capture while the real mouse remains held.
    const released = await track(kind).evaluate(el => {
      for (let id = 1; id <= 32; id++) if (el.hasPointerCapture(id)) { el.releasePointerCapture(id); return true; }
      return false;
    });
    check(label + ': real pointer capture was released while mouse held', released);
    await settle();
    const stoppedAt = (await metrics(kind)).scrollLeft;
    await page.mouse.move(x - 55, y, { steps: 3 }); await settle();
    check(label + ': lost capture ends drag despite still-held mouse', !await rail(kind).evaluate(el => el.classList.contains('dragging')) && Math.abs((await metrics(kind)).scrollLeft - stoppedAt) <= 1);
    // Release over the original button after a prolonged hold: a timed click guard would expire here.
    await page.waitForTimeout(550);
    await page.mouse.move(x - 20, y, { steps: 3 }); await settle();
  } else if (terminal === 'cancel') {
    // Chromium does not offer a physical mouse-cancel API. This one branch is an explicit synthetic event boundary.
    const cancelled = await track(kind).evaluate(el => {
      for (let id = 1; id <= 32; id++) if (el.hasPointerCapture(id)) { el.dispatchEvent(new PointerEvent('pointercancel', { pointerId: id, pointerType: 'mouse', isPrimary: true, buttons: 1, bubbles: true })); return true; }
      return false;
    });
    check(label + ': synthetic pointercancel reaches active actual component', cancelled);
    report.boundaries.push({ name: label, status: 'synthetic-event-boundary', reason: 'Actual mouse down/move; pointercancel dispatched to mounted production component because CDP offers no physical mouse cancel' }); save();
    await settle();
    check(label + ': pointercancel clears dragging state', !await rail(kind).evaluate(el => el.classList.contains('dragging')));
  } else {
    await page.mouse.move(x - Math.min(65, x - 4), y, { steps: 5 });
  }
  await page.mouse.up(); await settle();
  check(label + ': button-origin mouse gesture actually scrolled rail', (await metrics(kind)).scrollLeft > initial.scrollLeft + 5);
  check(label + ': release does not execute command, reply or any write', JSON.stringify(before) === JSON.stringify(await uiSnapshot()));
}
async function safeClickAfterDrag(label, keyboard = false) {
  const before = report.blockedWrites.length;
  const button = rail('shortcuts').getByRole('button', { name: '修改设置', exact: true });
  if (keyboard) { await button.focus(); await page.keyboard.press('Enter'); }
  else await button.click();
  await assistant().getByText('请先从赛事管理选择一场赛事，再在这里修改设置。', { exact: true }).waitFor();
  check(label + (keyboard ? ': keyboard activation passes pointer-click suppression' : ': fresh normal click is not swallowed after drag/cancel'), await assistant().getByText('请帮我读取当前赛事设置，展示可修改内容，由我核对后保存。', { exact: true }).count() === 1 && report.blockedWrites.length === before);
  await restoreCandidate();
}
async function openAndCloseForm(label, file) {
  const actions = assistant().locator('.b-ai-draft-actions[data-task-id="' + taskId + '"]');
  await actions.getByRole('button', { name: '查看表单', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: '核对办赛草稿', exact: true });
  await dialog.waitFor();
  check(label + ': existing candidate opens populated form', (await dialog.getByLabel('赛事名称', { exact: true }).inputValue()).trim().length > 0);
  check(label + ': form fits viewport horizontally', await dialog.evaluate(el => { const r = el.getBoundingClientRect(); return r.left >= -1 && r.right <= innerWidth + 1 && el.scrollWidth <= el.clientWidth + 1; }));
  await shot(file);
  await dialog.getByRole('button', { name: '关闭', exact: true }).click();
  await dialog.waitFor({ state: 'hidden' });
  await track('shortcuts').waitFor(); await track('suggestions').waitFor();
}

save();
try {
  report.storedBefore = readStoredFacts(); save();
  check('Original candidate and materials exist before UI operations', report.storedBefore.status === 'PENDING_CONFIRMATION' && report.storedBefore.filesCount > 0);
  browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
  session = await browser.newContext({ viewport: { width: 1440, height: 1000 }, reducedMotion: 'reduce', hasTouch: true });
  page = await session.newPage(); page.setDefaultTimeout(45000);
  page.on('pageerror', () => { report.errors.push('Browser script error; raw message omitted to protect private material'); save(); });
  await session.route('**/*', route => {
    const request = route.request(), url = new URL(request.url()), method = request.method();
    if (['GET', 'HEAD', 'OPTIONS'].includes(method)) return route.continue();
    if (method === 'POST' && url.origin === new URL(context.frontend).origin && ['/dev-api/auth/login', '/dev-api/auth/organization/enter'].includes(url.pathname)) {
      report.authenticationWrites.push({ method, path: url.pathname }); save(); return route.continue();
    }
    report.blockedWrites.push({ method, path: url.pathname }); save(); return route.abort('blockedbyclient');
  });
  await page.goto(context.frontend + '/portal/login?returnTo=/portal/organization', { waitUntil: 'domcontentloaded' });
  await page.getByPlaceholder('请输入手机号', { exact: true }).fill(state.people[0].phone);
  await page.getByPlaceholder('请输入密码', { exact: true }).fill(state.password);
  await page.getByRole('button', { name: '登录', exact: true }).click();
  await page.waitForURL(url => url.pathname === '/portal/organization');
  await page.getByRole('button', { name: '进入办赛工作台', exact: true }).first().click();
  await page.waitForURL(url => url.pathname.startsWith('/org-desk/'));
  const identity = await fetchIdentityAndCandidate();
  check('Fresh ordinary organizer owns original pending candidate in exact organization', /^\d+$/.test(identity.userId) && identity.organizationId === String(context.organizationId) && String(identity.task?.id) === taskId && identity.task.status === 'PENDING_CONFIRMATION');
  viewBefore = candidateView(identity.task);
  await page.evaluate(({ userId, organizationId, taskId }) => sessionStorage.setItem('business-ai-task:' + userId + ':' + organizationId, taskId), { userId: identity.userId, organizationId: identity.organizationId, taskId });
  await restoreCandidate();
  cdp = await session.newCDPSession(page);
  await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
  report.actualSuggestions = { count: viewBefore.proposal.suggestions?.length || 0, lengths: (viewBefore.proposal.suggestions || []).map(value => value.length) }; save();

  // Boundary widths are intentional: 700px is fullscreen and 701px is the small desktop window.
  for (const width of [320, 390, 700, 701, 1440]) {
    await page.setViewportSize({ width, height: width <= 700 ? 844 : 1000 }); await settle();
    await verifyLayout(width + 'px');
    await shot('rail-' + width + '.png');
    if (width <= 390) {
      await verifyKeyboard('shortcuts', width + 'px shortcuts keyboard');
      await verifyKeyboard('suggestions', width + 'px suggestions keyboard');
      await nativeSwipe('shortcuts', width + 'px shortcuts touch');
      await nativeSwipe('suggestions', width + 'px suggestions touch');
      await shot('rail-touch-' + width + '.png');
    }
  }
  await assistant().getByRole('button', { name: '放大聊天窗口', exact: true }).click();
  await verifyLayout('1440px expanded'); await shot('rail-expanded-desktop.png');
  await assistant().getByRole('button', { name: '还原聊天窗口', exact: true }).click(); await settle();

  await page.setViewportSize({ width: 320, height: 844 }); await settle();
  await mouseDrag('shortcuts', '320px shortcuts normal mouse drag');
  await safeClickAfterDrag('Normal mouse drag');
  await mouseDrag('suggestions', '320px suggestions normal mouse drag');
  await mouseDrag('shortcuts', '320px shortcuts lost capture', 'lost-capture');
  await safeClickAfterDrag('Lost capture');
  await mouseDrag('shortcuts', '320px shortcuts pointercancel', 'cancel');
  await safeClickAfterDrag('Pointercancel');
  await mouseDrag('shortcuts', '320px shortcuts before keyboard activation');
  await safeClickAfterDrag('Post-drag keyboard', true);

  await home('shortcuts'); await page.keyboard.press('End'); await settle();
  const narrow = await metrics('shortcuts');
  check('Narrow rail shows leading cue at End', narrow.before && !narrow.after);
  await page.setViewportSize({ width: 1440, height: 1000 }); await settle();
  const wide = await metrics('shortcuts'), wideOverflow = wide.scrollWidth > wide.clientWidth + 1;
  check('ResizeObserver refreshes edge cues after widening', wide.before === (wide.scrollLeft > 1) && wide.after === (wide.scrollWidth - wide.clientWidth - wide.scrollLeft > 1) && (wideOverflow || !wide.before && !wide.after), { narrow: { width: narrow.clientWidth, scroll: narrow.scrollLeft }, wide: { width: wide.clientWidth, scroll: wide.scrollLeft, before: wide.before, after: wide.after } });
  await page.setViewportSize({ width: 390, height: 844 }); await settle();
  await home('shortcuts');
  const resized = await metrics('shortcuts');
  check('Shrinking restores trailing overflow cue', resized.after === (resized.scrollWidth > resized.clientWidth + 1) && !resized.before);

  const suggestions = await metrics('suggestions');
  const actualLong = suggestions.buttons.some(button => button.width > suggestions.clientWidth);
  if (actualLong) {
    await home('suggestions'); await page.keyboard.press('End'); await settle();
    const ending = await metrics('suggestions');
    check('Actual long suggestion preserves full label and scrolls to its end', suggestions.buttons.every(button => button.whiteSpace === 'nowrap' && button.textOverflow !== 'ellipsis' && button.scrollWidth <= button.clientWidth + 1) && ending.buttons.at(-1).right <= ending.right + 1);
    report.boundaries.push({ name: 'Long suggestions', status: 'actual-candidate-covered', reason: 'At least one real candidate suggestion is wider than the rail' });
  } else {
    report.boundaries.push({ name: 'Long suggestions', status: 'unverified-long-content', reason: 'The unchanged real candidate has no single suggestion wider than its rail; only actual suggestion overflow was tested. No synthetic model/business data was substituted.' });
  }
  save();
  await openAndCloseForm('390px', 'form-mobile-390.png');
  const actions = assistant().locator('.b-ai-draft-actions[data-task-id="' + taskId + '"]');
  await actions.getByRole('button', { name: '删除草稿', exact: true }).click();
  const confirmation = page.getByRole('dialog', { name: '删除办赛草稿', exact: true });
  await confirmation.waitFor();
  check('Delete exposes explicit confirmation only', await confirmation.getByRole('button', { name: '删除草稿', exact: true }).isVisible());
  await shot('delete-cancel-mobile.png');
  await confirmation.getByRole('button', { name: '留下', exact: true }).click();
  await confirmation.waitFor({ state: 'hidden' });
  check('Cancelling deletion retains original candidate action card', await actions.count() === 1 && await actions.getAttribute('data-task-id') === taskId && !report.blockedWrites.length);
  await actions.scrollIntoViewIfNeeded();
  check('Mobile draft buttons have compact natural width', await actions.locator('.b-ai-draft-action-buttons button').evaluateAll(buttons => buttons.every(button => { const r = button.getBoundingClientRect(); return r.width <= 120 && r.height >= 35.5 && r.height <= 39; })));
  await shot('rail-final-mobile.png');
  await page.setViewportSize({ width: 1440, height: 1000 }); await settle();
  await openAndCloseForm('Desktop small window', 'form-desktop.png');
  await shot('rail-final-desktop.png');

  const afterIdentity = await fetchIdentityAndCandidate();
  report.viewDifferencePaths = differences(viewBefore, candidateView(afterIdentity.task));
  report.dynamicViewExplanation = 'GET task view recomputes readiness.checkedAt. Candidate/file storage must remain identical; no other DTO field may differ.';
  check('Candidate DTO changed only in permitted per-read readiness clock', report.viewDifferencePaths.every(key => key === 'proposal.readiness.checkedAt'));
  report.storedAfter = readStoredFacts();
  check('Every stored candidate and material column, status, version and linked-event count is unchanged', JSON.stringify(report.storedBefore) === JSON.stringify(report.storedAfter));
  report.sourceAfter = sourceHashes();
  check('All tested assistant source fingerprints stayed frozen', JSON.stringify(report.sourceBefore) === JSON.stringify(report.sourceAfter));
  check('Only login and organization entry POSTs occurred; zero model/business write attempts', report.authenticationWrites.length === 2 && !report.blockedWrites.length);
  check('No browser script errors', !report.errors.length);
  report.passed = true;
} catch (error) {
  report.failure = sanitize(error); process.exitCode = 1;
  if (page && !page.isClosed()) { try { await shot('failure.png'); } catch { report.errors.push('Failure screenshot unavailable'); } }
} finally {
  // Still collect storage/source evidence after a failed UI check. Never retry a business action.
  if (!report.storedAfter && report.storedBefore) {
    try { report.storedAfter = readStoredFacts(); report.storedUnchangedAfterFailure = JSON.stringify(report.storedBefore) === JSON.stringify(report.storedAfter); }
    catch { report.errors.push('Final read-only stored-facts query unavailable'); }
  }
  if (!report.sourceAfter) { try { report.sourceAfter = sourceHashes(); } catch { report.errors.push('Final source fingerprint unavailable'); } }
  if (browser) await browser.close();
  report.finishedAt = new Date().toISOString(); save();
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failure: report.failure, boundaries: report.boundaries, evidence: out, receiptSha256: sha256(fs.readFileSync(path.join(out, 'receipt.json'))) }));
}
