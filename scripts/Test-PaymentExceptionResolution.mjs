// Real isolated duplicate-request review. It changes only the two selected exceptions;
// all original payments, allocations, refunds, registration and payment obligations must stay intact.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {context as c, api, request, readSql, createEvidence, key} from './lib/BusinessRegression.mjs';

const round2=process.argv.includes('--round2');
const execute=process.argv.includes('--execute');
const statePath=path.join(c.out,round2?'funds-competition-fixed-state.json':'funds-competition-state.json');
const original=JSON.parse(fs.readFileSync(statePath,'utf8').replace(/^\uFEFF/,''));
assert.equal(original.runId,c.runId,'The selected funds state must belong to this isolated run.');
const privatePath=path.join(c.out,'governance','checkpoint.private.json');
const own=JSON.parse(fs.readFileSync(privatePath,'utf8').replace(/^\uFEFF/,''));
const otherOrganizer=own.organizer;
assert.ok(otherOrganizer?.token,'A different ordinary organization identity is required.');
const test=createEvidence(round2?'payment-exception-resolution-round2':'payment-exception-resolution');
const checkpointPath=path.join(c.out,round2?'payment-exception-resolution-round2.private.json':'payment-exception-resolution.private.json');
const s=fs.existsSync(checkpointPath)?JSON.parse(fs.readFileSync(checkpointPath,'utf8')):{runId:c.runId,operations:{}};
assert.equal(s.runId,c.runId);
const persist=()=>fs.writeFileSync(checkpointPath,JSON.stringify(s,null,2),{mode:0o600});
const check=(name,condition,details={})=>test.check(name,condition,details);
let responsibleUserId;
const id=value=>{assert.match(String(value),/^\d+$/);return String(value);};
const records=value=>api(c.organizer,`/sports/b/fees/obligations/${id(value)}/records`);
const endpoint=(obligation,exception)=>`/sports/b/fees/obligations/${id(obligation)}/exceptions/${id(exception)}/resolve`;
const fingerprint=obligation=>readSql(`
  SELECT md5(COALESCE(string_agg(t.fact,'|' ORDER BY t.kind,t.fact),'')) FROM (
    SELECT 'obligation' AS kind,to_jsonb(x)::text AS fact FROM asp_fee_obligation x WHERE x.id=${id(obligation)}
    UNION ALL SELECT 'registration',to_jsonb(x)::text FROM asp_registration x JOIN asp_fee_obligation o ON o.registration_id=x.id WHERE o.id=${id(obligation)}
    UNION ALL SELECT 'payment',to_jsonb(x)::text FROM asp_payment x WHERE x.id IN (SELECT payment_id FROM asp_payment_allocation WHERE obligation_id=${id(obligation)})
    UNION ALL SELECT 'allocation',to_jsonb(x)::text FROM asp_payment_allocation x WHERE x.obligation_id=${id(obligation)}
    UNION ALL SELECT 'refund',to_jsonb(x)::text FROM asp_refund x WHERE x.payment_id IN (SELECT payment_id FROM asp_payment_allocation WHERE obligation_id=${id(obligation)})
    UNION ALL SELECT 'payment-action',to_jsonb(x)::text FROM asp_payment_action x WHERE x.obligation_id=${id(obligation)}
  ) t;
`);
const auditCount=exception=>Number(readSql(`SELECT count(*) FROM asp_audit_event WHERE action='finance.duplicate_payment.resolve' AND object_type='payment_exception' AND object_id=${id(exception)};`));
const exceptionFact=exception=>JSON.parse(readSql(`SELECT json_build_object('id',id::text,'status',status,'version',version,'owner',owner_id::text,'resolution',resolution)::text FROM asp_payment_exception WHERE id=${id(exception)};`));
const sourceFiles=['scripts/Test-PaymentExceptionResolution.mjs',
  'backend/aisports-domains/d06/aisports-table-fee-obligation/src/main/java/org/dromara/sports/finance/service/FinanceService.java',
  'backend/aisports-domains/d06/aisports-table-fee-obligation/src/main/java/org/dromara/sports/finance/controller/FeeOrganizerController.java',
  'plus-ui/src/components/business/PaymentExceptionPanel.vue'];
