// Actual isolated services, ordinary government/organizer and independent objects.
// No account password, token, attachment bytes or response payload enters receipts.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const argument = name => process.argv[process.argv.indexOf(name) + 1];
assert.ok(process.argv.includes('--context'), 'A protected batch context is required');
const contextPath = path.resolve(argument('--context'));
const local = path.resolve('.local/business-regression-20261011');
assert.ok(contextPath.startsWith(local + path.sep), 'Context stays within this batch workspace');
const context = JSON.parse(fs.readFileSync(contextPath, 'utf8'));
assert.equal(context.backend, 'http://127.0.0.1:8082');
assert.equal(context.frontend, 'http://127.0.0.1:5192');
assert.match(context.database, /^aisports_verify_phase1_[a-f0-9]{32}$/);
assert.match(context.prefix, /^回归-[a-f0-9]{8}$/);
process.env.AISPORTS_REGRESSION_CONTEXT = contextPath;
const { readSql } = await import('./lib/BusinessRegression.mjs');
const rootOut = path.dirname(contextPath);
const owned = path.join(rootOut, 'governance');
fs.mkdirSync(owned, { recursive: true });
const runId = crypto.randomUUID();
const runOut = path.join(owned, runId);
fs.mkdirSync(runOut);
const checkpoint = path.join(owned, 'checkpoint.private.json');
const state = fs.existsSync(checkpoint) ? JSON.parse(fs.readFileSync(checkpoint, 'utf8')) : { batch: context.runId, operations: {}, completedStages: {}, createdEvents: {} };
assert.equal(state.batch, context.runId);
const report = {
  at: new Date().toISOString(), runId, batch: context.runId,
  scope: 'Ordinary government admission, explicit organization grants, lifecycle, complaints and persistent notifications on 8082. Independent synthetic organization/events, no shared-organization suspension, no login, model, real bank/SMS or direct database mutation.',
  passed: false, checks: [], failures: [], findings: [], previousStages: state.completedStages,
  setupBoundary: 'Administrator only assigns admission reviewer and explicit organization grants. Ordinary government reviews/coordinates; the approved applicant owns the organizer session.',
  roleEvidence: [], sourceFiles: [], changedObjects: {}, externalConditions: ['Actual business SMS is not connected', 'Synthetic organizers/materials/events do not prove real admission or on-site competition'],
};
let definitions;
const applicant = context.people[4];
const outsider = context.people[3];
const government = context.government;
const admin = context.admin;
function save() { const temporary = checkpoint + '.tmp-' + runId; fs.writeFileSync(temporary, JSON.stringify(state, null, 2) + '\n'); fs.renameSync(temporary, checkpoint); }
function check(id, title, ok, observed = {}) {
  report.checks.push({ id, title, passed: Boolean(ok), observed });
  if (!ok) report.findings.push({ id, title, observed });
  console.log((ok ? 'PASS ' : 'FAIL ') + id + ' ' + title);
  return Boolean(ok);
}
async function request(actor, route, method = 'GET', body) {
  assert.ok(route.startsWith('/') && !route.includes('://'));
  const response = await fetch(context.backend + route, {
    method, headers: { clientid: actor?.clientId || context.clientId, 'Content-Type': 'application/json', ...(actor?.token ? { Authorization: 'Bearer ' + actor.token } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  let data; try { data = await response.json(); } catch { data = { code: response.status }; }
  return { http: response.status, ...data };
}
async function api(actor, route, method = 'GET', body) {
  const data = await request(actor, route, method, body);
  if (data.code !== 200) throw new Error('Required actual request rejected: ' + route + ' code=' + data.code);
  return data.data;
}
async function execute(actor, code, input, key = crypto.randomUUID()) {
  const definition = definitions.find(item => item.definition.code === code)?.definition;
  assert.ok(definition, 'Registered action exists: ' + code);
  let confirmationId;
  if (definition.confirmation) { await api(actor, '/sports/platform/actions/' + code + '/preview', 'POST', input); confirmationId = await api(actor, '/sports/platform/actions/' + code + '/confirm', 'POST', input); }
  return api(actor, '/sports/platform/actions/' + code + '/execute', 'POST', { input, requestKey: key, confirmationId });
}
async function action(slot, actor, code, input) {
  const old = state.operations[slot];
  if (old?.completed) return old.receipt.result || old.receipt;
  const operation = old || { code, input, key: crypto.randomUUID(), originatingRun: runId };
  if (!old) { state.operations[slot] = operation; save(); }
  const definition = definitions.find(item => item.definition.code === code)?.definition;
  assert.ok(definition, 'Registered action exists: ' + code);
  if (definition.confirmation && !operation.confirmationId) {
    await api(actor, '/sports/platform/actions/' + code + '/preview', 'POST', operation.input);
    operation.confirmationId = await api(actor, '/sports/platform/actions/' + code + '/confirm', 'POST', operation.input); save();
  }
  operation.receipt = await api(actor, '/sports/platform/actions/' + code + '/execute', 'POST', { input: operation.input, requestKey: operation.key, confirmationId: operation.confirmationId });
  operation.completed = true; save();
  return operation.receipt.result || operation.receipt;
}
async function denied(id, title, actor, route, method = 'GET', body) {
  const response = await request(actor, route, method, body);
  return check(id, title, response.code !== 200, { http: response.http, code: response.code });
}
async function deniedAction(id, title, actor, code, input) {
  let response = await request(actor, '/sports/platform/actions/' + code + '/preview', 'POST', input);
  if (response.code === 200) {
    let confirmationId;
    if (definitions.find(item => item.definition.code === code)?.definition.confirmation) {
      response = await request(actor, '/sports/platform/actions/' + code + '/confirm', 'POST', input); confirmationId = response.data;
    }
    if (response.code === 200) response = await request(actor, '/sports/platform/actions/' + code + '/execute', 'POST', { input, requestKey: crypto.randomUUID(), confirmationId });
  }
  return check(id, title, response.code !== 200, { http: response.http, code: response.code });
}
async function mine() { return api(applicant, '/sports/platform/actions/organization.mine/preview', 'POST', {}); }
async function upload(actor, suffix, bytes = Buffer.from('Synthetic admission evidence; no external identity or qualification claim.')) {
  const form = new FormData(); form.set('file', new Blob([bytes], { type: 'text/plain' }), context.prefix + '-' + suffix + '.txt');
  const response = await fetch(context.backend + '/sports/c/organization/files', { method: 'POST', headers: { Authorization: 'Bearer ' + actor.token, clientid: actor.clientId || context.clientId }, body: form });
  const body = await response.json(); if (body.code !== 200) throw new Error('Synthetic application file upload rejected'); return body.data;
}
async function binary(actor, route) {
  const response = await fetch(context.backend + route, { headers: { clientid: actor?.clientId || context.clientId, ...(actor?.token ? { Authorization: 'Bearer ' + actor.token } : {}) } });
  const bytes = Buffer.from(await response.arrayBuffer()); const jsonType = response.headers.get('content-type')?.includes('json');
  let code = response.status; if (jsonType) { try { code = JSON.parse(bytes.toString()).code; } catch {} }
  return { http: response.status, code, binary: !jsonType && response.status === 200, bytes: bytes.length };
}
function draft(name, shifts = {}) {
  const date = hour => new Date(Date.now() + hour * 3600000).toISOString();
  return { name: context.prefix + '-' + name, location: '合成回归球馆，不用于实际参赛', projectName: '羽毛球', feeDescription: '免费，隔离回归不产生实际付款', registrationOpensAt: date(-1), registrationClosesAt: date(24), startsAt: date(48), endsAt: date(52), registrationReview: 'manual', rulesText: '本机合成赛制与人工对阵', noticeText: '仅隔离服务测试，不用于正式办赛', declarationText: '合成资料，不产生实际参赛责任', declarationAckRequired: true, ...shifts };
}
async function eventVersion(eventId) { return Number((await api(state.organizer, '/sports/platform/actions/event.mine/preview', 'POST', { eventId })).version); }
async function createEvent(slot, name, data = draft(name)) {
  if (state.createdEvents[slot]) return state.createdEvents[slot];
  const existing = (await api(state.organizer, '/sports/b/events')).find(event => event.name === context.prefix + '-' + name);
  const eventId = existing?.id || (await action('create-' + slot, state.organizer, 'event.create', { draftJson: JSON.stringify(data) })).eventId;
  state.createdEvents[slot] = eventId; save(); return eventId;
}
async function publishEvent(slot, eventId) { return action(slot, state.organizer, 'event.publish', { eventId, expectedVersion: await eventVersion(eventId), contactName: '隔离回归负责人', contactMethod: '仅本机测试，无真实联系方式' }); }
async function organizationRow() { return (await api(government, '/sports/government')).find(row => String(row.id) === state.organizationId); }
const version = (table, id) => { assert.match(table, /^asp_[a-z_]+$/); assert.match(String(id), /^\d+$/); return Number(readSql(`SELECT version FROM ${table} WHERE id=${id};`)); };
async function ownUnit(slot, eventId) {
  state.units ||= {};
  if (!state.units[slot]) {
    const types = await api(null, '/sports/types'); const single = types.types.find(row => row.entry_type === 'individual' && row.capability_status === 'manual');
    assert.ok(single, 'Enabled single competition type exists');
    state.units[slot] = (await action('unit-' + slot, state.organizer, 'unit.create', { eventId, competitionTypeId: single.id, name: context.prefix + '-单打', limitCount: '4', charged: false })).unitId; save();
  }
  return state.units[slot];
}
async function simpleWrite(slot, actor, route, body) {
  if (state.operations[slot]?.completed) return state.operations[slot].result;
  const result = await api(actor, route, 'POST', body);
  state.operations[slot] = { completed: true, originatingRun: runId, result }; save(); return result;
}
async function stage(name, run) {
  if (state.completedStages[name]) { report.roleEvidence.push({ stage: name, status: 'previously-observed', receipt: state.completedStages[name].receipt, noMutationReplay: true }); return; }
  await run(); state.completedStages[name] = { at: new Date().toISOString(), receipt: path.relative(process.cwd(), path.join(runOut, 'receipt.json')).replaceAll('\\', '/') }; save();
}

try {
  definitions = (await api(admin, '/sports/platform/management')).definitions;
  check('PRE01', 'Actual management definitions read without changing release flags', Array.isArray(definitions));
  check('PRE02', 'Government uses a distinct ordinary system identity', Boolean(government.id) && government.id !== '1');
  await stage('admission', async () => {
    const current = await mine();
    assert.ok(!current.application?.applicationId || String(current.application.applicationId) === state.applicationId, 'Applicant must have no unrelated existing application');
    const incomplete = { name: context.prefix + '-政府轮', contactName: '', contactMethod: '', statement: '合成入驻申请，仅隔离回归', fileIds: [] };
    const saved = await action('admission-incomplete-save', applicant, 'organization.save', { draftJson: JSON.stringify(incomplete), expectedVersion: current.version });
    state.applicationId = String(saved.applicationId); save();
    check('G01', 'Ordinary applicant saves an incomplete draft', (await mine()).application.status === 'draft');
    await deniedAction('G02', 'Incomplete admission submission is rejected', applicant, 'organization.submit', { draftJson: JSON.stringify(incomplete), expectedVersion: (await mine()).version });
    check('G02b', 'Failed submission leaves no pending version', (await mine()).application.versions.length === 0);
    if (!state.ownFile) { state.ownFile = (await upload(applicant, '本人合成材料')).fileId; save(); }
    if (!state.foreignFile) { state.foreignFile = (await upload(outsider, '他人合成材料')).fileId; save(); }
    check('G03', 'Applicant reads own actual stored attachment', (await binary(applicant, '/sports/c/organization/files/' + state.ownFile)).binary);
    check('G03b', 'Another account cannot read this attachment', !(await binary(outsider, '/sports/c/organization/files/' + state.ownFile)).binary);
    const complete = { ...incomplete, contactName: '合成申请人', contactMethod: '仅本机回归', fileIds: [state.ownFile] };
    state.admissionDraft = complete; save();
    await deniedAction('G04', 'Another account attachment cannot be bound to the application', applicant, 'organization.save', { draftJson: JSON.stringify({ ...complete, fileIds: [state.foreignFile] }), expectedVersion: (await mine()).version });
    const previous = (await mine()).version;
    await action('admission-complete-save', applicant, 'organization.save', { draftJson: JSON.stringify(complete), expectedVersion: previous });
    await deniedAction('G04b', 'Stale draft version is rejected', applicant, 'organization.save', { draftJson: JSON.stringify(complete), expectedVersion: previous });
    await action('admission-first-submit', applicant, 'organization.submit', { draftJson: JSON.stringify(complete), expectedVersion: (await mine()).version });
    check('G05', 'Complete applicant submission produces one pending history version', (await mine()).application.status === 'pending' && (await mine()).application.versions.length === 1);
    const first = state.operations['admission-first-submit'];
    const replay = await api(applicant, '/sports/platform/actions/organization.submit/execute', 'POST', { input: first.input, requestKey: first.key, confirmationId: first.confirmationId });
    check('G05b', 'Same admission request replays its original receipt without a second version', replay.replayed === true && (await mine()).application.versions.length === 1);
    await deniedAction('G06', 'Pending application cannot be edited', applicant, 'organization.save', { draftJson: JSON.stringify(complete), expectedVersion: (await mine()).version });
    await denied('G06b', 'An unassigned ordinary government cannot read the application', government, '/sports/organization-review/' + state.applicationId);
    check('G06c', 'Unassigned application does not leak into ordinary review queue', !(await api(government, '/sports/organization-review/pending')).some(row => String(row.applicationId) === state.applicationId));
    await denied('G07', 'Applicant cannot approve own admission', applicant, '/sports/organization-review/' + state.applicationId + '/approve', 'POST');
    await deniedAction('G07b', 'Ordinary government cannot assign its own reviewer scope', government, 'government.assignAdmission', { applicationId: state.applicationId, sysUserId: government.id, expectedVersion: (await mine()).version });
    await deniedAction('G07c', 'Platform cannot assign a non-system applicant as reviewer', admin, 'government.assignAdmission', { applicationId: state.applicationId, sysUserId: outsider.id, expectedVersion: (await mine()).version });
    await action('admission-assign-first', admin, 'government.assignAdmission', { applicationId: state.applicationId, sysUserId: government.id, expectedVersion: (await mine()).version });
    check('G08', 'Assigned ordinary government sees only its explicit application in the queue', (await api(government, '/sports/organization-review/pending')).some(row => String(row.applicationId) === state.applicationId));
    check('G08b', 'Assigned reviewer reads actual attached material', (await binary(government, '/sports/organization-review/' + state.applicationId + '/files/' + state.ownFile)).binary);
    check('G08c', 'Assigned reviewer cannot read another account unrelated attachment', !(await binary(government, '/sports/organization-review/' + state.applicationId + '/files/' + state.foreignFile)).binary);
    await denied('G09', 'Admission rejection requires a reason', government, '/sports/organization-review/' + state.applicationId + '/reject', 'POST', { reason: '' });
    await api(government, '/sports/organization-review/' + state.applicationId + '/reject', 'POST', { reason: '仅隔离回归：请补充合成联系核验说明' });
    const rejected = await mine();
    check('G09b', 'Ordinary government rejection preserves reason and submitted version', rejected.application.status === 'rejected' && rejected.application.versions[0].status === 'rejected' && Boolean(rejected.application.reviewReason));
    await denied('G09c', 'An already rejected application cannot be approved directly', government, '/sports/organization-review/' + state.applicationId + '/approve', 'POST');
    const corrected = { ...complete, statement: '已补充合成联系人说明，仍仅隔离测试，不作真实资质证明' };
    await action('admission-correct-save', applicant, 'organization.save', { draftJson: JSON.stringify(corrected), expectedVersion: rejected.version });
    await action('admission-resubmit', applicant, 'organization.submit', { draftJson: JSON.stringify(corrected), expectedVersion: (await mine()).version });
    check('G10', 'Corrected resubmission has two independent versions and retains old rejection', (await mine()).application.status === 'pending' && (await mine()).application.versions.length === 2 && (await mine()).application.versions[0].status === 'rejected');
    const outcomes = await Promise.all([request(government, '/sports/organization-review/' + state.applicationId + '/approve', 'POST'), request(government, '/sports/organization-review/' + state.applicationId + '/approve', 'POST')]);
    const approved = await mine(); state.organizationId = String(approved.application.organizationId); save();
    check('G11', 'Two real concurrent ordinary approvals succeed exactly once', outcomes.filter(row => row.code === 200).length === 1 && approved.application.status === 'approved', { successCount: outcomes.filter(row => row.code === 200).length });
    assert.match(state.applicationId, /^\d+$/); assert.match(state.organizationId, /^\d+$/);
    const approvalRows = readSql(`SELECT (SELECT count(*) FROM asp_organization WHERE id=a.organization_id), (SELECT count(*) FROM asp_account_tenant_principal WHERE account_id=a.applicant_account_id AND tenant_id=a.organization_tenant_id AND status='active'), (SELECT count(*) FROM asp_staff_grant WHERE organization_id=a.organization_id AND account_id=a.applicant_account_id AND status='active') FROM asp_organization_application a WHERE a.id=${state.applicationId};`);
    check('G11a', 'Concurrent approval leaves one organization, principal and staff grant', approvalRows === '1|1|1', { counts: approvalRows });
    await denied('G11b', 'Approved admission cannot be rejected afterwards', government, '/sports/organization-review/' + state.applicationId + '/reject', 'POST', { reason: '合成重复测试' });
    await deniedAction('G11c', 'Approved application cannot be rewritten', applicant, 'organization.save', { draftJson: JSON.stringify(corrected), expectedVersion: approved.version });
    const entry = await api(applicant, '/auth/organization/enter', 'POST');
    state.organizer = { token: entry.accessToken || entry.access_token, clientId: entry.clientId || entry.client_id || context.clientId }; save();
    check('G12', 'Approved ordinary applicant enters the independent organizer workspace', Boolean(state.organizer.token) && (await api(state.organizer, '/sports/b/desk/context')).organizationName === complete.name);
    report.roleEvidence.push({ stage: 'admission', actor: 'ordinary-applicant and assigned ordinary-government', concurrentApprovals: 2, administratorOnlySetup: 'reviewer assignment' });
  });
  await stage('governance-scopes', async () => {
    assert.ok(state.organizationId && state.organizationId !== String(context.organizationId), 'Only the independent organization can be managed by this script');
    check('G13', 'Ungrant organization is absent from government summary', !(await api(government, '/sports/government')).some(row => String(row.id) === state.organizationId));
    await deniedAction('G13b', 'Ordinary government cannot grant its own organization scope', government, 'government.grant', { organizationId: state.organizationId, sysUserId: government.id, permissions: 'qualify,summary,complaint', status: 'active' });
    await action('grant-summary-only', admin, 'government.grant', { organizationId: state.organizationId, sysUserId: government.id, permissions: 'summary', status: 'active' });
    const summary = await organizationRow();
    check('G14', 'Only explicit summary grant exposes the new organization necessary counts', Boolean(summary) && Number(summary.event_count) === 0 && Number(summary.registration_count) === 0);
    await deniedAction('G14b', 'Summary-only government cannot suspend qualification', government, 'government.qualify', { organizationId: state.organizationId, status: 'restricted', reason: '合成范围测试', expectedVersion: summary.version });
    await deniedAction('G14c', 'Unsupported governance permissions cannot be granted', admin, 'government.grant', { organizationId: state.organizationId, sysUserId: government.id, permissions: 'summary,refund', status: 'active' });
    await action('grant-full', admin, 'government.grant', { organizationId: state.organizationId, sysUserId: government.id, permissions: 'qualify,summary,complaint', status: 'active' });
    await deniedAction('G15', 'Invalid qualification status is rejected', government, 'government.qualify', { organizationId: state.organizationId, status: 'approved', reason: '合成测试', expectedVersion: (await organizationRow()).version });
    await deniedAction('G15b', 'Empty qualification reason is rejected', government, 'government.qualify', { organizationId: state.organizationId, status: 'restricted', reason: '', expectedVersion: (await organizationRow()).version });
    await deniedAction('G15c', 'Participant cannot suspend an organizer', applicant, 'government.qualify', { organizationId: state.organizationId, status: 'restricted', reason: '合成测试', expectedVersion: (await organizationRow()).version });
    report.roleEvidence.push({ stage: 'governance', actor: 'ordinary-government', administratorOnlySetup: 'explicit summary and qualification/complaint grants' });
  });
  await stage('event-lifecycle', async () => {
    const gap = await createEvent('gap', '缺比赛项目发布检查');
    const missingUnit = await request(state.organizer, '/sports/b/events/' + gap + '/publish', 'POST', { requestKey: crypto.randomUUID(), contactConfirmed: true, contactName: '隔离回归负责人', contactMethod: '仅本机测试，无真实联系方式' });
    check('E01', 'An event without any competition type or quota cannot be published', missingUnit.code !== 200, { code: missingUnit.code });
    if (missingUnit.code === 200) { await simpleWrite('gap-offline', state.organizer, '/sports/b/events/' + gap + '/offline'); state.gapUnexpectedPublication = gap; save(); }
    const eventId = await createEvent('lifecycle', '赛事状态与通知'); state.lifecycleEvent = eventId; save();
    const unitId = await ownUnit('lifecycle', eventId);
    await denied('E02', 'First publication requires explicit contact disclosure confirmation', state.organizer, '/sports/b/events/' + eventId + '/publish', 'POST', { requestKey: crypto.randomUUID(), contactConfirmed: false, contactName: '隔离回归负责人', contactMethod: '仅本机测试，无真实联系方式' });
    await publishEvent('lifecycle-publish', eventId);
    check('E03', 'Independent organizer publishes typed, free event visible anonymously', (await api(null, '/sports/public/events/' + eventId)).publicationStatus === 'published');
    const first = state.operations['lifecycle-publish'];
    const replay = await api(state.organizer, '/sports/platform/actions/event.publish/execute', 'POST', { input: first.input, requestKey: first.key, confirmationId: first.confirmationId });
    check('E03b', 'Repeat publication returns existing receipt without a second command', replay.replayed === true && readSql(`SELECT count(*) FROM asp_event_command WHERE event_id=${eventId};`) === '1');
    await deniedAction('E04', 'Published event cannot be changed directly', state.organizer, 'event.update', { eventId, expectedVersion: await eventVersion(eventId), draftJson: JSON.stringify(draft('赛事状态与通知')) });
    await denied('E04b', 'A different organizer cannot read managed event details', context.organizer, '/sports/b/events/' + eventId);
    await denied('E04c', 'A different organizer cannot cancel the event', context.organizer, '/sports/b/events/' + eventId + '/cancel', 'POST', { reason: '合成越权检查' });
    await denied('E04d', 'Ordinary government cannot publish on behalf of the organizer', government, '/sports/b/events/' + eventId + '/publish', 'POST', { requestKey: crypto.randomUUID(), contactConfirmed: true, contactName: '合成', contactMethod: '合成' });
    await simpleWrite('lifecycle-first-offline', state.organizer, '/sports/b/events/' + eventId + '/offline');
    await denied('E05', 'Offline event is absent from anonymous detail', null, '/sports/public/events/' + eventId);
    await denied('E05b', 'A previously published event cannot be deleted as a draft', state.organizer, '/sports/b/events/' + eventId + '/delete-draft', 'POST');
    await deniedAction('E06', 'Restoring publication cannot silently replace frozen public contact', state.organizer, 'event.publish', { eventId, expectedVersion: await eventVersion(eventId), contactName: '已更换的合成联系人', contactMethod: '已更换的合成联系方式' });
    await publishEvent('lifecycle-restored', eventId);
    if (!state.registrationId) { state.registrationId = (await simpleWrite('registration-draft', outsider, '/sports/c/registrations', { unitId, requestKey: crypto.randomUUID() })).id; save(); }
    await simpleWrite('registration-ack', outsider, '/sports/c/registrations/' + state.registrationId + '/declaration-ack');
    await action('registration-formal', outsider, 'registration.submit', { registrationId: state.registrationId, expectedVersion: version('asp_registration', state.registrationId) });
    check('E07', 'Formal free registration freezes rules and consumes one quota', readSql(`SELECT registration_review_locked FROM asp_event WHERE id=${eventId};`) === 't' && readSql(`SELECT used_count FROM asp_capacity_pool WHERE unit_id=${unitId};`) === '1');
    await simpleWrite('lifecycle-formal-offline', state.organizer, '/sports/b/events/' + eventId + '/offline');
    const original = await api(state.organizer, '/sports/b/events/' + eventId);
    await deniedAction('E08', 'Major dates cannot be changed after formal registration', state.organizer, 'event.update', { eventId, expectedVersion: await eventVersion(eventId), draftJson: JSON.stringify({ ...original, startsAt: new Date(Date.now() + 72 * 3600000).toISOString(), endsAt: new Date(Date.now() + 76 * 3600000).toISOString() }) });
    await deniedAction('E08b', 'Frozen declaration cannot be replaced after formal registration', state.organizer, 'event.update', { eventId, expectedVersion: await eventVersion(eventId), draftJson: JSON.stringify({ ...original, declarationText: '合成替换声明' }) });
    await publishEvent('lifecycle-second-restored', eventId);
    const movable = await createEvent('movable', '未提交草稿改期');
    const newDates = draft('未提交草稿改期', { startsAt: new Date(Date.now() + 96 * 3600000).toISOString(), endsAt: new Date(Date.now() + 100 * 3600000).toISOString() });
    await action('movable-update', state.organizer, 'event.update', { eventId: movable, expectedVersion: await eventVersion(movable), draftJson: JSON.stringify(newDates) });
    check('E09', 'Unsubmitted draft allows legal new dates', new Date((await api(state.organizer, '/sports/b/events/' + movable)).startsAt).getTime() === new Date(newDates.startsAt).getTime());
    await deniedAction('E09b', 'Illegal registration and competition time order is rejected', state.organizer, 'event.update', { eventId: movable, expectedVersion: await eventVersion(movable), draftJson: JSON.stringify({ ...newDates, endsAt: newDates.startsAt }) });
    await simpleWrite('movable-delete', state.organizer, '/sports/b/events/' + movable + '/delete-draft');
    await denied('E10', 'Deleted empty draft is no longer managed', state.organizer, '/sports/b/events/' + movable);
  });
  await stage('qualification-and-complaint', async () => {
    const eventId = state.lifecycleEvent;
    const originalVersion = (await organizationRow()).version;
    await action('qualification-restrict', government, 'government.qualify', { organizationId: state.organizationId, status: 'restricted', reason: '本机合成回归：暂停新增办赛，保留收尾责任', expectedVersion: originalVersion });
    check('G16', 'Ordinary government restricts only its granted independent organizer', (await organizationRow()).status === 'restricted');
    await deniedAction('G16b', 'Stale organization version cannot restore qualification', government, 'government.qualify', { organizationId: state.organizationId, status: 'certified', reason: '合成', expectedVersion: originalVersion });
    await denied('G17', 'Restricted organizer published event disappears from public detail', null, '/sports/public/events/' + eventId);
    check('G17b', 'Restricted organizer retains historical managed details', (await api(state.organizer, '/sports/b/events/' + eventId)).id === eventId);
    await denied('G17c', 'Restricted organizer does not accept new registrations', context.people[2], '/sports/c/registrations', 'POST', { unitId: state.units.lifecycle, requestKey: crypto.randomUUID() });
    const restrictedDraft = await request(state.organizer, '/sports/b/events', 'POST', draft('暂停期新增草稿检查'));
    check('G17d', 'Restricted organizer cannot create a new event', restrictedDraft.code !== 200, { code: restrictedDraft.code });
    if (restrictedDraft.code === 200) { state.createdEvents.restrictedUnexpected = restrictedDraft.data.id; save(); }
    if (!state.complaintId) { state.complaintId = (await action('complaint-submit', outsider, 'complaint.submit', { objectType: 'event', objectId: eventId, message: '本机合成投诉：暂停后如何处理已有报名？' })).complaintId; save(); }
    let detail = await api(outsider, '/sports/issues/' + state.complaintId);
    check('C01', 'Participant can submit a numbered complaint for the existing restricted event', detail.complaint.status === 'submitted' && detail.messages.length === 1);
    const submit = state.operations['complaint-submit'];
    const replay = await api(outsider, '/sports/platform/actions/complaint.submit/execute', 'POST', { input: submit.input, requestKey: submit.key, confirmationId: submit.confirmationId });
    check('C01b', 'Repeat complaint request does not duplicate its messages', replay.replayed === true && (await api(outsider, '/sports/issues/' + state.complaintId)).messages.length === 1);
    await denied('C02', 'An unrelated participant cannot read this private complaint', context.people[2], '/sports/issues/' + state.complaintId);
    await denied('C02b', 'A different organizer cannot read this complaint', context.organizer, '/sports/issues/' + state.complaintId);
    await deniedAction('C02c', 'A participant cannot submit an official handling conclusion', outsider, 'complaint.handle', { complaintId: state.complaintId, action: 'resolve', message: '合成', expectedVersion: detail.complaint.version });
    await deniedAction('C03', 'Empty complaint reply is rejected', state.organizer, 'complaint.reply', { complaintId: state.complaintId, message: '', expectedVersion: detail.complaint.version });
    await action('complaint-org-reply', state.organizer, 'complaint.reply', { complaintId: state.complaintId, message: '本机合成回复：保留报名，等待协调和收尾', expectedVersion: detail.complaint.version });
    await deniedAction('C03b', 'A stale complaint version cannot overwrite a new reply', government, 'complaint.handle', { complaintId: state.complaintId, action: 'accept', message: '合成', expectedVersion: detail.complaint.version });
    detail = await api(government, '/sports/issues/' + state.complaintId);
    await action('complaint-gov-accept', government, 'complaint.handle', { complaintId: state.complaintId, action: 'accept', message: '本机合成：政府范围内受理', expectedVersion: detail.complaint.version });
    await action('complaint-gov-coordinate', government, 'complaint.handle', { complaintId: state.complaintId, action: 'coordinate', message: '本机合成：联系双方核对已有责任', expectedVersion: (await api(government, '/sports/issues/' + state.complaintId)).complaint.version });
    check('C04', 'Ordinary scoped government becomes responsible coordinator with visible history', (await api(outsider, '/sports/issues/' + state.complaintId)).complaint.status === 'investigating' && String((await api(outsider, '/sports/issues/' + state.complaintId)).complaint.owner_id) === government.id);
    await action('grant-without-complaint', admin, 'government.grant', { organizationId: state.organizationId, sysUserId: government.id, permissions: 'qualify,summary', status: 'active' });
    await denied('C05', 'Revoked complaint scope takes effect immediately for ordinary government', government, '/sports/issues/' + state.complaintId);
    check('C05b', 'Complaint disappears from revoked-scope government list', !(await api(government, '/sports/issues')).some(row => String(row.id) === state.complaintId));
    await action('grant-complaint-restored', admin, 'government.grant', { organizationId: state.organizationId, sysUserId: government.id, permissions: 'qualify,summary,complaint', status: 'active' });
    await action('complaint-gov-resolve', government, 'complaint.handle', { complaintId: state.complaintId, action: 'resolve', message: '本机合成结案：取消赛事并保留原报名及问题处理记录', expectedVersion: (await api(government, '/sports/issues/' + state.complaintId)).complaint.version });
    await action('complaint-reopen', outsider, 'complaint.reopen', { complaintId: state.complaintId, message: '本机合成：补充问题，申请再次核对', expectedVersion: (await api(outsider, '/sports/issues/' + state.complaintId)).complaint.version });
    check('C06', 'Only the applicant can reopen a closed problem with new history', (await api(outsider, '/sports/issues/' + state.complaintId)).complaint.status === 'appealed');
    await deniedAction('C06b', 'Open problem cannot be repeatedly reopened', outsider, 'complaint.reopen', { complaintId: state.complaintId, message: '合成重复', expectedVersion: (await api(outsider, '/sports/issues/' + state.complaintId)).complaint.version });
    await deniedAction('C06c', 'Government cannot impersonate applicant reopening', government, 'complaint.reopen', { complaintId: state.complaintId, message: '合成', expectedVersion: (await api(government, '/sports/issues/' + state.complaintId)).complaint.version });
    await action('complaint-final-resolve', government, 'complaint.handle', { complaintId: state.complaintId, action: 'resolve', message: '本机合成再次结案，所有回复保留', expectedVersion: (await api(government, '/sports/issues/' + state.complaintId)).complaint.version });
    check('C07', 'Both conclusion versions and reopen record are retained', (await api(outsider, '/sports/issues/' + state.complaintId)).messages.filter(row => row.action === 'resolve').length === 2 && (await api(outsider, '/sports/issues/' + state.complaintId)).messages.some(row => row.action === 'reopen'));
    await simpleWrite('cancel-restricted-existing', state.organizer, '/sports/b/events/' + eventId + '/cancel', { reason: '本机合成：暂停期取消，既有报名与资金责任保留' });
    check('E11', 'Restricted organizer can cancel an existing event for responsible wrap-up', (await api(state.organizer, '/sports/b/events/' + eventId)).holdingStatus === 'cancelled');
    await denied('E11b', 'Cancelled event cannot be cancelled again', state.organizer, '/sports/b/events/' + eventId + '/cancel', 'POST', { reason: '合成重复' });
    await denied('E11c', 'Cancelled event blocks registration approval', state.organizer, '/sports/b/registrations/' + state.registrationId + '/approve', 'POST');
    await action('qualification-restored', government, 'government.qualify', { organizationId: state.organizationId, status: 'certified', reason: '本机合成：恢复新增办赛资格，历史责任不重置', expectedVersion: (await organizationRow()).version });
    check('G18', 'Restored qualification keeps original organization and historical complaint', (await organizationRow()).status === 'certified' && (await api(outsider, '/sports/issues/' + state.complaintId)).complaint.status === 'resolved');
    await deniedAction('E12', 'Restoring organizer qualification does not restore a cancelled event', state.organizer, 'event.publish', { eventId, expectedVersion: await eventVersion(eventId), contactName: '隔离回归负责人', contactMethod: '仅本机测试，无真实联系方式' });
  });
  await stage('notifications', async () => {
    const messages = await api(outsider, '/sports/c/notices');
    const progress = messages.filter(row => row.businessType === 'complaint' && row.businessId === state.complaintId);
    check('N01', 'Complaint progress writes persistent recipient-scoped messages', progress.length >= 7);
    check('N01b', 'Complaint notification carries a usable trusted target path', progress.every(row => row.targetPath === '/portal/issues/' + state.complaintId), { messageCount: progress.length, messagesWithPath: progress.filter(row => row.targetPath).length });
    const qualification = (await api(applicant, '/sports/c/notices')).filter(row => row.businessType === 'organization' && row.businessId === state.organizationId);
    check('N02', 'Qualification changes notify organizer account through persistent inbox', qualification.length >= 2);
    check('N02b', 'Qualification notice carries a usable organizer task path', qualification.every(row => row.targetPath === '/portal/organization'), { messageCount: qualification.length, messagesWithPath: qualification.filter(row => row.targetPath).length });
    const cancelled = messages.filter(row => row.businessType === 'event' && row.businessId === state.lifecycleEvent && row.purpose === 'event-cancel');
    check('N03', 'Cancellation creates exactly one persistent notice for affected participant', cancelled.length === 1);
    state.cancelNotice = cancelled[0]?.id; save();
    assert.ok(state.cancelNotice, 'Concrete cancellation recipient exists');
    await denied('N04', 'Another account cannot mark this notice read', applicant, '/sports/c/notices/' + state.cancelNotice + '/read', 'POST');
    await simpleWrite('notice-read', outsider, '/sports/c/notices/' + state.cancelNotice + '/read');
    const firstVersion = version('asp_notification', state.cancelNotice);
    await api(outsider, '/sports/c/notices/' + state.cancelNotice + '/read', 'POST');
    check('N04b', 'Repeat mark-read preserves original read state without another version', version('asp_notification', state.cancelNotice) === firstVersion && (await api(outsider, '/sports/c/notices')).find(row => row.id === state.cancelNotice).read);
    const deliveries = await api(state.organizer, '/sports/b/events/' + state.lifecycleEvent + '/notices');
    check('N05', 'Cancellation records inbox delivered and SMS honestly failed', deliveries.some(row => row.channel === 'inbox' && row.status === 'delivered') && deliveries.some(row => row.channel === 'sms' && row.status === 'failed' && row.failureReason));
    await denied('N05b', 'Another organizer cannot inspect event notice delivery details', context.organizer, '/sports/b/events/' + state.lifecycleEvent + '/notices');
    await denied('N05c', 'Another organizer cannot retry its cancellation SMS', context.organizer, '/sports/b/events/notices/' + state.cancelNotice + '/retry-sms', 'POST');
    await denied('N05d', 'Participant cannot trigger an organizer SMS retry', outsider, '/sports/b/events/notices/' + state.cancelNotice + '/retry-sms', 'POST');
    const retried = await simpleWrite('notice-sms-retry', state.organizer, '/sports/b/events/notices/' + state.cancelNotice + '/retry-sms');
    check('N06', 'A failed SMS retry appends its attempt and never claims delivery', retried.status === 'failed' && retried.attempt === 2);
    check('N06b', 'Inbox remains readable after failed external SMS retry', (await api(outsider, '/sports/c/notices')).find(row => row.id === state.cancelNotice).read === true);
  });
  if (process.argv.includes('--verify-fixes')) await stage('verified-fixes', async () => {
    const gap = state.createdEvents.gap;
    await denied('R01', 'Previously empty published-and-offline event now fails restore without a project', state.organizer, '/sports/b/events/' + gap + '/publish', 'POST', { requestKey: crypto.randomUUID(), contactConfirmed: true, contactName: '隔离回归负责人', contactMethod: '仅本机测试，无真实联系方式' });
    const eventId = await createEvent('fixedFormal', '重大变更修复复验'); const unitId = await ownUnit('fixedFormal', eventId);
    await publishEvent('fixed-formal-publish', eventId);
    if (!state.fixedRegistrationId) { state.fixedRegistrationId = (await simpleWrite('fixed-registration-draft', outsider, '/sports/c/registrations', { unitId, requestKey: crypto.randomUUID() })).id; save(); }
    await simpleWrite('fixed-registration-ack', outsider, '/sports/c/registrations/' + state.fixedRegistrationId + '/declaration-ack');
    await action('fixed-registration-submit', outsider, 'registration.submit', { registrationId: state.fixedRegistrationId, expectedVersion: version('asp_registration', state.fixedRegistrationId) });
    await simpleWrite('fixed-formal-offline', state.organizer, '/sports/b/events/' + eventId + '/offline');
    const original = await api(state.organizer, '/sports/b/events/' + eventId);
    const digest = readSql(`SELECT md5(row_to_json(e)::text) FROM asp_event e WHERE id=${eventId};`);
    for (const [name, changes] of [
      ['competition dates', { startsAt: new Date(Date.now() + 72 * 3600000).toISOString(), endsAt: new Date(Date.now() + 76 * 3600000).toISOString() }],
      ['registration dates', { registrationOpensAt: new Date(Date.now() - 2 * 3600000).toISOString() }],
      ['venue', { location: '替换实际场地的合成请求' }], ['project', { projectName: '替换实际项目的合成请求' }], ['fee promise', { feeDescription: '改为收取合成报名费用' }],
    ]) await deniedAction('R02-' + name, 'Formal history rejects changed ' + name, state.organizer, 'event.update', { eventId, expectedVersion: await eventVersion(eventId), draftJson: JSON.stringify({ ...original, ...changes }) });
    check('R02-facts', 'Rejected major changes leave the entire existing event row unchanged', readSql(`SELECT md5(row_to_json(e)::text) FROM asp_event e WHERE id=${eventId};`) === digest);
    await action('fixed-name-correction', state.organizer, 'event.update', { eventId, expectedVersion: await eventVersion(eventId), draftJson: JSON.stringify({ ...original, name: context.prefix + '-重大变更修复复验（名称更正）', startsAt: new Date(original.startsAt).toISOString(), endsAt: new Date(original.endsAt).toISOString() }) });
    check('R03', 'General name correction and equivalent timezone do not alter frozen dates', new Date((await api(state.organizer, '/sports/b/events/' + eventId)).startsAt).getTime() === new Date(original.startsAt).getTime());
    await publishEvent('fixed-formal-restore', eventId);
    await action('fixed-restrict', government, 'government.qualify', { organizationId: state.organizationId, status: 'restricted', reason: '本机合成：暂停新增办赛修复复验', expectedVersion: (await organizationRow()).version });
    const count = readSql(`SELECT count(*) FROM asp_event WHERE organization_id=${state.organizationId};`);
    try {
      await denied('R04-native', 'Restricted organizer native create is now rejected', state.organizer, '/sports/b/events', 'POST', draft('暂停期新增修复检查'));
      await deniedAction('R04-action', 'Restricted organizer registered create is also rejected', state.organizer, 'event.create', { draftJson: JSON.stringify(draft('暂停期登记动作修复检查')) });
      check('R04-facts', 'Both rejected creation paths leave event count unchanged', readSql(`SELECT count(*) FROM asp_event WHERE organization_id=${state.organizationId};`) === count);
      check('R05', 'Restricted organizer still reads historical registration and problem', Boolean(await api(state.organizer, '/sports/b/events/' + eventId)) && Boolean(await api(state.organizer, '/sports/issues/' + state.complaintId)));
      await simpleWrite('fixed-restricted-cancel', state.organizer, '/sports/b/events/' + eventId + '/cancel', { reason: '本机合成：既有赛事收尾通路复验' });
      check('R05b', 'Restriction retains responsible cancellation path after the fix', (await api(state.organizer, '/sports/b/events/' + eventId)).holdingStatus === 'cancelled');
    } finally {
      await action('fixed-restore', government, 'government.qualify', { organizationId: state.organizationId, status: 'certified', reason: '本机合成：复验后恢复，未动共享组织', expectedVersion: (await organizationRow()).version });
    }
    const progress = (await api(outsider, '/sports/c/notices')).filter(row => row.businessType === 'complaint' && row.businessId === state.complaintId);
    const qualification = (await api(applicant, '/sports/c/notices')).filter(row => row.businessType === 'organization' && row.businessId === state.organizationId);
    check('R06-history', 'Old complaint notices retain content and now resolve their exact task path', progress.length >= 7 && progress.every(row => row.targetPath === '/portal/issues/' + state.complaintId));
    check('R07-history', 'Old and new qualification notices expose the safe organization task', qualification.length >= 4 && qualification.every(row => row.targetPath === '/portal/organization'));
    await action('fixed-complaint-new-notice', state.organizer, 'complaint.reply', { complaintId: state.complaintId, message: '本机合成：补充核对入口修复，历史记录保留', expectedVersion: (await api(state.organizer, '/sports/issues/' + state.complaintId)).complaint.version });
    check('R06-new', 'New progress writer stores targetPath rather than relying on legacy fallback', Number(readSql(`SELECT count(*) FROM asp_notification WHERE business_type='complaint' AND business_id=${state.complaintId} AND content->>'targetPath'='/portal/issues/${state.complaintId}';`)) >= 2);
    check('R07-new', 'New qualification writer stores targetPath explicitly', Number(readSql(`SELECT count(*) FROM asp_notification WHERE business_type='organization' AND business_id=${state.organizationId} AND content->>'targetPath'='/portal/organization';`)) >= 2);
    await action('fixed-revoke-all-scope', admin, 'government.grant', { organizationId: state.organizationId, sysUserId: government.id, permissions: 'qualify,summary,complaint', status: 'revoked' });
    check('G19', 'Full government scope revocation removes organization from ordinary summary', !(await api(government, '/sports/government')).some(row => String(row.id) === state.organizationId));
    await denied('G19b', 'Revoked government cannot read its former private complaint', government, '/sports/issues/' + state.complaintId);
    await deniedAction('G19c', 'Revoked government cannot alter its former organizer qualification', government, 'government.qualify', { organizationId: state.organizationId, status: 'restricted', reason: '合成', expectedVersion: version('asp_organization', state.organizationId) });
    await action('fixed-restore-scope-final', admin, 'government.grant', { organizationId: state.organizationId, sysUserId: government.id, permissions: 'qualify,summary,complaint', status: 'active' });
    check('G20', 'Restored explicit grant resumes only existing organization responsibility', (await organizationRow()).status === 'certified' && (await api(government, '/sports/issues/' + state.complaintId)).complaint.status === 'resolved');
  });
  if (process.argv.includes('--time-boundaries')) await stage('time-boundaries', async () => {
    if (!state.timerDates) { const now=Date.now(); state.timerDates={ startsAt:new Date(now+15000).toISOString(),endsAt:new Date(now+30000).toISOString() }; save(); }
    const timer = await createEvent('timer', '实际时点生命周期', draft('实际时点生命周期', { ...state.timerDates, registrationClosesAt:new Date(Date.now()-1800000).toISOString() }));
    await ownUnit('timer', timer); await publishEvent('timer-first-publish', timer);
    await simpleWrite('timer-offline-before-start', state.organizer, '/sports/b/events/' + timer + '/offline');
    const emptyDraft = await createEvent('neverPublished', '从未发布取消检查');
    await denied('E13', 'An unpublished draft cannot be cancelled as a formal event', state.organizer, '/sports/b/events/' + emptyDraft + '/cancel', 'POST', { reason:'合成取消' });
    const waitTo = async value => { const wait = Math.max(0,new Date(value).getTime()-Date.now()+250); assert.ok(wait < 60000); if(wait) await new Promise(resolve=>setTimeout(resolve,wait)); };
    await waitTo(state.timerDates.startsAt);
    check('E14-clock', 'Real clock reaches ongoing without direct timestamp changes', (await api(state.organizer, '/sports/b/events/' + timer)).phase === 'ongoing');
    await publishEvent('timer-ongoing-restored', timer);
    check('E14', 'A formerly published offline event can restore during competition', (await api(null, '/sports/public/events/' + timer)).phase === 'ongoing');
    await denied('E14b', 'Competition already started cannot be taken offline', state.organizer, '/sports/b/events/' + timer + '/offline', 'POST');
    await waitTo(state.timerDates.endsAt);
    check('E15-clock', 'Actual wall-clock reaches finished', (await api(state.organizer, '/sports/b/events/' + timer)).phase === 'finished');
    await denied('E15', 'Finished competition cannot be cancelled', state.organizer, '/sports/b/events/' + timer + '/cancel', 'POST', { reason:'合成已结束取消' });
    const past = await createEvent('firstPast', '已开赛首次发布检查', draft('已开赛首次发布检查', { registrationOpensAt:new Date(Date.now()-7200000).toISOString(),registrationClosesAt:new Date(Date.now()-3600000).toISOString(),startsAt:new Date(Date.now()-1800000).toISOString(),endsAt:new Date(Date.now()+3600000).toISOString() }));
    await ownUnit('firstPast', past);
    await deniedAction('E15b', 'An already started draft cannot publish for the first time', state.organizer, 'event.publish', { eventId:past, expectedVersion:await eventVersion(past),contactName:'隔离回归负责人',contactMethod:'仅本机测试，无真实联系方式' });
  });
  report.changedObjects = { applicationId: state.applicationId, organizationId: state.organizationId, eventIds: state.createdEvents };
  report.passed = report.checks.every(row => row.passed) && report.findings.length === 0;
} catch (error) {
  report.failures.push({ name: error.name, message: error.name === 'AssertionError' || String(error.message).startsWith('Required actual request rejected:') ? error.message : 'Business verification stopped; private details omitted' });
  process.exitCode = 1;
} finally {
  for (const file of ['scripts/Test-GovernanceBusinessRegression.mjs', 'backend/aisports-domains/d01/aisports-table-governance-grant/src/main/java/org/dromara/sports/tables/d01/governance_grant/GovernanceService.java', 'backend/aisports-domains/d01/aisports-table-organization-application/src/main/java/org/dromara/sports/organization/service/OrganizationApplicationService.java', 'backend/aisports-domains/d13/aisports-table-complaint/src/main/java/org/dromara/sports/tables/d13/complaint/ComplaintService.java', 'backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/service/EventCancellationNoticeService.java', 'plus-ui/src/views/portal/notices.vue']) report.sourceFiles.push({ path: file, sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') });
  report.previousStages = state.completedStages;
  fs.writeFileSync(path.join(runOut, 'receipt.json'), JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, findings: report.findings.length, failures: report.failures.length, receipt: path.relative(process.cwd(), path.join(runOut, 'receipt.json')).replaceAll('\\', '/') }));
  if (!report.passed) process.exitCode = 1;
}
