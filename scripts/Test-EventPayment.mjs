/** Real local ordinary-role HTTP, Vue and storage. All events/accounts/materials/funds are synthetic. */
import {createRequire} from 'node:module';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const base = 'http://127.0.0.1:8080', clientId = 'e5cd7e4891bf95d1d19206ce24a7b32e';
const {chromium} = createRequire(path.join(process.env.AISPORTS_TEST_NODE_MODULES, '_resolve.cjs'))('playwright');
const runId = Date.now(), out = path.resolve('.local/event-payment-' + runId), checks = [], errors = [];
await fs.mkdir(out, {recursive: true});
const check = (condition, label) => {assert.ok(condition, label); checks.push(label); console.log('PASS ' + label);};
const ok = (response, label) => {assert.equal(response.code, 200, label + ': ' + response.msg); return response.data;};
const key = () => crypto.randomUUID();
async function api(url, actor, method = 'GET', data) {
  const response = await fetch(base + url, {method, headers: {clientid: clientId, ...(actor ? {Authorization: 'Bearer ' + actor.token} : {}), ...(data !== undefined ? {'Content-Type': 'application/json'} : {})}, body: data === undefined ? undefined : JSON.stringify(data)});
  return response.json();
}
async function login(suffix) {
  const phone = '131000000' + suffix;
  const data = ok(await api('/auth/login', null, 'POST', {username: phone, password: process.env.AISPORTS_TRIAL_PASSWORD, clientId, grantType: 'platform', tenantId: '900001'}), 'ordinary trial login');
  return {token: data.access_token, phone};
}
const [owner, participant, stranger, otherOwner] = await Promise.all(['10', '09', '08', '07'].map(login));
const organizer = {token: ok(await api('/auth/organization/enter', owner, 'POST'), 'enter prepared test organization').access_token};
const otherOrganizer = {token: ok(await api('/auth/organization/enter', otherOwner, 'POST'), 'enter prepared isolated organization').access_token};
const browser = await chromium.launch({executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', headless: true});
if (process.argv[2] === 'capture-only') {
  // 只读取本轮已下架的合成赛事，截图等待资源完成并关闭动画，避免桌面切手机时拍到滑出中的侧栏。
  const evidence = JSON.parse(await fs.readFile(process.argv[3], 'utf8')), target = path.dirname(path.resolve(process.argv[3]));
  const context = await browser.newContext({viewport: {width: 1440, height: 1000}});
  await context.addInitScript(({org, platform}) => {localStorage.setItem('Admin-Token', org); localStorage.setItem('Platform-Token', platform);}, {org: organizer.token, platform: owner.token});
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:5173/org-desk/workspace/' + evidence.eventId + '?task=projects');
  await page.locator('.b-inline-fee').first().waitFor(); await page.screenshot({path: path.join(target, 'projects-locked.png'), fullPage: true, animations: 'disabled'});
  await page.goto('http://127.0.0.1:5173/org-desk/workspace/' + evidence.eventId + '?task=fields');
  await page.locator('.b-event-payment img').first().waitFor(); await page.waitForFunction(() => [...document.querySelectorAll('.b-event-payment img')].every(img => img.complete && img.naturalWidth > 0));
  await page.screenshot({path: path.join(target, 'event-channels-locked.png'), fullPage: true, animations: 'disabled'});
  await page.setViewportSize({width: 390, height: 844}); await page.screenshot({path: path.join(target, 'event-channels-mobile.png'), fullPage: true, animations: 'disabled'});
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
  await context.close(); await browser.close(); console.log('READONLY CAPTURE PASS; existing synthetic event and registrations preserved'); process.exit(0);
}
let event;
try {
  const time = days => new Date(Date.now() + days * 86400000).toISOString();
  event = ok(await api('/sports/b/events', organizer, 'POST', {name: '赛事统一收款测试-' + runId + '（模拟）', location: '模拟本地场馆', projectName: '羽毛球', feeDescription: '单打198元／单，双打120元／单，公益单打免费。全部为模拟资金，不真实转账。', registrationOpensAt: time(-1), registrationClosesAt: time(5), startsAt: time(7), endsAt: time(8), registrationReview: 'manual', rulesText: '本赛事及收款材料只供本地系统验证，不涉及真实比赛或转账。'}), 'create synthetic event');
  const createUnit = async (name, type, charged, amount, mode) => ok(await api('/sports/b/registrations/units', organizer, 'POST', {eventId: event.id, name, entryType: type, minMembers: type === 'pair' ? 2 : 1, maxMembers: type === 'pair' ? 2 : 1, limitCount: 8, requestKey: key(), charged, amount, paymentMode: mode, payInstruction: mode === 'offline' ? '模拟旧单元线下说明' : ''}), 'create unit');
  const unit = await createUnit('业余成人单打', 'individual', true, 123, 'event');
  const legacy = await createUnit('亲子双打', 'pair', true, 120, 'offline');
  const free = await createUnit('公益单打', 'individual', false, 0, 'free');
  const publishData = () => ({requestKey: key(), contactConfirmed: true, contactName: '模拟承办人', contactMethod: owner.phone});
  const blocked = await api('/sports/b/events/' + event.id + '/publish', organizer, 'POST', publishData());
  check(blocked.code !== 200 && blocked.msg.includes('收款渠道'), 'paid publication blocked until event channels are configured');
  let basic = ok(await api('/sports/b/events/' + event.id + '/promotion', organizer), 'initial promotion');
  check(basic.copySource === 'basic' && basic.groupBody.includes('123.00') && basic.invitation.includes('正式发布'), 'opening promotion immediately returns truthful draft basic copy');
  const orgContext = await browser.newContext({viewport: {width: 1440, height: 1000}});
  await orgContext.addInitScript(({org, platform}) => {localStorage.setItem('Admin-Token', org); localStorage.setItem('Platform-Token', platform);}, {org: organizer.token, platform: owner.token});
  const page = await orgContext.newPage(); page.on('pageerror', e => errors.push(e.message));
  await page.goto('http://127.0.0.1:5173/org-desk/workspace/' + event.id + '?task=projects');
  const row = page.locator('.el-table__row').filter({hasText: '业余成人单打'}), editor = row.locator('.b-inline-fee');
  await editor.waitFor();
  await editor.getByRole('radio', {name: '免费', exact: true}).click();
  check(await editor.getByRole('radio', {name: '免费', exact: true}).getAttribute('aria-checked') === 'true' && await page.getByRole('dialog', {name: '收费设置'}).count() === 0, 'free/paid slider edits outside dialogs');
  await Promise.all([page.waitForResponse(r => r.url().includes('/sports/b/fees/units?') && r.request().method() === 'GET'), editor.getByRole('button', {name: '保存', exact: true}).click()]);
  check(ok(await api('/sports/b/fees/units?eventId=' + event.id, organizer), 'free saved').find(u => u.unitId === unit.id).paymentMode === 'free', 'inline free choice persists zero price');
  await editor.getByRole('radio', {name: '收费', exact: true}).click();
  await editor.getByLabel('项目报名费').fill('198');
  await Promise.all([page.waitForResponse(r => r.url().includes('/sports/b/fees/units?') && r.request().method() === 'GET'), editor.getByRole('button', {name: '保存', exact: true}).click()]);
  check(Number(ok(await api('/sports/b/fees/units?eventId=' + event.id, organizer), 'paid saved').find(u => u.unitId === unit.id).amount) === 198, 'inline paid amount persists without per-project payment channels');
  await page.screenshot({path: path.join(out, 'projects-inline.png'), fullPage: true});
  await page.getByRole('link', {name: '前往赛事收款设置 →', exact: true}).click();
  const configPanel = page.locator('.b-event-payment'); await configPanel.getByRole('button', {name: '保存赛事收款设置'}).waitFor();
  await page.waitForFunction(() => !document.querySelector('.b-event-payment .el-button--primary')?.disabled);
  const png = Buffer.from(await page.evaluate(() => {
    const canvas = document.createElement('canvas'); canvas.width = 400; canvas.height = 260;
    const ctx = canvas.getContext('2d'); ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, 400, 260); ctx.fillStyle = '#19889a'; ctx.fillRect(25, 25, 80, 80); ctx.font = '20px sans-serif'; ctx.fillText('SIMULATED TEST CODE', 30, 155); ctx.fillText('NO REAL PAYMENT', 30, 205);
    return canvas.toDataURL('image/png').split(',')[1];
  }), 'base64');
  for (const label of ['微信', '支付宝', '自定义收款码']) {
    const channel = configPanel.locator('.b-payment-channel').filter({hasText: label});
    await channel.locator('.el-checkbox').click();
    if (label === '自定义收款码') await channel.getByLabel('自定义收款码名称').fill('模拟俱乐部码');
    const uploaded = page.waitForResponse(r => r.url().includes('/sports/b/media?purpose=payment-qr') && r.request().method() === 'POST');
    await channel.locator('input[type=file]').setInputFiles({name: 'SIMULATED-' + label + '.png', mimeType: 'image/png', buffer: png});
    ok(await (await uploaded).json(), 'real UI upload ' + label); await channel.locator('img').waitFor();
  }
  await configPanel.locator('.b-payment-channel').filter({hasText: '银行转账'}).locator('.el-checkbox').click();
  await configPanel.getByLabel('银行开户名').fill('模拟组织户名'); await configPanel.getByLabel('银行开户行').fill('模拟开户银行'); await configPanel.getByLabel('银行账号', {exact: true}).fill('SIMULATED-ACCOUNT-NO-REAL-TRANSFER');
  await configPanel.locator('.b-payment-channel').filter({hasText: '线下付款'}).locator('.el-checkbox').click(); await configPanel.getByLabel('线下付款付款说明').fill('联系模拟承办人，不真实付款');
  await configPanel.getByLabel('赛事统一付款说明').fill('模拟流程：付款时备注姓名及项目。上传凭证非强制，不代表实际到账。');
  const savedResponse = page.waitForResponse(r => r.url().endsWith('/' + event.id + '/payment-config') && r.request().method() === 'PUT');
  await configPanel.getByRole('button', {name: '保存赛事收款设置'}).click();
  const config = ok(await (await savedResponse).json(), 'real UI saves unified channels');
  check(config.channels.length === 5 && config.channels.filter(c => c.qrFileId).length === 3, 'all five channels save once at event level through real UI');
  await page.screenshot({path: path.join(out, 'event-channels.png'), fullPage: true, animations: 'disabled'});
  await page.setViewportSize({width: 390, height: 844}); await page.screenshot({path: path.join(out, 'event-channels-mobile.png'), fullPage: true, animations: 'disabled'});
  check(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), 'event payment settings have no mobile page overflow');
  const revised = ok(await api('/sports/b/fees/events/' + event.id + '/payment-config', organizer, 'PUT', {...config, instruction: config.instruction + '（已核对）'}), 'revise before formal submission');
  check((await api('/sports/b/fees/events/' + event.id + '/payment-config', organizer, 'PUT', config)).code !== 200, 'stale event payment revision cannot overwrite newer settings');
  const prices = ok(await api('/sports/b/fees/units?eventId=' + event.id, organizer), 'unified prices');
  check(prices.find(p => p.unitId === legacy.id).paymentMode === 'event' && prices.find(p => p.unitId === free.id).paymentMode === 'free', 'event settings also apply to existing charged projects while free projects stay free');
  check((await api('/sports/b/fees/events/' + event.id + '/payment-config', otherOrganizer)).code !== 200 && (await api('/sports/b/fees/events/' + event.id + '/payment-config', participant)).code !== 200, 'cross-organization and participant sessions cannot read collection settings');
  ok(await api('/sports/b/events/' + event.id + '/publish', organizer, 'POST', publishData()), 'publish configured event');
  const publicFees = ok(await api('/sports/public/events/' + event.id + '/fees', null), 'public fees');
  check(!JSON.stringify(publicFees).includes('SIMULATED-ACCOUNT') && !JSON.stringify(publicFees).includes(config.channels[0].qrFileId), 'public fee response does not expose bank accounts or collection QR file IDs');
  basic = ok(await api('/sports/b/events/' + event.id + '/promotion', organizer), 'updated promotion');
  check(basic.copySource === 'basic' && basic.groupBody.includes('198.00') && basic.groupPath.includes(event.id), 'basic copy follows changed amounts and contains published event link');
  if (process.argv[2] === 'generate-copy') {
    const generated = ok(await api('/sports/b/events/' + event.id + '/promotion', organizer, 'POST', {consent: true, note: '文案简洁自然，收费项目可写198元和120元，不要杜撰任何数字。'}), 'real configured model copy');
    check(generated.saved && generated.copySource === 'ai' && !generated.stale, 'real configured model generates and saves checked promotional copy');
  }
  let entry = ok(await api('/sports/c/registrations', participant, 'POST', {unitId: unit.id, requestKey: key()}), 'create registration');
  check((await api('/sports/c/registrations/' + entry.id + '/payment-instructions', participant)).code !== 200, 'unsubmitted draft has no payment instructions or obligation');
  entry = ok(await api('/sports/c/registrations/' + entry.id + '/submit', participant, 'POST', {requestKey: entry.requestKey}), 'formal submission');
  const instructions = ok(await api('/sports/c/registrations/' + entry.id + '/payment-instructions', participant), 'submitted instructions');
  check(entry.paymentMode === 'event' && Number(entry.feeAmount) === 198 && instructions.channels.length === 5 && instructions.instruction === revised.instruction, 'formal registration snapshots all event channels and its own 198 amount');
  check((await api('/sports/b/fees/events/' + event.id + '/payment-config', organizer, 'PUT', {...revised, channels: []})).code !== 200, 'collection settings lock after first formal submission');
  check((await api('/sports/b/fees/units/' + unit.id, organizer, 'POST', {amount: 199, paymentMode: 'event'})).code !== 200, 'project price also locks after first formal submission');
  check((await api('/sports/c/registrations/' + entry.id + '/payment-instructions', stranger)).code !== 200, 'stranger cannot read another registration bank and payment instructions');
  for (const type of ['wechat', 'alipay', 'custom_qr']) {
    const response = await fetch(base + '/sports/c/registrations/' + entry.id + '/payment-channels/' + type + '/qr', {headers: {clientid: clientId, Authorization: 'Bearer ' + participant.token}});
    check(response.headers.get('content-type').startsWith('image/') && Buffer.from(await response.arrayBuffer()).equals(png), type + ' authorized registration QR download preserves bytes');
  }
  const participantContext = await browser.newContext({viewport: {width: 390, height: 844}});
  await participantContext.addInitScript(token => {localStorage.setItem('Admin-Token', token); localStorage.setItem('Platform-Token', token);}, participant.token);
  const participantPage = await participantContext.newPage(); participantPage.on('pageerror', e => errors.push(e.message));
  await participantPage.goto('http://127.0.0.1:5173/portal/registration/detail/' + entry.id);
  await participantPage.getByRole('button', {name: '查看付款指引／我已付款'}).click();
  const paymentPanel = participantPage.locator('.b-payment-instructions'); await paymentPanel.locator('img').waitFor();
  await paymentPanel.getByRole('button', {name: '银行转账', exact: true}).click();
  check((await paymentPanel.innerText()).includes('SIMULATED-ACCOUNT-NO-REAL-TRANSFER'), 'participant selects bank payment in real mobile UI');
  await paymentPanel.getByRole('button', {name: '支付宝', exact: true}).click(); await paymentPanel.locator('img').waitFor();
  await participantPage.screenshot({path: path.join(out, 'participant-payment-mobile.png')});
  check(await participantPage.locator('.payment-proof-dialog').evaluate(el => el.getBoundingClientRect().bottom <= innerHeight && el.getBoundingClientRect().top >= 0), 'multi-channel participant dialog fits phone viewport');
  const uploadedProofResponse = participantPage.waitForResponse(r => r.url().includes('/payment-proofs?') && r.request().method() === 'POST');
  await participantPage.locator('.payment-proof-panel input[type=file]').setInputFiles({name: 'SIMULATED-RECEIPT.png', mimeType: 'image/png', buffer: png});
  const proof = ok(await (await uploadedProofResponse).json(), 'upload optional proof');
  check(proof.obligationId === entry.obligationId, 'optional proof links to same obligation as event-channel snapshot');
  check((await api('/sports/b/registrations/' + entry.id + '/approve', organizer, 'POST')).code !== 200, 'proof and unified payment instructions do not replace actual receipts');
  const occurredAt = new Date(Date.now() + 8 * 3600000).toISOString().slice(0,19).replace('T',' ');
  ok(await api('/sports/b/fees/obligations/' + entry.obligationId + '/confirm', organizer, 'POST', {payerName: '模拟付款人', amount: 198, occurredAt, note: 'SIMULATED: 无真实转账，仅验证统一渠道流程', requestKey: key()}), 'record simulated receipt');
  entry = ok(await api('/sports/b/registrations/' + entry.id + '/approve', organizer, 'POST'), 'approve fully paid registration');
  check(entry.status === 'approved' && entry.obligationStatus === 'settled', 'unified-channel paid registration reaches success after sufficient actual-receipt simulation and approval');
  check(ok(await api('/sports/c/registrations/' + entry.id + '/payment-instructions', participant), 'historical snapshot').instruction === revised.instruction, 'approved registration retains submitted payment snapshot');
  check(errors.length === 0, 'real organizer and participant interfaces have no script errors');
  await participantContext.close(); await orgContext.close();
  await fs.writeFile(path.join(out, 'results.json'), JSON.stringify({scope: 'real local ordinary roles, synthetic data and funds; optional real external copy model; no real transfer', eventId: event.id, unitId: unit.id, registrationId: entry.id, obligationId: entry.obligationId, passed: checks.length, checks, errors}, null, 2));
  console.log('EVENT PAYMENT PASS ' + checks.length + ' checks; evidence ' + out);
} finally {
  if (event) {const result = await api('/sports/b/events/' + event.id + '/offline', organizer, 'POST'); if (result.code !== 200) console.log('Synthetic event offline cleanup needs attention; eventId=' + event.id);}
  await browser.close();
}
