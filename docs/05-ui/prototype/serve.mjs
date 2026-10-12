import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.dirname(fileURLToPath(import.meta.url));
const aiRoot=path.resolve(root,'../ai-native/prototype');
const port=Number(process.argv[2]||5188);
const allowed=new Set(['index.html','business.html','organizer.html','organization.js','b-shell.js','styles.css','common.js','platform.js','auth.js','consumer.js','business.js','brand.svg','ai-workbench.html','ai-workbench.css','ai-workbench.js']);
const mime={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.svg':'image/svg+xml'};
http.createServer(async(req,res)=>{
  const name=new URL(req.url,'http://localhost').pathname.replace(/^\//,'')||'index.html';
  if(!allowed.has(name)||!['GET','HEAD'].includes(req.method)){res.writeHead(404);res.end('Not found');return}
  // 旧书签兼容：AI 原型源已移至独立目录，历史原型文件不混入新设计。
  try{const data=await readFile(path.join(name.startsWith('ai-workbench.')?aiRoot:root,name));res.writeHead(200,{'Content-Type':mime[path.extname(name)],'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(req.method==='HEAD'?undefined:data)}catch{res.writeHead(404);res.end('Not found')}
}).listen(port,'127.0.0.1',()=>console.log(`UI prototype: http://127.0.0.1:${port}/ (local only)`));

