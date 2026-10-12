import {createRequire} from 'node:module';
import path from 'node:path';
import fs from 'node:fs/promises';
const require=createRequire(path.join(process.argv[2],'_resolve.cjs'));
const {chromium}=require('playwright');
const root=path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/,'$1'));
const out=path.join(root,'previews','review-'+(process.argv[4]||'before'));await fs.mkdir(out,{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
try{const metrics=[];for(const [name,route,width,height] of [['c-mobile','#home',390,844],['c-desktop','#home',1440,900],['b-laptop','business.html',1280,720],['b-desktop','business.html',1440,900]]){const ctx=await browser.newContext({viewport:{width,height}});const p=await ctx.newPage();await p.goto('http://127.0.0.1:'+(process.argv[3]||5188)+'/'+route);await p.screenshot({path:path.join(out,name+'.png')});metrics.push({name,width,height,boxes:await p.evaluate(()=>{const selectors=['.home-events .event-body h3','.home-events .event-bottom','.todo','.todo [data-action]','.stats','.b-overview-table h3'];return Object.fromEntries(selectors.map(s=>[s,[...document.querySelectorAll(s)].map(el=>{const r=el.getBoundingClientRect();return {text:el.textContent.trim(),y:r.y,bottom:r.bottom}})]))})});await ctx.close()}await fs.writeFile(path.join(out,'metrics.json'),JSON.stringify(metrics,null,2));console.log('Saved 4 '+(process.argv[4]||'before')+' viewport screenshots and metrics.')}finally{await browser.close()}
