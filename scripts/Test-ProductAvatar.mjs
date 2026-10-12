// Real HTTP/storage verification against the existing guarded isolated service only.
// Recovery sessions stay in memory; reports never contain tokens, passwords or request bodies.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';

const root = process.cwd();
const stateRoot = path.join(root, '.local/phase1-implementation');
const runtime = JSON.parse(fs.readFileSync(path.join(stateRoot, 'verification-runtime.json'), 'utf8'));
const state = JSON.parse(fs.readFileSync(path.join(stateRoot, 'verification-session.json'), 'utf8'));
assert.ok(/^aisports_verify_phase1_[a-f0-9]{32}$/.test(runtime.database), 'Guard: isolated database identity');
assert.equal(runtime.port, 8082, 'Guard: only isolated HTTP port 8082');
assert.equal(state.database, runtime.database, 'Guard: recovery session belongs to isolated database');
assert.ok(Number.isSafeInteger(runtime.pid) && runtime.pid > 0, 'Guard: runtime PID');
const base = 'http://127.0.0.1:8082';
const out = path.join(root, '.local/product-release-20261011');
fs.mkdirSync(out, { recursive: true });
const report = { timestamp: new Date().toISOString(), scope: 'Real local HTTP and object storage with fictional accounts and a generated sports image. No real-person avatar, real event, bank, SMS or model acceptance.', backend: base, database: runtime.database, jarSHA256: runtime.jarSHA256, checks: [], restoration: 'not_started' };
const reportPath = path.join(out, 'avatar-http-' + Date.now() + '-' + crypto.randomBytes(4).toString('hex') + '.json');
const sha256 = body => crypto.createHash('sha256').update(body).digest('hex');
function check(name, actual, expected = true) {
  assert.deepEqual(actual, expected, name);
  report.checks.push({ name, passed: true });
  console.log('PASS ' + name);
}
function sql(query) {
  // Only caller-owned fixed SELECT statements are accepted by this helper.
  assert.ok(/^SELECT\s/i.test(query) && !/\b(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|TRUNCATE)\b/i.test(query), 'Guard: read-only fixture query');
  const result = spawnSync('C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe', ['-X', '-h', '127.0.0.1', '-p', process.env.POSTGRES_PORT, '-U', process.env.POSTGRES_USER, '-d', runtime.database, '-At', '-v', 'ON_ERROR_STOP=1'], { input: query, encoding: 'utf8', env: { ...process.env, PGPASSWORD: process.env.POSTGRES_PASSWORD } });
  if (result.status !== 0) throw new Error('Read-only isolated fixture verification failed; credential-free report retained');
  return result.stdout.trim();
}
async function request(actor, route, options = {}) {
  const response = await fetch(base + route, { ...options, headers: { clientid: actor?.clientId || 'e5cd7e4891bf95d1d19206ce24a7b32e', ...(actor?.token ? { Authorization: 'Bearer ' + actor.token } : {}), ...(options.headers || {}) }, signal: AbortSignal.timeout(20000) });
  const bytes = Buffer.from(await response.arrayBuffer());
  const contentType = response.headers.get('content-type') || '';
  let json;
  if (contentType.includes('json')) { try { json = JSON.parse(bytes.toString('utf8')); } catch { throw new Error('Malformed JSON response'); } }
  return { status: response.status, contentType, bytes, json, cacheControl: response.headers.get('cache-control'), nosniff: response.headers.get('x-content-type-options') };
}
async function api(actor, route, method = 'GET', body) {
  const response = await request(actor, route, { method, ...(body === undefined ? {} : { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }) });
  if (response.json?.code !== 200) throw new Error('Expected successful isolated API: ' + route + ' (code ' + (response.json?.code || response.status) + ')');
  return response.json.data;
}
async function upload(actor, version, bytes, filename, type) {
  const data = new FormData();
  data.append('file', new Blob([bytes], { type }), filename);
  return request(actor, '/sports/display/avatar?expectedVersion=' + version, { method: 'POST', body: data });
}
async function visibility(actor, current, publicVisible) {
  const input = { nickname: current.display.nickname, avatarStyle: current.display.avatar_style, tagline: current.display.tagline || '', publicVisible, expectedVersion: Number(current.display.version) };
  const result = await api(actor, '/sports/platform/actions/profile.display/execute', 'POST', { input, requestKey: crypto.randomUUID() });
  assert.ok(result.receiptId, 'Registered display action returns a real business receipt');
  return api(actor, '/sports/display');
}

