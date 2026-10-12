// Seal the current isolated package, immutable receipts and UI evidence; no successful write is replayed.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { context, readSql } from './lib/BusinessRegression.mjs';
const root = process.cwd();
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const relative = file => path.relative(root, path.resolve(file)).replaceAll('\\', '/');
const artifact = (file, role) => ({ path: relative(file), sha256: hash(fs.readFileSync(file)), role });
const backend = '.local/agent-runtime-20261012/build-a1233943e2be422ab40279fde56ff010/receipt.json';
const frontend = '.local/product-release-20261011/frontend-refinement-24b80ebcbc714ba289166ad31b32e8f5/receipt.json';
const runtimePath = '.local/phase1-implementation/verification-runtime.json';
const b = read(backend), f = read(frontend), runtime = read(runtimePath);
assert.ok(b.passed && f.passed, 'Final build and frontend receipts must actually pass');
assert.equal(context.database, 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b');
assert.equal(context.database, runtime.database);
assert.equal(b.jarSha256, runtime.jarSHA256); assert.equal(f.jarSha256, b.jarSha256);
assert.equal(hash(fs.readFileSync(runtime.jarPath)), b.jarSha256);
assert.equal(path.resolve(runtime.jarPath), path.join(root, '.local', 'runtime-packages', b.jarSha256, 'ruoyi-admin.jar'));
for (const source of [...b.sources, ...f.sources, ...f.assets]) assert.equal(hash(fs.readFileSync(source.path)), source.sha256, 'Current source/asset changed after checks: ' + source.path);
for (const log of f.logs) assert.equal(hash(fs.readFileSync(path.join(path.dirname(frontend), log.file))), log.sha256);
const javaLog = fs.readFileSync(path.join(path.dirname(backend), 'maven-package.log'), 'utf8');
const suites = [...javaLog.matchAll(/^\[INFO\] Tests run: (\d+), Failures: (\d+), Errors: (\d+), Skipped: (\d+), Time elapsed:.* -- in (.+)\r?$/gm)];
assert.equal(suites.length, 97); assert.ok(suites.every(m => m[2] === '0' && m[3] === '0' && m[4] === '0'));
const javaTests = suites.reduce((total, m) => total + Number(m[1]), 0); assert.equal(javaTests, 492);
const gatewayLog = fs.readFileSync(path.join(path.dirname(backend), 'gateway-tests.log'), 'utf8');
assert.match(gatewayLog, /tests 76/); assert.match(gatewayLog, /pass 76/); assert.match(gatewayLog, /fail 0/);
const utilityLog = fs.readFileSync(path.join(path.dirname(frontend), 'tests.log'), 'utf8').replace(/\u001b\[[0-9;]*m/g, '');
assert.match(utilityLog, /Test Files\s+9 passed/); assert.match(utilityLog, /Tests\s+46 passed/);
const migration = '.local/team-invite-experience-20261012/f0556f2ba04f4009a3efacc802e19341/migration-98dd013f2d284220b0952935ee089f38/receipt.json';
const m = read(migration); assert.ok(m.passed); assert.equal(m.database, context.database);
assert.equal(m.migrationSha256, hash(fs.readFileSync('database/migrations/V041__team_share_invitation.sql')));
assert.equal(readSql("SELECT checksum FROM aisports_schema_history WHERE version='V041';"), m.migrationSha256);
const book = '.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/';
const award = '.local/honor-repair-20261012/legacy-4af0e36c/';
const stages = [
  [migration, 5, 'Fresh backup, independent restore, forward/idempotent and rolled-back constraints before isolated activation'],
  ['.local/team-invite-experience-20261012/f0556f2ba04f4009a3efacc802e19341/flow-ef18739e-c8cd-4c74-be23-c4954c26089f/receipt.json', 25, 'Actual team share and join flow on the current Java package'],
  [book + 'registration-invite-experience-1791795523563-8574c9d1/receipt.json', 18, 'Actual targeted invitations and member removal; successful business writes not repeated'],
  [book + 'registration-invite-refresh-1791795693958-b01aa0cb/receipt.json', 5, 'Actual visible-page automatic notice refresh, 29497ms; references the earlier 18-check receipt'],
  [award + 'reading-07a50261-e858-4aa4-82f1-33e697b66e29/receipt.json', 13, 'One clean owned synthetic material save, unsaved security input and desktop/mobile reading'],
  [award + 'fixture-presentation-027da172-afed-4044-adf7-388807513fc5/receipt.json', 23, 'Final typography read-only fixture/score/award checks; references the first successful UI schedule without replay'],
  [book + 'product-readability-1791797276421-d4009510/receipt.json', 29, 'Final ordinary-role brand, typography, material and button contrast checks'],
  [book + 'header-brand-1791797091243-71b7aa14/receipt.json', 12, 'Fresh anonymous/signed-in desktop/mobile brand geometry and complete text'],
  ['.local/home-compact-20261012/6d39c30c-f99c-4e65-a7b7-50e183424ba1/receipt.json', 36, 'Four-width real-room/approved-entry homepage alignment, links and states; no business writes'],
  ['.local/assistant-draft-actions-20261012/ccac7027-ce59-46e6-8261-1dff93f381f0/receipt.json', 27, 'Final existing candidate read-only chat controls, actual send hit-test and unchanged stored task/files'],
  ['.local/team-invite-experience-20261012/greetings-3ecb6d5d-3c6f-41be-ac16-c11960019b96/receipt.json', 24, 'Final shared bubble real timers, opened-chat icon hiding, mute persistence and new login reset']
];
function screenshotFile(receiptPath, entry) {
  const file = typeof entry === 'string' ? entry : entry.file;
  const candidates = [path.resolve(file), path.resolve(path.dirname(receiptPath), file), path.resolve(path.dirname(receiptPath), '..', file)];
  const found = candidates.find(candidate => fs.existsSync(candidate)); assert.ok(found, 'Screenshot exists: ' + file);
  assert.ok(found.startsWith(root + path.sep), 'Evidence image must remain in this workspace');
  if (entry.sha256) assert.equal(hash(fs.readFileSync(found)), entry.sha256);
  return artifact(found, 'Actual synthetic UI screenshot, visually inspected');
}
const screenshots = [];
const evidence = stages.map(([file, count, role]) => {
  const receipt = read(file); assert.equal(receipt.passed, true, file); assert.equal(receipt.checks.length, count, file);
  assert.ok(receipt.checks.every(check => typeof check === 'string' || check.passed === true));
  if (receipt.jarSha256) assert.equal(receipt.jarSha256, b.jarSha256, file);
  for (const screenshot of receipt.screenshots || []) screenshots.push(screenshotFile(file, screenshot));
  return { ...artifact(file, role), observations: count, at: receipt.at, packageSha256: receipt.jarSha256 || null, prior: receipt.priorEvidence || null };
});
const partialVisual = '.local/assistant-draft-actions-20261012/a438b23a-81c5-438c-9d45-7d0a9acfbfb4/visual-review.json';
assert.equal(read(partialVisual).visualAccepted, false, 'The earlier obscured-send screenshots stay failed');
const finalVisual = '.local/assistant-draft-actions-20261012/ccac7027-ce59-46e6-8261-1dff93f381f0/visual-review.json';
assert.equal(read(finalVisual).visualAccepted, true);
const failureCandidates = [
  '.local/agent-runtime-20261012/build-5bb5b9ce3e6244a79d8b981339d4cf8e/receipt.json',
  '.local/product-release-20261011/frontend-refinement-9d8e395359bf4abbb1859c10f8d2a7e3/receipt.json',
  '.local/product-release-20261011/frontend-refinement-ee1f5bdf4a6b46e1a1d4dc9ce5c5af44/receipt.json',
  award + 'fixture-presentation-5779b0fc-fb84-44d8-8829-c0bdb1700177/receipt.json'
];
for (const directory of [book, '.local/team-invite-experience-20261012', '.local/assistant-draft-actions-20261012']) {
  for (const name of fs.readdirSync(directory)) {
    if (!/^(product-readability-|greetings-|ad42|3b2)/.test(name)) continue;
    const file = path.join(directory, name, 'receipt.json');
    if (fs.existsSync(file) && read(file).passed === false) failureCandidates.push(file);
  }
}
const retained = [...new Set(failureCandidates)].map(file => ({ ...artifact(file, 'Retained failure or partial observation; never rewritten as PASS'), passed: false }));
retained.push({ ...artifact(partialVisual, 'Earlier automated 26-pass stage rejected by actual visual review'), passed: false });
const oldIndex = 'docs/04-verification/奖项材料与队伍报名修复验证-20261012.json';
assert.equal(hash(fs.readFileSync(oldIndex)), 'f16dfda1da798b604e0f053acd50f33239645a2d5ec0236d2821770e7e93f3da');
const command = "$ErrorActionPreference='Stop';$p=Get-CimInstance Win32_Process -Filter ('ProcessId='+$env:AISPORTS_FINAL_JAVA_PID);if(!$p -or !$p.CommandLine.Contains($env:AISPORTS_FINAL_JAVA_JAR)){throw 'Package ownership changed'};$rows=@();foreach($port in @(8082,8091,5192)){$l=@(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop);if($l.Count -ne 1 -or $l[0].LocalAddress -ne '127.0.0.1'){throw 'Expected one loopback listener'};$rows+=@{port=$port;pid=$l[0].OwningProcess;address=$l[0].LocalAddress}};if(Get-NetTCPConnection -State Listen -LocalPort 8080,5190 -ErrorAction SilentlyContinue){throw 'Main services unexpectedly listening'};@{listeners=$rows;javaAlive=$true;mainOff=$true}|ConvertTo-Json -Depth 5 -Compress";
const processCheck = spawnSync('pwsh', ['-NoProfile', '-Command', command], { encoding: 'utf8', env: { ...process.env, AISPORTS_FINAL_JAVA_PID: String(runtime.pid), AISPORTS_FINAL_JAVA_JAR: runtime.jarPath } });
assert.equal(processCheck.status, 0, 'Live process/listener verification'); const live = JSON.parse(processCheck.stdout.trim());
for (const url of [context.frontend + '/portal/login', context.backend + '/sports/public/events']) assert.equal((await fetch(url, { signal: AbortSignal.timeout(10000) })).status, 200);
const generated = [];
for (const args of [['scripts/generate-model.py', '--check'], ['scripts/generate-table-modules.py', '--check'], ['scripts/Test-TableArchitecture.py']]) {
  const result = spawnSync('python', args, { encoding: 'utf8' }); assert.equal(result.status, 0, args[0]); generated.push({ entry: args.join(' '), passed: true, output: result.stdout.trim() });
}
const report = 'docs/04-verification/队伍邀请场次与体验修复验证-20261012.md';
const target = 'docs/04-verification/队伍邀请场次与体验修复验证-20261012.json'; assert.ok(!fs.existsSync(target), 'Never replace an existing immutable index');
const sources = ['database/model/catalog.py', 'database/model/catalog.json', 'database/schema/current.sql', 'database/migrations/V041__team_share_invitation.sql', 'docs/README.md', 'docs/01-development/交接记录.md', 'docs/01-development/一期未完成事项.md', 'docs/04-verification/验收映射.md', 'docs/03-architecture/ADR-042-队伍分享邀请与参赛办理体验.md', 'docs/03-architecture/ADR-043-品牌字号与聊天选择交互.md', 'docs/02-modeling/长期队伍分享邀请接口.md', 'docs/02-modeling/报名邀请身份与名单通知接口.md', 'docs/05-ui/队伍赛事与材料资源-20261012.md', 'scripts/Test-TeamShareMigration.ps1', 'scripts/Test-TeamShareFlow.mjs', 'scripts/Test-RegistrationInviteExperience.mjs', 'scripts/Test-RegistrationInviteRefresh.mjs', 'scripts/Test-FixturePresentationUI.mjs', 'scripts/Test-MaterialReadingExperience.mjs', 'scripts/Inspect-ProductReadability.mjs', 'scripts/Inspect-HeaderBrand.mjs', 'scripts/Test-CompactHomePresentationUI.mjs', 'scripts/Test-AssistantGreetingsUI.mjs', 'scripts/Test-AssistantDraftActionsUi.mjs', 'scripts/Test-ProductRefinementFrontend.ps1', 'scripts/Freeze-InvitationExperienceEvidence.mjs'];
const result = { schemaVersion: 1, at: new Date().toISOString(), timezone: 'Asia/Shanghai', passed: true, scope: 'User invitation/fixture/material improvements and subsequent brand/chat/home UI requests; ordinary-role isolated observations, not real full phase-one acceptance', database: context.database, packageSha256: b.jarSha256, java: { tests: javaTests, suites: suites.length, failures: 0, errors: 0, skipped: 0, receipt: artifact(backend, 'Accepted full offline build'), sources: b.sources }, gateway: { tests: 76, passed: true }, frontend: { utilityTests: 46, testFiles: 9, receipt: artifact(frontend, 'Accepted final typecheck/tests/build with unchanged source and assets'), sources: f.sources, assets: f.assets, largeChunkWarning: f.largeChunkWarning }, logs: ['maven-package.log', 'gateway-tests.log'].map(file => artifact(path.join(path.dirname(backend), file), 'Actual backend execution log')).concat(f.logs.map(log => artifact(path.join(path.dirname(frontend), log.file), 'Actual frontend execution log'))), live, generated, evidence, screenshots, finalChatVisual: artifact(finalVisual, 'Explicit final screenshot review'), retainedFailedOrPartialHistory: retained, earlierIndexUnchanged: artifact(oldIndex, 'Earlier sealed report retained unchanged'), sourceFiles: sources.map(file => artifact(file, 'Current model, contracts, decision, handoff or verification entry')), report: artifact(report, 'Human-readable report'), limitations: ['Existing-account web flow is verified; real first registration SMS/profile completion, WeChat miniapp and hardware phones are unverified.', 'Original customer events, actual funds and actual courts require responsible-person acceptance.', 'Earlier successful writes are referenced and were not replayed by final visual checks.', 'Stage observations are not aggregated into a real full business acceptance count.', 'Only the owned synthetic material current version was cleaned; original user material and history stay intact.', 'Whole-site historical-page, performance and soft-keyboard acceptance are incomplete; build retains its large-chunk warning.', 'No main activation, public exposure, remote commit or push; phase-one 21/17/7 gates are not globally closed.'] };
const temporary = target + '.' + crypto.randomUUID() + '.tmp'; const fd = fs.openSync(temporary, 'wx');
try { fs.writeFileSync(fd, JSON.stringify(result, null, 2) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
assert.ok(!fs.existsSync(target)); fs.renameSync(temporary, target); console.log('Sealed: ' + target);
