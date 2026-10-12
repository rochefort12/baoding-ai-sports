// New synthetic history object only. Real HTTP, ordinary payment role and read-only SQL evidence.
// No bank transfer, model call, shared-event mutation, clock change or direct database write.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {context as c,key,api,request,action,readSql,versionOf,createEvidence,iso,beijingTime} from './lib/BusinessRegression.mjs';
const mode=process.argv[2]||'prepare';
assert.ok(['prepare','resolve','final'].includes(mode));
const test=createEvidence('historical-funds-'+mode);
const jarPath=process.env.AISPORTS_REGRESSION_JAR_PATH,expectedJar=process.env.AISPORTS_REGRESSION_JAR_SHA256;
assert.ok(jarPath&&/^[a-f0-9]{64}$/.test(expectedJar||''),'The live isolated JAR must be explicitly bound.');
assert.ok(fs.realpathSync(jarPath).startsWith(fs.realpathSync(process.cwd())+path.sep),'The runtime JAR stays in this project.');
const actualJar=crypto.createHash('sha256').update(fs.readFileSync(jarPath)).digest('hex');assert.equal(actualJar,expectedJar);
test.evidence.jarSha256=actualJar;test.evidence.runtimePid=Number(process.env.AISPORTS_REGRESSION_RUNTIME_PID);test.evidence.jarFile=path.relative(process.cwd(),jarPath).replaceAll('\\','/');
const stateFile=path.join(c.out,'historical-funds.private.json');
const own=JSON.parse(fs.readFileSync(path.join(c.out,'governance','checkpoint.private.json'),'utf8'));
const actor=c.people[5],otherActor=c.people[2];
const s=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{runId:c.runId,steps:{},keys:{},money:{}};
assert.equal(s.runId,c.runId);
const save=()=>fs.writeFileSync(stateFile,JSON.stringify(s,null,2));
const remember=async(slot,work)=>{if(s[slot]!==undefined)return s[slot];const value=await work();s[slot]=value;save();return value;};
const step=async(slot,work)=>{if(s.steps[slot])return;await work();s.steps[slot]=true;save();};
const act=async(identity,code,input)=>(await action(identity,code,input)).value;
const id=value=>{assert.match(String(value),/^\d+$/);return String(value);};
const row=async()=>{const value=(await api(actor,'/sports/c/registrations')).find(e=>e.id===s.registrationId);assert.ok(value);return value;};
const records=obligation=>api(c.organizer,`/sports/b/fees/obligations/${id(obligation)}/records`);
const history=()=>api(c.organizer,`/sports/b/fees/registrations/${id(s.registrationId)}/history`);
const entries=()=>api(c.organizer,`/sports/b/registrations/units/${id(s.unitId)}/entries`);
const fingerprint=obligation=>readSql(`SELECT md5(COALESCE(string_agg(t.fact,'|' ORDER BY t.kind,t.fact),'')) FROM (
  SELECT 'obligation' AS kind,to_jsonb(x)::text AS fact FROM asp_fee_obligation x WHERE x.id=${id(obligation)}
  UNION ALL SELECT 'payment',to_jsonb(x)::text FROM asp_payment x WHERE x.id IN(SELECT payment_id FROM asp_payment_allocation WHERE obligation_id=${id(obligation)})
  UNION ALL SELECT 'allocation',to_jsonb(x)::text FROM asp_payment_allocation x WHERE x.obligation_id=${id(obligation)}
  UNION ALL SELECT 'refund',to_jsonb(x)::text FROM asp_refund x WHERE x.payment_id IN(SELECT payment_id FROM asp_payment_allocation WHERE obligation_id=${id(obligation)})
  UNION ALL SELECT 'payment-action',to_jsonb(x)::text FROM asp_payment_action x WHERE x.obligation_id=${id(obligation)}) t;`);
test.evidence.scope='Actual isolated third synthetic event: formal v1, duplicate-request exception, full original-payer refund, independent v2, original exception review, withdrawal. No real bank transfer; protected checkpoint resumes successful steps without replay.';
const sources=['scripts/Test-HistoricalFundsRegression.mjs','backend/aisports-api/src/main/java/org/dromara/sports/api/FeeApi.java',
  'backend/aisports-domains/d06/aisports-table-fee-obligation/src/main/java/org/dromara/sports/finance/service/FinanceService.java',
  'backend/aisports-domains/d05/aisports-table-registration/src/main/java/org/dromara/sports/registration/service/RegistrationService.java',
  'plus-ui/src/views/sports/registration/review.vue'];
