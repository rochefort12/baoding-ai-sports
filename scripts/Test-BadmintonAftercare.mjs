// Real ordinary-role HTTP; retained synthetic ledger facts, no database mutation.
import fs from 'node:fs';
import path from 'node:path';
import {context as c,key,beijingTime,api,request,action,readSql,versionOf,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('badminton-aftercare');
const stage=process.argv[2]||'competition';
const scheduled=process.argv.includes('--scheduled');
const canonical=scheduled||process.argv.includes('--canonical');
const funds=JSON.parse(fs.readFileSync(path.join(c.out,scheduled?'ai-scheduled-entry-state.json':canonical?'ai-canonical-entry-state.json':stage==='cancel'?'funds-competition-state.json':'funds-competition-fixed-state.json'),'utf8'));
const competition=JSON.parse(fs.readFileSync(path.join(c.out,scheduled?'scheduled-competition-results-state.json':canonical?'canonical-competition-results-state.json':'competition-results-state.json'),'utf8'));
const stateFile=path.join(c.out,'aftercare-'+(scheduled?'scheduled-':canonical?'canonical-':'')+(stage==='finish'?'competition':stage)+'-state.json');
const s=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{runId:c.runId,steps:{},keys:{}};
if(s.runId!==c.runId)throw Error('Wrong recovery run');
const save=()=>fs.writeFileSync(stateFile,JSON.stringify(s,null,2));
const step=async(name,fn)=>{if(s.steps[name])return;await fn();s.steps[name]=true;save();};
const act=async(actor,code,input,name)=>{if(name){s.keys[name]??=key();save();}return (await action(actor,code,input,name?s.keys[name]:undefined)).value;};
const event=funds.eventId;
const input=()=>({eventId:event,expectedVersion:versionOf('asp_event',event)});
const summary=()=>act(c.organizer,'event.closure',{eventId:event});
const denied=async(name,actor,code,value)=>{let refused=false;try{await action(actor,code,value);}catch{refused=true;}test.check(name,refused);};
async function competitionAftercare(){
  const actor=c.people[1];
  if(!s.complaintId){s.complaintId=(await act(actor,'complaint.submit',{objectType:'registration',objectId:competition.entryA,message:c.prefix+'：合成投诉，核对结果更正及重新签发证明，无真实纠纷'},'complaint')).complaintId;save();}
  test.check('unrelated participant cannot read the private complaint',(await request(c.people[5],'/sports/issues/'+s.complaintId)).code!==200);
  await step('reply',()=>act(actor,'complaint.reply',{complaintId:s.complaintId,message:'合成补充：原证明已撤销，新证明应关联当前正式结果',expectedVersion:versionOf('asp_complaint',s.complaintId)},'reply'));
  await step('coordinate',()=>act(c.government,'complaint.handle',{complaintId:s.complaintId,action:'coordinate',message:'合成协调：请主办方核对结果及证明版本',expectedVersion:versionOf('asp_complaint',s.complaintId)},'coordinate'));
  await denied('participant cannot declare whole-event closure',actor,'event.close',input());
  await step('wrapup',()=>act(c.organizer,'event.wrapup',input(),'wrapup'));
  const before=await summary();
  test.check('formal results permit competition wrap-up while money and issues remain separate',before.competitionEnded&&before.missingResults===0&&before.proofsAwaitingReview===0);
  if(!s.steps.firstResolve){
    if(before.unresolvedPaymentExceptions>0)test.check('unresolved money exceptions remain visible in wrap-up',!before.fundsClosed);
    await denied('an open complaint or payment exception blocks overall closure',c.organizer,'event.close',input());
    await step('firstResolve',()=>act(c.government,'complaint.handle',{complaintId:s.complaintId,action:'resolve',message:'合成结果版本与新证明已核对，完成首次回复',expectedVersion:versionOf('asp_complaint',s.complaintId)},'firstResolve'));
  }
  const after=await summary();
  test.check('issue resolution preserves the independently reported financial state',after.issuesClosed&&after.unresolvedPaymentExceptions===before.unresolvedPaymentExceptions);
  if(after.unresolvedPaymentExceptions>0)await denied('payment exceptions alone prevent whole-event closure',c.organizer,'event.close',input());
  else test.evidence.paymentExceptionBoundary='Human exception tests completed concurrently before this summary; no unresolved-exception blocking claim from this stage';
}
async function finish(){
  const current=await summary();
  test.check('money obligations actions exceptions and refunds have individually closed',current.fundsClosed&&current.openObligations===0&&current.pendingFundActions===0&&current.unresolvedPaymentExceptions===0&&current.pendingRefunds===0);
  await step('firstClose',()=>act(c.organizer,'event.close',input(),'firstClose'));
  test.check('formal results private proofs refunds and issues reach whole-event closed',readSql(`SELECT closure_status FROM asp_event WHERE id=${event};`)==='closed');
  await step('reopen',()=>act(c.people[1],'complaint.reopen',{complaintId:s.complaintId,message:'合成补充证据，重新核对原问题，不能形成伪关闭',expectedVersion:versionOf('asp_complaint',s.complaintId)},'reopen'));
  if(!s.steps.secondResolve)test.check('reopened complaint restores event wrap-up responsibility',readSql(`SELECT closure_status FROM asp_event WHERE id=${event};`)==='wrap_up');
  if(!s.steps.secondResolve)await denied('reopened complaint again blocks closure',c.organizer,'event.close',input());
  await step('secondResolve',()=>act(c.government,'complaint.handle',{complaintId:s.complaintId,action:'resolve',message:'合成补充依据已核对，完成再次协调',expectedVersion:versionOf('asp_complaint',s.complaintId)},'secondResolve'));
  await step('secondClose',()=>act(c.organizer,'event.close',input(),'secondClose'));
  const closed=await summary();test.check('second closure keeps independent result money and complaint facts',closed.competitionEnded&&closed.fundsClosed&&closed.issuesClosed&&readSql(`SELECT closure_status FROM asp_event WHERE id=${event};`)==='closed');
  const notices=await api(c.people[1],'/sports/c/notices');
  const relevant=notices.filter(n=>n.targetPath==='/portal/issues/'+s.complaintId);
  test.check('complaint progress produces persistent actionable personal messages',relevant.length>=3);
  const notice=relevant[0];
  test.check('other participant cannot mark this private notification read',(await request(c.people[5],'/sports/c/notices/'+notice.id+'/read','POST')).code!==200);
  await api(c.people[1],'/sports/c/notices/'+notice.id+'/read','POST');
  const v=versionOf('asp_notification',notice.id);await api(c.people[1],'/sports/c/notices/'+notice.id+'/read','POST');
  test.check('repeat mark-read keeps a single durable read state',versionOf('asp_notification',notice.id)===v&&(await api(c.people[1],'/sports/c/notices')).find(n=>n.id===notice.id).read);
  test.evidence.sms='Not configured: no real SMS delivery claimed';
}
async function cancellation(){
  const checkins=readSql(`SELECT count(*) FROM asp_checkin WHERE event_id=${event};`);
  await step('cancel',()=>api(c.organizer,`/sports/b/events/${event}/cancel`,'POST',{reason:'合成隔离回归：旧版本错误允许不足额报到，取消后接续退款，保留原事实'}));
  test.check('cancellation preserves the previously observed erroneous check-in history',readSql(`SELECT count(*) FROM asp_checkin WHERE event_id=${event};`)===checkins);
  test.check('cancelled event refuses new participant business',(await request(c.people[3],'/sports/c/registrations','POST',{unitId:funds.pairUnit,requestKey:key()})).code!==200);
  for(const obligation of [funds.partialEntryObligation,funds.surplusEntryObligation]){
    for(const row of (await api(c.organizer,`/sports/b/fees/obligations/${obligation}/records`)).receipts.filter(x=>x.status==='confirmed'&&Number(x.refundedAmount)<Number(x.amount))){
      await step('refund-'+row.paymentId,()=>api(c.organizer,`/sports/b/fees/actions/${row.pendingActionId}/refund`,'POST',{amount:String(Number(row.amount)-Number(row.refundedAmount)),occurredAt:beijingTime(),recipientName:row.payerName,note:'合成取消退款记录，未发生实际银行转账',requestKey:key()}));
    }
    test.check('cancelled synthetic obligation retains receipts and zero effective funds',Number((await api(c.organizer,`/sports/b/fees/obligations/${obligation}/records`)).netAmount)===0);
  }
  await step('wrapup',()=>act(c.organizer,'event.wrapup',input(),'wrapup'));
  await step('close',()=>act(c.organizer,'event.close',input(),'close'));
  test.check('the former failed scenario closes through cancellation and refund business actions',readSql(`SELECT closure_status FROM asp_event WHERE id=${event};`)==='closed');
}
try{if(stage==='competition')await competitionAftercare();else if(stage==='finish')await finish();else if(stage==='cancel')await cancellation();else throw Error('Unknown aftercare stage');test.evidence.objects={eventId:event,complaintId:s.complaintId};test.finish();}catch(error){test.evidence.failure=error.message;test.save();console.error(error.message);process.exitCode=1;}
