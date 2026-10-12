import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {context,api,readSql} from './lib/BusinessRegression.mjs';
const build=process.env.AISPORTS_AWARD_BUILD;assert.ok(build);const evidence=fs.readFileSync(build);const compiled=JSON.parse(evidence.toString().replace(/^\uFEFF/,''));
const runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,''));
assert.ok(compiled.passed&&compiled.jarSha256===runtime.jarSHA256,'Current tested package binding');
const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const admin={token:(await api(null,'/auth/login','POST',{username:readSql('SELECT user_name FROM sys_user WHERE user_id=1;'),password:session.password,grantType:'password',tenantId:'000000',clientId:context.clientId})).access_token};
const before=await api(admin,'/sports/platform/management');const d=before.definitions.find(r=>r.definition.code==='honor.resolve');assert.ok(d&&!d.definition.agent,'Human review only');
const agents=v=>JSON.stringify(v.activations.filter(a=>a.channel==='agent').sort((a,b)=>String(a.code).localeCompare(String(b.code))));
assert.match(d.definitionHash,/^[a-f0-9]{64}$/);
const alreadyOpen=readSql("SELECT count(*) FROM asp_capability_activation a JOIN asp_capability_version v ON v.id=a.capability_version_id AND v.code=a.code WHERE a.code='honor.resolve' AND a.channel='ui' AND a.enabled AND v.status='published' AND v.source_hash='"+d.definitionHash+"';")!=='0';
if(!alreadyOpen)await api(admin,'/sports/platform/management/release','POST',{code:'honor.resolve',channel:'ui',enabled:true,definitionHash:d.definitionHash,evidenceHash:crypto.createHash('sha256').update(evidence).digest('hex')});
const after=await api(admin,'/sports/platform/management');assert.equal(agents(before),agents(after),'No agent channel changes');
const out=path.join(process.env.AISPORTS_AWARD_RUN,'activation-'+crypto.randomUUID()+'.json');
fs.writeFileSync(out,JSON.stringify({at:new Date().toISOString(),scope:'Provisional human UI release in existing isolated database only; compile evidence, business acceptance follows separately',database:context.database,code:'honor.resolve',channel:'ui',definitionHash:d.definitionHash,jarSha256:runtime.jarSHA256,compileEvidenceHash:crypto.createHash('sha256').update(evidence).digest('hex'),activationMutation:!alreadyOpen,agentActivationsUnchanged:true,passed:true},null,2));console.log('Evidence: '+out);

