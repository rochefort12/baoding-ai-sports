"""Package generated world-honor and assistant art; preserve sources and alpha."""
import hashlib,json,pathlib,shutil,sys
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[1]
rows=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
art=root/'docs/05-ui/assets-20261011-v4'
(art/'originals').mkdir(parents=True,exist_ok=True)
manifest=[]
for row in rows:
    name=row['key'];kind=row['kind'];assert kind in ('badge','frame','assistant')
    assert name.replace('-','').isalnum()
    source=pathlib.Path(row['source']);original=art/'originals'/(name+'.png')
    target=root/'plus-ui/public/images/sports'/('assistant' if kind=='assistant' else 'honors')/(name+'.webp')
    target.parent.mkdir(parents=True,exist_ok=True)
    if not original.exists():shutil.copyfile(source,original)
    assert original.read_bytes()==source.read_bytes()
    if not target.exists():
        with Image.open(source) as im:
            im=im.convert('RGBA');im.thumbnail((192,192) if kind=='assistant' else (512,512),Image.Resampling.LANCZOS);im.save(target,'WEBP',quality=92,method=6)
    with Image.open(target) as im:
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
        alpha=im.getpixel((im.width//2,im.height//2))[3]
        if kind=='frame':assert alpha==0,'Avatar aperture must remain transparent'
        manifest.append({'key':name,'kind':kind,'file':target.relative_to(root).as_posix(),'width':im.width,'height':im.height,'bytes':target.stat().st_size,'centerAlpha':alpha,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'original':original.relative_to(root).as_posix(),'originalSha256':hashlib.sha256(original.read_bytes()).hexdigest(),'prompt':row['prompt']})
target=art/'assets.json';content=json.dumps({'generation':'built-in image_gen; model identifier not exposed','scope':'Static visuals only; no actual certification or growth award is issued by these resources.','assets':manifest},ensure_ascii=False,indent=2)+'\n'
if target.exists():assert target.read_text(encoding='utf-8')==content
else:target.write_text(content,encoding='utf-8')
print(json.dumps({'assets':len(manifest),'bytes':sum(m['bytes'] for m in manifest),'transparentFrameCenters':sum(m['kind']=='frame' and m['centerAlpha']==0 for m in manifest)}))
