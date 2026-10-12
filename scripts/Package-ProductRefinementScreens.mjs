// Preserve a small, inspected screenshot set. Product previews are never award facts.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const out='docs/05-ui/global-product-20261011-v3';assert.ok(!fs.existsSync(path.join(out,'screenshots.json')),'The screenshot manifest is immutable.');fs.mkdirSync(out,{recursive:true});
const args=process.argv.slice(2),base='.local/product-release-20261011/';
const chatDir=args.includes('--chat-dir')?args[args.indexOf('--chat-dir')+1]:base+'floating-assistant-1791692490480';assert.ok(chatDir.startsWith('.local/'));
const sources=[
 ['home-desktop.png',base+'entry-ui-1791691539827/5192-1440-home.png','首页，隔离演练数据'],
 ['events-mobile.png',base+'entry-ui-1791691539827/5192-390-catalog.png','紧凑赛事筛选与手机赛事卡'],
 ['events-desktop.png',base+'entry-ui-1791691539827/5192-1440-catalog.png','桌面赛事列表'],
 ['chat-public-mobile.png',chatDir+'/5192-390-chat.png','公开助手静态功能入口和本人草稿'],
 ['chat-public-desktop.png',chatDir+'/5190-1440-chat.png','主站聊天主题可取消，输入不预填指令'],
 ['chat-task-mobile.png',chatDir+'/participant-390-saved.png','已保存实际只读任务'],
 ['chat-task-desktop.png',chatDir+'/participant-1440-saved.png','桌面办理进度与真实任务记录'],
 ['chat-resized.png',base+'assistant-modal-1791690845953/desktop-pointer-resized.png','实际拖动调整聊天窗口尺寸'],
 ['chat-modal-restored.png',base+'assistant-modal-1791690845953/mobile-chat-restored.png','业务弹窗关闭后恢复聊天草稿'],
 ['profile-mobile.png',base+'profile-entry-1791690674314/mobile-profile.png','资料页头像与认证入口'],
 ['profile-crop-mobile.png',base+'profile-entry-1791690674314/mobile-profile-crop.png','真实本地裁剪预览；未上传未保存'],
 ['main-management.png','.local/main-access/post-release-018d0896-936d-4426-a391-c9ba8ddbefb7/main-platform-verified.png','真实主站管理员登录，认证六人工入口已开放']
];
for(const name of ['desktop-synthetic-podium-appearance.png','mobile-synthetic-podium-appearance.png'])sources.push(['world-'+name,'docs/05-ui/world-honor-display-20261011/'+name,'三项世界徽章与头像框的合成外观检验；未授予实际荣誉']);
if(args.includes('--review-dir')){const directory=args[args.indexOf('--review-dir')+1];assert.ok(directory.startsWith('.local/'));for(const name of fs.readdirSync(directory).filter(n=>n.endsWith('.png')))sources.push(['review-'+name,path.join(directory,name).replaceAll('\\','/'),'真实合成认证历史界面，已撤销，无实际世界荣誉效力']);}
for(const [flag,prefix,caption] of [['--motion-dir','motion','当前成长及聊天实际交互；段位预览不授予奖励'],['--focus-dir','focus','工作账号与表单实际单边框焦点检验']])if(args.includes(flag)){const directory=args[args.indexOf(flag)+1];assert.ok(directory.startsWith('.local/'));for(const name of fs.readdirSync(directory).filter(n=>n.endsWith('.png')))sources.push([prefix+'-'+name,path.join(directory,name).replaceAll('\\','/'),caption]);}
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const manifest=sources.map(([name,source,caption])=>{assert.ok(fs.existsSync(source),source);const target=path.join(out,name);assert.ok(!fs.existsSync(target));fs.copyFileSync(source,target);assert.equal(hash(target),hash(source));return {file:name,source,caption,bytes:fs.statSync(target).size,sha256:hash(target)};});
fs.writeFileSync(path.join(out,'screenshots.json'),JSON.stringify({at:new Date().toISOString(),scope:'Actual rendered UI; isolated people/events and honor evidence are synthetic. Rank previews do not issue awards.',images:manifest},null,2)+'\n',{flag:'wx'});
const markdown='# 浮泡交互、段位资源与荣誉认证截图\n\n当前实际界面见 5190 / 5192。本页包括合成赛事和核验记录，不能用于证明真实获奖。段位图为目录预览；高段位没有通过改积分或伪造奖项授予。每张截图的来源及 SHA256 见 [清单](screenshots.json)。\n\n'+manifest.map(i=>'## '+i.caption+'\n\n!['+i.caption+']('+i.file+')\n').join('\n');
fs.writeFileSync(path.join(out,'README.md'),markdown,{flag:'wx'});console.log(JSON.stringify({passed:true,directory:out,images:manifest.length,bytes:manifest.reduce((n,i)=>n+i.bytes,0),manifestSha256:hash(path.join(out,'screenshots.json'))}));