let actor, original, current, visibilityChanged = false;
try {
  const guard = spawnSync('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe', ['-NoProfile', '-Command', 'if($PSVersionTable.PSVersion.Major -lt 7){throw "PowerShell 7 required"}; $row=Get-CimInstance Win32_Process -Filter "ProcessId=' + runtime.pid + '"; $port=Get-NetTCPConnection -State Listen -LocalPort 8082 -ErrorAction Stop; if(!$row -or $row.CommandLine -notlike "*体育*ruoyi-admin.jar*--server.port=8082*" -or !($port.OwningProcess -contains ' + runtime.pid + ')){throw "Isolated process identity mismatch"}; Write-Output "ISOLATED_PROCESS_VERIFIED"'], { encoding: 'utf8' });
  check('live 8082 listener belongs to the receipt-owned sports Java process', guard.status === 0 && guard.stdout.includes('ISOLATED_PROCESS_VERIFIED'));
  check('read-only database identity matches isolated receipt', sql('SELECT current_database();'), runtime.database);
  const jar = fs.readFileSync(path.join(root, 'backend/ruoyi-admin/target/ruoyi-admin.jar'));
  check('running release receipt matches current local JAR bytes', sha256(jar), runtime.jarSHA256.toLowerCase());
  actor = state.people[0];
  for (const person of state.people) assert.ok(/^\d+$/.test(person.id), 'Guard: fixture account IDs');
  assert.ok(actor?.token, 'Recovered participant session exists');
  original = await api(actor, '/sports/display');
  check('ordinary participant reads only their own display profile', original.accountId, actor.id);
  check('fixture begins with a private display profile', original.display.public_visible, false);
  current = original;
  const related = state.people.filter(person => person.id !== actor.id).map(person => ({ person, count: Number(sql('SELECT count(*) FROM asp_team_room_member mine JOIN asp_team_room_member peer ON peer.room_id=mine.room_id WHERE mine.account_id=' + actor.id + ' AND peer.account_id=' + person.id + " AND mine.status='active' AND peer.status='active';")), any: Number(sql('SELECT count(*) FROM asp_team_member mine JOIN asp_account a ON a.person_id=mine.person_id JOIN asp_team_member peer ON peer.team_id=mine.team_id JOIN asp_account b ON b.person_id=peer.person_id WHERE a.id=' + actor.id + ' AND b.id=' + person.id + " AND mine.status='active' AND peer.status='active';")) }));
  const peer = related.find(item => item.count > 0)?.person;
  const unrelated = related.find(item => item.count === 0 && item.any === 0)?.person;
  check('fixtures include an active room peer and an unrelated ordinary account', Boolean(peer && unrelated));
  const asset = fs.readFileSync(path.join(root, 'plus-ui/public/images/sports/brand-mark-v1.webp'));
  report.fixture = { avatar: 'Generated sports mark used as a fictional avatar', sha256: sha256(asset), bytes: asset.length, accountId: actor.id, peerId: peer.id, unrelatedId: unrelated.id };
  const oldVersion = Number(current.display.version);
  const uploaded = await upload(actor, oldVersion, asset, 'fictional-sports-avatar.webp', 'image/webp');
  check('multipart upload returns a real file and profile version receipt', uploaded.json?.code === 200 && /^\d+$/.test(uploaded.json.data?.fileId || '') && Number.isInteger(uploaded.json.data?.version));
  current = await api(actor, '/sports/display');
  check('profile references the uploaded avatar file', current.display.avatar_file_id, uploaded.json.data.fileId);
  check('avatar upload advances the existing profile version', Number(current.display.version) > oldVersion);
  const stale = await upload(actor, oldVersion, asset, 'stale-avatar.webp', 'image/webp');
  check('stale profile version is rejected without overwriting the avatar', stale.json?.code, 409);
  const invalid = await upload(actor, Number(current.display.version), Buffer.from('Not an image. Fictional local acceptance fixture.'), 'fake-avatar.png', 'image/png');
  check('non-image bytes are rejected despite image filename and MIME', invalid.json?.code !== 200);
  const afterReject = await api(actor, '/sports/display');
  check('rejected uploads preserve the file reference and object version', { file: afterReject.display.avatar_file_id, version: Number(afterReject.display.version) }, { file: current.display.avatar_file_id, version: Number(current.display.version) });
  const self = await request(actor, '/sports/display/avatar/' + actor.id);
  check('owner reads exact stored avatar bytes through the protected endpoint', self.status === 200 && self.contentType.includes('image/webp') && sha256(self.bytes) === sha256(asset));
  check('private avatar disables caches and content sniffing', { cache: self.cacheControl, nosniff: self.nosniff }, { cache: 'no-store', nosniff: 'nosniff' });
  const teammate = await request(peer, '/sports/display/avatar/' + actor.id);
  check('active room peer reads the necessary display avatar', teammate.status === 200 && teammate.contentType.includes('image/webp') && sha256(teammate.bytes) === sha256(asset));
  const outsider = await request(unrelated, '/sports/display/avatar/' + actor.id);
  check('unrelated ordinary account cannot read a private avatar', outsider.json?.code, 403);
  const workAccount = await request(state.government, '/sports/display/avatar/' + actor.id);
  check('government work identity cannot borrow participant avatar access', workAccount.json?.code !== 200);
  const anonymousPrivate = await request(null, '/sports/display/avatar/' + actor.id);
  check('anonymous request cannot enter the protected avatar endpoint', anonymousPrivate.json?.code !== 200 && !anonymousPrivate.contentType.startsWith('image/'));
  const anonymousDefault = await request(null, '/sports/display/public/' + actor.id + '/avatar');
  check('anonymous public route denies a default-private avatar', anonymousDefault.json?.code, 404);
  current = await visibility(actor, current, true); visibilityChanged = true;
  check('public opt-in is persisted by the registered profile.display action', current.display.public_visible, true);
  const anonymousPublic = await request(null, '/sports/display/public/' + actor.id + '/avatar');
  check('anonymous avatar access follows explicit public opt-in', anonymousPublic.status === 200 && anonymousPublic.contentType.includes('image/webp') && sha256(anonymousPublic.bytes) === sha256(asset));
  check('public avatar also remains uncached after privacy changes', anonymousPublic.cacheControl, 'no-store');
  current = await visibility(actor, current, false); visibilityChanged = false;
  const hiddenAgain = await request(null, '/sports/display/public/' + actor.id + '/avatar');
  check('closing public display immediately restores anonymous denial', hiddenAgain.json?.code, 404);
  const readableAgain = await request(actor, '/sports/display/avatar/' + actor.id);
  check('owner retains avatar access after closing public display', readableAgain.contentType.includes('image/webp'));
  report.restoration = 'Original private visibility restored; generated fictional avatar retained for browser crop/upload continuation.';
  report.passed = true;
} catch (error) {
  report.passed = false;
  report.failure = String(error.message).replace(/Bearer\s+[^\s]+/gi, 'Bearer [redacted]');
  console.log('FAIL avatar HTTP verification; immutable credential-free report retained');
  process.exitCode = 1;
} finally {
  if (visibilityChanged && actor && original) {
    try {
      const latest = await api(actor, '/sports/display');
      await visibility(actor, latest, Boolean(original.display.public_visible));
      report.restoration = 'Original display visibility restored in failure cleanup.';
    } catch { report.restoration = 'Visibility cleanup failed; operator must retry through the profile action.'; report.passed = false; process.exitCode = 1; }
  }
  report.finishedAt = new Date().toISOString();
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2), { flag: 'wx' });
  console.log('Immutable avatar report: ' + path.relative(root, reportPath));
}
