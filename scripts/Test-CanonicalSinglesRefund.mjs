// Exercise the material-created singles price through real isolated services.
// All identity, bank money and participant facts in this scenario are synthetic.
import fs from 'node:fs';import path from 'node:path';
import {context as c,key,api,request,action,readSql,versionOf,beijingTime,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('canonical-singles-refund');
const canonical=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
if(canonical.runId!==c.runId||!canonical.singleUnitId)throw Error('Use the organizer’s source-created canonical event');
const actor=c.people[5],event=String(canonical.eventId),unit=String(canonical.singleUnitId);
const file=path.join(c.out,'canonical-singles-refund-state.json');
const s=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{runId:c.runId,eventId:event,unitId:unit,steps:{},keys:{}};
if(s.runId!==c.runId||s.eventId!==event||s.unitId!==unit)throw Error('Wrong singles checkpoint');
const save=()=>fs.writeFileSync(file,JSON.stringify(s,null,2));
const once=async(name,work)=>{if(s.steps[name])return;await work();s.steps[name]=true;save();};
const remember=async(name,work)=>{if(s[name])return s[name];s[name]=await work();save();return s[name];};
const requestKey=name=>{s.keys[name]??=key();save();return s.keys[name];};
const row=async()=>(await api(actor,'/sports/c/registrations')).find(r=>r.id===s.registrationId);
const records=()=>api(c.organizer,`/sports/b/fees/obligations/${s.obligationId}/records`);
try{
  await remember('registrationId',async()=>(await api(actor,'/sports/c/registrations','POST',{unitId:unit,requestKey:requestKey('create')})).id);
  const own=await row();test.check('source-created singles allows one actual member without a room',own.members.filter(m=>m.status==='confirmed').length===1);
  await once('answers',async()=>{const fields=await api(actor,`/sports/c/registrations/${s.registrationId}/fields`);if(fields.length)await api(actor,`/sports/c/registrations/${s.registrationId}/fields`,'PUT',fields.map(f=>({eventFieldId:f.eventFieldId,valueText:({text:'本轮合成参赛者本人',number:'3',date:'2026-10-11',enum:f.options?.[0]})[f.valueType]})));});
  await once('acknowledged',()=>api(actor,`/sports/c/registrations/${s.registrationId}/declaration-ack`,'POST'));
  await once('submitted',()=>action(actor,'registration.submit',{registrationId:s.registrationId,expectedVersion:versionOf('asp_registration',s.registrationId)},requestKey('submit')));
  await remember('obligationId',async()=>(await api(c.organizer,`/sports/b/fees/units/${unit}/obligations`)).find(o=>o.registrationId===s.registrationId).obligationId);
  let due=await records();test.check('the AI source price freezes as exactly twenty yuan per singles order',Number(due.dueAmount)===20);
  if(!s.steps.paid)test.check('formal submission creates an unpaid independent obligation immediately',Number(due.netAmount)===0&&(await row()).status==='submitted');
  if(!s.steps.paid)test.check('unpaid singles cannot pass manual qualification',(await request(c.organizer,`/sports/b/registrations/${s.registrationId}/approve`,'POST')).code!==200);
  s.payment??={payerName:'本轮合成单打付款人',amount:'20.00',occurredAt:beijingTime(),note:'本机合成收款登记，不是真实银行到账',requestKey:requestKey('receipt')};save();
  await once('paid',()=>api(c.organizer,`/sports/b/fees/obligations/${s.obligationId}/confirm`,'POST',s.payment));
  if(!s.steps.withdrawn){due=await records();test.check('ordinary finance records one twenty-yuan receipt against the original obligation',Number(due.netAmount)===20&&due.receipts.length===1);await once('approved',()=>api(c.organizer,`/sports/b/registrations/${s.registrationId}/approve`,'POST'));test.check('adequate funds and human review authorize singles participation',(await row()).status==='approved');}
  await once('withdrawn',()=>api(actor,`/sports/c/registrations/${s.registrationId}/withdraw`,'POST'));
  test.check('withdrawal before check-in returns an editable draft and releases its singles slot',(await row()).status==='draft'&&readSql(`SELECT used_count FROM asp_capacity_pool WHERE unit_id=${unit};`)==='0');
  await remember('refundActionId',async()=>(await records()).receipts.find(r=>r.status==='confirmed').pendingActionId);
  s.refund??={amount:'20.00',occurredAt:beijingTime(),recipientName:s.payment.payerName,note:'本机合成退赛退款登记，不是真实银行转账',requestKey:requestKey('refund')};save();
  await once('refunded',()=>api(c.organizer,`/sports/b/fees/actions/${s.refundActionId}/refund`,'POST',s.refund));
  due=await records();test.check('refund preserves the receipt and independently closes its original-payer balance',Number(due.netAmount)===0&&due.receipts.length===1&&due.refunds.length===1);
  const history=await api(c.organizer,`/sports/b/fees/registrations/${s.registrationId}/history`);
  test.check('withdrawn singles retains a queryable original obligation and no pending financial duty',history.some(h=>h.obligationId===s.obligationId&&h.pending===false));
  const person=readSql(`SELECT person_id FROM asp_account WHERE id=${actor.id};`);
  test.check('participation fees never create attendance or growth facts by themselves',readSql(`SELECT count(*) FROM asp_checkin WHERE event_id=${event} AND person_id=${person}; SELECT count(*) FROM asp_growth_record WHERE event_id=${event} AND person_id=${person};`)==='0\n0');
  test.evidence.objects={eventId:event,unitId:unit,registrationId:s.registrationId,obligationId:s.obligationId};test.finish();
}catch(error){test.evidence.failure=error.message;test.save();console.error(error.message);process.exitCode=1;}
