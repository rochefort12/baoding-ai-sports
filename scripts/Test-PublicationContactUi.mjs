// 真实页面、显式隔离响应；发布写入只保存在内存，不创建实际赛事。
import {createRequire} from 'node:module';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createFixtureAudit} from './lib/UiFixtureAudit.mjs';
import {event,menus} from './critical-ui-fixtures.mjs';
const require=createRequire(path.join(process.argv[2],'_resolve.cjs'));
const {chromium}=require('playwright');
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
const ctx=await browser.newContext({viewport:{width:1440,height:900}});
const audit=createFixtureAudit(),writes=[],errors=[],checks=[];
let fail=true, published=false;
const check=(ok,label)=>{assert.ok(ok,label);checks.push(label);console.log('PASS '+label)};
await ctx.addInitScript(()=>{localStorage.setItem('Admin-Token','isolated-publication');localStorage.setItem('Platform-Token','isolated-publication')});
await ctx.route('**/*',async route=>{
 const req=route.request();if(!['xhr','fetch'].includes(req.resourceType()))return route.continue();
 const u=new URL(req.url()).pathname;let data,code=200,msg='isolated';
 if(req.method()==='POST' && u.endsWith('/sports/b/events/901/publish')){
  writes.push(req.postDataJSON());if(fail){code=500;msg='隔离模拟：发布暂时失败'}else{published=true;data={...event,publicationStatus:'published'}}
 }else if(req.method()!=='GET')return audit.reject(route);
 else if(u.endsWith('/system/user/getInfo'))data={user:{userId:'201',tenantId:'fixture-tenant',userName:'fixture',nickName:'虚构办赛者',avatar:''},roles:['organizer'],permissions:[]};
 else if(u.endsWith('/system/menu/getRouters'))data=menus;
 else if(u.endsWith('/auth/tenant/list'))data={tenantEnabled:false,voList:[]};
 else if(u.endsWith('/sports/b/desk/context'))data={organizationId:'601',organizationName:'虚构组织',organize:true,payment:true};
 else if(u.endsWith('/sports/b/ai/assistant/sessions'))data=[];
 else if(u.endsWith('/sports/b/registrations/units'))data=[];
 else if(u.endsWith('/sports/b/events/901'))data={...event,publicationStatus:published?'published':'draft',editable:!published};
 else if(u.endsWith('/sports/b/events/901/preview-fees'))data={eventId:'901',organizationName:'虚构组织',contactName:'公开联系人',contactMethod:'公开服务渠道',contactFrozen:false,units:[]};
 else if(u.endsWith('/sports/b/events'))data=[{...event,publicationStatus:published?'published':'draft',editable:!published}];
 else return audit.reject(route);
 return route.fulfill({json:{code,msg,data}});
});
const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));page.setDefaultTimeout(12000);
try{
 await page.goto((process.argv[3]||'http://127.0.0.1:5173')+'/org-desk/workspace/901?task=publication');
 await page.getByRole('button',{name:'首次发布',exact:true}).click();
 const dialog=page.getByRole('dialog',{name:'确认公开赛事'});
 await dialog.waitFor();const send=dialog.getByRole('button',{name:'确认发布',exact:true});
 check(await send.isDisabled(),'未确认公开联系信息时不能发布');
 check(await dialog.locator('.el-form-item').filter({hasText:'公开联系人'}).locator('input').inputValue()==='公开联系人','读取真实预览接口结构并回填组织默认联系人');
 await dialog.locator('.el-checkbox').click();
 const contact=dialog.locator('.el-form-item').filter({hasText:'公开联系方式'}).locator('input');
 await contact.fill('');check(await send.isDisabled(),'空公开联系方式不能发布');await contact.fill('公开服务渠道');
 await send.click();await page.getByText('隔离模拟：发布暂时失败',{exact:true}).waitFor();
 check(await dialog.isVisible(),'发布失败保留核对窗口');check(writes.length===1 && writes[0].contactConfirmed===true,'只在明确同意后发送发布请求');
 fail=false;await send.click();await dialog.waitFor({state:'hidden'});
 check(writes.length===2 && writes[0].requestKey===writes[1].requestKey,'失败重试沿用请求键避免重复发布');
 check(writes[1].contactName==='公开联系人' && writes[1].contactMethod==='公开服务渠道','发布请求包含核对后的联系信息');
 audit.assertClean();check(errors.length===0,'发布页面无脚本异常且所有接口有显式夹具');
 await fs.mkdir('.local/publication-contact-ui',{recursive:true});
 await fs.writeFile('.local/publication-contact-ui/results.json',JSON.stringify({scope:'isolated UI fixtures',checks,completed:true},null,2));
 console.log('PUBLICATION CONTACT UI PASS '+checks.length);
}finally{await browser.close()}
