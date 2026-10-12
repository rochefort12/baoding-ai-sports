// Rebind only previously enabled registration candidates in the isolated test service.
// This is a provisional test release, not a claim that the subsequent live test passed.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
import {context as c,api,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('registration-candidate-rebind');
const logPath=fs.realpathSync(process.argv[2]||'');
const root=fs.realpathSync(c.out);
if(!logPath.startsWith(root+path.sep))throw Error('Build evidence must belong to the protected run');
const log=fs.readFileSync(logPath,'utf8');
if(!log.includes('BUILD SUCCESS'))throw Error('Successful full build required');
for(const name of ['RegistrationActionWriteScopeTest','RegistrationDeclarationImageTest','FieldCatalogDraftBoundaryTest','HistoricalFundRecordsTest'])test.check(name+' passes in the selected full build',new RegExp('Tests run: \\d+, Failures: 0, Errors: 0, Skipped: 0[^\\r\\n]*'+name).test(log));
const catalog=await api(c.admin,'/sports/platform/management');
for(const code of ['registration.create','registration.submit','registration.mine']){
  const current=catalog.definitions.find(r=>r.definition.code===code);if(!current)throw Error('Missing action '+code);
  const prior=catalog.activations.filter(a=>a.code===code&&a.enabled&&(['ui','agent'].includes(a.channel)));
  for(const activation of prior){
    if(activation.channel==='agent'&&(code!=='registration.mine'||current.definition.mutation||current.definition.writes.length))throw Error('Write Agent activation is prohibited');
    if(activation.source_hash===current.definitionHash)continue;
    const basis={scope:'PROVISIONAL_PREVIOUSLY_ENABLED_ISOLATED_TEST_CANDIDATE',database:c.database,code,channel:activation.channel,oldDefinitionHash:activation.source_hash,definitionHash:current.definitionHash,buildLogSha256:crypto.createHash('sha256').update(fs.readFileSync(logPath)).digest('hex')};
    const bytes=JSON.stringify(basis,null,2);fs.writeFileSync(path.join(test.directory,code+'-'+activation.channel+'-basis.json'),bytes);
    await api(c.admin,'/sports/platform/management/release','POST',{code,channel:activation.channel,enabled:true,definitionHash:current.definitionHash,evidenceHash:crypto.createHash('sha256').update(bytes).digest('hex')});
    test.check('only the previously enabled '+code+' '+activation.channel+' candidate is rebound',true,basis);
  }
}
const file=process.env.AISPORTS_REGRESSION_CONTEXT;const latest=JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));const temp=file+'.'+crypto.randomUUID()+'.tmp';fs.writeFileSync(temp,JSON.stringify({...latest,definitions:catalog.definitions},null,2));fs.renameSync(temp,file);
test.check('fresh catalog preserves all concurrently updated role sessions',true);test.finish();
