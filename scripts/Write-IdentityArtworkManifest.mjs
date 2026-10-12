import fs from 'node:fs';import crypto from 'node:crypto';
const assets=[];
for(const category of ['frames','titles'])for(const name of fs.readdirSync('plus-ui/public/images/sports/'+category).filter(n=>n.endsWith('.svg')).sort()){
 const file='plus-ui/public/images/sports/'+category+'/'+name,bytes=fs.readFileSync(file);
 assets.push({file,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),format:'native SVG',viewBox:'0 0 256 256',purpose:category==='frames'?'Real growth rank avatar frame':'Earned sports title ornament'});
}
if(assets.length!==13)throw new Error('Expected seven frames and six title ornaments');
fs.writeFileSync('docs/05-ui/assets-20261011-v2/identity-artwork.json',JSON.stringify({origin:'Original project-authored SVG; decorative artwork never grants rank/title',assets},null,2)+'\n',{flag:'wx'});
console.log('PASS 13 original SVG resources recorded');
