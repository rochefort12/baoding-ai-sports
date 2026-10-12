// A new synthetic badminton round, exercised through real ordinary-role services.
// Bank transfers and match facts are simulated explicitly; no SQL business writes are permitted.
import fs from 'node:fs';
import path from 'node:path';
import {context as c,key,iso,beijingTime,api,request,action,readSql,versionOf,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('funds-competition');
const requestedStage=process.argv[2]||'funds';
const secondRound=requestedStage.endsWith('-round2');
const stateFile=path.join(c.out,secondRound?'funds-competition-fixed-state.json':'funds-competition-state.json');
const s=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{runId:c.runId,payments:{},steps:{}};
if(s.runId!==c.runId) throw new Error('This business state belongs to another round.');
const save=()=>fs.writeFileSync(stateFile,JSON.stringify(s,null,2));
const remember=async(name,work)=>{if(s[name]!==undefined)return s[name];const value=await work();s[name]=value;save();return value;};
const step=async(name,work)=>{if(s.steps[name])return;await work();s.steps[name]=true;save();};
const act=async(actor,code,input,requestKey)=> (await action(actor,code,input,requestKey)).value;
const rowFor=async(actor,id)=>(await api(actor,'/sports/c/registrations')).find(row=>row.id===id);
async function payment(obligation,amount,slot){
  s.payments[slot]??={payerName:'本轮模拟第三方付款人',amount,occurredAt:beijingTime(),note:'合成款项：不是实际银行到账',requestKey:key()};save();
  return api(c.organizer,`/sports/b/fees/obligations/${obligation}/confirm`,'POST',s.payments[slot]);
}
const records=id=>api(c.organizer,`/sports/b/fees/obligations/${id}/records`);
async function prepare(){
  await remember('eventId',async()=>{const result=await act(c.organizer,'event.create',{draftJson:JSON.stringify({name:c.prefix+'-资金赛务轮',location:'本轮合成羽毛球馆',projectName:'羽毛球',feeDescription:'单打和双打每单100元（模拟）',registrationOpensAt:iso(-1),registrationClosesAt:iso(8),startsAt:iso(9),endsAt:iso(12),registrationReview:'manual',rulesText:'仅本机多角色测试；未参赛或赛事取消按原付款人退还模拟款项。',declarationText:'合成赛事与款项，不要真实付款；本人确认参加。',declarationAckRequired:true})});return result.eventId;});
  for(const [name,entryType,limitCount] of [['partialUnit','individual',8],['surplusUnit','individual',8],['pairUnit','pair',2]]){
    await remember(name,async()=>{const result=await api(c.organizer,'/sports/b/registrations/units','POST',{eventId:s.eventId,name:c.prefix+'-'+name,entryType,minMembers:entryType==='pair'?2:1,maxMembers:entryType==='pair'?2:1,limitCount,requestKey:key(),charged:true,amount:'100.00',paymentMode:'offline',payInstruction:'只使用模拟收款登记；禁止真实转账'});return result.id;});
  }
  await step('published',async()=>{await act(c.organizer,'event.publish',{eventId:s.eventId,expectedVersion:versionOf('asp_event',s.eventId),contactName:'本轮模拟责任人',contactMethod:'finance@simulation.invalid'});});
  test.check('ordinary organizer publishes the new synthetic event',readSql(`SELECT publication_status FROM asp_event WHERE id=${s.eventId};`)==='published');
  for(const [name,index,unit] of [['partialEntry',4,s.partialUnit],['surplusEntry',5,s.surplusUnit]]){
    await remember(name,async()=>{const result=await api(c.people[index],'/sports/c/registrations','POST',{unitId:unit,requestKey:key()});return result.id;});
    await step(name+'Submitted',async()=>{await api(c.people[index],`/sports/c/registrations/${s[name]}/declaration-ack`,'POST');await act(c.people[index],'registration.submit',{registrationId:s[name],expectedVersion:versionOf('asp_registration',s[name])});});
    await remember(name+'Obligation',async()=>{const rows=await api(c.organizer,`/sports/b/fees/units/${unit}/obligations`);return rows.find(row=>row.registrationId===s[name]).obligationId;});
  }
  test.evidence.objects={eventId:s.eventId,partialEntry:s.partialEntry,surplusEntry:s.surplusEntry};test.save();
}
async function funds(){
  const obligation=s.partialEntryObligation,actor=c.people[4];
  const initial=await records(obligation);
  test.check('formal submission creates an independent payment obligation',Number(initial.dueAmount)===100&&s.partialEntryObligation!==s.surplusEntryObligation);
  const current=await rowFor(actor,s.partialEntry);
  test.check('normal applicant can read their own frozen amount and instructions',Number(current.feeAmount)===100&&Boolean(await api(actor,`/sports/c/registrations/${s.partialEntry}/payment-instructions`)));
  await step('declared',async()=>{await api(actor,`/sports/c/registrations/${s.partialEntry}/payment-declared`,'POST');});
  test.check('payment declaration alone does not settle the obligation',Number((await records(obligation)).netAmount)===0||s.steps.partialPaid);
  test.check('unrelated participant cannot declare this payment',(await request(c.people[3],`/sports/c/registrations/${s.partialEntry}/payment-declared`,'POST')).code!==200);
  test.check('ordinary government cannot record money',(await request(c.government,`/sports/b/fees/obligations/${obligation}/confirm`,'POST',{payerName:'越权测试',amount:'100',occurredAt:beijingTime(),note:'合成拒绝',requestKey:key()})).code!==200);
  test.check('participant cannot call organizer receipt management',(await request(actor,`/sports/b/fees/obligations/${obligation}/records`)).code!==200);
  for(const [amount,label] of [['0','zero'],['-1','negative'],['1.001','fraction beyond cents'],['10000000000000000','overflow']]){
    const before=await records(obligation);const rejected=await request(c.organizer,`/sports/b/fees/obligations/${obligation}/confirm`,'POST',{payerName:'合成金额拒绝',amount,occurredAt:beijingTime(),note:'无真实款项',requestKey:key()});const after=await records(obligation);
    test.check(label+' receipt is rejected without adding a payment',rejected.code!==200&&after.receipts.length===before.receipts.length,{code:rejected.code});
  }
  await step('partialPaid',()=>payment(obligation,'40.00','partial40'));
  test.check('partial receipt remains payable',Number((await records(obligation)).netAmount)===40||s.steps.partialSettled);
  if(!s.steps.partialSettled){
    test.check('partial receipt cannot approve qualification',(await request(c.organizer,`/sports/b/registrations/${s.partialEntry}/approve`,'POST')).code!==200);
    const before=await records(obligation);await payment(obligation,'40.00','partial40');const after=await records(obligation);
    test.check('replaying the identical receipt key adds no money',after.receipts.length===before.receipts.length&&Number(after.netAmount)===40);
    const conflict=await request(c.organizer,`/sports/b/fees/obligations/${obligation}/confirm`,'POST',{...s.payments.partial40,amount:'41.00'});
    test.check('same receipt key with changed amount is rejected',conflict.code!==200&&Number((await records(obligation)).netAmount)===40);
    const other=await request(c.organizer,`/sports/b/fees/obligations/${s.surplusEntryObligation}/confirm`,'POST',s.payments.partial40);
    test.check('same receipt key cannot be attached to a different obligation',other.code!==200&&Number((await records(s.surplusEntryObligation)).netAmount)===0);
  }
  await step('partialSettled',()=>payment(obligation,'60.00','partial60'));
  test.check('two actual service receipts settle exactly one obligation',Number((await records(obligation)).netAmount)===100);
  await step('partialApproved',async()=>{await api(c.organizer,`/sports/b/registrations/${s.partialEntry}/approve`,'POST');});
  if(!s.steps.partialWithdrawn) test.check('sufficient receipt allows ordinary organizer qualification',(await rowFor(actor,s.partialEntry)).status==='approved');
  await step('partialReversed',async()=>{const paid=await records(obligation);const paymentId=paid.receipts.find(row=>Number(row.amount)===60&&row.status==='confirmed').paymentId;await api(c.organizer,`/sports/b/fees/obligations/${obligation}/reverse`,'POST',{paymentId,requestKey:key()});});
  const reversed=await records(obligation);
  test.check('reversal preserves the wrong receipt and makes the balance short',reversed.receipts.some(row=>row.status==='reversed')&&(Number(reversed.netAmount)===40||s.steps.repaid));
  if(!s.steps.repaid){
    const personId=readSql(`SELECT person_id FROM asp_account WHERE id=${actor.id};`);
    test.check('reversed short payment prevents new check-in',(await request(c.organizer,`/sports/b/competition/events/${s.eventId}/check-ins`,'POST',{personId,requestKey:key()})).code!==200);
  }
  await step('repaid',()=>payment(obligation,'60.00','repaid60'));
  test.check('a new correct receipt restores the financial condition',Number((await records(obligation)).netAmount)===100&&reversed.receipts.some(row=>row.status==='reversed'));
  await step('partialWithdrawn',async()=>{await api(actor,`/sports/c/registrations/${s.partialEntry}/withdraw`,'POST');});
  test.check('approved but unreported unscheduled entry withdraws back to its editable draft',(await rowFor(actor,s.partialEntry)).status==='draft');
  test.check('withdrawal releases quota and preserves money',readSql(`SELECT used_count FROM asp_capacity_pool WHERE unit_id=${s.partialUnit};`)==='0'&&Number((await records(obligation)).netAmount)===100);
  await remember('resubmittedEntry',async()=>{const draft=await api(actor,'/sports/c/registrations','POST',{unitId:s.partialUnit,requestKey:key()});await api(actor,`/sports/c/registrations/${draft.id}/declaration-ack`,'POST');await act(actor,'registration.submit',{registrationId:draft.id,expectedVersion:versionOf('asp_registration',draft.id)});return draft.id;});
  await remember('resubmittedObligation',async()=>{const rows=await api(c.organizer,`/sports/b/fees/units/${s.partialUnit}/obligations`);return rows.find(row=>row.registrationId===s.resubmittedEntry).obligationId;});
  test.check('a resubmission owns a fresh unpaid obligation',s.resubmittedObligation!==obligation&&Number((await records(s.resubmittedObligation)).netAmount)===0);
  test.check('old money cannot qualify the new entry',(await request(c.organizer,`/sports/b/registrations/${s.resubmittedEntry}/approve`,'POST')).code!==200);
  await step('resubmissionWithdrawn',()=>api(actor,`/sports/c/registrations/${s.resubmittedEntry}/withdraw`,'POST'));
  const surplus=s.surplusEntryObligation;
  await step('overpaid',()=>payment(surplus,'120.00','overpaid120'));
  test.check('excess receipt is retained with an unresolved financial action',(await records(surplus)).receipts.some(row=>Number(row.amount)===120&&row.pendingActionId));
  await step('surplusRefunded',async()=>{const source=(await records(surplus)).receipts.find(row=>Number(row.amount)===120);const tooMuch=await request(c.organizer,`/sports/b/fees/actions/${source.pendingActionId}/refund`,'POST',{amount:'121',occurredAt:beijingTime(),recipientName:source.payerName,note:'合成超额退款拒绝',requestKey:key()});test.check('refund cannot exceed effective collected funds',tooMuch.code!==200);const otherRecipient=await request(c.organizer,`/sports/b/fees/actions/${source.pendingActionId}/refund`,'POST',{amount:'20',occurredAt:beijingTime(),recipientName:'另一位合成接收人',note:'未核实变更拒绝',requestKey:key()});test.check('changing refund recipient requires an explicit verified basis',otherRecipient.code!==200);await api(c.organizer,`/sports/b/fees/actions/${source.pendingActionId}/refund`,'POST',{amount:'20',occurredAt:beijingTime(),recipientName:source.payerName,note:'合成多收20元已退记录',requestKey:key()});});
  test.check('partial excess refund preserves original receipt and net fee',Number((await records(surplus)).netAmount)===100&&(await records(surplus)).refunds.length===1);
  await step('surplusWithdrawn',()=>api(c.people[5],`/sports/c/registrations/${s.surplusEntry}/withdraw`,'POST'));
  await step('surplusFullyRefunded',async()=>{const source=(await records(surplus)).receipts.find(row=>Number(row.amount)===120);await api(c.organizer,`/sports/b/fees/actions/${source.pendingActionId}/refund`,'POST',{amount:'100',occurredAt:beijingTime(),recipientName:source.payerName,note:'合成撤回后余款100已退记录',requestKey:key()});});
  test.check('multiple refund records close the effective receipt balance',Number((await records(surplus)).netAmount)===0&&(await records(surplus)).refunds.length===2);
  const source=(await records(surplus)).receipts.find(row=>Number(row.amount)===120);
  test.check('already refunded receipt cannot be reversed',(await request(c.organizer,`/sports/b/fees/obligations/${surplus}/reverse`,'POST',{paymentId:source.paymentId,requestKey:key()})).code!==200);
  await step('partialRefunded',async()=>{for(const source of (await records(obligation)).receipts.filter(row=>row.status==='confirmed'&&Number(row.refundedAmount)===0)){await api(c.organizer,`/sports/b/fees/actions/${source.pendingActionId}/refund`,'POST',{amount:String(source.amount),occurredAt:beijingTime(),recipientName:source.payerName,note:'合成撤回后的原付款人退款记录',requestKey:key()});}});
  test.check('withdrawn partial-payment round ends with all simulated funds returned',Number((await records(obligation)).netAmount)===0);
  test.evidence.objects={...test.evidence.objects,resubmittedEntry:s.resubmittedEntry,obligations:[obligation,surplus,s.resubmittedObligation]};test.save();
}

const stage=requestedStage.replace(/-round2$/,'');
try{await prepare();if(stage==='funds')await funds();else if(stage!=='prepare')throw new Error('Unknown funds stage.');test.finish();}
catch(error){test.evidence.failure=error.message;test.evidence.objects={...test.evidence.objects,eventId:s.eventId};test.save();save();console.error(error.message);process.exitCode=1;}
