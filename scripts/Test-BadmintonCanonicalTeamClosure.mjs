// Run only after the root's canonical competition/funds/issues closure. Ordinary
// captain changes do not rewrite the already frozen registration or its manager.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {testHarness,hashFile} from './lib/badminton-participant-test.mjs';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json'),{chromium}=require('playwright');
const scope=process.argv[4]||'canonical';assert.ok(['canonical','scheduled'].includes(scope));
const h=testHarness(scope==='scheduled'?'participant-canonical-scheduled-closure':'participant-canonical-closure',scope==='scheduled'?{progressName:'participant-scheduled-progress.private.json'}:{}),{context,people,api,check,once}=h,[A,B]=people;
const statePath=path.resolve(process.argv[3]||''),state=JSON.parse(fs.readFileSync(statePath,'utf8'));assert.equal(state.runId,context.runId);assert.equal(String(state.entryAManager),String(A.id));
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'}),contexts=[];let activePage;
h.report.pageErrors=[];h.report.scope='Actual ordinary captain/leave/disband UI after the linked canonical event is truly closed in the isolated synthetic flow. No new payment, roster, model, check-in, result or award facts.';
async function open(actor,width){const ctx=await browser.newContext({viewport:{width,height:width<600?844:1000},reducedMotion:'reduce'});contexts.push(ctx);await ctx.addInitScript(t=>{localStorage.setItem('Admin-Token',t);localStorage.setItem('Platform-Token',t);},actor.token);const page=await ctx.newPage();activePage=page;page.on('pageerror',()=>h.report.pageErrors.push('script error'));return {page,actor};}
async function go(tab,route){activePage=tab.page;await tab.page.goto(context.frontend+route,{waitUntil:'domcontentloaded'});await tab.page.locator('div.consumer-app').first().waitFor({timeout:60000});}
async function ui(tab,suffix,button,dialogName,confirmation){const wait=tab.page.waitForResponse(r=>r.request().method()==='POST'&&new URL(r.url()).pathname.endsWith(suffix),{timeout:25000});wait.catch(()=>{});await button.click();const dialog=tab.page.getByRole('dialog',{name:dialogName,exact:true});await dialog.waitFor();await dialog.getByRole('button',{name:confirmation,exact:true}).click();const b=await(await wait).json();assert.equal(b.code,200,'Actual ordinary closed-team UI '+suffix);return b.data;}
async function shot(tab,name){await tab.page.locator('.el-message').first().waitFor({state:'hidden',timeout:5000}).catch(()=>{});await tab.page.evaluate(()=>{document.activeElement?.blur();window.scrollTo(0,0);});const file=path.join(h.out,name+'.png');await tab.page.screenshot({path:file,fullPage:true});h.report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:hashFile(file)});}
function frozen(entry){return {id:entry.id,status:entry.status,teamName:entry.teamName,rosterRevision:entry.rosterRevision,requestKey:entry.requestKey,obligationId:entry.obligationId,feeAmount:entry.feeAmount,members:entry.members.map(m=>({id:m.id,accountId:m.accountId,status:m.status}))};}
try{
 await h.preflight();const closureReadRoute='/sports/closure/events/'+state.eventId;const summary=await api(h.organizer,closureReadRoute);
 const cancelled=summary.event.holding_status==='cancelled';
 check('KC01','The real event has closed through cancellation or completed results, with money and issues settled',summary.event.closure_status==='closed'&&summary.competitionEnded&&summary.fundsClosed&&summary.issuesClosed&&(cancelled||summary.missingResults===0)&&summary.proofsAwaitingReview===0);
 h.report.closureBoundary=cancelled?'Cancelled event retains unplayed match history; no formal-score or award claim':'Completed formal results with no missing result or unreviewed proof';
 h.report.closureReadRoute=closureReadRoute;h.report.closureSummary=summary;
 const before=await h.entry(A,state.entryA);h.progress.objects.canonicalClosedRoster ||= frozen(before);h.save();const original=h.progress.objects.canonicalClosedRoster;
 const captain=await open(A,390),member=await open(B,1440);
 await go(captain,'/portal/teams/'+state.team);
 await once('canonical-team-closure.transfer',()=>ui(captain,'/'+state.team+'/captain',captain.page.getByRole('button',{name:'转让队长',exact:true}),'转让队长','确认转让'));
 const transferred=await api(B,'/sports/c/teams/'+state.team);
 check('KC02','After actual closure the ordinary captain can transfer the long-term team to B',transferred.members.filter(m=>m.status==='active'&&m.role==='captain').length===1&&String(transferred.members.find(m=>m.status==='active'&&m.role==='captain').accountId)===String(B.id));
 check('KC03','Captain transfer keeps the frozen entry manager independent and preserves formal facts',(await h.entry(A,state.entryA)).canManage===true&&(await h.call(B,'/sports/entry-management/'+state.entryA)).code!==200&&JSON.stringify(frozen(await h.entry(A,state.entryA)))===JSON.stringify(original));
 await go(member,'/portal/teams/'+state.team);await member.page.getByRole('button',{name:'保存队名',exact:true}).waitFor();await shot(member,'desktop-closed-canonical-new-captain');
 await go(captain,'/portal/teams/'+state.team);await once('canonical-team-closure.leave',()=>ui(captain,'/'+state.team+'/leave',captain.page.getByRole('button',{name:'退出队伍',exact:true}),'退出小队','确认退出'));
 const left=(await api(A,'/sports/c/teams')).memberships.find(m=>String(m.teamId)===String(state.team));
 check('KC04','Former captain can leave the closed long-term team through actual mobile UI',left&&left.membershipStatus!=='active');
 await go(member,'/portal/teams/'+state.team);await member.page.getByRole('button',{name:'解散队伍',exact:true}).waitFor();await once('canonical-team-closure.disband',()=>ui(member,'/'+state.team+'/disband',member.page.getByRole('button',{name:'解散队伍',exact:true}),'解散队伍','确定'));
 const dissolved=(await api(B,'/sports/c/teams')).memberships.find(m=>String(m.teamId)===String(state.team));check('KC05','The new captain can disband this genuinely closed canonical team',dissolved?.teamStatus==='disbanded'&&dissolved.membershipStatus!=='active');
 const retained=await h.entry(A,state.entryA);check('KC06','Disband and departure retain historical roster, amount, obligation and the responsible manager',retained.canManage===true&&JSON.stringify(frozen(retained))===JSON.stringify(original));
 await go(captain,'/portal/registration/detail/'+state.entryA);await captain.page.locator('.registration-overview').waitFor();check('KC07','Former captain still opens their original canonical registration on the phone without horizontal overflow',await captain.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));await shot(captain,'mobile-closed-canonical-history-after-disband');
 check('KC08','Canonical close-out team pages report no browser script errors',h.report.pageErrors.length===0);h.report.passed=true;
}catch(error){h.report.failures.push({id:'canonical-team-closure',reason:error.message});if(activePage)await shot({page:activePage},'failure').catch(()=>{});process.exitCode=1;}
finally{for(const ctx of contexts)await ctx.close();await browser.close();h.final({stage:'canonical-team-closure',canonicalStateSHA256:hashFile(statePath),sourceFiles:['scripts/Test-BadmintonCanonicalTeamClosure.mjs','scripts/lib/badminton-participant-test.mjs','plus-ui/src/views/portal/team.vue','plus-ui/src/views/sports/registration/enter.vue'].map(file=>({path:file,sha256:hashFile(file)}))});}
