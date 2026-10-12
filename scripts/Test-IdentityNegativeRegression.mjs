// Authentication rejection paths only. No SMS dispatch, credential change or account closure.
import {context as c,key,request,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('identity-negative');
const before=()=>readSql(`SELECT md5(row_to_json(a)::text) FROM asp_account a WHERE id=${c.people[5].id};`);
const fingerprint=before();
async function rejected(label,owner,route,body){const result=await request(owner,route,'POST',body);test.check(label,result.code!==200&&result.data==null,{httpStatus:result.httpStatus,businessCode:result.code});}
try{
  const captcha=await request(null,'/auth/participant/captcha-config');
  test.check('public captcha configuration contains no service credentials',captcha.code===200&&Object.keys(captcha.data).every(k=>['aliyun','region','prefix','sceneId','mode'].includes(k)));
  await rejected('invalid registration phone is rejected before SMS',null,'/auth/participant/sms-code',{phone:'not-a-phone'});
  await rejected('invalid reset phone is rejected before SMS',null,'/auth/participant/reset-sms-code',{phone:'not-a-phone'});
  await rejected('registration needs an actual issued one-time code',null,'/auth/participant/register',{phone:'131'+String(Date.now()).slice(-8),password:'Synthetic-'+key().slice(0,8),smsCode:'unissued-'+key()});
  await rejected('empty mandatory registration fields are rejected',null,'/auth/participant/register',{phone:'',password:'',smsCode:''});
  await rejected('invalid password format cannot create an account',null,'/auth/participant/register',{phone:'131'+String(Date.now()).slice(-8),password:'<>',smsCode:'unissued-'+key()});
  await rejected('unissued reset code cannot change the existing password',null,'/auth/participant/reset-password',{phone:c.people[5].phone,password:'Synthetic-'+key().slice(0,8),smsCode:'unissued-'+key()});
  await rejected('anonymous caller cannot ask to close an account',null,'/auth/participant/close-sms-code',{});
  await rejected('anonymous caller cannot submit account closure',null,'/auth/participant/close',{smsCode:'unissued-'+key()});
  await rejected('ordinary government cannot close a participant account',c.government,'/auth/participant/close',{smsCode:'unissued-'+key()});
  await rejected('responsibilities or invalid code prevent actual account closure',c.people[5],'/auth/participant/close',{smsCode:'unissued-'+key()});
  await rejected('wrong participant password grants no session',null,'/auth/login',{tenantId:'000000',username:c.people[5].phone,password:'Wrong-'+key(),grantType:'platform',clientId:c.clientId});
  await rejected('unknown client cannot grant a login session',null,'/auth/login',{tenantId:'000000',username:'synthetic',password:'Synthetic',grantType:'platform',clientId:'unregistered-'+key()});
  test.check('authentication rejection paths preserve the whole existing account row',before()===fingerprint);
  test.evidence.notExecuted=['Real SMS registration and delivery','Real reset/closure code delivery and success path','Expired issued code and purpose reuse through a real provider'];
  test.evidence.boundary='No Redis code injection, SQL setup, authentication bypass, SMS simulation or real phone dispatch.';
  test.finish();
}catch(error){test.evidence.failure=error.message;test.save();console.error(error.message);process.exitCode=1;}
