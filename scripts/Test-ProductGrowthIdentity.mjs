// Read-only real participant verification. No mocked responses or rank/award/business writes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const privateRoot=path.resolve('.local/phase1-implementation');
const state=JSON.parse(fs.readFileSync(path.join(privateRoot,'verification-session.json'),'utf8'));
const runtime=JSON.parse(fs.readFileSync(path.join(privateRoot,'verification-runtime.json'),'utf8'));
const frontend=JSON.parse(fs.readFileSync('.local/demo-20261011/frontend-runtime.json','utf8'));
assert.equal(runtime.port,8082); assert.match(runtime.database,/^aisports_verify_phase1_[a-f0-9]{32}$/);
assert.equal(state.database,runtime.database,'Existing ordinary sessions must belong to the same isolated database');
assert.equal(frontend.port,5192); assert.equal(frontend.backendPort,8082);
const out=path.resolve('.local/product-release-20261011','growth-ui-'+Date.now()); fs.mkdirSync(out,{recursive:true});
const checks=[],failures=[],errors=[],writes=[];
const proofOnly=process.argv.includes('--proof-only');
const base='http://127.0.0.1:5192';
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
let current;
function check(name,condition=true){assert.ok(condition,name);checks.push(name);console.log('PASS '+name);}
async function open(actor,mobile=false){
  const context=await browser.newContext({viewport:mobile?{width:390,height:844}:{width:1440,height:1000},reducedMotion:'reduce'});
  if(actor)await context.addInitScript(token=>localStorage.setItem('Admin-Token',token),actor.token);
  const page=await context.newPage();page.on('pageerror',()=>errors.push('Page script error'));
  page.on('request',request=>{if(!['GET','HEAD'].includes(request.method()))writes.push(new URL(request.url()).pathname);});
  return current={context,page,actor};
}
async function read(endpoint,actor=current.actor){
  const result=await current.page.request.get(base+'/dev-api'+endpoint,{headers:{Authorization:'Bearer '+actor.token,clientid:'e5cd7e4891bf95d1d19206ce24a7b32e'}});
  const body=await result.json();assert.equal(body.code,200,'Actual authorized read: '+endpoint);return body.data;
}
async function navigate(route,heading){await current.page.goto(base+route,{waitUntil:'domcontentloaded'});if(heading)await current.page.getByRole('heading',{name:heading,exact:true}).waitFor({timeout:20000});assert.equal(await current.page.locator('vite-error-overlay').count(),0);}
async function shot(name,viewport=false){await current.page.evaluate(()=>window.scrollTo(0,0));await current.page.screenshot({path:path.join(out,name+'.png'),fullPage:!viewport});}
async function scenario(name,run){if(proofOnly&&name!=='ordinary-private-proof')return;try{await run();}catch(error){failures.push({name,reason:String(error.message).replace(/(token|Authorization|password)=[^&\s]+/gi,'credential=[REDACTED]').slice(0,700)});console.error('FAIL '+name+': '+failures.at(-1).reason.slice(0,180));await shot(name+'-failed').catch(()=>{});}finally{await current?.context.close();current=undefined;}}
const names=['新星','青铜','白银','黄金','铂金','钻石','星耀','王者','传奇'];
const keys=['bronze','silver','gold','platinum','diamond','stellar','king','legend'];
const thresholds=[0,40,120,400,1000,2400,4800,9600,19200];
function titleGoalsAreActual(card,ownerType){
  const codes=ownerType==='team'?['team_first','team_partners','team_veterans']:['first_checkin','first_finish','regular'];
  const verified=new Set(card.titles.map(title=>title.title_code));
  return card.titleGoals?.length===3&&card.titleGoals.every((goal,index)=>
    goal.code===codes[index]&&Number(goal.required)>0&&Number(goal.current)>=0&&
    Number(goal.remaining)===Math.max(0,Number(goal.required)-Number(goal.current))&&
    goal.eligible===(Number(goal.current)>=Number(goal.required))&&
    goal.awarded===verified.has(goal.code)&&
    (ownerType!=='team'||goal.milestone==='team_finish'));
}
try{
  for(const mobile of [false,true])await scenario((mobile?'mobile':'desktop')+'-rank-directory',async()=>{
    await open(state.people[0],mobile);const growth=await read('/sports/growth/card?sportId='+state.sportId);const approved=await read('/sports/honors/certifications/approved?sportId='+state.sportId);
    check('当前真实规则保留原门槛、王者9600分并追加传奇19200分',growth.ranks?.length===9&&growth.ranks.every((rank,index)=>rank.name===names[index]&&Number(rank.threshold)===thresholds[index]));
    const rankIndex=thresholds.filter(threshold=>Number(growth.points)>=threshold).length-1;
    check('本人当前段位按真实分值计算，未假增积分',growth.rank===names[rankIndex]&&Number(growth.rankIndex)===rankIndex);
    check('本人三种称号条件和差距来自实际记录，条件达到不冒充授予',titleGoalsAreActual(growth,'person'));
    await navigate('/portal/growth','成长与荣誉');
    await current.page.locator('.rank-catalog>button').last().waitFor();
    await current.page.waitForFunction(()=>[...document.querySelectorAll('.rank-catalog img')].length===8&&[...document.querySelectorAll('.rank-catalog img')].every(image=>image.complete&&image.naturalWidth>0));
    check((mobile?'手机':'桌面')+'八级徽章全部真实加载',await current.page.locator('.rank-catalog [data-rank]').count()===8);
    check('个人称号条件表完整显示三个实际里程碑',await current.page.locator('.growth-title-goals .goal-list>article').count()===3&&JSON.stringify(await current.page.locator('.growth-title-goals [role="progressbar"]').evaluateAll(nodes=>nodes.map(node=>Number(node.getAttribute('aria-valuenow')))))===JSON.stringify(growth.titleGoals.map(goal=>Math.min(Number(goal.current),Number(goal.required)))));
    check('运动名片认证荣誉独立于成长称号，空认证列表不赠奖牌',JSON.stringify(await current.page.locator('.growth-passport .certified-honor-badge').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('data-honor-id'))))===JSON.stringify(approved.filter(honor=>honor.worn&&honor.sportId===state.sportId).map(honor=>honor.honorId)));
    check('未达到的等级在目录锁定，头像只佩戴本人当前段位',await current.page.locator('.growth-passport .sports-rank-badge').getAttribute('aria-label')==='成长段位：'+growth.rank&&await current.page.locator('.rank-catalog>button.locked').count()===thresholds.slice(1).filter(threshold=>threshold>Number(growth.points)).length);
    check('进度说明不受旧条形背景污染',await current.page.locator('.passport-progress .progress-next').evaluate(node=>[node,...node.querySelectorAll('span')].every(part=>getComputedStyle(part).backgroundColor==='rgba(0, 0, 0, 0)')));
    for(let index=0;index<keys.length;index++){
      await current.page.locator('.rank-catalog>button').nth(index).click();
      const dialog=current.page.getByRole('dialog',{name:names[index+1]+'段位',exact:true});await dialog.waitFor();
      await dialog.locator('.avatar-frame-art').waitFor();
      await current.page.waitForFunction(()=>{const frame=document.querySelector('.rank-preview .avatar-frame-art');return frame?.complete&&frame.naturalWidth>0;});
      check((mobile?'手机':'桌面')+' '+names[index+1]+'独立资源与头像框加载',await dialog.locator('.sports-rank-badge img').getAttribute('src')==='/images/sports/ranks/'+keys[index]+'.webp'&&await dialog.locator('.avatar-frame-art').getAttribute('src')==='/images/sports/frames-v2/'+keys[index]+'.webp');
      check('段位预览图片不可拖拽且不撑破弹窗 '+keys[index],await dialog.locator('img').evaluateAll(images=>images.every(image=>image.draggable===false&&image.getBoundingClientRect().width<=180)));
      await shot((mobile?'mobile':'desktop')+'-tier-'+keys[index],true);
      await dialog.getByRole('button',{name:'关闭',exact:true}).click();await dialog.waitFor({state:'hidden'});
    }
    check('鼠标关闭预览后不误聚焦跳过导航链接',!await current.page.locator('.consumer-skip').evaluate(node=>node.matches(':focus-visible')));
    await shot((mobile?'mobile':'desktop')+'-growth');
    check('成长页无横向溢出 '+(mobile?'mobile':'desktop'),!await current.page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+2));
    const currentTitle=growth.titles.find(title=>title.title_code===growth.equipment?.title_code);
    const title=current.page.locator('.growth-passport .avatar-title');
    if(currentTitle){check('已佩戴称号位于头像上方且来自真实荣誉',await title.innerText()===currentTitle.title&&await current.page.locator('.growth-passport .sports-avatar').evaluate(node=>node.querySelector('.avatar-title').getBoundingClientRect().bottom<=node.querySelector('.avatar-frame').getBoundingClientRect().top));await current.page.waitForFunction(()=>[...document.querySelectorAll('.title-wall img')].every(image=>image.complete&&image.naturalWidth>0));}
    else check('未获得或未佩戴称号时不赠送展示称号',await title.innerText()==='未佩戴称号');
    await navigate('/portal/profile','我的');await current.page.waitForFunction(()=>document.querySelector('.profile-person .sports-rank-badge'));
    check('个人资料保留新版兼容地址，头像上传集中在完善资料',new URL(current.page.url()).pathname==='/portal/profile'&&await current.page.locator('.profile-avatar-field .sports-avatar-editor').count()===1&&await current.page.locator('.profile-menu .sports-avatar-editor').count()===0);
    check('个人中心使用相同真实运动段位',await current.page.locator('.profile-person .sports-rank-badge').getAttribute('aria-label')==='成长段位：'+growth.rank);
    if(mobile)check('手机资料头像编辑说明完整，消息文字保留正常横排',await current.page.locator('.profile-avatar-field').evaluate(node=>{const editor=node.querySelector('.sports-avatar-editor');return editor.getBoundingClientRect().width>=node.getBoundingClientRect().width-60;})&&await current.page.locator('.profile-menu a[href="/portal/notices"] .shortcut-label').evaluate(label=>getComputedStyle(label).whiteSpace==='nowrap'&&label.scrollWidth<=label.clientWidth+2));
    await shot((mobile?'mobile':'desktop')+'-identity');
    const after=await read('/sports/growth/card?sportId='+state.sportId);
    check('浏览徽章和头像框不修改积分、荣誉或佩戴',after.points===growth.points&&JSON.stringify(after.facts)===JSON.stringify(growth.facts)&&JSON.stringify(after.titles)===JSON.stringify(growth.titles)&&JSON.stringify(after.equipment)===JSON.stringify(growth.equipment));
  });
  await scenario('ordinary-private-proof',async()=>{
    await open(state.people[0],true);const proofs=await read('/sports/c/proofs');
    check('本人获奖证明来自实际受控接口',proofs.length>0);
    await navigate('/portal/proofs','成绩证明');
    await current.page.locator('.proof-card').first().waitFor();
    const placements=new Set(['冠军','第一名','第1名','金牌','亚军','第二名','第2名','银牌','季军','第三名','第3名','铜牌']);
    check('无明确名次的正式奖项使用中性符号，不按成长或胜负赠奖牌',await current.page.locator('.proof-card').evaluateAll((nodes,known)=>nodes.every(node=>known.includes(node.querySelector('h3').textContent.trim())||node.querySelector('.official-award-medal.neutral')&&!node.querySelector('.official-award-medal img')),[...placements]));
    check('证明没有成长段位徽章冒充赛果奖项',await current.page.locator('.proof-card img[src*="/ranks/"]').count()===0);
    const staticMedals=await current.page.evaluate(async()=>Promise.all(['gold','silver','bronze'].map(async key=>{const image=new Image();image.src='/images/sports/medals/'+key+'.webp';image.draggable=false;await image.decode();return {key,width:image.naturalWidth,height:image.naturalHeight};})));
    check('金银铜三种奖牌静态资源真实存在',staticMedals.every(item=>item.width===512&&item.height===512));
    const downloading=current.page.waitForEvent('download');await current.page.getByRole('button',{name:'保存证明图片',exact:true}).first().click();
    const download=await downloading;const file=path.join(out,'ordinary-private-proof.png');await download.saveAs(file);
    const png=fs.readFileSync(file);check('私有证明图片下载保留原记录，PNG尺寸完整',png.subarray(1,4).toString()==='PNG'&&png.readUInt32BE(16)===1120&&png.readUInt32BE(20)===790);
    await shot('mobile-private-proofs');
    const after=await read('/sports/c/proofs');check('查看和保存不改变获奖记录',JSON.stringify(after)===JSON.stringify(proofs));
  });
  await scenario('ordinary-room-team',async()=>{
    await open(state.people[2],true);
    const progress=JSON.parse(fs.readFileSync('.local/product-release-20261011/room-ui-progress.json','utf8'));
    const detail=await read('/sports/rooms/'+progress.roomId);
    await navigate('/portal/rooms/'+progress.roomId,'参赛房间');await current.page.locator('.room-stage .sports-avatar').first().waitFor();
    const badgeIds=(await Promise.all(detail.members.map(async member=>(await read(member.account_id===detail.accountId?'/sports/honors/certifications/approved?sportId='+detail.room.sport_id:'/sports/honors/certifications/public/'+member.account_id+'?sportId='+detail.room.sport_id)).filter(honor=>honor.worn&&honor.sportId===detail.room.sport_id).map(honor=>honor.honorId)))).flat();
    check('房间认证只来自本人或双公开队友事实，空数据没有假认证徽章',JSON.stringify(await current.page.locator('.room-stage .certified-honor-badge').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('data-honor-id'))))===JSON.stringify(badgeIds));
    check('真实双打名单房主计1，静态框不改变成员及准备',detail.members.length===2&&await current.page.locator('.room-stage .sports-avatar').count()===2&&detail.room.registration_id===null);
    check('房间各成员使用其运动真实段位',JSON.stringify(await current.page.locator('.room-stage .sports-rank-badge').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('aria-label'))))===JSON.stringify(detail.members.map(member=>'成长段位：'+member.rank_name)));
    check('头像称号在上方，用户图片不可拖拽',await current.page.locator('.room-stage .sports-avatar').evaluateAll(nodes=>nodes.every(node=>node.querySelector('.avatar-title').getBoundingClientRect().bottom<=node.querySelector('.avatar-frame').getBoundingClientRect().top&&[...node.querySelectorAll('img')].every(image=>image.draggable===false))));
    await shot('mobile-room');
    const teams=await read('/sports/c/teams');const member=teams.memberships?.find(row=>row.membershipStatus==='active'&&row.teamStatus==='active');
    if(member){await navigate('/portal/teams/'+member.teamId);await current.page.locator('.team-growth .team-rank').waitFor();const board=await read('/sports/growth/teams/'+member.teamId+'/board');const teamCard=await read('/sports/growth/card?sportId='+board[0].sport_id+'&teamId='+member.teamId);check('队伍按自身sport_id读取成长及各成员段位',await current.page.locator('.team-rank .sports-rank-badge').getAttribute('aria-label')==='成长段位：'+teamCard.rank);check('小队三种称号条件只按真实小队完赛记录计算',titleGoalsAreActual(teamCard,'team')&&await current.page.locator('.team-growth .growth-title-goals .goal-list>article').count()===3);await shot('mobile-team');}
    else {await navigate('/portal/teams','我的小队');await current.page.getByText('暂无队伍',{exact:true}).waitFor();check('普通C没有有效长期队时展示本人空状态',await current.page.locator('.team-growth').count()===0);}
  });
  await scenario('team-read-boundary',async()=>{
    await open(state.people[0]);const ownTeams=await read('/sports/c/teams');const dTeams=await read('/sports/c/teams',state.people[3]);
    const own=ownTeams.memberships?.find(row=>row.membershipStatus==='active'&&row.teamStatus==='active');
    if(own){await navigate('/portal/teams/'+own.teamId);await current.page.locator('.team-growth .team-rank').waitFor();const board=await read('/sports/growth/teams/'+own.teamId+'/board');const team=await read('/sports/growth/card?sportId='+board[0].sport_id+'&teamId='+own.teamId);check('真实普通队员进入长期队，按队伍运动显示成长',await current.page.locator('.team-rank .sports-rank-badge').getAttribute('aria-label')==='成长段位：'+team.rank&&await current.page.locator('.team-athletes .sports-avatar').count()===board.length);check('长期队称号条件与真实授予状态一致',titleGoalsAreActual(team,'team')&&await current.page.locator('.team-growth .growth-title-goals .goal-list>article').count()===3);await shot('desktop-team');}
    const foreign=ownTeams.memberships?.find(row=>row.membershipStatus==='active'&&!dTeams.memberships?.some(other=>other.teamId===row.teamId&&other.membershipStatus==='active'));
    if(foreign){const result=await current.page.request.get(base+'/dev-api/sports/growth/teams/'+foreign.teamId+'/board',{headers:{Authorization:'Bearer '+state.people[3].token,clientid:'e5cd7e4891bf95d1d19206ce24a7b32e'}});const body=await result.json();check('非队员普通账号无法读取其他队伍成长',body.code===403);}
    else failures.push({name:'team-read-boundary',reason:'No existing unrelated active team available; this boundary was not tested.'});
  });
  await scenario('public-honor-projection',async()=>{
    await open(state.people[0],true);const own=await read('/sports/display');await current.context.close();await open(undefined,true);
    const headers={clientid:'e5cd7e4891bf95d1d19206ce24a7b32e'};
    const response=await current.page.request.get(base+'/dev-api/sports/display/public/'+own.accountId,{headers});const publicCard=await response.json();
    const honorsResponse=await current.page.request.get(base+'/dev-api/sports/honors/certifications/public/'+own.accountId,{headers});const honors=await honorsResponse.json();assert.equal(honors.code,200);
    check('匿名认证投影不包含申请材料、审核说明或本人身份资料',honors.data.every(honor=>Object.keys(honor).every(key=>['honorId','title','eventYear','eventName','sportId','sportName','place','worn','publicVisible'].includes(key))&&honor.publicVisible));
    if(publicCard.code===200){
      const completed=current.page.waitForResponse(response=>new URL(response.url()).pathname==='/dev-api/sports/honors/certifications/public/'+own.accountId);
      await navigate('/public/athletes/'+own.accountId);await current.page.locator('.athlete-card').waitFor();const actual=await(await completed).json();assert.equal(actual.code,200);
      const sport=publicCard.data.sports[0]?.sport_id||honors.data.find(honor=>honor.worn)?.sportId;
      check('公开名片认证徽章按真实运动及双公开事实显示，没有空列表假获奖',JSON.stringify(await current.page.locator('.athlete-card .certified-honor-badge').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('data-honor-id'))))===JSON.stringify(honors.data.filter(honor=>honor.worn&&honor.sportId===sport).map(honor=>honor.honorId)));
      check('公开名片在手机无横向溢出',!await current.page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+2));
      await shot('mobile-public-athlete');
    }else{
      check('本人未公开名片时匿名名片仍被拒绝，认证不绕过公开开关',publicCard.code===404&&honors.data.length===0);
      await navigate('/public/athletes/'+own.accountId);await current.page.getByText('这张运动名片暂未公开',{exact:true}).waitFor();check('未公开名片页面不绘制认证徽章',await current.page.locator('.certified-honor-badge').count()===0);await shot('mobile-private-athlete-rejected');
    }
  });
  assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);
}finally{
  await current?.context.close();await browser.close();
  fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify({timestamp:new Date().toISOString(),scope:proofOnly?'Actual ordinary private proof read/download and three static medals only. Growth, room and team scenarios not executed.':'Actual isolated ordinary participant reads and static resource previews. No response interception, grade/award writes, registration, funds or match facts.',checks,failures,pageErrors:errors,writes},null,2),{flag:'wx'});
  console.log('Evidence: '+path.relative(process.cwd(),out));if(failures.length||errors.length||writes.length)process.exitCode=1;
}
