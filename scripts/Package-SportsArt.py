"""Package inspected generated artwork, preserving original pixels and alpha."""
import hashlib,json,pathlib,shutil,sys
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[1]
rows=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
art=root/'docs/05-ui/assets-20261011-v2'
(art/'originals').mkdir(parents=True,exist_ok=True)
manifest=[]
for row in rows:
    source=pathlib.Path(row['source'])
    name=row['name']; category={'rank':'ranks','medal':'medals','background':'art','assistant':''}[row['type']]
    target=root/'plus-ui/public/images/sports'/category/(name+'.webp')
    original=art/'originals'/(category+'-'+name+'.png')
    if not original.exists(): shutil.copyfile(source,original)
    elif hashlib.sha256(original.read_bytes()).digest()!=hashlib.sha256(source.read_bytes()).digest(): raise ValueError('Existing original differs')
    target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists():
        with Image.open(source) as image:
            image=image.convert('RGBA' if row['type']!='background' else 'RGB')
            image.thumbnail((256,256) if row['type']=='assistant' else (512,512) if row['type']!='background' else (1536,1024),Image.Resampling.LANCZOS)
            image.save(target,'WEBP',quality=88,method=6)
    with Image.open(target) as image:
        info={'file':str(target.relative_to(root)).replace('\\','/'),'width':image.width,'height':image.height,'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'prompt':row['prompt'],'originalSha256':hashlib.sha256(original.read_bytes()).hexdigest()}
        if 'A' in image.getbands():
            low,high=image.getchannel('A').getextrema()
            if low!=0 or high!=255: raise ValueError('Transparent artwork does not preserve alpha')
            info.update(alphaMin=low,alphaMax=high)
        manifest.append(info)
(art/'assets.json').write_text(json.dumps({'generation':'built-in image_gen','assets':manifest},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'packaged':len(manifest),'bytes':sum(r['bytes'] for r in manifest),'transparent':sum('alphaMin' in r for r in manifest)}))
