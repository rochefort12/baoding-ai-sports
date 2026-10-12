// Must run after canonical participant submit, before any receipt registration.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
import {context as c,key,api,request,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('canonical-payment-proof');
const scheduled=process.argv.includes('--scheduled');
const entries=JSON.parse(fs.readFileSync(path.join(c.out,scheduled?'ai-scheduled-entry-state.json':'ai-canonical-entry-state.json'),'utf8'));
const stateFile=path.join(c.out,scheduled?'scheduled-payment-proof-state.json':'canonical-payment-proof-state.json');const s=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{runId:c.runId,requestKey:key()};
if(s.runId!==c.runId)throw Error('Wrong proof checkpoint');const save=()=>fs.writeFileSync(stateFile,JSON.stringify(s,null,2));save();
const bytes=fs.readFileSync('plus-ui/public/images/sports/badminton-hero-v1.webp');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function upload(actor,registration,content=bytes,requestKey=s.requestKey){const form=new FormData();form.append('file',new Blob([content],{type:'image/webp'}),'synthetic-payment-proof.webp');const r=await fetch(c.backend+`/sports/c/registrations/${registration}/payment-proofs?requestKey=${encodeURIComponent(requestKey)}`,{method:'POST',signal:AbortSignal.timeout(45000),headers:{clientid:c.clientId,...(actor?.token?{Authorization:'Bearer '+actor.token}:{})},body:form});return {http:r.status,...await r.json()};}
async function image(actor,registration,id,channel='c'){const r=await fetch(c.backend+`/sports/${channel}/registrations/${registration}/payment-proofs/${id}/image`,{headers:{clientid:c.clientId,...(actor?.token?{Authorization:'Bearer '+actor.token}:{})}});const content=Buffer.from(await r.arrayBuffer());return {http:r.status,content,headers:r.headers};}
try{
  const records=()=>api(c.organizer,`/sports/b/fees/obligations/${entries.entryAObligation}/records`);
  const before=await records();test.check('the confirmed material amount is owed but no payment is registered',Number(before.dueAmount)===40&&Number(before.netAmount)===0);
  const first=await upload(c.people[0],entries.entryA);test.check('entry manager actually uploads a private optional payment image',first.code===200&&Boolean(first.data?.id));s.proofId=first.data.id;save();
  const replay=await upload(c.people[0],entries.entryA);test.check('identical image and upload key reuse the same proof',replay.code===200&&replay.data.id===s.proofId&&(await api(c.people[0],`/sports/c/registrations/${entries.entryA}/payment-proofs`)).length===1);
  const changed=await upload(c.people[0],entries.entryA,Buffer.concat([bytes,Buffer.from('synthetic-change')]));test.check('same upload request cannot silently replace its image',changed.code!==200&&(await api(c.people[0],`/sports/c/registrations/${entries.entryA}/payment-proofs`)).length===1);
  test.check('an unrelated person cannot attach a payment proof',(await upload(c.people[5],entries.entryA,bytes,key())).code!==200);
  test.check('anonymous upload is rejected',(await upload(null,entries.entryA,bytes,key())).code!==200);
  test.check('another squad cannot list the first squads private financial proof',(await request(c.people[2],`/sports/c/registrations/${entries.entryA}/payment-proofs`)).code!==200);
  const personal=await image(c.people[0],entries.entryA,s.proofId);test.check('owner retrieves exact private image bytes with no-store protection',personal.http===200&&hash(personal.content)===hash(bytes)&&personal.headers.get('cache-control')==='no-store');
  const organized=await image(c.organizer,entries.entryA,s.proofId,'b');test.check('authorized finance role can read the original evidence',organized.http===200&&hash(organized.content)===hash(bytes));
  const otherManager=c.people.find(p=>p.id===entries.entryBManager);if(!otherManager)throw Error('Actual second manager required');
  const foreign=await image(otherManager,entries.entryB,s.proofId);test.check('an authorized second manager cannot move a proof identifier to their own obligation context',foreign.http!==200||hash(foreign.content)!==hash(bytes));
  const anonymous=await image(null,entries.entryA,s.proofId);test.check('private payment evidence is unavailable anonymously',anonymous.http!==200||hash(anonymous.content)!==hash(bytes));
  const after=await records();test.check('uploading evidence neither confirms money nor approves qualification',Number(after.netAmount)===0&&after.receipts.length===before.receipts.length&&(await api(c.people[0],'/sports/c/registrations')).find(r=>r.id===entries.entryA).status==='submitted');
  test.evidence.objects={eventId:entries.eventId,registrationId:entries.entryA,proofId:s.proofId};test.finish();
}catch(error){test.evidence.failure=error.message;test.save();console.error(error.message);process.exitCode=1;}
