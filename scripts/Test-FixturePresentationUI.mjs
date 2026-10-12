// Actual ordinary-role browsers against owned synthetic records. No scores, awards or funds are written.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { context, api, key } from './lib/BusinessRegression.mjs';

const requestedRun = process.env.AISPORTS_AWARD_RUN;
assert.ok(requestedRun, 'Explicit owned award run is required');
const run = fs.realpathSync(requestedRun);
const allowedRoot = fs.realpathSync('.local/honor-repair-20261012');
assert.ok(run.startsWith(allowedRoot + path.sep), 'Only the existing isolated synthetic award fixture');
const state = JSON.parse(fs.readFileSync(path.join(run, 'state.private.json'), 'utf8'));
assert.match(state.label, /模拟/);
assert.match(String(state.event.id), /^\d+$/);
const out = path.join(run, 'fixture-presentation-' + crypto.randomUUID());
fs.mkdirSync(out);
const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8').replace(/^\uFEFF/, ''));
const sources = ['plus-ui/src/components/sports/MatchScoreCard.vue', 'plus-ui/src/components/sports/HonorReviewDialog.vue', 'plus-ui/src/views/sports/workspace/ClosureAndFixtures.vue', 'plus-ui/src/assets/styles/match-experience.scss', 'plus-ui/src/assets/styles/honor-experience.scss', 'plus-ui/src/views/portal/results.vue', 'plus-ui/src/components/consumer/EventDetailContent.vue'];
const fingerprint = () => Object.fromEntries(sources.map(file => [file, crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')]));
const receipt = { at: new Date().toISOString(), passed: false, scope: 'Actual desktop/mobile organizer and participant UI. Existing synthetic honors/results read-only; one new owned future event and unscored fixture only, no external services or awards/result/funds writes', jarSha256: runtime.jarSHA256, database: context.database, sources: fingerprint(), checks: [], screenshots: [], unverified: [] };
const save = () => fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(receipt, null, 2));
const check = (name, passed, details = {}) => { receipt.checks.push({ name, passed: !!passed, ...details }); save(); assert.ok(passed, name); console.log('PASS ' + name); };
const session = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json', 'utf8').replace(/^\uFEFF/, ''));
const loginActor = async (phone, password) => ({ token: (await api(null, '/auth/login', 'POST', { username: phone, password, grantType: 'platform', tenantId: '900001', clientId: context.clientId })).access_token });
const platform = await loginActor(session.people[0].phone, session.password);
const orgActor = { token: (await api(platform, '/auth/organization/enter', 'POST', {})).access_token };
const fixtures = await api(orgActor, `/sports/fixtures/events/${state.event.id}`);
const claims = await api(orgActor, `/sports/proof-review/events/${state.event.id}?includeVerified=true`);
const placing = claims.find(claim => claim.award_kind === 'placing' && claim.unit_name.includes('项目甲'));
assert.ok(placing && fixtures.length, 'Existing completed synthetic award trial is required');
const sameCode = fixtures.filter(fixture => fixture.code === '01');
check('fixture API distinguishes identical match numbers by project and returns frozen opponents', sameCode.length === 2 && new Set(sameCode.map(fixture => fixture.unit_id)).size === 2 && sameCode.every(fixture => fixture.unit_name && fixture.side_a && fixture.side_b));
check('award basis includes the correct project and both frozen opponents for every official result', placing.basis_results.length === 3 && placing.basis_results.every(result => result.unitName === placing.unit_name && result.sideA && result.sideB && result.status === 'confirmed'));

// This new, unscored future fixture has its own durable state. Successful mutations are never repeated.
const scheduleRun = process.env.AISPORTS_FIXTURE_SCHEDULE_RUN || path.join(run, 'presentation-schedule-state');
fs.mkdirSync(scheduleRun, { recursive: true });
const scheduleResolved = fs.realpathSync(scheduleRun);
assert.ok(scheduleResolved.startsWith(fs.realpathSync('.local') + path.sep), 'Schedule evidence remains protected local');
const scheduleFile = path.join(scheduleResolved, 'state.private.json');
const scheduleState = fs.existsSync(scheduleFile) ? JSON.parse(fs.readFileSync(scheduleFile, 'utf8')) : { scope: 'synthetic-fixture-schedule', database: context.database, keys: {}, steps: {} };
assert.equal(scheduleState.scope, 'synthetic-fixture-schedule'); assert.equal(scheduleState.database, context.database);
const saveSchedule = () => fs.writeFileSync(scheduleFile, JSON.stringify(scheduleState, null, 2));
const rememberSchedule = async (name, fn) => { if (scheduleState[name] === undefined) { scheduleState[name] = await fn(); saveSchedule(); } return scheduleState[name]; };
const scheduleKey = name => { scheduleState.keys[name] ||= key(); saveSchedule(); return scheduleState.keys[name]; };
const onceSchedule = async (name, fn) => { if (!scheduleState.steps[name]) { await fn(); scheduleState.steps[name] = true; saveSchedule(); } };
receipt.scheduleContext = path.relative(process.cwd(), scheduleResolved); save();
if (scheduleState.scheduleSaved) {
  const prior = fs.readdirSync(run).filter(name => name.startsWith('fixture-presentation-')).map(name => path.join(run, name, 'receipt.json')).filter(file => fs.existsSync(file)).map(file => ({ file, value: JSON.parse(fs.readFileSync(file, 'utf8')) })).find(item => item.value.checks.some(check => check.name === 'ordinary organizer saves the new cross-day arrangement through real UI confirmation' && check.passed));
  assert.ok(prior, 'Successful UI save has a preserved original observation');
  receipt.priorSuccessfulMutation = { receipt: path.relative(process.cwd(), prior.file), sha256: crypto.createHash('sha256').update(fs.readFileSync(prior.file)).digest('hex'), jarSha256: prior.value.jarSha256, fact: 'Original confirmed UI saved this exact future schedule. This run only reopens and reads it; the original overall receipt remains failed.' }; save();
}
async function prepareSchedule() {
  if (!scheduleState.label) {
    scheduleState.label = '场次时间回显演练 ' + key().slice(0, 8) + '（模拟）';
    const shanghai = new Date(Date.now() + 8 * 3600000);
    const tomorrow = new Date(Date.UTC(shanghai.getUTCFullYear(), shanghai.getUTCMonth(), shanghai.getUTCDate() + 1)).toISOString().slice(0, 10);
    const nextDay = new Date(Date.UTC(shanghai.getUTCFullYear(), shanghai.getUTCMonth(), shanghai.getUTCDate() + 2)).toISOString().slice(0, 10);
    scheduleState.startsAt = tomorrow + 'T23:00:00+08:00'; scheduleState.endsAt = nextDay + 'T01:00:00+08:00';
    scheduleState.scheduleStartsAt = tomorrow + ' 23:45:00'; scheduleState.scheduleEndsAt = nextDay + ' 00:15:00'; scheduleState.courtName = '模拟 1 号场';
    saveSchedule();
  }
  assert.ok(new Date(scheduleState.endsAt).getTime() > Date.now(), 'An expired synthetic run must not be silently replaced or its business gate bypassed');
  const event = await rememberSchedule('event', async () => {
    const recovered = (await api(orgActor, '/sports/b/events')).filter(event => event.name === scheduleState.label);
    assert.ok(recovered.length <= 1, 'No ambiguous event creation recovery');
    if (recovered.length) return recovered[0];
    return api(orgActor, '/sports/b/events', 'POST', { name: scheduleState.label, location: '隔离模拟球馆', projectName: '羽毛球', feeDescription: '免费模拟排期测试', registrationOpensAt: new Date(Date.now() - 3600000).toISOString(), registrationClosesAt: new Date(new Date(scheduleState.startsAt).getTime() - 3600000).toISOString(), startsAt: scheduleState.startsAt, endsAt: scheduleState.endsAt, registrationReview: 'manual', rulesText: '仅本地测试场次安排，不进行真实比赛，不录分。', noticeText: '模拟演练，无真实付款。', declarationText: '' });
  });
  scheduleState.eventId = event.id; saveSchedule();
  const unit = await rememberSchedule('unit', () => api(orgActor, '/sports/b/registrations/units', 'POST', { eventId: event.id, name: '跨日单打排期（模拟）', entryType: 'individual', minMembers: 1, maxMembers: 1, limitCount: 8, charged: false, amount: 0, paymentMode: 'free', requestKey: scheduleKey('unit') }));
  await onceSchedule('published', async () => { if ((await api(orgActor, '/sports/b/events')).find(value => value.id === event.id)?.publicationStatus !== 'published') await api(orgActor, `/sports/b/events/${event.id}/publish`, 'POST', { requestKey: scheduleKey('publish'), contactConfirmed: true, contactName: '模拟排期负责人', contactMethod: '仅本地演练，不实际联系' }); });
  const actors = await Promise.all(context.people.slice(0, 2).map(person => loginActor(person.phone, context.password)));
  const entry = async (actor, id) => (await api(actor, '/sports/c/registrations')).find(value => value.id === id);
  for (const [index, actor] of actors.entries()) {
    const registration = await rememberSchedule('registration-' + index, () => api(actor, '/sports/c/registrations', 'POST', { unitId: unit.id, requestKey: scheduleKey('registration-' + index) }));
    await onceSchedule('submitted-' + index, async () => { const actual = await entry(actor, registration.id); assert.ok(actual, 'Own draft remains readable'); if (actual.status === 'draft') await api(actor, `/sports/c/registrations/${registration.id}/submit`, 'POST', { requestKey: registration.requestKey }); });
    await onceSchedule('approved-' + index, async () => { const actual = await entry(actor, registration.id); if (actual.status !== 'approved') await api(orgActor, `/sports/b/registrations/${registration.id}/approve`, 'POST'); });
  }
  const match = await rememberSchedule('match', () => api(orgActor, `/sports/b/competition/units/${unit.id}/matches`, 'POST', { code: 'TIME-01', registrationA: scheduleState['registration-0'].id, registrationB: scheduleState['registration-1'].id, requestKey: scheduleKey('match') }));
  scheduleState.matchId = match.matchId; saveSchedule();
  const fixture = (await api(orgActor, `/sports/fixtures/events/${event.id}`)).find(value => value.id === match.matchId);
  assert.ok(fixture && fixture.holding_status === 'normal' && !['completed', 'confirmed', 'cancelled'].includes(fixture.status), 'Future synthetic fixture is editable');
  assert.equal(fixture.result_revision, null, 'Schedule fixture stays unscored');
  scheduleState.fixture = fixture;
  if (fixture.scheduled_start && fixture.scheduled_end) {
    assert.equal(pickerTime(fixture.scheduled_start), scheduleState.scheduleStartsAt, 'Recover only the exact successful saved arrangement');
    assert.equal(pickerTime(fixture.scheduled_end), scheduleState.scheduleEndsAt, 'Recover only the exact saved end');
    assert.equal(fixture.court_name, scheduleState.courtName);
    scheduleState.scheduleSaved = true; saveSchedule();
  }
  check('future schedule fixture has two approved individual entries and no official score', (await entry(actors[0], scheduleState['registration-0'].id)).status === 'approved' && (await entry(actors[1], scheduleState['registration-1'].id)).status === 'approved' && !fixture.result_revision);
}

const { chromium } = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
let activePage;
async function login(phone, password, viewport) { const ctx = await browser.newContext({ viewport }); const page = await ctx.newPage(); await page.goto(context.frontend + '/portal/login'); await page.getByPlaceholder('请输入手机号').fill(phone); await page.getByPlaceholder('请输入密码').fill(password); await page.getByRole('button', { name: '登录', exact: true }).click(); await page.waitForURL(url => !url.pathname.includes('/login')); return { ctx, page }; }
async function stable(page) { await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))); await page.waitForFunction(() => document.getAnimations().every(animation => animation.effect?.getTiming().iterations === Infinity || animation.playState !== 'running')); await page.locator('.el-message').waitFor({ state: 'hidden' }); }
async function capture(page, name) { await stable(page); const target = path.join(out, name + '.png'); await page.screenshot({ path: target }); receipt.screenshots.push(target); save(); }
const pickerTime = value => {
  const input = /[Zz]|[+-]\d{2}:\d{2}$/.test(value) ? value : value.replace(' ', 'T') + '+08:00';
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' }).formatToParts(new Date(input));
  const get = name => parts.find(part => part.type === name).value;
  return `${get('year')}-${get('month')}-${get('day')} ${get('hour')}:${get('minute')}:${get('second')}`;
};
try {
  await prepareSchedule();
  for (const [device, viewport] of [['desktop', { width: 1440, height: 1000 }], ['mobile', { width: 390, height: 844 }]]) {
    const organizer = await login(session.people[0].phone, session.password, viewport); activePage = organizer.page;
    await activePage.goto(context.frontend + '/portal/organization?tab=status'); await activePage.getByRole('button', { name: '进入办赛工作台' }).click(); await activePage.waitForURL(url => url.pathname.startsWith('/org-desk'));
    await activePage.goto(`${context.frontend}/org-desk/workspace/${state.event.id}?task=closure`);
    await activePage.locator('.fixture-card').first().waitFor(); await stable(activePage);
    check(device + ' cards show the same match code in its own named project', await activePage.locator('.fixture-card').count() === fixtures.length && await activePage.locator('.fixture-card h4').filter({ hasText: '场次 01' }).count() === 2);
    check(device + ' original court illustration is decoded without replacing score data', await activePage.locator('.fixture-heading-art').evaluate(image => image.complete && image.naturalWidth > 0));
    await activePage.locator('.fixture-filters .el-select').click(); await activePage.getByRole('option', { name: placing.unit_name, exact: true }).click();
    const projectRows = fixtures.filter(fixture => fixture.unit_name === placing.unit_name);
    check(device + ' project filter hides the other project with the same match number', await activePage.locator('.fixture-card').count() === projectRows.length && await activePage.locator('.fixture-card').evaluateAll(cards => cards.every(card => card.innerText.includes('单打项目甲（模拟）'))));
    await activePage.locator('.fixture-card').first().scrollIntoViewIfNeeded(); await capture(activePage, 'fixture-project-' + device);
    await activePage.locator('.el-switch').click();
    const award = activePage.locator('.honor-review-cards article').filter({ hasText: placing.unit_name }).filter({ hasText: '项目名次' });
    await award.getByRole('button', { name: '核实奖项与证明', exact: true }).click();
    const dialog = activePage.getByRole('dialog', { name: '核实奖项与证明', exact: true }); await dialog.waitFor(); await stable(activePage);
    check(device + ' review uses all real official scorecards with opponents and per-game labels', await dialog.locator('.honor-basis-list .match-score-card').count() === placing.basis_results.length && (await dialog.innerText()).includes(placing.basis_results[0].sideA) && await dialog.getByText('第 1 局', { exact: true }).count() === placing.basis_results.length);
    const geometry = await activePage.locator('.honor-review-dialog').evaluate(element => { const bounds = element.getBoundingClientRect(), footer = element.querySelector('.el-dialog__footer').getBoundingClientRect(), body = element.querySelector('.el-dialog__body'); return { x: bounds.x, y: bounds.y, right: bounds.right, bottom: bounds.bottom, width: bounds.width, height: bounds.height, footerBottom: footer.bottom, footerTop: footer.top, bodyBottom: body.getBoundingClientRect().bottom, overflow: getComputedStyle(body).overflowY, pageWidth: document.documentElement.scrollWidth }; });
    receipt[device + 'ReviewGeometry'] = geometry;
    check(device + ' review dialog and footer stay inside viewport with a separate scrollable body', geometry.x >= 0 && geometry.y >= 0 && geometry.right <= viewport.width + 1 && geometry.bottom <= viewport.height + 1 && geometry.footerBottom <= viewport.height + 1 && geometry.bodyBottom <= geometry.footerTop + 1 && geometry.overflow === 'auto' && geometry.pageWidth <= viewport.width + 1);
    await dialog.locator('.el-dialog__body').evaluate(body => { body.scrollTop = body.scrollHeight; });
    check(device + ' award handling remains reachable after scrolling all results', await dialog.getByRole('button', { name: '确认并签发', exact: true }).isVisible() && await dialog.getByPlaceholder('例如：已核对全部正式赛果，确认该报名获得第二名。').isVisible());
    await capture(activePage, 'award-review-' + device); await dialog.getByRole('button', { name: '暂不办理', exact: true }).click();
    if (scheduleState) {
      await activePage.goto(`${context.frontend}/org-desk/workspace/${scheduleState.eventId}?task=closure`);
      const card = activePage.locator(`.fixture-card[data-match-id="${scheduleState.matchId}"]`); await card.waitFor();
      if (!scheduleState.scheduleSaved) {
        assert.equal(device, 'desktop', 'One desktop save supplies both read-only echo checks');
        await card.getByRole('button', { name: '安排时间', exact: true }).click();
        const editor = activePage.getByRole('dialog', { name: '安排场次时间', exact: true }); await editor.waitFor();
        await editor.getByPlaceholder('选择开始时间').fill(scheduleState.scheduleStartsAt); await editor.getByPlaceholder('选择开始时间').press('Tab');
        await editor.getByPlaceholder('选择结束时间').fill(scheduleState.scheduleEndsAt); await editor.getByPlaceholder('选择结束时间').press('Tab');
        await editor.getByPlaceholder('例如 1 号场').fill(scheduleState.courtName);
        const response = activePage.waitForResponse(response => response.url().endsWith('/match.schedule/execute') && response.request().method() === 'POST');
        await editor.getByRole('button', { name: '核对并保存安排', exact: true }).click(); await activePage.locator('.el-message-box').getByRole('button', { name: '确认', exact: true }).click();
        const result = await (await response).json(); check('ordinary organizer saves the new cross-day arrangement through real UI confirmation', result.code === 200);
        scheduleState.scheduleSaved = true; saveSchedule(); await editor.waitFor({ state: 'hidden' });
        scheduleState.fixture = (await api(orgActor, `/sports/fixtures/events/${scheduleState.eventId}`)).find(value => value.id === scheduleState.matchId);
        saveSchedule();
      }
      await card.getByRole('button', { name: '调整时间', exact: true }).click();
      const schedule = activePage.getByRole('dialog', { name: '安排场次时间', exact: true }); await schedule.waitFor();
      const values = await schedule.locator('.el-date-editor input').evaluateAll(inputs => inputs.map(input => input.value));
      check(device + ' saved start and end echo the exact Beijing date without losing the timezone', values[0] === pickerTime(scheduleState.fixture.scheduled_start) && values[1] === pickerTime(scheduleState.fixture.scheduled_end) && (await schedule.innerText()).includes(scheduleState.fixture.unit_name));
      await capture(activePage, 'schedule-echo-' + device); await schedule.getByRole('button', { name: '取消', exact: true }).click();
    }
    await organizer.ctx.close();
    const participant = await login(context.people[0].phone, context.password, viewport); activePage = participant.page;
    await activePage.goto(context.frontend + '/portal/results'); const result = activePage.locator('.result-card').filter({ hasText: state.label }); await result.first().waitFor();
    check(device + ' participant formal results show live teams and per-game scores', await result.locator('.match-score-card').count() > 0 && await result.first().getByText('第 1 局', { exact: true }).count() === 1 && (await result.first().innerText()).includes('总比分'));
    check(device + ' participant result cards have no page width overflow', await activePage.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
    await result.first().scrollIntoViewIfNeeded(); await capture(activePage, 'participant-scores-' + device);
    await activePage.goto(`${context.frontend}/public/events/${state.event.id}`); await activePage.locator('.detail-plan').waitFor();
    check(device + ' participation arrangement scrolls in normal page flow', await activePage.locator('.detail-plan').evaluate(element => getComputedStyle(element).position === 'static'));
    await participant.ctx.close();
  }
  assert.deepEqual(fingerprint(), receipt.sources, 'Presentation source did not change while observing');
  receipt.visualChecksPassed = true; receipt.passed = receipt.unverified.length === 0; receipt.finishedAt = new Date().toISOString(); save(); console.log('Evidence: ' + out);
  if (!receipt.passed) process.exitCode = 2;
} catch (cause) { receipt.failure = cause.message; save(); await activePage?.screenshot({ path: path.join(out, 'failure.png') }).catch(() => {}); throw cause; } finally { await browser.close(); }
