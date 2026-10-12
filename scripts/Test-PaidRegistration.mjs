/** Ordinary local trial roles and real HTTP/database/storage. Funds and uploaded receipt are synthetic. */
import { writeFile, mkdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
const mode = process.argv[2] || 'preflight';
const base = 'http://127.0.0.1:8080', clientId = 'e5cd7e4891bf95d1d19206ce24a7b32e';
const actors = [];
async function api(path, actor, method = 'GET', body) {
  const response = await fetch(base + path, { method, headers: { clientid: clientId, ...(actor ? { Authorization: 'Bearer ' + actor.token } : {}), ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
  return response.json();
}
for (const suffix of ['10','09','08']) {
  const phone = '131000000' + suffix;
  const login = await api('/auth/login', null, 'POST', { username: phone, password: process.env.AISPORTS_TRIAL_PASSWORD, clientId, grantType: 'platform', tenantId: '900001' });
  if (login.code !== 200) throw new Error('Trial login failed for role ' + suffix + ' code=' + login.code);
  const actor = { label: 'trial-' + suffix, phone, token: login.data.access_token };
  const identity = await api('/sports/c/identity', actor);
  const application = await api('/sports/c/organization/application', actor);
  actors.push(actor);
  console.log(JSON.stringify({ role: actor.label, login: login.code, profileRead: identity.code, profilePresent: Boolean(identity.data?.self), organizationRead: application.code, organizationStatus: application.data?.status, canEnter: application.data?.canEnter }));
}
if (mode === 'flow') {
  const { chromium } = createRequire(path.join(process.env.AISPORTS_TEST_NODE_MODULES, '_resolve.cjs'))('playwright');
  const browser = await chromium.launch({ executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', headless: true });
  try {
  const checks = [], runId = Date.now().toString(), key = () => crypto.randomUUID();
  const ok = (r, label) => { if (r.code !== 200) throw new Error(label + ': ' + r.msg); return r.data; };
  const assert = (condition, label) => { if (!condition) throw new Error(label); checks.push(label); console.log('PASS ' + label); };
  const [owner, participant, stranger] = actors;
  for (const [index, actor] of actors.entries()) {
    const identity = ok(await api('/sports/c/identity', actor), 'identity');
    if (!identity.self) ok(await api('/sports/c/identity/self', actor, 'POST', { legalName: '模拟测试选手' + index, birthDate: '1990-01-01', gender: 'male', mobile: actor.phone }), 'profile');
  }
  let application = ok(await api('/sports/c/organization/application', owner), 'application');
  if (!application.canEnter) {
    if (application.status !== 'submitted') application = ok(await api('/sports/c/organization/application/submit', owner, 'POST', { name: '模拟金额流程测试组织', contactName: '模拟测试承办人', contactMethod: owner.phone, statement: '仅本地验证收费报名与凭证，不涉及真实赛事和资金。', fileIds: [] }), 'submit organization');
    const adminLogin = ok(await api('/auth/login', null, 'POST', { username: 'admin', password: process.env.AISPORTS_TEST_ADMIN_PASSWORD, clientId, grantType: 'password', tenantId: '000000' }), 'admin prep login');
    ok(await api('/sports/organization-review/' + application.applicationId + '/approve', { token: adminLogin.access_token }, 'POST'), 'organization admission');
  }
  const entered = ok(await api('/auth/organization/enter', owner, 'POST'), 'enter organization');
  const organizer = { label: 'ordinary organizer', token: entered.access_token };
  const format = (days) => new Date(Date.now() + days * 86400000).toISOString();
  const event = ok(await api('/sports/b/events', organizer, 'POST', { name: '金额凭证流程测试-' + runId + '（模拟）', location: '本地模拟场地', projectName: '羽毛球', feeDescription: '模拟198元，不真实转账', registrationOpensAt: format(-1), registrationClosesAt: format(5), startsAt: format(7), endsAt: format(8), registrationReview: 'manual', rulesText: '本赛事仅用于本地系统验收，金额及到账均为模拟测试数据。' }), 'create event');
  const unit = ok(await api('/sports/b/registrations/units', organizer, 'POST', { eventId: event.id, name: '成人业余单打', entryType: 'individual', minMembers: 1, maxMembers: 1, limitCount: 5, requestKey: key(), charged: true, amount: 198, paymentMode: 'offline', payInstruction: '模拟测试，不进行真实转账' }), 'create paid unit');
  ok(await api('/sports/b/events/' + event.id + '/publish', organizer, 'POST', { requestKey: key(), contactConfirmed: true, contactName: '模拟测试承办人', contactMethod: owner.phone }), 'publish event');
  let entry = ok(await api('/sports/c/registrations', participant, 'POST', { unitId: unit.id, requestKey: key() }), 'create entry');
  const upload = async (actor, registrationId, body, requestKey = key()) => {
    const data = new FormData(); data.append('file', new Blob([body], { type: 'image/png' }), 'SIMULATED-receipt.png');
    return (await fetch(base + '/sports/c/registrations/' + registrationId + '/payment-proofs?requestKey=' + requestKey,
      { method: 'POST', headers: { clientid: clientId, Authorization: 'Bearer ' + actor.token }, body: data })).json();
  };
  const receiptPage = await browser.newPage();
  const png = Buffer.from(await receiptPage.evaluate(() => {
    const canvas = document.createElement('canvas'); canvas.width = 700; canvas.height = 350;
    const c = canvas.getContext('2d'); c.fillStyle = '#fff'; c.fillRect(0, 0, 700, 350); c.fillStyle = '#222'; c.font = '30px sans-serif';
    ['SIMULATED RECEIPT - NOT REAL PAYMENT', 'Local paid registration test', 'Amount: CNY 198.00', 'No real transfer or bank transaction'].forEach((line, i) => c.fillText(line, 20, 65 + i * 65));
    return canvas.toDataURL('image/png').split(',')[1];
  }), 'base64'); await receiptPage.close();
  assert((await upload(participant, entry.id, png)).code !== 200, 'draft cannot upload payment proof');
  entry = ok(await api('/sports/c/registrations/' + entry.id + '/submit', participant, 'POST', { requestKey: entry.requestKey }), 'submit');
  assert(entry.status === 'submitted' && Number(entry.feeAmount) === 198 && entry.obligationStatus === 'open', 'formal submit creates 198 obligation, awaiting review');
  assert((await api('/sports/b/registrations/' + entry.id + '/approve', organizer, 'POST')).code !== 200, 'approval blocked without receipts');
  assert((await upload(stranger, entry.id, png)).code !== 200, 'stranger cannot upload proof for another registration');
  assert((await upload(participant, entry.id, Buffer.from('not an image'))).code !== 200, 'server rejects forged image content');
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  await context.addInitScript(token => { localStorage.setItem('Admin-Token', token); localStorage.setItem('Platform-Token', token); }, participant.token);
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:5173/portal/registration/detail/' + entry.id);
  await page.getByRole('button', { name: '查看付款指引／我已付款' }).click({ timeout: 30000 });
  await page.getByText('强烈推荐上传付款凭证', { exact: false }).waitFor();
  const uploaded = page.waitForResponse(response => response.url().includes('/payment-proofs?') && response.request().method() === 'POST');
  await page.locator('.payment-proof-panel input[type=file]').setInputFiles({ name: 'SIMULATED-receipt.png', mimeType: 'image/png', buffer: png });
  const proof = ok(await (await uploaded).json(), 'UI upload');
  await page.locator('.payment-proof-images img').waitFor();
  await mkdir('.local/paid-registration-ui', { recursive: true });
  await page.screenshot({ path: '.local/paid-registration-ui/participant-proof.png' });
  assert(await page.locator('.payment-proof-dialog').evaluate(element => element.getBoundingClientRect().bottom <= innerHeight && element.getBoundingClientRect().top >= 0), 'mobile proof dialog remains within viewport with accessible footer');
  assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'mobile receipt upload has no horizontal overflow');
  assert(proof.obligationId === entry.obligationId, 'real UI upload links proof to current obligation');
  assert((await api('/sports/c/registrations/' + entry.id + '/payment-proofs', participant)).data.length === 1, 'participant reads uploaded proof');
  assert((await api('/sports/b/registrations/' + entry.id + '/payment-proofs', organizer)).data[0].id === proof.id, 'ordinary organizer reads same proof');
  const readProof = await fetch(base + '/sports/b/registrations/' + entry.id + '/payment-proofs/' + proof.id + '/image', { headers: { clientid: clientId, Authorization: 'Bearer ' + organizer.token } });
  assert(readProof.headers.get('cache-control') === 'no-store' && Buffer.from(await readProof.arrayBuffer()).equals(png), 'private storage download preserves original receipt bytes');
  assert((await api('/sports/c/registrations/' + entry.id + '/payment-proofs', stranger)).code !== 200, 'stranger cannot list private proof');
  assert((await api('/sports/b/media/' + proof.fileId, organizer)).code !== 200, 'generic organizer media cannot expose private proof');
  assert((await api('/sports/b/registrations/' + entry.id + '/approve', organizer, 'POST')).code !== 200, 'uploaded proof alone cannot approve');
  const duplicateKey = key();
  const extra = ok(await upload(participant, entry.id, png, duplicateKey), 'second proof');
  assert(ok(await upload(participant, entry.id, png, duplicateKey), 'duplicate upload').id === extra.id, 'duplicate proof request returns same attachment');
  assert((await upload(participant, entry.id, Buffer.concat([png, Buffer.from('different')]), duplicateKey)).code !== 200, 'same upload key cannot change attachment content');
  assert((await api('/sports/c/registrations/' + entry.id + '/payment-declared', stranger, 'POST')).code !== 200, 'stranger cannot declare payment');
  entry = ok(await api('/sports/c/registrations/' + entry.id + '/payment-declared', participant, 'POST'), 'declare');
  assert(entry.paymentDeclared && entry.obligationStatus === 'open' && entry.status === 'submitted', 'declaration does not confirm funds');
  assert((await api('/sports/b/registrations/' + entry.id + '/approve', organizer, 'POST')).code !== 200, 'declaration alone cannot approve');
  const occurredAt = () => new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 19).replace('T', ' ');
  const fixedTime = occurredAt();
  const confirm = async (amount, requestKey = key()) => ok(await api('/sports/b/fees/obligations/' + entry.obligationId + '/confirm', organizer, 'POST', { payerName: '模拟测试付款人', amount, occurredAt: fixedTime, note: 'SIMULATED: 本地流程测试，无真实收款', requestKey }), 'receipt');
  const organizerContext = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  await organizerContext.addInitScript(({ orgToken, platformToken }) => {
    localStorage.setItem('Admin-Token', orgToken); localStorage.setItem('Platform-Token', platformToken);
  }, { orgToken: organizer.token, platformToken: owner.token });
  const organizerPage = await organizerContext.newPage();
  await organizerPage.goto('http://127.0.0.1:5173/org-desk/workspace/' + event.id + '?task=registrations&unitId=' + unit.id);
  await organizerPage.getByRole('button', { name: '查看办理', exact: true }).first().click({ timeout: 30000 });
  assert(await organizerPage.getByRole('button', { name: '审核通过', exact: true }).isDisabled(), 'real organizer page disables unpaid approval');
  await organizerPage.getByRole('button', { name: '登记实际到账', exact: true }).click();
  const receiptDialog = organizerPage.getByRole('dialog', { name: '登记实际到账', exact: true });
  await receiptDialog.locator('.el-form-item').filter({ hasText: '实际付款人' }).locator('input').fill('模拟测试付款人');
  await receiptDialog.locator('.el-form-item').filter({ hasText: '实际到账金额' }).locator('input').fill('98');
  await receiptDialog.locator('.el-form-item').filter({ hasText: '实际到账时间' }).locator('input').fill(fixedTime);
  await receiptDialog.locator('textarea').fill('SIMULATED: 本地流程测试，无真实收款');
  const receiptResponse = organizerPage.waitForResponse(response => response.url().endsWith('/' + entry.obligationId + '/confirm') && response.request().method() === 'POST');
  await receiptDialog.getByRole('button', { name: '确认登记', exact: true }).click();
  const firstReceipt = await receiptResponse;
  ok(await firstReceipt.json(), 'UI first receipt');
  ok(await api('/sports/b/fees/obligations/' + entry.obligationId + '/confirm', organizer, 'POST', firstReceipt.request().postDataJSON()), 'repeat actual UI request');
  assert(true, 'ordinary organizer fills payer amount time and note in real receipt form');
  let records = ok(await api('/sports/b/fees/obligations/' + entry.obligationId + '/records', organizer), 'records');
  assert(Number(records.netAmount) === 98 && records.receipts.length === 1, 'partial receipt and duplicate request count once');
  assert((await api('/sports/b/registrations/' + entry.id + '/approve', organizer, 'POST')).code !== 200, 'partial funds cannot approve');
  await confirm(100);
  records = ok(await api('/sports/b/fees/obligations/' + entry.obligationId + '/records', organizer), 'records');
  assert(Number(records.netAmount) === 198, 'split receipts mapped to this obligation total 198');
  await organizerPage.reload();
  await organizerPage.getByRole('button', { name: '查看办理', exact: true }).first().click({ timeout: 30000 });
  await organizerPage.locator('.payment-proof-images img').first().waitFor();
  await organizerPage.screenshot({ path: '.local/paid-registration-ui/organizer-proof-and-funds.png', fullPage: true });
  const approvedResponse = organizerPage.waitForResponse(response => response.url().endsWith('/' + entry.id + '/approve') && response.request().method() === 'POST');
  await organizerPage.getByRole('button', { name: '审核通过', exact: true }).click();
  entry = ok(await (await approvedResponse).json(), 'UI approve');
  assert(true, 'ordinary organizer approves through real page with proof and funds visible');
  assert(entry.status === 'approved' && entry.obligationStatus === 'settled', 'full receipt plus approval results registration success');
  const mine = ok(await api('/sports/c/registrations?eventId=' + event.id, participant), 'mine');
  assert(mine.some(row => row.id === entry.id && row.status === 'approved'), 'participant sees approved result');
  await page.reload();
  await page.getByText('已通过', { exact: true }).first().waitFor();
  await page.screenshot({ path: '.local/paid-registration-ui/participant-approved.png', fullPage: true });
  assert((await upload(participant, entry.id, png)).code !== 200, 'settled registration does not accept unrelated new proof');
  const successfulId = entry.id, successfulObligation = entry.obligationId;
  // 普通另一用户验证不上传、不声明也可按实际足额收款审批。
  let second = ok(await api('/sports/c/registrations', stranger, 'POST', { unitId: unit.id, requestKey: key() }), 'second user');
  second = ok(await api('/sports/c/registrations/' + second.id + '/submit', stranger, 'POST', { requestKey: second.requestKey }), 'second submit');
  assert(Number(ok(await api('/sports/b/fees/obligations/' + second.obligationId + '/records', organizer), 'second zero').netAmount) === 0, 'first participant receipts never pay another participant obligation');
  entry = second; await confirm(198);
  second = ok(await api('/sports/b/registrations/' + second.id + '/approve', organizer, 'POST'), 'optional proof approve');
  assert(second.status === 'approved' && !second.paymentDeclared && ok(await api('/sports/c/registrations/' + second.id + '/payment-proofs', stranger), 'empty proofs').length === 0, 'proof and declaration are optional for valid paid approval');
  const oldObligation = second.obligationId;
  await api('/sports/c/registrations/' + second.id + '/withdraw', stranger, 'POST');
  second = ok(await api('/sports/c/registrations/' + second.id + '/submit', stranger, 'POST', { requestKey: key() }), 'reapply');
  assert(second.obligationId !== oldObligation && second.obligationStatus === 'open' && !second.paymentDeclared, 'withdraw reapply opens new unpaid independent obligation');
  assert((await api('/sports/b/registrations/' + second.id + '/approve', organizer, 'POST')).code !== 200, 'old paid obligation cannot approve resubmission');
  const oldRecords = ok(await api('/sports/b/fees/obligations/' + oldObligation + '/records', organizer), 'old funds');
  assert(Number(oldRecords.netAmount) === 198, 'withdrawal retains original receipts for follow-up');
  ok(await api('/sports/c/registrations/' + successfulId + '/withdraw', participant, 'POST'), 'withdraw receipt owner');
  const renewed = ok(await api('/sports/c/registrations/' + successfulId + '/submit', participant, 'POST', { requestKey: key() }), 'receipt owner reapply');
  assert(renewed.obligationId !== successfulObligation && ok(await api('/sports/c/registrations/' + successfulId + '/payment-proofs', participant), 'new proofs').length === 0, 'resubmission does not inherit earlier proof');
  assert((await api('/sports/b/events/' + event.id + '/registration-review', organizer, 'POST', { registrationReview: 'none' })).code !== 200, 'review mode cannot change after formal registrations');
  entry = renewed; await confirm(198);
  ok(await api('/sports/b/registrations/' + renewed.id + '/approve', organizer, 'POST'), 'reapply final approve');
  const autoEvent = ok(await api('/sports/b/events', organizer, 'POST', { name: '金额凭证免审核测试-' + runId + '（模拟）', location: '本地模拟场地', projectName: '羽毛球', feeDescription: '模拟198元，不真实转账', registrationOpensAt: format(-1), registrationClosesAt: format(5), startsAt: format(7), endsAt: format(8), registrationReview: 'none', rulesText: '本地模拟测试，无真实收款。' }), 'auto event');
  const autoUnit = ok(await api('/sports/b/registrations/units', organizer, 'POST', { eventId: autoEvent.id, name: '成人单打', entryType: 'individual', minMembers: 1, maxMembers: 1, limitCount: 5, requestKey: key(), charged: true, amount: 198, paymentMode: 'offline', payInstruction: '仅模拟' }), 'auto unit');
  ok(await api('/sports/b/events/' + autoEvent.id + '/publish', organizer, 'POST', { requestKey: key(), contactConfirmed: true, contactName: '模拟测试承办人', contactMethod: owner.phone }), 'auto publish');
  entry = ok(await api('/sports/c/registrations', participant, 'POST', { unitId: autoUnit.id, requestKey: key() }), 'auto entry');
  entry = ok(await api('/sports/c/registrations/' + entry.id + '/submit', participant, 'POST', { requestKey: entry.requestKey }), 'auto submit');
  assert(entry.status === 'submitted', 'no-review charged event still waits for full funds');
  await confirm(198);
  const auto = ok(await api('/sports/c/registrations?eventId=' + autoEvent.id, participant), 'auto status').find(row => row.id === entry.id);
  assert(auto.status === 'approved' && auto.obligationStatus === 'settled', 'no-review charged registration auto succeeds only after full receipt');
  // 原收款撤回后的部分退款和精确冲正，不触碰重新提交产生的新收款。
  const original = ok(await api('/sports/b/fees/obligations/' + successfulObligation + '/records', organizer), 'original receipt followup');
  const refundSource = original.receipts.find(receipt => Number(receipt.amount) === 98);
  const refundKey = key();
  const refundBody = { requestKey: refundKey, amount: 20, occurredAt: fixedTime, recipientName: '模拟退款接收人', recipientBasis: 'SIMULATED: 原付款人测试核对', note: 'SIMULATED: 无实际资金转移的退款流程测试' };
  ok(await api('/sports/b/fees/actions/' + refundSource.pendingActionId + '/refund', organizer, 'POST', refundBody), 'partial refund');
  ok(await api('/sports/b/fees/actions/' + refundSource.pendingActionId + '/refund', organizer, 'POST', refundBody), 'refund retry');
  const refunded = ok(await api('/sports/b/fees/obligations/' + successfulObligation + '/records', organizer), 'refunded records');
  assert(Number(refunded.netAmount) === 178 && refunded.refunds.length === 1, 'partial refund and duplicate request reduce original net funds once');
  assert((await api('/sports/b/fees/actions/' + refundSource.pendingActionId + '/refund', organizer, 'POST', { ...refundBody, requestKey: key(), amount: 79 })).code !== 200, 'refund cannot exceed remaining source receipt');
  assert((await api('/sports/b/fees/obligations/' + successfulObligation + '/reverse', organizer, 'POST', { requestKey: key(), paymentId: refundSource.paymentId })).code !== 200, 'cannot erase source receipt after actual refund record');
  const wrongReceipt = original.receipts.find(receipt => Number(receipt.amount) === 100);
  ok(await api('/sports/b/fees/obligations/' + successfulObligation + '/reverse', organizer, 'POST', { requestKey: key(), paymentId: wrongReceipt.paymentId }), 'precise reversal');
  assert(Number(ok(await api('/sports/b/fees/obligations/' + successfulObligation + '/records', organizer), 'reversed records').netAmount) === 78, 'reversal targets selected receipt without removing another payment');
  assert(Number(ok(await api('/sports/b/fees/obligations/' + renewed.obligationId + '/records', organizer), 'renewed net').netAmount) === 198, 'old refunds and reversals never alter new obligation funds');
  assert((await api('/sports/b/fees/obligations/' + renewed.obligationId + '/records', stranger)).code !== 200, 'platform participant has no organizer financial access');
  // 第二个普通承办组织真实授权后仍不能读/写第一组织的钱或凭证。
  const otherLogin = ok(await api('/auth/login', null, 'POST', { username: '13100000007', password: process.env.AISPORTS_TRIAL_PASSWORD, clientId, grantType: 'platform', tenantId: '900001' }), 'other organizer platform');
  const otherPlatform = { token: otherLogin.access_token };
  let otherApplication = ok(await api('/sports/c/organization/application', otherPlatform), 'other application');
  if (!otherApplication.canEnter) {
    if (otherApplication.status !== 'submitted') otherApplication = ok(await api('/sports/c/organization/application/submit', otherPlatform, 'POST', { name: '模拟金额流程隔离组织', contactName: '模拟隔离承办人', contactMethod: '13100000007', statement: '仅本地跨组织权限验证，不真实办赛或收款。', fileIds: [] }), 'other admission submit');
    const admin = ok(await api('/auth/login', null, 'POST', { username: 'admin', password: process.env.AISPORTS_TEST_ADMIN_PASSWORD, clientId, grantType: 'password', tenantId: '000000' }), 'other admission admin');
    ok(await api('/sports/organization-review/' + otherApplication.applicationId + '/approve', { token: admin.access_token }, 'POST'), 'other admission');
  }
  const otherOrganizer = { token: ok(await api('/auth/organization/enter', otherPlatform, 'POST'), 'other enter').access_token };
  assert((await api('/sports/b/registrations/' + successfulId + '/payment-proofs', otherOrganizer)).code !== 200, 'another certified organizer cannot read registration proof');
  assert((await api('/sports/b/fees/obligations/' + renewed.obligationId + '/records', otherOrganizer)).code !== 200, 'another organizer cannot read financial records');
  assert((await api('/sports/b/fees/obligations/' + renewed.obligationId + '/confirm', otherOrganizer, 'POST', { payerName: '模拟越权人', amount: 198, occurredAt: fixedTime, requestKey: key() })).code !== 200, 'another organizer cannot confirm receipts');
  // 测试赛事下架，不取消、不发短信；本人历史与资金记录保留。
  ok(await api('/sports/b/events/' + event.id + '/offline', organizer, 'POST'), 'offline manual test event');
  ok(await api('/sports/b/events/' + autoEvent.id + '/offline', organizer, 'POST'), 'offline auto test event');
  await mkdir('.local', { recursive: true });
  await writeFile('.local/paid-registration-' + runId + '.json', JSON.stringify({ runId, simulatedFunds: true, eventId: event.id, unitId: unit.id, registrationId: successfulId, obligationId: renewed.obligationId, originalObligationId: successfulObligation, autoEventId: autoEvent.id, autoRegistrationId: auto.id, checks, records, oldRecords, refunded }, null, 2));
  console.log(JSON.stringify({ runId, eventId: event.id, checks: checks.length }));
  } finally { await browser.close(); }
}
if (mode === 'cleanup') {
  const entered = await api('/auth/organization/enter', actors[0], 'POST');
  if (entered.code !== 200) throw new Error('Cannot enter synthetic test organization');
  const organizer = { token: entered.data.access_token };
  const list = await api('/sports/b/events', organizer);
  if (list.code !== 200) throw new Error('Cannot list test events');
  let count = 0;
  for (const event of list.data) {
    if (!/^金额凭证(?:流程|免审核)测试-\d+（模拟）$/.test(event.name) || event.publicationStatus !== 'published') continue;
    if ((await api('/sports/b/events/' + event.id + '/offline', organizer, 'POST')).code !== 200) throw new Error('Synthetic event offline failed');
    count++;
  }
  console.log(JSON.stringify({ syntheticEventsOfflined: count, retainedRecords: true, cancelled: false }));
}
