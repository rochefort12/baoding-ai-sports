// Renew only the existing ordinary government session; never initialize roles,
// reset a credential or replay successful tournament business.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {context as c,api,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('ordinary-government-auth-recovery');
try {
  if(c.government.id!=='839000000100')throw Error('Prepared ordinary government identity required');
  const username=readSql(`SELECT user_name FROM sys_user WHERE user_id=${c.government.id} AND tenant_id='000000' AND status='0' AND del_flag='0';`);
  if(username!=='phase1-government')throw Error('Existing government credential identity changed');
  const fingerprint=()=>readSql(`SELECT md5(row_to_json(u)::text) FROM sys_user u WHERE user_id=${c.government.id};`);
  const before=fingerprint();
  const originalHash=readSql(`SELECT password FROM sys_user WHERE user_id=${c.government.id};`);
  const login=await api(null,'/auth/login','POST',{username,password:c.password,grantType:'password',clientId:c.clientId,tenantId:'000000'});
  test.check('existing government password authenticates without resetting the account',Boolean(login.access_token));
  const actor={...c.government,token:login.access_token,clientId:login.client_id};
  const info=await api(actor,'/system/user/getInfo');
  test.check('renewed session retains the same ordinary government identity',String(info.user.userId)===c.government.id);
  // Login updates supported login metadata; the credential and role assignment
  // are not written by this script. Check the actual password hash separately.
  const hash=readSql(`SELECT password FROM sys_user WHERE user_id=${c.government.id};`);
  test.check('credential is still the existing hash after a real login',Boolean(hash&&hash===originalHash));
  const file=process.env.AISPORTS_REGRESSION_CONTEXT;
  const latest=JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
  const temporary=file+'.'+crypto.randomUUID()+'.tmp';
  fs.writeFileSync(temporary,JSON.stringify({...latest,government:actor},null,2));fs.renameSync(temporary,file);
  test.evidence.objects={governmentId:c.government.id};
  test.evidence.accountRowUnchanged=fingerprint()===before;
  test.evidence.scope='Existing government login only; no password reset, roles, grants or tournament business replay.';
  test.finish();
} catch(error){test.evidence.failure=error.message;test.save();console.error(error.message);process.exitCode=1;}
