"""Copy inspected generated frames without changing any prior frozen artwork."""
import hashlib,json,pathlib,shutil,sys
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[1]
rows=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
art=root/'docs/05-ui/assets-20261011-v3'
(art/'originals').mkdir(parents=True,exist_ok=True)
manifest=[]
for row in rows:
    source=pathlib.Path(row['source']);name=row['name']
    kind=row.get('kind','frame')
    original=art/'originals'/(kind+'-'+name+'.png')
    target=root/'plus-ui/public/images/sports'/('ranks' if kind=='badge' else 'frames-v2')/(name+'.webp')
    target.parent.mkdir(parents=True,exist_ok=True)
    if not original.exists(): shutil.copyfile(source,original)
    if hashlib.sha256(original.read_bytes()).digest()!=hashlib.sha256(source.read_bytes()).digest(): raise ValueError('Existing artwork source changed')
    if not target.exists():
        with Image.open(source) as im:
            im=im.convert('RGBA');im.thumbnail((512,512),Image.Resampling.LANCZOS);im.save(target,'WEBP',quality=90,method=6)
    with Image.open(target) as im:
        assert im.getchannel('A').getextrema()==(0,255)
        if kind=='frame': assert im.getpixel((im.width//2,im.height//2))[3]==0,'Frame center must remain transparent'
        center_alpha=im.getpixel((im.width//2,im.height//2))[3]
        manifest.append({'key':name,'file':target.relative_to(root).as_posix(),'width':im.width,'height':im.height,'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'original':original.relative_to(root).as_posix(),'originalSha256':hashlib.sha256(original.read_bytes()).hexdigest(),'prompt':row['prompt'],'centerAlpha':center_alpha})
target=art/(sys.argv[2] if len(sys.argv)>2 else 'frames.json')
content=json.dumps({'generation':'built-in image_gen; model identifier unavailable','assets':manifest},ensure_ascii=False,indent=2)+'\n'
if target.exists(): assert target.read_text(encoding='utf-8')==content,'Do not overwrite a different manifest'
else: target.write_text(content,encoding='utf-8')
print(json.dumps({'assets':len(manifest),'bytes':sum(r['bytes'] for r in manifest),'transparentCenters':sum(r['centerAlpha']==0 for r in manifest)}))
