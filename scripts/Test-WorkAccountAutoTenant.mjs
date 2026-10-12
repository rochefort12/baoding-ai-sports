// Actual work-password regression in the existing isolated service only.
// Run after installing the new immutable backend package, with --backend-sha256.
// Fixtures are public-API-created synthetic system accounts; passwords live only
// in the ACL-protected .private.json checkpoint. No old account is changed.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {context as c,request,readSql,createEvidence} from './lib/BusinessRegression.mjs';

const expectedJar = process.argv[process.argv.indexOf('--backend-sha256') + 1];
if (!process.argv.includes('--backend-sha256') || !/^[a-f0-9]{64}$/.test(expectedJar || '')) {
  throw new Error('An explicitly selected installed backend SHA256 is required.');
}
const test = createEvidence('work-account-auto-tenant');
const stateFile = path.join(c.out, 'work-account-auto-tenant.private.json');
let stage = 'runtime ownership';
let failure;
let admin;
const sqlText = value => "'" + String(value).replaceAll("'", "''") + "'";
const identifier = value => {
  if (!/^\d+$/.test(String(value))) throw new Error('Unsafe numeric evidence identifier.');
  return String(value);
};
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
function powerShell7Executable() {
  // Desktop tools may resolve their shell alias to the bundled runtime. Node's
  // child_process does not perform that resolution, so verify a real PS7 file.
  const explicit = process.env.AISPORTS_TEST_PWSH;
  const candidates = explicit ? [explicit] : [
    path.join(process.env.ProgramFiles || 'C:/Program Files', 'PowerShell/7/pwsh.exe'),
    path.join(process.env.USERPROFILE || 'C:/Users/ADMIN', '.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'),
    ...(process.env.PATH || '').split(path.delimiter).filter(Boolean).map(entry => path.join(entry, 'pwsh.exe'))
  ];
  for (const candidate of [...new Set(candidates)]) {
    if (!fs.existsSync(candidate)) continue;
    const version = spawnSync(candidate, ['-NoProfile','-Command','$PSVersionTable.PSVersion.Major'], {encoding:'utf8'});
    if (version.status === 0 && version.stdout?.trim() === '7') return candidate;
  }
  throw new Error('A verified PowerShell 7 executable is required; no alternate shell is permitted.');
}
const parseRows = statement => {
  const result = readSql(statement);
  return result ? result.split(/\r?\n/).map(row => JSON.parse(row)) : [];
};
const expectOne = (rows, label) => {
  if (rows.length !== 1) throw new Error(label + ' is not unique.');
  return rows[0];
};
const saveState = () => {
  const temporary = stateFile + '.' + crypto.randomUUID() + '.tmp';
  const fd = fs.openSync(temporary, 'wx', 0o600);
  try { fs.writeFileSync(fd, JSON.stringify(state, null, 2)); fs.fsyncSync(fd); }
  finally { fs.closeSync(fd); }
  fs.renameSync(temporary, stateFile);
};
const fresh = () => {
  const suffix = crypto.randomUUID().slice(0, 6);
  const base = 'work-' + c.runId.slice(0, 8) + '-' + suffix;
  const password = () => 'Wrk-' + crypto.randomBytes(9).toString('hex') + '!';
  return {
    runId: c.runId, database: c.database, createdAt: new Date().toISOString(),
    marker: base, companyName: c.prefix + '-工作登录-' + suffix,
    packageId: '2106100000000000012',
    usernames: {different: base + '-d', ambiguous: base + '-s', unknown: base + '-unknown'},
    passwords: {defaultDifferent: password(), tenantDifferent: password(), ambiguous: password()},
    requests: {}, fixtures: {}
  };
};
let state;
if (fs.existsSync(stateFile)) {
  state = JSON.parse(fs.readFileSync(stateFile, 'utf8').replace(/^\uFEFF/, ''));
  if (state.runId !== c.runId || state.database !== c.database || !/^work-[a-f0-9]{8}-[a-f0-9]{6}$/.test(state.marker)) {
    throw new Error('Fixture checkpoint belongs to another protected run.');
  }
} else {
  state = fresh();
  saveState();
}

