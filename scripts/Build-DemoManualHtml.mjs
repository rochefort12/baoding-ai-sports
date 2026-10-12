import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {createRequire} from 'node:module';import {pathToFileURL} from 'node:url';
// The browser and its Markdown download share this sanitized content. Never copy
// the local source Markdown first: it contains links intended only for local files.
function redactPrivateFileLinks(markdown) {
  return markdown.replace(/\[([^\]\r\n]+)\]\(([^)\r\n]+)\)/g, (link, label, target) => {
    let destination=target.trim().replace(/^<|>$/g,'');
    try { destination=decodeURIComponent(destination); } catch { /* Inspect the original path if malformed. */ }
    return /(?:^|[\\/])\.local(?:[\\/]|$)/i.test(destination)
      ? `${label}（本机受保护文件，账号不经网页提供）` : link;
  });
}
// Public handbook derivatives use a fixed list of safe aliases. The gallery
// service accepts these exact names; arbitrary repository paths stay private.
const publicReports=[
  ['羽毛球一期闭环本机验证-20261010.md','evidence-phase1.md'],
  ['产品组件与视觉验证-20261010.md','evidence-ui.md'],
  ['正式产品界面与创作功能验证-20261011.md','evidence-product.md'],
  ['全局视觉与办理智能体验证-20261011.md','evidence-global.md'],
  ['浮泡交互与传奇荣誉认证验证-20261011.md','evidence-bubble-honor.md']
];
const publicAlias=new Map([
  ...publicReports,
  ['浮泡交互与传奇荣誉认证验证-20261011.json','evidence-bubble-honor.json'],
  ['演示账号与测试流程手册-20261011.md','manual.md']
]);
function publicMarkdown(markdown) {
  return redactPrivateFileLinks(markdown).replace(/\[([^\]\r\n]+)\]\(([^)\r\n]+)\)/g,(link,label,target)=>{
    let destination=target.trim().replace(/^<|>$/g,'');
    try { destination=decodeURIComponent(destination); } catch { /* Preserve malformed public links. */ }
    if(/^[a-z][a-z\d+.-]*:/i.test(destination))return link;
    const [pathname,fragment]=destination.split('#');
    const basename=path.posix.basename(pathname.replaceAll('\\','/'));
    let mapped=publicAlias.get(basename);
    if(/(?:^|\/)demo-20261011\/access\.json$/.test(pathname))mapped='demo-access.json';
    for(const directory of ['global-product-20261011-v3','world-honor-display-20261011']) {
      if(pathname.endsWith('/'+directory+'/README.md'))mapped='../'+directory+'/README.md';
    }
    return mapped?`[${label}](${mapped}${fragment?'#'+fragment:''})`:link;
  });
}
const original=fs.readFileSync('docs/01-development/演示账号与测试流程手册-20261011.md','utf8');
const privateSafe=publicMarkdown(original);
if(process.argv.includes('--check-private-links')) {
  const samples=[
    '[演示账号文件](../../.local/demo-20261011/演示账号.txt)',
    '[主站管理员文件](../../.local/main-access/主站管理员.txt)',
    '[保护文件](C:/project/%2Elocal/main-access/account.txt)'
  ];
  for(const sample of samples) assert.ok(!redactPrivateFileLinks(sample).includes(']('),'Private credential file links must not survive');
  const publicLink='[报告](../04-verification/report.md)';assert.equal(redactPrivateFileLinks(publicLink),publicLink);
  assert.ok(!/\[[^\]]+\]\([^)]*(?:\.local|%2elocal)[^)]*\)/i.test(privateSafe));
  assert.equal(publicMarkdown('[补验](../04-verification/浮泡交互与传奇荣誉认证验证-20261011.md)'),'[补验](evidence-bubble-honor.md)');
  assert.equal(publicMarkdown('[清单](浮泡交互与传奇荣誉认证验证-20261011.json)'),'[清单](evidence-bubble-honor.json)');
  assert.equal(publicMarkdown('[截图](../05-ui/global-product-20261011-v3/README.md)'),'[截图](../global-product-20261011-v3/README.md)');
  console.log('Private link and public alias checks passed; no browser files were generated.');process.exit(0);
}
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');const {marked}=await import(pathToFileURL(require.resolve('marked')).href);const root=path.resolve('docs/05-ui/style-selection-20261011');
const safe=privateSafe;
fs.writeFileSync(path.join(root,'manual.md'),safe);
let index=0;const toc=[];let html=marked.parse(safe).replace(/<h([1-3])>(.*?)<\/h\1>/g,(_,level,text)=>{const id='section-'+index++;if(level==='2')toc.push({id,text});return `<h${level} id="${id}">${text}</h${level}>`;});html=html.replace(/<table>/g,'<div class="table-scroll" tabindex="0" aria-label="可横向查看的步骤表"><table>').replace(/<\/table>/g,'</table></div>');
const result=`<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>羽毛球一期演示账号与测试流程手册</title><style>*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;font:15px/1.85 system-ui,'Microsoft YaHei',sans-serif;color:#263840;background:#f4f6f7}a{color:#167176}header{background:white;border-bottom:1px solid #dce3e7;padding:16px max(22px,calc((100vw - 1280px)/2));display:flex;gap:24px;align-items:center;flex-wrap:wrap;font-size:14px}header b{margin-right:auto}aside{position:fixed;left:max(22px,calc((100vw - 1280px)/2));top:90px;width:200px;font-size:13px}aside a{display:block;padding:6px 0;text-decoration:none;color:#607681}.layout{max-width:1280px;margin:28px auto;padding:0 22px 60px}.paper{margin-left:235px;background:white;border:1px solid #dde6e9;border-radius:12px;padding:40px}h1{font-size:29px;line-height:1.35;letter-spacing:-.03em;margin-top:0}h2{font-size:22px;line-height:1.45;margin:38px 0 16px;scroll-margin-top:20px}h3{font-size:18px;line-height:1.45;margin-top:28px}p{margin:12px 0}strong{font-weight:650}code{font-size:13px;background:#edf3f4;padding:2px 5px;border-radius:3px;overflow-wrap:anywhere}.table-scroll{overflow:auto;margin:20px 0;border:1px solid #dce5e8;border-radius:8px}table{border-collapse:collapse;width:100%;min-width:600px;font-size:13px;line-height:1.7}th,td{padding:12px 13px;border-bottom:1px solid #e5ebed;vertical-align:top;text-align:left}th{color:#436571;background:#f0f5f6}td:first-child{font-weight:550}th:first-child{min-width:75px}li{margin:9px 0}a:focus-visible,.table-scroll:focus-visible{outline:3px solid #24858b;outline-offset:3px}@media(max-width:900px){aside{position:static;width:auto;padding:22px;display:flex;gap:12px;flex-wrap:wrap;max-width:1280px;margin:auto}aside a{padding:3px 8px;background:#e9eff1;border-radius:4px}.layout{margin:0 auto}.paper{margin-left:0;padding:22px}h1{font-size:24px}h2{font-size:20px}}@media print{header,aside{display:none}.layout{margin:0;padding:0}.paper{margin:0;border:0;padding:0}.table-scroll{overflow:visible}table{min-width:0;font-size:10px}h2{break-after:avoid}tr{break-inside:avoid}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}</style></head><body><header><b>体育平台 · 本机试用手册</b><a href="/">返回风格选型册</a><a href="http://127.0.0.1:5192/portal/home" target="_blank" rel="noopener">进入独立演示站 ↗</a><a href="manual.md" download>保存手册</a></header><aside aria-label="手册目录">${toc.map(t=>`<a href="#${t.id}">${t.text}</a>`).join('')}</aside><main class="layout"><article class="paper">${html}</article></main></body></html>`;fs.writeFileSync(path.join(root,'manual.html'),result);
fs.copyFileSync('docs/04-verification/demo-20261011/access.json',path.join(root,'demo-access.json'));
for(const [source,alias] of publicReports) {
  const report=path.join('docs/04-verification',source);
  if(fs.existsSync(report))fs.writeFileSync(path.join(root,alias),publicMarkdown(fs.readFileSync(report,'utf8')));
}
// The evidence JSON is copied byte-for-byte, preserving the parent's freeze.
fs.copyFileSync('docs/04-verification/浮泡交互与传奇荣誉认证验证-20261011.json',path.join(root,'evidence-bubble-honor.json'));
console.log('Built browser manual and Markdown download with protected-file links removed.');
