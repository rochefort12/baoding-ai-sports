import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

// 独立 AI 设计原型，仅提供明确列出的本地静态文件，不代理业务接口。
const root=path.dirname(fileURLToPath(import.meta.url));
const port=Number(process.argv[2]||5192);
const allowed=new Set(['consumer.html','consumer.css','consumer.js','ai-workbench.html','ai-workbench.css','ai-workbench.js','assets/community-sports-hero.png','assets/event-court.svg','assets/event-community.svg']);
const mime={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.svg':'image/svg+xml','.png':'image/png'};
http.createServer(async(req,res)=>{
  let name;
  try{name=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\//,'')||'consumer.html'}catch{res.writeHead(400);res.end();return}
  if(!allowed.has(name)||!['GET','HEAD'].includes(req.method)){res.writeHead(404);res.end('Not found');return}
  try{const data=await readFile(path.join(root,name));res.writeHead(200,{'Content-Type':mime[path.extname(name)],'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(req.method==='HEAD'?undefined:data)}catch{res.writeHead(404);res.end('Not found')}
}).listen(port,'127.0.0.1',()=>console.log(`AI design prototypes: http://127.0.0.1:${port}/consumer.html`));
