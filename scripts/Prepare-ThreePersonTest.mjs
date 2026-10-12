// New local fixture identities only. No old passwords, organizations, admissions,
// registrations, money, results or capability releases are changed by this entry.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';

const workspace = process.cwd();
const expectedDb = 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b';
const expectedJar = 'cdf0321b954b7551f9f52a50b256f195678f5f540e028bcde3ed1a010ce8474e';
const real = value => fs.realpathSync(value);
const run = real(process.env.AISPORTS_THREE_PERSON_RUN || '');
const allowedRunRoot = real(path.join(workspace, '.local/three-person-test-20261012'));
if (path.dirname(run) !== allowedRunRoot || !/^[a-f0-9]{32}$/.test(path.basename(run))) throw Error('A protected, unique batch directory is required.');
const runId = path.basename(run);
const contextPath = real(process.env.AISPORTS_REGRESSION_CONTEXT || '');
if (!contextPath.startsWith(real(path.join(workspace, '.local/business-regression-20261011')) + path.sep)) throw Error('Select a verified private backup context.');
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const context = readJson(contextPath);
const preflight = readJson(path.join(path.dirname(contextPath), 'preflight-receipt.json'));
const guard = readJson(path.join(run, 'runtime-guard.json'));
const runtime = readJson(path.join(workspace, '.local/phase1-implementation/verification-runtime.json'));
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
if (context.database !== expectedDb || preflight.database !== expectedDb || !preflight.passed || runtime.database !== expectedDb || runtime.port !== 8082 || runtime.jarSHA256 !== expectedJar || guard.database !== expectedDb || guard.pid !== runtime.pid || guard.jarSha256 !== expectedJar || !guard.aclPassed || Date.now() - Date.parse(guard.at) > 600000) throw Error('Exact protected runtime/backup preflight is required.');
if (context.backend !== 'http://127.0.0.1:8082' || context.frontend !== 'http://127.0.0.1:5192') throw Error('Unexpected service scope.');
if (sha(fs.readFileSync(path.join(path.dirname(contextPath), 'before-business-tests.dump'))) !== preflight.backupSha256) throw Error('Backup bytes do not match verified evidence.');
const psql = process.env.AISPORTS_THREE_PERSON_PSQL;
if (!psql || !fs.existsSync(psql)) throw Error('Prepared PostgreSQL toolchain is required.');
const sqlLiteral = value => "'" + String(value).replaceAll("'", "''") + "'";
const sqlId = value => { if (!/^\d+$/.test(String(value))) throw Error('Invalid owned identifier.'); return String(value); };
function sql(statement, write = false) {
  const result = spawnSync(psql, ['-X','-h','127.0.0.1','-p',process.env.POSTGRES_PORT,'-U',process.env.POSTGRES_USER,'-d',expectedDb,'-At','-q','-v','ON_ERROR_STOP=1'], {
    input:write ? statement : 'BEGIN READ ONLY;\n' + statement + '\nROLLBACK;', encoding:'utf8',
    env:{...process.env,PGPASSWORD:process.env.POSTGRES_PASSWORD}, maxBuffer:8 * 1024 * 1024
  });
  if (result.status !== 0) throw Error(write ? 'New identity transaction failed; no partial seed is permitted.' : 'Read-only isolated identity verification failed.');
  return result.stdout.trim();
}
if (sql('SELECT current_database();') !== expectedDb) throw Error('Database ownership check failed.');
if (!Array.isArray(guard.databaseClientPorts)||!guard.databaseClientPorts.length||guard.databaseClientPorts.some(p=>!Number.isInteger(p)||p<1||p>65535)||Number(sql(`SELECT count(*) FROM pg_stat_activity WHERE datname=${sqlLiteral(expectedDb)} AND client_addr='127.0.0.1'::inet AND client_port IN(${guard.databaseClientPorts.join(',')});`))===0) throw Error('Active Java PostgreSQL sockets do not belong to the exact isolated database.');
function atomicJson(file, value) {
  const temporary = file + '.tmp-' + crypto.randomUUID();
  const descriptor = fs.openSync(temporary, 'wx');
  try { fs.writeFileSync(descriptor, JSON.stringify(value, null, 2)); fs.fsyncSync(descriptor); }
  finally { fs.closeSync(descriptor); }
  fs.renameSync(temporary, file);
}
const checkpoint = path.join(run, 'state.private.json');
let state = fs.existsSync(checkpoint) ? readJson(checkpoint) : null;
const attemptId = crypto.randomUUID();
const receiptFile = path.join(run, 'receipt-' + attemptId + '.json');
const receipt = {at:new Date().toISOString(),runId,database:expectedDb,backend:context.backend,frontend:context.frontend,
  jarSha256:expectedJar,backup:{preflight:path.relative(workspace,path.join(path.dirname(contextPath),'preflight-receipt.json')).replaceAll('\\','/'),sha256:preflight.backupSha256},
  scope:'Six fictional local fixture identities and independent actual HTTP sessions. Simulated account provisioning and auxiliary profiles only; not SMS or full business acceptance.',
  checks:[],accounts:[],passed:false};