// Error messages are not written to evidence: auth/API implementations might
// echo an input. Only controlled stages and numeric HTTP/business codes survive.
async function checked(actor, route, method = 'GET', body) {
  const value = await request(actor, route, method, body);
  if (value.code !== 200) {
    const error = new Error('Business request rejected.');
    error.httpStatus = value.httpStatus;
    error.businessCode = value.code;
    throw error;
  }
  return value.data;
}
async function clearDynamic() {
  if (admin) await checked(admin, '/system/tenant/dynamic/clear');
}
async function inTenant(tenantId, operation) {
  if (!/^\d{6}$/.test(tenantId)) throw new Error('Unsafe test tenant.');
  await clearDynamic();
  try {
    await checked(admin, '/system/tenant/dynamic/' + tenantId);
    return await operation();
  } finally { await clearDynamic(); }
}
function userBinding(userId) {
  return expectOne(parseRows(`SELECT json_build_object('userId',user_id::text,'tenantId',tenant_id,'userName',user_name,'userType',user_type,'status',status,'deleted',del_flag,'deptId',dept_id::text) FROM sys_user WHERE user_id=${identifier(userId)};`), 'System account binding');
}
function existingBindingFingerprint() {
  // Explicit fields only. Never select sys_user.password or a derivative of it.
  return sha256(readSql(`SELECT json_build_object('userId',u.user_id::text,'tenantId',u.tenant_id,'userName',u.user_name,'userType',u.user_type,'status',u.status,'deleted',u.del_flag,'deptId',u.dept_id::text,'roles',(SELECT coalesce(json_agg(json_build_object('roleId',r.role_id::text) ORDER BY r.role_id),'[]'::json) FROM sys_user_role r WHERE r.user_id=u.user_id)) FROM sys_user u WHERE u.user_id IN(1,${identifier(c.government.id)}) ORDER BY u.user_id;`));
}
function sportsFingerprint() {
  const tables = ['organization','staff_grant','governance_grant','event','registration','registration_member','team','team_member','fee_obligation','payment','payment_allocation','refund','payment_action','payment_exception','result_version','honor','growth_record'];
  return sha256(readSql(tables.map(table => `SELECT '${table}='||count(*)||':'||md5(coalesce(string_agg(row_to_json(t)::text,'|' ORDER BY id),'')) FROM asp_${table} t;`).join('\n')));
}
async function login(username, password, grantType = 'work-password', extra = {}) {
  const value = await checked(null, '/auth/login', 'POST', {username, password, grantType, clientId:c.clientId, ...extra});
  if (!value?.access_token || typeof value.access_token !== 'string') throw new Error('Login returned no session.');
  return {token:value.access_token, clientId:value.client_id};
}
async function authenticated(label, username, password, expectedId, expectedTenant, extra = {}, grantType = 'work-password') {
  const actor = await login(username, password, grantType, extra);
  const info = await checked(actor, '/system/user/getInfo');
  const binding = userBinding(info.user?.userId);
  test.check(label, String(info.user?.userId) === String(expectedId)
    && info.user?.tenantId === expectedTenant && binding.tenantId === expectedTenant
    && binding.userName === username && binding.userType === 'sys_user'
    && binding.status === '0' && binding.deleted === '0', {tenantId:expectedTenant});
  return actor;
}
async function rejected(label, body, ambiguity = false) {
  const value = await request(null, '/auth/login', 'POST', body);
  const publicValue = JSON.stringify(value);
  const noSession = value.code !== 200 && !value.data?.access_token && !value.access_token;
  const noTenantDirectory = !/(tenantList|tenant_list|companyName|contactPhone|passwordHash)/i.test(publicValue)
    && !value.data?.tenants && !value.data?.tenantId;
  const exactAmbiguity = !ambiguity || (value.code !== 200 && String(value.msg || '').includes('多个组织'));
  test.check(label, noSession && noTenantDirectory && exactAmbiguity,
    {httpStatus:value.httpStatus, businessCode:value.code, noSession, noTenantDirectory});
}
function findTenant() {
  return parseRows(`SELECT json_build_object('id',id::text,'tenantId',tenant_id,'companyName',company_name,'status',status,'packageId',package_id::text,'remark',remark) FROM sys_tenant WHERE company_name=${sqlText(state.companyName)} AND del_flag='0';`);
}
function findUser(tenantId, username) {
  return parseRows(`SELECT json_build_object('userId',user_id::text,'tenantId',tenant_id,'userName',user_name,'nickName',nick_name,'userType',user_type,'status',status,'deleted',del_flag,'remark',remark) FROM sys_user WHERE tenant_id=${sqlText(tenantId)} AND user_name=${sqlText(username)};`);
}
async function ensureTenant() {
  let rows = findTenant();
  if (!rows.length) {
    if (state.fixtures.tenant) throw new Error('Previously created synthetic tenant disappeared; do not recreate.');
    state.requests.tenant = {attemptedAt:new Date().toISOString()};
    saveState();
    // A single valid package is reused; its roles/menus/permissions are not edited.
    await inTenant('000000', () => checked(admin, '/system/tenant', 'POST', {
      companyName:state.companyName, contactUserName:'工作登录核验', contactPhone:'13900000000',
      username:state.usernames.different, password:state.passwords.tenantDifferent,
      packageId:state.packageId, accountCount:-1, status:'0',
      intro:'独立合成账号登录边界核验，不是正式组织', remark:state.marker
    }));
    rows = findTenant();
  }
  const tenant = expectOne(rows, 'Run-prefixed synthetic tenant');
  if (tenant.remark !== state.marker || tenant.status !== '0' || tenant.packageId !== state.packageId
    || ['000000','100001','900001'].includes(tenant.tenantId)) throw new Error('Synthetic tenant ownership mismatch.');
  if (state.fixtures.tenant && state.fixtures.tenant.tenantId !== tenant.tenantId) throw new Error('Tenant checkpoint changed.');
  state.fixtures.tenant = {id:tenant.id, tenantId:tenant.tenantId};
  const owner = expectOne(findUser(tenant.tenantId, state.usernames.different), 'Automatically created tenant admin');
  if (owner.userType !== 'sys_user' || owner.status !== '0' || owner.deleted !== '0') throw new Error('Tenant admin is not a working system account.');
  // RuoYi's TENANT_ADMIN_ROLE_KEY is "admin"; "superadmin" is separate.
  const role = expectOne(parseRows(`SELECT json_build_object('roleId',role_id::text,'roleKey',role_key) FROM sys_role WHERE tenant_id=${sqlText(tenant.tenantId)} AND role_key='admin' AND status='0' AND del_flag='0';`), 'New tenant admin role');
  const dept = expectOne(parseRows(`SELECT json_build_object('deptId',dept_id::text) FROM sys_dept WHERE tenant_id=${sqlText(tenant.tenantId)} AND parent_id=0 AND status='0' AND del_flag='0';`), 'New tenant root department');
  state.fixtures.tenantOwner = {id:owner.userId, tenantId:tenant.tenantId};
  state.fixtures.tenantRoleId = role.roleId;
  state.fixtures.tenantDeptId = dept.deptId;
  saveState();
  test.check('public tenant creation produces one independent synthetic work identity', Boolean(owner.userId && role.roleId && dept.deptId), {tenantId:tenant.tenantId});
}
async function ensureUser(slot, tenantId, username, password, roleId, deptId) {
  let rows = findUser(tenantId, username);
  if (!rows.length) {
    if (state.fixtures[slot]) throw new Error('Previously created synthetic account disappeared; do not recreate.');
    state.requests[slot] = {attemptedAt:new Date().toISOString()};
    saveState();
    await inTenant(tenantId, () => checked(admin, '/system/user', 'POST', {
      userName:username, nickName:state.marker, password, userType:'sys_user', sex:'2',
      status:'0', roleIds:[roleId], postIds:[], deptId, remark:state.marker + ':' + slot
    }));
    rows = findUser(tenantId, username);
  }
  const user = expectOne(rows, 'Run-prefixed synthetic account');
  if (user.remark !== state.marker + ':' + slot || user.nickName !== state.marker
    || user.userType !== 'sys_user' || user.status !== '0' || user.deleted !== '0') throw new Error('Synthetic account ownership mismatch.');
  if (state.fixtures[slot] && state.fixtures[slot].id !== user.userId) throw new Error('Account checkpoint changed.');
  const roleCount = Number(readSql(`SELECT count(*) FROM sys_user_role WHERE user_id=${identifier(user.userId)} AND role_id=${identifier(roleId)};`));
  if (roleCount !== 1) throw new Error('Synthetic account role is not the requested existing role.');
  state.fixtures[slot] = {id:user.userId, tenantId};
  saveState();
  test.check('public account creation or exact checkpoint recovery: ' + slot, true, {tenantId});
}