test.evidence.sourceFiles=Object.fromEntries(sourceFiles.map(file=>[file,crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')]));
test.evidence.scope='Actual isolated HTTP; two existing synthetic duplicate-payment exceptions, ordinary SYS_USER payment role. No bank transfer, SQL write, model call or original financial mutation.';

async function denied(actor,obligation,exception,body,label){
  const before=exceptionFact(exception), count=auditCount(exception);
  const response=await request(actor,endpoint(obligation,exception),'POST',body);
  check(label,response.code!==200&&JSON.stringify(exceptionFact(exception))===JSON.stringify(before)&&auditCount(exception)===count,{code:response.code});
}

async function resolve(entry,index){
  const obligation=entry.obligationId,exception=entry.exceptionId;
  const before=fingerprint(obligation), current=exceptionFact(exception), auditsBefore=auditCount(exception);
  const displayed=await records(obligation);
  const row=displayed.exceptions?.find(item=>String(item.exceptionId)===exception);
  check(`EX${index} ordinary payment role reads the selected exception`,Boolean(row)&&row.exceptionType==='duplicate_payment');
  check(`EX${index} records expose no raw resolution or request key`,row&&!['resolution','requestKey','actorAccountId'].some(field=>field in row));
  const plan=s.operations[exception]??={requestKey:key(),alternateKey:key(),expectedVersion:current.version,note:`合成核对：复查本轮原收款与分配记录，重复请求内容冲突；保留原款项，不另记到账，不调整退款或资格。`, mode:index===1?'same-key':'different-key'};
  plan.originalFingerprint??=before;plan.originalNet??=displayed.netAmount;plan.originalDue??=displayed.dueAmount;
  persist();
  const body={expectedVersion:plan.expectedVersion,note:plan.note,requestKey:plan.requestKey};
  if(!plan.done&&current.status==='resolved'){
    const conclusion=current.resolution;
    check(`EX${index} interrupted local receipt can recover only its exact original review`,
      [plan.requestKey,plan.alternateKey].includes(conclusion?.requestKey)&&conclusion.note===plan.note&&conclusion.expectedVersion===plan.expectedVersion&&String(conclusion.responsibleUserId)===responsibleUserId&&auditsBefore===1);
    plan.winner={...body,requestKey:conclusion.requestKey};plan.done=true;persist();
  }
  if(!plan.done){
    check(`EX${index} starts as an unresolved duplicate-request exception`,current.status==='open'&&auditsBefore===0);
    await denied(c.people[4],obligation,exception,body,`EX${index} participant cannot close a payment exception`);
    await denied(c.government,obligation,exception,body,`EX${index} ordinary government cannot close a payment exception`);
    await denied(otherOrganizer,obligation,exception,body,`EX${index} another ordinary organization is rejected`);
    check(`EX${index} participant cannot read organizer records`,(await request(c.people[4],`/sports/b/fees/obligations/${obligation}/records`)).code!==200);
    check(`EX${index} unrelated organizer cannot read these records`,(await request(otherOrganizer,`/sports/b/fees/obligations/${obligation}/records`)).code!==200);
    await denied(c.organizer,obligation,exception,{...body,note:' '},`EX${index} blank review explanation is rejected`);
    await denied(c.organizer,obligation,exception,{...body,note:'a'.repeat(1001)},`EX${index} overlong review explanation is rejected`);
    await denied(c.organizer,obligation,exception,{...body,requestKey:'invalid key!'},`EX${index} malformed request key is rejected`);
    await denied(c.organizer,obligation,exception,{...body,expectedVersion:current.version+1},`EX${index} stale exception version is rejected`);
    const other=s.entries.find(item=>item.obligationId!==obligation);
    await denied(c.organizer,other.obligationId,exception,body,`EX${index} an exception cannot be attached to another obligation`);
    assert.ok(execute,'Use --execute only after the new candidate runtime is ready and mutations are authorized.');
    const second=plan.mode==='same-key'?body:{...body,requestKey:plan.alternateKey};
    const responses=await Promise.all([request(c.organizer,endpoint(obligation,exception),'POST',body),request(c.organizer,endpoint(obligation,exception),'POST',second)]);
    const successes=responses.map((response,slot)=>({response,slot})).filter(item=>item.response.code===200);
    check(`EX${index} simultaneous ${plan.mode} requests have the expected result`,plan.mode==='same-key'?successes.length===2:successes.length===1,{businessCodes:responses.map(response=>response.code)});
    const winner=successes[0];plan.winner=winner.slot===0?body:second;plan.done=true;persist();
  } else {
    check(`EX${index} resumed completed review preserves its original conclusion`,current.status==='resolved'&&Boolean(plan.winner));
  }
  const resolved=exceptionFact(exception), auditAfter=auditCount(exception);
  check(`EX${index} conclusion records one responsible human and one new version`,resolved.status==='resolved'&&resolved.version===plan.expectedVersion+1&&String(resolved.owner)===responsibleUserId&&Boolean(resolved.resolution?.resolvedAt));
  check(`EX${index} exactly one audit event accompanies the conclusion`,auditAfter===1);
  const repeated=await api(c.organizer,endpoint(obligation,exception),'POST',plan.winner);
  check(`EX${index} an identical retry returns the original conclusion`,String(repeated.exceptionId)===exception&&repeated.version===resolved.version&&auditCount(exception)===auditAfter);
  await denied(c.organizer,obligation,exception,{...plan.winner,note:'另一核对说明'},`EX${index} a reused key cannot replace the explanation`);
  await denied(c.organizer,obligation,exception,{...plan.winner,expectedVersion:resolved.version},`EX${index} a reused key cannot change the original expected version`);
  await denied(c.organizer,obligation,exception,{...body,expectedVersion:resolved.version,requestKey:key()},`EX${index} a new key cannot close the already resolved exception twice`);
  const after=await records(obligation);
  check(`EX${index} original payments, allocations, refunds, duties and qualification stay unchanged`,fingerprint(obligation)===plan.originalFingerprint);
  check(`EX${index} original financial total stays unchanged`,Number(after.netAmount)===Number(plan.originalNet)&&Number(after.dueAmount)===Number(plan.originalDue));
}

try{
  check('PRE01 two known obligations belong to the current synthetic funds event',Boolean(original.eventId)&&Boolean(original.partialEntryObligation)&&Boolean(original.surplusEntryObligation));
  const shared=(await api(c.organizer,'/sports/b/desk/context'));
  check('PRE02 current organizer retains the shared organization without granting government powers',String(shared.organizationId)===String(c.organizationId));
  const info=await api(c.organizer,'/system/user/getInfo');
  responsibleUserId=id(info.user.userId);
  check('PRE03 review responsibility is bound to the current real SYS_USER identity',Boolean(responsibleUserId));
  if(!s.entries){
    s.entries=[original.partialEntryObligation,original.surplusEntryObligation].map(value=>{
      const obligationId=id(value);
      const exceptions=JSON.parse(readSql(`SELECT COALESCE(json_agg(json_build_object('exceptionId',x.id::text,'obligationId',${obligationId}::text) ORDER BY x.id),'[]'::json)::text FROM asp_payment_exception x WHERE x.obligation_id=${obligationId} AND x.exception_type='duplicate_payment';`));
      assert.equal(exceptions.length,1,'Each selected obligation must have exactly one preserved duplicate-request exception.');
      return exceptions[0];
    });persist();
  }
  test.evidence.objects={eventId:original.eventId,entries:s.entries};test.save();
  for(let index=0;index<s.entries.length;index++)await resolve(s.entries[index],index+1);
  check('all selected original financial facts remain unchanged by human review',s.entries.every(entry=>exceptionFact(entry.exceptionId).status==='resolved'));
  test.finish();
}catch(error){
  test.evidence.failure=error.message;test.evidence.finishedAt=new Date().toISOString();test.save();persist();console.error(error.message);process.exitCode=1;
}