test.evidence.sourceFiles=Object.fromEntries(sources.map(file=>[file,crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')]));
async function prepare(){
  await remember('eventId',async()=>{const value=await act(c.organizer,'event.create',{draftJson:JSON.stringify({name:c.prefix+'-付款历史第三轮',projectName:'羽毛球',location:'本轮合成羽毛球馆',feeDescription:'单打每单100元，仅合成登记',registrationOpensAt:iso(-1),registrationClosesAt:iso(10),startsAt:iso(11),endsAt:iso(14),registrationReview:'manual',rulesText:'本机合成记录，不是真实银行款项。未参赛时模拟全额原路退还。',declarationText:'仅本机合成验证，请勿真实转账。',declarationAckRequired:true})});return value.eventId;});
  await remember('unitId',async()=>{const value=await api(c.organizer,'/sports/b/registrations/units','POST',{eventId:s.eventId,name:c.prefix+'-历史单打',entryType:'individual',minMembers:1,maxMembers:1,limitCount:8,charged:true,amount:'100.00',paymentMode:'offline',payInstruction:'合成记录，不要真实付款',requestKey:key()});return value.id;});
  await step('published',()=>act(c.organizer,'event.publish',{eventId:s.eventId,expectedVersion:versionOf('asp_event',s.eventId),contactName:'合成资金责任人',contactMethod:'history@simulation.invalid'}));
  await remember('privateDraftId',async()=>{const value=await api(otherActor,'/sports/c/registrations','POST',{unitId:s.unitId,requestKey:key()});return value.id;});
  await remember('registrationId',async()=>{const value=await api(actor,'/sports/c/registrations','POST',{unitId:s.unitId,requestKey:key()});return value.id;});
  await step('v1Submitted',async()=>{await api(actor,`/sports/c/registrations/${s.registrationId}/declaration-ack`,'POST');await act(actor,'registration.submit',{registrationId:s.registrationId,expectedVersion:versionOf('asp_registration',s.registrationId)});});
  await remember('v1',async()=>{const value=await row();return value.obligationId;});
  test.check('HF01 new formal duty freezes the actual roster revision', (await history()).find(d=>d.obligationId===s.v1)?.rosterRevision===1);
  s.money.original??={payerName:'第三轮合成原付款人',amount:'100.00',occurredAt:beijingTime(),note:'合成登记，不是真实银行到账',requestKey:key()};save();
  await step('paid',()=>api(c.organizer,`/sports/b/fees/obligations/${s.v1}/confirm`,'POST',s.money.original));
  await step('conflict',async()=>{const rejected=await request(c.organizer,`/sports/b/fees/obligations/${s.v1}/confirm`,'POST',{...s.money.original,amount:'101.00'});test.check('HF02 changing amount under the same receipt key is rejected',rejected.code!==200);});
  await remember('exceptionId',async()=>{for(let attempt=0;attempt<8;attempt++){const value=(await records(s.v1)).exceptions.find(x=>x.exceptionType==='duplicate_payment'&&x.status!=='resolved');if(value)return value.exceptionId;await new Promise(resolve=>setTimeout(resolve,250));}throw Error('Actual duplicate exception not persisted');});
  test.check('HF03 conflict adds no second receipt', (await records(s.v1)).receipts.length===1&&Number((await records(s.v1)).netAmount)===(s.steps.v1Refunded?0:100));
  await step('v1Withdrawn',()=>api(actor,`/sports/c/registrations/${s.registrationId}/withdraw`,'POST'));
  await remember('refundActionId',async()=>{const value=await records(s.v1);const receipt=value.receipts.find(r=>r.status==='confirmed');assert.ok(receipt?.pendingActionId);return receipt.pendingActionId;});
  s.money.refund??={amount:'100.00',occurredAt:beijingTime(),recipientName:s.money.original.payerName,recipientBasis:'',note:'合成未参赛按原规则向原付款人退还，不是真实转账',requestKey:key()};save();
  await step('v1Refunded',()=>api(c.organizer,`/sports/b/fees/actions/${s.refundActionId}/refund`,'POST',s.money.refund));
  const refunded=await records(s.v1),afterRefund=(await entries()).find(e=>e.id===s.registrationId);
  test.check('HF04 full refund preserves original receipt and records zero net',refunded.receipts.length===1&&refunded.refunds.length===1&&Number(refunded.netAmount)===0);
  test.check(s.steps.v2Submitted?'HF05 continued submitted object retains original pending responsibility':'HF05 unresolved old exception retains a refunded draft in organizer work',afterRefund?.status===(s.steps.v2Submitted?'submitted':'draft')&&afterRefund.fundsPending===true);
  test.check('HF06 untouched private drafts are not shown to organizers',!(await entries()).some(e=>e.id===s.privateDraftId));
  await step('v2Submitted',async()=>{await api(actor,`/sports/c/registrations/${s.registrationId}/declaration-ack`,'POST');await act(actor,'registration.submit',{registrationId:s.registrationId,expectedVersion:versionOf('asp_registration',s.registrationId)});});
  await remember('v2',async()=>{const value=await row();return value.obligationId;});
  const duties=await history();
  test.check('HF07 repeated formal submission creates a separate unpaid duty',s.v1!==s.v2&&Number((await records(s.v2)).netAmount)===0&&Number((await records(s.v2)).dueAmount)===100);
  test.check('HF08 history binds both actual submitted versions without inferring numbers',duties.length===2&&duties.find(d=>d.obligationId===s.v1)?.rosterRevision===1&&duties.find(d=>d.obligationId===s.v2)?.rosterRevision===2);
  test.check('HF09 old closed duty remains a pending exception while current duty stays open',duties.find(d=>d.obligationId===s.v1)?.status==='void'&&duties.find(d=>d.obligationId===s.v1)?.pending===true&&duties.find(d=>d.obligationId===s.v2)?.current===true&&duties.find(d=>d.obligationId===s.v2)?.status==='open');
  for(const [identity,label] of [[actor,'participant'],[c.government,'government'],[own.organizer,'different organization']])
    test.check('HF10 '+label+' cannot read organizer payment history',(await request(identity,`/sports/b/fees/registrations/${s.registrationId}/history`)).code!==200);
  test.check('HF11 history DTO excludes bank channels, payer identity and private exception material',duties.every(d=>!['payInstruction','channels','payerName','quoteSnapshot','resolution','requestKey'].some(field=>field in d)));
  s.beforeResolutionFingerprint??=fingerprint(s.v1);save();
}
async function resolve(){
  assert.ok(s.steps.v2Submitted&&s.exceptionId&&s.beforeResolutionFingerprint);
  const record=(await records(s.v1)).exceptions.find(e=>e.exceptionId===s.exceptionId);assert.ok(record);
  s.review??={expectedVersion:record.version,note:'合成历史核对：原付款100元已按原付款人全额退还，101元请求为同键金额冲突；保留原收款退款事实，不重复记账。',requestKey:key()};save();
  await step('exceptionResolved',()=>api(c.organizer,`/sports/b/fees/obligations/${s.v1}/exceptions/${s.exceptionId}/resolve`,'POST',s.review));
  test.check('HF12 closing the original exception changes no original financial fact',fingerprint(s.v1)===s.beforeResolutionFingerprint);
  const duties=await history();test.check('HF13 old duty has no remaining work; current unpaid duty is independent',duties.find(d=>d.obligationId===s.v1)?.pending===false&&duties.find(d=>d.obligationId===s.v2)?.pending===true&&Number((await records(s.v2)).netAmount)===0);
  await step('v2Withdrawn',()=>api(actor,`/sports/c/registrations/${s.registrationId}/withdraw`,'POST'));
}
async function final(){
  assert.ok(s.steps.v2Withdrawn);
  const listed=(await entries()).find(e=>e.id===s.registrationId),duties=await history();
  test.check('HF14 fully closed withdrawal remains queryable without a payment reminder',listed?.status==='draft'&&listed.rosterRevision===2&&listed.fundsPending===false);
  test.check('HF15 both original closed duties remain accessible without reopening payment',duties.length===2&&duties.every(d=>d.status==='void'&&!d.pending));
  const original=await records(s.v1);test.check('HF16 old receipt, full refund and human exception note remain queryable',original.receipts.length===1&&original.refunds.length===1&&Number(original.netAmount)===0&&original.exceptions.find(e=>e.exceptionId===s.exceptionId)?.status==='resolved');
  test.check('HF17 no withdrawn entry occupies a slot',readSql(`SELECT used_count FROM asp_capacity_pool WHERE unit_id=${id(s.unitId)};`)==='0');
  test.check('HF18 never-submitted private draft still stays private',!(await entries()).some(e=>e.id===s.privateDraftId));
  test.check('HF19 review audit is append-only exactly once',readSql(`SELECT count(*) FROM asp_audit_event WHERE action='finance.duplicate_payment.resolve' AND object_type='payment_exception' AND object_id=${id(s.exceptionId)};`)==='1');
  test.check('HF20 original financial fingerprint remains unchanged',fingerprint(s.v1)===s.beforeResolutionFingerprint);
  await step('eventCancelled',()=>api(c.organizer,`/sports/b/events/${s.eventId}/cancel`,'POST',{reason:'第三轮合成历史测试已完成；未产生现场比赛或真实转账，保留全部旧记录。'}));
  test.check('HF21 synthetic event is stopped after both duties are closed',readSql(`SELECT holding_status FROM asp_event WHERE id=${id(s.eventId)};`)==='cancelled');
}
try{
  const preflight=JSON.parse(fs.readFileSync(path.join(c.out,'preflight-receipt.json'),'utf8'));
  test.check('isolated backup/restore preflight receipt guard',preflight.passed===true&&preflight.database===c.database);
  const identity=await api(c.organizer,'/system/user/getInfo');
  const administrator=await api(c.admin,'/system/user/getInfo');
  test.check('ordinary organization funds identity is distinct from platform setup administrator',Boolean(identity.user?.userId)&&identity.user.userId!==administrator.user?.userId);
  if(mode==='prepare')await prepare();else if(mode==='resolve')await resolve();else await final();
  test.evidence.objects={eventId:s.eventId,unitId:s.unitId,registrationId:s.registrationId,v1:s.v1,v2:s.v2,exceptionId:s.exceptionId};
  test.check('source stayed stable during actual narrow checks',sources.every(file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')===test.evidence.sourceFiles[file]));
  test.finish();
}catch(error){test.evidence.failure={name:error.name,message:String(error.message).slice(0,800)};test.save();process.exitCode=1;console.log('FAILED '+error.name);}