const saveReceipt = () => atomicJson(receiptFile,receipt);
function check(name, condition, details = {}) { receipt.checks.push({name,passed:Boolean(condition),...details}); saveReceipt(); assert.ok(condition,name); }
function saveState() { atomicJson(checkpoint,state); }
function manifest(accounts) { return accounts.map(a=>({code:a.code,accountId:a.accountId,identityId:a.identityId,subjectHash:a.subjectHash,passwordHash:a.passwordHash,displayName:a.displayName,phone:a.phone})); }
function hashPassword(password) {
  const libs = ['crypto','core'].map(name=>`D:/dev/m2/repository/cn/hutool/hutool-${name}/5.8.43/hutool-${name}-5.8.43.jar`).join(';');
  const helper = path.join(workspace,'scripts/lib/TestPasswordHasher.java');
  const compiled = spawnSync('D:/dev/jdk17/bin/javac.exe',['-cp',libs,'-d',run,helper],{encoding:'utf8'});
  if (compiled.status !== 0) throw Error('Private fixture password helper compilation failed.');
  const result = spawnSync('D:/dev/jdk17/bin/java.exe',['-cp',run+';'+libs,'TestPasswordHasher'],{input:password+'\n',encoding:'utf8'});
  if (result.status !== 0 || !/^\$2[aby]\$/.test(result.stdout.trim())) throw Error('Private fixture password helper failed.');
  return result.stdout.trim();
}
async function api(actor, route, method = 'GET', body) {
  const response = await fetch(context.backend+route,{method,signal:AbortSignal.timeout(45000),headers:{clientid:context.clientId,'Content-Type':'application/json',...(actor?.token?{Authorization:'Bearer '+actor.token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
  let value; try { value = await response.json(); } catch { throw Error('Expected JSON for '+route); }
  if (value.code !== 200) throw Error(route+' returned business code '+value.code+' (response content withheld).');
  return value.data;
}
async function login(username,password,grantType='platform') {
  const value = await api(null,'/auth/login','POST',{username,password,grantType,clientId:context.clientId,...(grantType==='platform'?{tenantId:'900001'}:{})});
  const token = value?.access_token ?? value?.accessToken;
  if (typeof token !== 'string' || !token) throw Error('Independent login returned no session.');
  return {token,clientId:value.client_id??value.clientId};
}
function ownedRows() {
  return JSON.parse(sql(`SELECT COALESCE(json_agg(json_build_object('accountId',a.id::text,'displayName',a.display_name,'passwordHash',a.password_hash,'status',a.status,'identityId',i.id::text,'subjectHash',i.subject_hash,'verificationSource',i.verification_source,'channel',i.channel) ORDER BY a.id),'[]'::json) FROM asp_account a JOIN asp_login_identity i ON i.account_id=a.id WHERE a.id IN(${state.accounts.map(a=>sqlId(a.accountId)).join(',')});`));
}
function validateSeed(rows) {
  return rows.length===6 && state.accounts.every(a=>rows.some(r=>r.accountId===a.accountId&&r.identityId===a.identityId&&r.displayName===a.displayName&&r.passwordHash===a.passwordHash&&r.status==='active'&&r.subjectHash===a.subjectHash&&r.channel==='phone'&&r.verificationSource==='isolated-three-person-test:'+runId));
}
function businessFingerprint() {
  const tables=['asp_organization','asp_organization_application','asp_account_tenant_principal','asp_staff_grant','asp_governance_grant','asp_event','asp_registration','asp_registration_member','asp_team','asp_team_member','asp_fee_obligation','asp_payment','asp_payment_allocation','asp_refund','asp_payment_action','asp_payment_exception','asp_match','asp_result_version','asp_honor','asp_capability_activation','asp_capability_version'];
  return sha(sql(tables.map(t=>`SELECT '${t}='||count(*)||':'||md5(COALESCE(string_agg(row_to_json(t)::text,'|' ORDER BY id),'')) FROM ${t} t;`).join('\n')));
}
function existingWorkFingerprint() {
  // Successful login may update login metadata; identity, password and authority
  // bindings must stay byte-for-byte equal to the pre-provisioning snapshot.
  return sha(sql(`SELECT json_build_object('userId',u.user_id::text,'tenantId',u.tenant_id,'deptId',u.dept_id::text,'userName',u.user_name,'userType',u.user_type,'passwordHash',u.password,'status',u.status,'deleted',u.del_flag,'roles',(SELECT COALESCE(json_agg(r.role_id::text ORDER BY r.role_id),'[]'::json) FROM sys_user_role r WHERE r.user_id=u.user_id)) FROM sys_user u WHERE u.user_id IN(1,${sqlId(context.government.id)}) ORDER BY u.user_id;`));
}
try {
  const preservedBefore = businessFingerprint();
  const existingUserBefore = existingWorkFingerprint();
  if (!state) {
    const candidates = Array.from({length:6},(_,i)=>'1669400100'+(i+1));
    const phoneHash = phone => sha('local-dev-phone-pepper\n'+phone);
    if (Number(sql(`SELECT count(*) FROM asp_login_identity WHERE channel='phone' AND subject_hash IN(${candidates.map(p=>sqlLiteral(phoneHash(p))).join(',')});`)) > 0) {
      let available = false;
      for (let attempt=0;attempt<10&&!available;attempt++) {
        const stem = '16694'+String(crypto.randomInt(0,99999)).padStart(5,'0');
        for (let i=0;i<6;i++) candidates[i] = stem+(i+1);
        available = Number(sql(`SELECT count(*) FROM asp_login_identity WHERE channel='phone' AND subject_hash IN(${candidates.map(p=>sqlLiteral(phoneHash(p))).join(',')});`))===0;
      }
      if (!available) throw Error('Could not select six unused synthetic phone subjects.');
    }
    const baseId = (BigInt(Date.now()) << 20n) + BigInt(crypto.randomInt(100000,900000));
    state = {schemaVersion:1,runId,database:expectedDb,jarSha256:expectedJar,createdAt:new Date().toISOString(),seeded:false,profilesPrepared:[],accounts:[]};
    for (const [index,code] of ['A','B','C','D','E','F'].entries()) {
      const password = crypto.randomBytes(10).toString('hex');
      const displayName = index<3 ? '联测主账号'+code+'（模拟）' : '联测辅助'+code+'（模拟）';
      state.accounts.push({code,accountId:String(baseId+BigInt(index*2)),identityId:String(baseId+BigInt(index*2+1)),phone:candidates[index],displayName,password,passwordHash:hashPassword(password),subjectHash:phoneHash(candidates[index]),profileKind:index<3?'blank-primary':'synthetic-auxiliary'});
    }
    state.seedManifestSha256 = sha(JSON.stringify(manifest(state.accounts)));
    saveState();
  }
  check('private seed manifest is bound to this exact batch',state.schemaVersion===1&&state.runId===runId&&state.database===expectedDb&&state.jarSha256===expectedJar&&state.accounts.length===6&&sha(JSON.stringify(manifest(state.accounts)))===state.seedManifestSha256);
  let rows = ownedRows();
  if (rows.length) {
    check('existing owned seed matches every immutable identity and password hash',validateSeed(rows));
    state.seeded=true; state.seedRecoveredAt=new Date().toISOString(); saveState();
    receipt.seedMode='verified-existing-owned-seed';
  } else {
    if (state.seeded) throw Error('Previously seeded identities disappeared; refusing to reconstruct them.');
    const accountIds=state.accounts.map(a=>sqlId(a.accountId)).join(',');
    const identityIds=state.accounts.map(a=>sqlId(a.identityId)).join(',');
    const subjects=state.accounts.map(a=>sqlLiteral(a.subjectHash)).join(',');
    const statements=state.accounts.map(a=>`INSERT INTO asp_account(id,display_name,password_hash,status) VALUES(${sqlId(a.accountId)},${sqlLiteral(a.displayName)},${sqlLiteral(a.passwordHash)},'active');\nINSERT INTO asp_login_identity(id,account_id,channel,subject_hash,valid_from,verification_source) VALUES(${sqlId(a.identityId)},${sqlId(a.accountId)},'phone',${sqlLiteral(a.subjectHash)},CURRENT_TIMESTAMP,${sqlLiteral('isolated-three-person-test:'+runId)});`).join('\n');
    sql(`BEGIN;\nSELECT pg_advisory_xact_lock(hashtextextended('three-person-identity-seed',0));\nDO $seed$ BEGIN IF EXISTS(SELECT 1 FROM asp_account WHERE id IN(${accountIds})) OR EXISTS(SELECT 1 FROM asp_login_identity WHERE id IN(${identityIds}) OR (channel='phone' AND subject_hash IN(${subjects}))) THEN RAISE EXCEPTION 'new fixture identity collision'; END IF; END $seed$;\n${statements}\nCOMMIT;`,true);
    rows=ownedRows(); check('six accounts and phone identities inserted in one transaction',validateSeed(rows));
    state.seeded=true; state.seededAt=new Date().toISOString(); saveState(); receipt.seedMode='new-transaction';
  }
  const seenTokens = new Set();
  for (const account of state.accounts) {
    const actor=await login(account.phone,account.password);
    check('independent platform login '+account.code,!seenTokens.has(actor.token)); seenTokens.add(actor.token);
    account.session=actor; saveState();
    let home=await api(actor,'/sports/c/identity');
    check('identity belongs to actor '+account.code,String(home.accountId)===account.accountId&&home.loginPhone===account.phone);
    if (account.profileKind==='synthetic-auxiliary'&&!home.self) {
      if (state.profilesPrepared.includes(account.code)) throw Error('Previously prepared auxiliary profile disappeared.');
      const self=await api(actor,'/sports/c/identity/self','POST',{legalName:'联测辅助'+account.code+'（模拟）',gender:'male',birthDate:'1996-01-01',mobile:account.phone});
      account.personId=String(self.personId); state.profilesPrepared.push(account.code); saveState();
      home=await api(actor,'/sports/c/identity');
    }
    const blank=account.profileKind==='blank-primary';
    check('expected blank or synthetic profile '+account.code,blank ? !home.self : Boolean(home.self&&home.self.legalName==='联测辅助'+account.code+'（模拟）'&&home.self.gender==='male'&&home.self.birthDate==='1996-01-01'&&home.self.mobile===account.phone&&home.self.boundToMe));
    if (home.self) { account.personId=String(home.self.personId); if(!state.profilesPrepared.includes(account.code))state.profilesPrepared.push(account.code); saveState(); }
    const application=await api(actor,'/sports/c/organization/application');
    const registrations=await api(actor,'/sports/c/registrations');
    check('no organizer admission or registration for '+account.code,!application.applicationId&&!application.organizationId&&!application.canEnter&&Array.isArray(registrations)&&registrations.length===0);
    receipt.accounts.push({code:account.code,accountId:account.accountId,loginIdentityId:account.identityId,phone:account.phone,profile:blank?'empty':'synthetic-prefilled',personId:account.personId??null,organizationId:null,registrationCount:0}); saveReceipt();
  }
  const workRows=JSON.parse(sql(`SELECT json_agg(json_build_object('id',user_id::text,'username',user_name,'tenantId',tenant_id,'active',status='0' AND del_flag='0') ORDER BY user_id) FROM sys_user WHERE user_id IN(1,${sqlId(context.government.id)});`));
  state.workAccounts=[];
  for (const [code,id] of [['G',String(context.government.id)],['P','1']]) {
    const user=workRows.find(r=>r.id===id); check('existing work identity is active '+code,Boolean(user&&user.active&&user.tenantId==='000000'));
    const actor=await login(user.username,context.password,'work-password');
    const info=await api(actor,'/system/user/getInfo');
    check('real existing work login '+code,String(info.user?.userId)===id&&info.user?.tenantId===user.tenantId);
    state.workAccounts.push({code,...user,password:context.password,session:actor}); saveState();
  }
  check('ordinary government is not the platform administrator',state.workAccounts.find(a=>a.code==='G').id!=='1');
  const catalog=await api(state.workAccounts.find(a=>a.code==='P').session,'/sports/platform/management');
  const essential=['government.assignAdmission','government.grant','event.create','unit.create','match.schedule','event.wrapup','event.close'];
  const capabilities=essential.map(code=>{
    const row=catalog.definitions?.find(d=>d.definition?.code===code);
    const activation=catalog.activations?.find(a=>a.code===code&&a.channel==='ui');
    return {code,registered:Boolean(row),uiEnabled:Boolean(activation?.enabled),currentDefinition:Boolean(activation&&row&&activation.source_hash===row.definitionHash)};
  });
  check('required platform capability definitions are discoverable',capabilities.every(c=>c.registered));
  receipt.capabilities=capabilities; receipt.capabilityCatalogReadOnly=true;
  check('existing work identity passwords and roles were preserved',existingUserBefore===existingWorkFingerprint());
  check('organizations business objects and capability releases were preserved',preservedBefore===businessFingerprint());
  const all=[...state.accounts,...state.workAccounts];
  const credentialText=codes=>[
    'AI体育三人逐条联测｜模拟身份，请勿用于真实赛事或真实支付',
    '批次：'+runId,'入口：由负责人另行提供当前内网入口','账号资料仅保存在本机受保护目录。不得把本文件上传到日志、截图或公开仓库。',
    '',...codes.flatMap(code=>{const a=all.find(item=>item.code===code);return ['角色 '+code+'：'+(a.displayName??(code==='G'?'已有普通政府岗位':'已有平台管理岗位')),'登录名：'+(a.phone??a.username),'密码：'+a.password,'入口：'+(a.phone?'参赛者登录':'工作账号登录'),...(a.profileKind==='blank-primary'?['首次登录后本人填写模拟个人档案；A尚未申请办赛入驻。']:[]),''];}),
    'A/B/C 为三个主账号，D/E/F 为轮换辅助身份。每个账号独立登录；切换账号前退出或使用独立浏览器会话。',
    '主 A 人工申请入驻，P 分配给 G，G 本人审核；请勿用平台管理账号代替政府审核。',
    '没有预办组织、赛事、报名、邀请、付款、报到、成绩或奖项。短信/微信/银行仍须单独验证。'
  ].join('\r\n');
  const privateFiles=[['全部账号.private.txt',['A','B','C','D','E','F','G','P']],['操作人A.private.txt',['A','F']],['操作人B.private.txt',['B','D','G']],['操作人C.private.txt',['C','E','P']]];
  for(const [filename,codes] of privateFiles) {
    const target=path.join(run,filename),content=credentialText(codes);
    if(fs.existsSync(target)) { if(fs.readFileSync(target,'utf8')!==content)throw Error('Existing private account sheet changed; refusing to overwrite.'); }
    else fs.writeFileSync(target,content,{flag:'wx'});
  }
  receipt.privateAccountFiles=privateFiles.map(([name,codes])=>({name,roles:codes}));
  receipt.existingWork=state.workAccounts.map(a=>({code:a.code,userId:a.id,username:a.username,tenantId:a.tenantId}));
  receipt.seedManifestSha256=state.seedManifestSha256;
  receipt.finishedAt=new Date().toISOString();receipt.passed=true;saveReceipt();
  state.preparedAt=receipt.finishedAt;state.latestReceipt=path.basename(receiptFile);saveState();
  console.log('PASS six new independent fixture identities; main profiles remain unfilled; no business objects prepared.');
  console.log('Receipt: '+receiptFile);
} catch(error) {
  receipt.failure={name:error?.name??'Error',message:error?.message??'Preparation failed; details withheld.'};
  receipt.finishedAt=new Date().toISOString();saveReceipt();
  console.error('FAILED three-person preparation. Preserved private checkpoint and receipt: '+receiptFile);
  process.exitCode=1;
}
