// Immutable, sanitized index. It reads existing receipts without editing them
// and does not execute business operations or turn partial runs into full PASS.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const contextPath=path.resolve(process.argv[2]||'');assert.ok(process.argv[2]);
const context=JSON.parse(fs.readFileSync(contextPath,'utf8')),root=path.dirname(contextPath);
assert.equal(context.backend,'http://127.0.0.1:8082');assert.equal(context.frontend,'http://127.0.0.1:5192');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const relative=file=>path.relative(process.cwd(),file).replaceAll('\\','/');
const scrub=text=>String(text||'').replace(/(\/invites\/)[A-Za-z0-9_-]+/g,'$1{private-invite}').replace(/\b\d{11}\b/g,'{private-phone}').replace(/(?:Bearer\s+|sk-)[A-Za-z0-9._-]+/g,'{credential}');
const boundary=id=>/^P0/.test(id)?'session and metadata preflight':/^(UI00|PX00|K03|HF33)$/.test(id)?'browser script/safety check':/^HF/.test(id)?'actual isolated certification transition/display/private storage with entirely synthetic claim, not factual world honor':/^R[12]\.(08|10|20)$|^B[12]\.12$|^RX04$/.test(id)?'executor denial without valid action confirmation; not a business-state guard proof':/^RXC04$|^RXC05$/.test(id)?'real natural expiry; previously valid confirmation rejected as expired or changed snapshot':'observed business or viewport check; see original receipt scope';
const entries=[];
for(const dir of fs.readdirSync(root).filter(name=>/^participant-(http|responsibility|ui|personal|canonical(?:-scheduled)?(?:-closure)?|honor|received|closed-history)-\d+$/.test(name)).sort()){
  const file=path.join(root,dir,'receipt.json');if(!fs.existsSync(file))continue;const r=JSON.parse(fs.readFileSync(file,'utf8'));assert.equal(r.runId,context.runId);
  entries.push({path:relative(file),sha256:sha(file),stage:r.stage||(dir.startsWith('participant-canonical')?'canonical':undefined),passed:r.passed,observedChecks:r.checks.length,
    preflightChecks:r.checks.filter(row=>/^P0/.test(row.id)).length,
    jarSHA256:r.jarSHA256||null,jarBinding:r.jarSHA256?'captured at actual run start':'original receipt did not capture JAR SHA; require root release chronology rather than inference',
    checks:r.checks.filter(row=>!/^P0/.test(row.id)).map(row=>({id:row.id,text:scrub(row.text),observedAt:row.observedAt,evidenceBoundary:boundary(row.id)})),
    failures:(r.failures||[]).map(row=>({id:row.id,reason:scrub(row.reason)})),
    scope:r.scope,
    screenshots:(r.screenshots||[]).map(row=>({path:row.path,sha256:row.sha256,...(row.viewport?{viewport:row.viewport}:{})})),
    restoration:r.restoration||[],canonicalState:r.canonicalState});
}
const index={createdAt:new Date().toISOString(),runId:context.runId,backend:context.backend,frontend:context.frontend,database:context.database,
  scope:'Actual isolated local HTTP/UI under six synthetic ordinary participants and organizer. No business response stubs, force clicks or SQL. Synthetic event/material/avatar facts; not real bank, SMS, venue participation or official awards.',
  countsAreNotBusinessCompletion:true,partialRunsRemainFailed:true,entries,
  unexecuted:['24-hour natural responsibility-invitation expiry','Actual SMS provider registration/password recovery','Closing any of the existing six participant accounts','Real bank transfer, real onsite match, official proof verification',...(!entries.some(row=>row.stage==='canonical'&&row.passed)?['Canonical AI-published participant chain until its own passing receipt exists']:[]),...(!entries.some(row=>row.stage==='canonical-scheduled'&&row.passed)?['Independent short-window AI-published participant chain until its own passing receipt exists']:[]),...(!entries.some(row=>row.path.includes('/participant-received-')&&row.passed)?['Own received-invitation reopened UI and denial boundaries after the updated candidate JAR']:[]),...(!entries.some(row=>row.stage==='canonical-team-closure'&&row.passed)?['Post-event funds/responsibility closure and team dissolution require the linked root closure receipt']:[])]};
const out=path.join(root,'participant-evidence-'+Date.now()+'.json');const fd=fs.openSync(out,'wx');try{fs.writeFileSync(fd,JSON.stringify(index,null,2));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
console.log(JSON.stringify({path:relative(out),sha256:sha(out),receiptCount:entries.length,successfulRunReceipts:entries.filter(r=>r.passed).length,failedRunReceipts:entries.filter(r=>!r.passed).length}));