try {
  const runtime = JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json', 'utf8').replace(/^\uFEFF/, ''));
  const jarHash = sha256(fs.readFileSync(runtime.jarPath));
  if (runtime.port !== 8082 || runtime.database !== c.database || runtime.jarSHA256 !== expectedJar || jarHash !== expectedJar) {
    throw new Error('Installed candidate package differs from the explicit expected release.');
  }
  const observation = spawnSync(powerShell7Executable(), ['-NoProfile','-Command',
    "$ErrorActionPreference='Stop';$taskPid=[int]$env:AISPORTS_TEST_RUNTIME_PID;$taskProcess=Get-CimInstance Win32_Process -Filter ('ProcessId='+$taskPid);$taskListeners=@(Get-NetTCPConnection -State Listen -LocalPort 8082);if(!$taskProcess -or !$taskProcess.CommandLine.Contains('--server.port=8082') -or !$taskProcess.CommandLine.Contains($env:AISPORTS_TEST_RUNTIME_JAR) -or $taskListeners.Count -ne 1 -or $taskListeners[0].LocalAddress -ne '127.0.0.1' -or $taskListeners[0].OwningProcess -ne $taskPid){throw 'Candidate runtime ownership mismatch'};Write-Output 'OWNED'"],
    {encoding:'utf8', env:{...process.env,AISPORTS_TEST_RUNTIME_PID:String(runtime.pid),AISPORTS_TEST_RUNTIME_JAR:runtime.jarPath}});
  test.check('new immutable candidate package owns only the isolated loopback service', observation.status === 0 && observation.stdout?.trim() === 'OWNED',
    {backendSha256:jarHash, backendPid:runtime.pid, runtimeProbe:{status:observation.status, signal:observation.signal, errorCode:observation.error?.code || null, ownedMarker:observation.stdout?.trim() === 'OWNED'}});
  test.evidence.backendSha256 = jarHash;
  test.evidence.backendPid = runtime.pid;
  test.evidence.scriptSha256 = sha256(fs.readFileSync(new URL(import.meta.url)));
  test.evidence.scope = 'Actual isolated HTTP work-account authentication and public sys tenant/user fixture APIs; no main database, SQL writes, credential reset or tournament mutations.';
  const existingBefore = existingBindingFingerprint();
  const sportsBefore = sportsFingerprint();
  stage = 'captcha prerequisite';
  const captcha = await checked(null, '/auth/code');
  test.check('test uses the actual disabled captcha setting without injecting a code', captcha?.captchaEnabled === false);
  stage = 'ordinary and administrator automatic authentication';
  const gov = expectOne(parseRows(`SELECT json_build_object('userName',user_name,'tenantId',tenant_id,'userType',user_type) FROM sys_user WHERE user_id=${identifier(c.government.id)} AND status='0' AND del_flag='0';`), 'Prepared ordinary government');
  if (gov.userName !== 'phase1-government' || gov.tenantId !== '000000' || gov.userType !== 'sys_user') throw new Error('Prepared ordinary government changed.');
  admin = await authenticated('administrator resolves its organization without a browser tenant', 'admin', c.password, '1', '000000');
  await authenticated('ordinary government resolves its organization without a browser tenant', gov.userName, c.password, c.government.id, '000000');
  await authenticated('forged participant tenant cannot redirect administrator authentication', 'admin', c.password, '1', '000000', {tenantId:'100001'});
  await authenticated('forged unknown tenant cannot redirect government authentication', gov.userName, c.password, c.government.id, '000000', {tenantId:'999999'});
  await authenticated('legacy password administrator contract remains compatible', 'admin', c.password, '1', '000000', {tenantId:'000000'}, 'password');
  await authenticated('legacy password ordinary government contract remains compatible', gov.userName, c.password, c.government.id, '000000', {tenantId:'000000'}, 'password');
  stage = 'authentication rejection boundaries';
  await rejected('unknown username returns no token or organization directory', {username:state.usernames.unknown, password:state.passwords.defaultDifferent, clientId:c.clientId, grantType:'work-password'});
  await rejected('wrong government password returns no token or organization directory', {username:gov.userName, password:state.passwords.defaultDifferent, clientId:c.clientId, grantType:'work-password'});
  await authenticated('a correct government password remains usable after one rejected attempt', gov.userName, c.password, c.government.id, '000000');
  await rejected('unknown client cannot grant a work session', {username:gov.userName, password:c.password, clientId:'unregistered-' + state.marker, grantType:'work-password'});
  await rejected('partial or compound grant cannot bypass the client grant directory', {username:gov.userName, password:c.password, clientId:c.clientId, grantType:'work-password,password'});
  const methods = await checked(null, '/auth/work-methods');
  test.check('public work login methods expose only WeChat availability', Object.keys(methods || {}).length === 1
    && Object.hasOwn(methods, 'wechat') && Object.keys(methods.wechat || {}).length === 1
    && typeof methods.wechat.available === 'boolean');
  stage = 'independent synthetic tenant fixture';
  const packageRow = expectOne(parseRows(`SELECT json_build_object('packageId',package_id::text,'status',status) FROM sys_tenant_package WHERE package_id=${identifier(state.packageId)} AND del_flag='0';`), 'Existing tenant package');
  if (packageRow.status !== '0') throw new Error('Fixture package is not active.');
  const defaultRole = expectOne(parseRows("SELECT json_build_object('roleId',role_id::text,'roleKey',role_key) FROM sys_role WHERE role_id=3 AND tenant_id='000000' AND status='0' AND del_flag='0';"), 'Existing ordinary default role');
  if (defaultRole.roleKey === 'superadmin') throw new Error('Fixture must not acquire superadministrator authority.');
  await ensureTenant();
  await ensureUser('defaultDifferent', '000000', state.usernames.different, state.passwords.defaultDifferent, '3', '100');
  await ensureUser('defaultAmbiguous', '000000', state.usernames.ambiguous, state.passwords.ambiguous, '3', '100');
  await ensureUser('tenantAmbiguous', state.fixtures.tenant.tenantId, state.usernames.ambiguous, state.passwords.ambiguous, state.fixtures.tenantRoleId, state.fixtures.tenantDeptId);
  stage = 'same username with different passwords';
  const tenantId = state.fixtures.tenant.tenantId;
  await authenticated('same username default password selects only the default work identity', state.usernames.different, state.passwords.defaultDifferent, state.fixtures.defaultDifferent.id, '000000');
  await authenticated('same username other password selects only its nondefault work identity', state.usernames.different, state.passwords.tenantDifferent, state.fixtures.tenantOwner.id, tenantId);
  await authenticated('forged nondefault tenant cannot redirect the default same-name password', state.usernames.different, state.passwords.defaultDifferent, state.fixtures.defaultDifferent.id, '000000', {tenantId});
  await authenticated('forged default tenant cannot redirect the nondefault same-name password', state.usernames.different, state.passwords.tenantDifferent, state.fixtures.tenantOwner.id, tenantId, {tenantId:'000000'});
  await authenticated('legacy explicit tenant contract works for the default same-name account', state.usernames.different, state.passwords.defaultDifferent, state.fixtures.defaultDifferent.id, '000000', {tenantId:'000000'}, 'password');
  await authenticated('legacy explicit tenant contract works for the nondefault same-name account', state.usernames.different, state.passwords.tenantDifferent, state.fixtures.tenantOwner.id, tenantId, {tenantId}, 'password');
  stage = 'ambiguous verified credentials';
  await rejected('two real password matches safely reject without exposing a tenant directory', {username:state.usernames.ambiguous, password:state.passwords.ambiguous, clientId:c.clientId, grantType:'work-password'}, true);
  await rejected('forged default tenant cannot choose one of two verified identities', {username:state.usernames.ambiguous, password:state.passwords.ambiguous, clientId:c.clientId, grantType:'work-password', tenantId:'000000'}, true);
  await rejected('forged nondefault tenant cannot choose one of two verified identities', {username:state.usernames.ambiguous, password:state.passwords.ambiguous, clientId:c.clientId, grantType:'work-password', tenantId}, true);
  stage = 'preservation and cleanup';
  await clearDynamic();
  const finalAdmin = await checked(admin, '/system/user/getInfo');
  test.check('fixture operations leave administrator in its original default organization', String(finalAdmin.user?.userId) === '1' && finalAdmin.user?.tenantId === '000000');
  test.check('existing administrator and government identity and roles remain unchanged', existingBindingFingerprint() === existingBefore);
  test.check('organization grants, teams, registrations, money, results and growth remain unchanged', sportsFingerprint() === sportsBefore);
  test.evidence.objects = {newTenantId:tenantId, newTenantPrimaryId:state.fixtures.tenant.id,
    newSyntheticUserIds:[state.fixtures.tenantOwner.id, state.fixtures.defaultDifferent.id, state.fixtures.defaultAmbiguous.id, state.fixtures.tenantAmbiguous.id]};
  test.evidence.notExecuted = ['Real WeChat OAuth callback and account binding', 'APP_USER / reserved tenant / mapped organizer direct-login cases are separately covered by backend unit tests', 'Main service login and user-interface acceptance'];
} catch (error) {
  failure = {stage, kind:error?.name || 'Error', ...(Number.isFinite(error?.httpStatus) ? {httpStatus:error.httpStatus} : {}), ...(Number.isFinite(error?.businessCode) ? {businessCode:error.businessCode} : {})};
} finally {
  try { await clearDynamic(); }
  catch (error) { failure = failure || {stage:'finally dynamic tenant cleanup', kind:error?.name || 'Error'}; }
}
if (failure) {
  test.evidence.failure = failure;
  test.save();
  console.error('FAIL work account regression at ' + failure.stage + '; diagnostics are sanitized.');
  process.exitCode = 1;
} else { test.finish(); }
