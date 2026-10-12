// Three independent real browser logins through the LAN frontend. Authentication only;
// no profile, organization, registration, model request or other business mutation.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const { chromium } = require('playwright');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const batch = path.resolve('.local/three-person-test-20261012/d23b25203cba4df8b509ee77d8be1249');
const statePath = path.join(batch, 'state.private.json');
const state = read(statePath);
const context = read('.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json');
assert.equal(state.database, 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b');
const accounts = ['A', 'B', 'C'].map(code => state.accounts.find(account => account.code === code));
assert.ok(accounts.every(account => account && account.profileKind === 'blank-primary'));
assert.equal(new Set(accounts.map(account => account.accountId)).size, 3);
const base = 'http://192.168.1.236:5193';
const out = path.join(batch, 'ui-readonly-' + crypto.randomUUID());
fs.mkdirSync(out);
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const sources = ['plus-ui/src/utils/actionFingerprint.ts', 'plus-ui/src/utils/requestKey.ts'];
const sourceHashes = () => Object.fromEntries(sources.map(file => [file, sha256(fs.readFileSync(file))]));
const report = { at: new Date().toISOString(), scope: 'Actual LAN HTTP browser form login with three isolated ordinary-account contexts; no profile/application/registration or AI mutation.', base, checks: [], actors: [], screenshots: [], blockedWrites: [], errors: [], sourceBefore: sourceHashes(), stateBeforeSha256: sha256(fs.readFileSync(statePath)), secondPhysicalDevice: 'NOT_RUN', passed: false };
const save = () => fs.writeFileSync(path.join(out, 'receipt.json'), JSON.stringify(report, null, 2));
const check = (name, condition, details = {}) => { report.checks.push({ name, passed: !!condition, ...details }); save(); assert.ok(condition, name); };
function sanitized(error) {
  let message = String(error?.message || error);
  for (const account of state.accounts) for (const value of [account.password, account.phone, account.session?.access_token, account.session?.token].filter(Boolean)) message = message.replaceAll(String(value), '[REDACTED]');
  return message.replace(/Bearer\s+[^\s]+/gi, 'Bearer [REDACTED]').replace(/https?:\/\/[^\s)]+/g, '[URL REDACTED]').slice(0, 400);
}
async function snapshot(page) {
  return page.evaluate(async clientId => {
    let token = localStorage.getItem('Admin-Token'); try { token = JSON.parse(token); } catch {}
    const headers = { Authorization: 'Bearer ' + token, clientid: clientId };
    const get = async route => { const response = await fetch('/dev-api' + route, { headers }); const value = await response.json(); if (!response.ok || value.code !== 200) throw new Error('Read-only account API failed'); return value.data; };
    const [identity, organization, entries, display] = await Promise.all(['/sports/c/identity', '/sports/c/organization/application', '/sports/c/registrations', '/sports/display'].map(get));
    const rows = Array.isArray(entries) ? entries : entries?.rows || entries?.records;
    return { accountId: String(identity?.accountId || ''), noSelf: identity?.self == null, noOrganization: !organization?.applicationId && !organization?.organizationId && organization?.canEnter === false, noRegistration: Array.isArray(rows) && rows.length === 0, nickname: display?.display?.nickname || '' };
  }, context.clientId);
}
async function screenshot(page, file) {
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await page.screenshot({ path: path.join(out, file) });
  report.screenshots.push({ file, sha256: sha256(fs.readFileSync(path.join(out, file))) }); save();
}
let browser;
save();
try {
  browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
  for (const account of accounts) {
    const browserContext = await browser.newContext({ viewport: account.code === 'C' ? { width: 390, height: 844 } : { width: 1440, height: 1000 }, reducedMotion: 'reduce' });
    const page = await browserContext.newPage(); page.setDefaultTimeout(25000);
    const actor = { code: account.code, viewport: account.code === 'C' ? '390px mobile' : '1440px desktop', authenticationPosts: 0 }; report.actors.push(actor); save();
    page.on('pageerror', () => { report.errors.push({ code: account.code, message: 'Browser script error; raw private content omitted' }); save(); });
    await browserContext.route('**/*', route => {
      const request = route.request(), url = new URL(request.url()), method = request.method();
      if (['GET', 'HEAD', 'OPTIONS'].includes(method)) return route.continue();
      if (method === 'POST' && url.origin === base && url.pathname === '/dev-api/auth/login') { actor.authenticationPosts++; save(); return route.continue(); }
      report.blockedWrites.push({ code: account.code, method, path: url.pathname }); save(); return route.abort('blockedbyclient');
    });
    await page.goto(base + '/portal/login?returnTo=/portal/home', { waitUntil: 'domcontentloaded' });
    check(account.code + ': fresh context starts with no previous browser token', await page.evaluate(() => !localStorage.getItem('Admin-Token')));
    await page.getByPlaceholder('请输入手机号', { exact: true }).fill(account.phone);
    await page.getByPlaceholder('请输入密码', { exact: true }).fill(account.password);
    await page.getByRole('button', { name: '登录', exact: true }).click();
    await page.waitForURL(url => url.pathname === '/portal/home');
    await page.locator('.header-account').waitFor({ state: account.code === 'C' ? 'attached' : 'visible' });
    const before = await snapshot(page);
    check(account.code + ': form login belongs to its prepared account', before.accountId === String(account.accountId));
    check(account.code + ': no self profile, organization application or registration exists', before.noSelf && before.noOrganization && before.noRegistration);
    await page.waitForFunction(nickname => document.querySelector('.header-account .account-name')?.textContent.trim() === nickname, before.nickname);
    if (account.code === 'C') {
      // Mobile header intentionally keeps only the avatar. The existing read-only
      // identity page shows the full display nickname without filling its form.
      await page.goto(base + '/portal/identity', { waitUntil: 'domcontentloaded' });
      await page.locator('.profile-person .sports-avatar > strong').waitFor();
      check(account.code + ': logged-in mobile page visibly identifies its own display profile', !!before.nickname && (await page.locator('.profile-person .sports-avatar > strong').innerText()).trim() === before.nickname && await page.getByRole('button', { name: '退出登录', exact: true }).isVisible());
    } else {
      check(account.code + ': logged-in page visibly identifies its own display profile', !!before.nickname && (await page.locator('.header-account .account-name').innerText()).trim() === before.nickname && await page.getByRole('button', { name: '退出', exact: true }).isVisible());
    }
    const cryptoEvidence = await page.evaluate(async () => {
      const { sha256Hex } = await import('/src/utils/actionFingerprint.ts');
      const { newRequestKey } = await import('/src/utils/requestKey.ts');
      return { secureContext: isSecureContext, subtleAvailable: typeof globalThis.crypto?.subtle?.digest === 'function', digest: await sha256Hex(new TextEncoder().encode('abc')), uuid: newRequestKey() };
    });
    check(account.code + ': actual LAN HTTP is insecure and digest fallback matches known SHA-256', cryptoEvidence.secureContext === false && cryptoEvidence.subtleAvailable === false && cryptoEvidence.digest === 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', { secureContext: cryptoEvidence.secureContext, subtleAvailable: cryptoEvidence.subtleAvailable, digest: cryptoEvidence.digest });
    check(account.code + ': request key works in actual LAN browser', /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(cryptoEvidence.uuid));
    // Never capture the login form, password field or token values.
    await screenshot(page, 'account-' + account.code + '-logged-in.png');
    const after = await snapshot(page);
    check(account.code + ': read-only UI preparation preserves empty business state', JSON.stringify(before) === JSON.stringify(after));
    check(account.code + ': only one form-login POST occurred', actor.authenticationPosts === 1 && !report.blockedWrites.some(write => write.code === account.code));
    actor.ownIdentityMatched = true; actor.noSelf = true; actor.noOrganization = true; actor.noRegistration = true;
    await browserContext.close();
  }
  report.stateAfterSha256 = sha256(fs.readFileSync(statePath));
  report.sourceAfter = sourceHashes();
  check('Private prepared account state file is unchanged', report.stateBeforeSha256 === report.stateAfterSha256);
  check('LAN fallback utility source stayed unchanged during browser verification', JSON.stringify(report.sourceBefore) === JSON.stringify(report.sourceAfter));
  check('No model/business write attempts or browser script errors', !report.blockedWrites.length && !report.errors.length);
  report.passed = true;
} catch (error) { report.failure = sanitized(error); process.exitCode = 1; }
finally {
  if (browser) await browser.close();
  report.finishedAt = new Date().toISOString(); save();
  console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failure: report.failure, screenshots: report.screenshots.length, evidence: out, receiptSha256: sha256(fs.readFileSync(path.join(out, 'receipt.json'))), secondPhysicalDevice: 'NOT_RUN' }));
}
