// Read-only follow-up after both independently scoped teams have dissolved.
// Proof ownership and the registered manager survive changes to the live team.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {testHarness,hashFile} from './lib/badminton-participant-test.mjs';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const h=testHarness('participant-closed-history'),{api,call,check,context,people}=h,[A,B,C,D,E,F]=people;
const readState=name=>{const file=path.join(h.root,name),value=JSON.parse(fs.readFileSync(file,'utf8'));assert.equal(value.runId,context.runId);return {file,value};};
const original=readState('ai-canonical-entry-state.json'),scheduled=readState('ai-scheduled-entry-state.json'),results=readState('scheduled-competition-results-state.json');
assert.equal(String(results.value.eventId),String(scheduled.value.eventId));
h.report.scope='Actual r7 read-only ordinary participant HTTP/UI after the two isolated synthetic teams dissolved. Previously recorded synthetic match and awards are not official real-world facts. No login, model, SQL, action execute, payment, attendance, result, award or team mutation.';
h.report.pageErrors=[];h.report.browserWrites=[];h.report.linkedStates=[original,scheduled,results].map(row=>({path:path.relative(process.cwd(),row.file).replaceAll('\\','/'),sha256:hashFile(row.file)}));
let browser;const contexts=[];let currentPage;
async function pageFor(actor,width){const ctx=await browser.newContext({viewport:{width,height:width<600?844:1000},reducedMotion:'reduce'});contexts.push(ctx);await ctx.addInitScript(token=>{localStorage.setItem('Admin-Token',token);localStorage.setItem('Platform-Token',token);},actor.token);const page=await ctx.newPage();currentPage=page;page.on('pageerror',()=>h.report.pageErrors.push('script error'));page.on('request',request=>{if(new URL(request.url()).pathname.includes('/sports/')&&!['GET','HEAD','OPTIONS'].includes(request.method()))h.report.browserWrites.push({method:request.method(),path:new URL(request.url()).pathname});});return page;}
async function screenshot(page,name){await page.locator('.el-message').first().waitFor({state:'hidden',timeout:5000}).catch(()=>{});await page.evaluate(()=>{document.activeElement?.blur();window.scrollTo(0,0);});const file=path.join(h.out,name+'.png');await page.screenshot({path:file,fullPage:true});h.report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:hashFile(file),viewport:page.viewportSize()});}
try{
 await h.preflight();
 const summaries=[];
 for(const [name,s] of [['cancelled-future',original.value],['naturally-started',scheduled.value]]){
  const closure=await api(h.organizer,'/sports/closure/events/'+s.eventId);summaries.push({scope:name,eventId:s.eventId,closure});
  check('CH01.'+name,'The linked closed event still reports competition, funds and issues complete',closure.event.closure_status==='closed'&&closure.competitionEnded&&closure.fundsClosed&&closure.issuesClosed&&closure.proofsAwaitingReview===0);
  const managed=await h.entry(A,s.entryA);
  // Test the actual projection, rather than accepting a successful response alone.
  check('CH02.'+name,'Dissolved team history keeps the original accountable registration manager, revision, amount and obligation',managed.canManage&&managed.rosterRevision===1&&Number(managed.feeAmount)===40&&String(managed.obligationId)===String(s.entryAObligation));
  const teamB=(await api(B,'/sports/c/teams')).memberships.find(row=>String(row.teamId)===String(s.team));
  check('CH03.'+name,'The new captain sees dissolved history, without inheriting the former manager authority',teamB?.teamStatus==='disbanded'&&teamB.membershipStatus!=='active'&&(await call(B,'/sports/entry-management/'+s.entryA)).code!==200);
 }
 h.report.closureSummaries=summaries;
 check('CH04','The original future event is cancelled and retains an unplayed fixture without inventing an official score',summaries[0].closure.event.holding_status==='cancelled'&&summaries[0].closure.missingResults===1);
 check('CH05','The independently scheduled event completed its formal results naturally and has no missing result',summaries[1].closure.event.holding_status!=='cancelled'&&summaries[1].closure.missingResults===0);
 const scheduledName=summaries[1].closure.event.name,originalName=summaries[0].closure.event.name;
 assert.ok(scheduledName&&originalName&&scheduledName!==originalName);
 const observedProofs=[];
 for(const actor of [A,B]){
  const cards=(await api(actor,'/sports/c/proofs')).filter(card=>card.eventName===scheduledName);
  check('CH06.'+actor.label,'The awarded frozen member still sees exactly their current synthetic private proof after team dissolution',cards.length===1&&cards[0].self===true&&cards[0].title==='本轮合成双打优胜奖'&&!results.value.oldHonors.includes(String(cards[0].honorId)));
  const proof=await api(actor,'/sports/c/proofs/'+cards[0].honorId);
  check('CH07.'+actor.label,'The owner proof detail exactly matches the current proof list',JSON.stringify(proof)===JSON.stringify(cards[0]));
  const other=actor===A?B:A;
  check('CH08.'+actor.label,'Neither the current teammate nor an unrelated account can read this member private proof',(await call(other,'/sports/c/proofs/'+cards[0].honorId)).code!==200&&(await call(F,'/sports/c/proofs/'+cards[0].honorId)).code!==200);
  observedProofs.push({actor:actor.label,honorId:cards[0].honorId,awardKey:cards[0].awardKey,eventName:cards[0].eventName,title:cards[0].title});
 }
 h.report.currentSyntheticProofs=observedProofs;
 for(const id of results.value.oldHonors)check('CH09.'+id,'An old replaced proof remains unavailable to its previous owner',(await call(A,'/sports/c/proofs/'+id)).code!==200);
 for(const actor of [A,B,C,D]){
  const cards=await api(actor,'/sports/c/results'),actual=cards.filter(card=>card.eventName===scheduledName&&card.matchCode===context.prefix+'-SCHEDULE-PAIR-01');
  check('CH10.'+actor.label,'Each frozen participant retains the current 2:1 official service result after the long-term team closes',actual.length===1&&actual[0].summary==='2:1'&&actual[0].outcomeA==='win'&&actual[0].outcomeB==='loss'&&actual[0].eventCancelled===false);
  check('CH11.'+actor.label,'The cancelled future event contributes no invented formal result',!cards.some(card=>card.eventName===originalName));
 }
 check('CH12','Unrelated ordinary accounts inherit neither the scheduled formal result nor its awards',!(await api(F,'/sports/c/results')).some(card=>card.eventName===scheduledName)&&!(await api(E,'/sports/c/proofs')).some(card=>card.eventName===scheduledName));
 browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 const mobile=await pageFor(A,390);await mobile.goto(context.frontend+'/portal/results',{waitUntil:'domcontentloaded'});await mobile.locator('article.result-card').filter({hasText:scheduledName}).filter({hasText:context.prefix+'-SCHEDULE-PAIR-01'}).waitFor({timeout:60000});
 check('CH13','The former captain sees the retained scheduled result on the phone without horizontal overflow',await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));await screenshot(mobile,'mobile-formal-result-after-team-disband');
 const desktop=await pageFor(B,1440);await desktop.goto(context.frontend+'/portal/proofs',{waitUntil:'domcontentloaded'});await desktop.locator('article.proof-card').filter({hasText:scheduledName}).waitFor({timeout:60000});
 check('CH14','The former member sees their private current synthetic proof on desktop without horizontal overflow',await desktop.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));await screenshot(desktop,'desktop-current-private-proof-after-team-disband');
 check('CH15','Opening the historical results and proofs performs no business write and raises no browser script error',h.report.browserWrites.length===0&&h.report.pageErrors.length===0);h.report.passed=true;
}catch(error){h.report.failures.push({id:'closed-history',reason:error.message});if(currentPage)await screenshot(currentPage,'failure').catch(()=>{});process.exitCode=1;}
finally{for(const ctx of contexts)await ctx.close();if(browser)await browser.close();h.final({stage:'closed-history',sourceFiles:['scripts/Test-BadmintonClosedHistory.mjs','scripts/lib/badminton-participant-test.mjs','plus-ui/src/views/portal/results.vue','plus-ui/src/views/portal/proof.vue'].map(file=>({path:file,sha256:hashFile(file)}))});}
