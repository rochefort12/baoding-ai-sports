"""New independent synthetic Word source for a naturally opening rehearsal.
Original frozen fixtures and canonical checkpoints are never rewritten.
"""
import argparse, copy, hashlib, json
from datetime import datetime
from pathlib import Path
from docx import Document

p=argparse.ArgumentParser()
p.add_argument('--original',required=True);p.add_argument('--out',required=True)
p.add_argument('--name',required=True);p.add_argument('--closes',required=True)
p.add_argument('--starts',required=True);p.add_argument('--ends',required=True)
a=p.parse_args();original=Path(a.original).resolve();out=Path(a.out).resolve()
if out.exists():raise SystemExit('Independent source directory already exists; frozen bytes may not be replaced')
manifest=json.loads((original/'manifest.json').read_text(encoding='utf-8'))
old=manifest['expected'];expected=copy.deepcopy(old)
expected.update(name=a.name,registrationClosesAt=a.closes,startsAt=a.starts,endsAt=a.ends)
assert expected['name'].startswith(manifest['prefix']+'-自然开赛-')
assert datetime.strptime(a.closes,'%Y-%m-%d %H:%M:%S')<datetime.strptime(a.starts,'%Y-%m-%d %H:%M:%S')<datetime.strptime(a.ends,'%Y-%m-%d %H:%M:%S')
doc=Document(original/'complete.docx')
for para in doc.paragraphs:
    replacements={old['name']:expected['name'],old['registrationClosesAt']:a.closes,old['startsAt']:a.starts,old['endsAt']:a.ends}
    for run in para.runs:
        text=run.text
        for before,after in replacements.items():text=text.replace(before,after)
        run.text=text
out.mkdir(parents=True);file=out/'complete.docx';doc.save(file)
new={'synthetic':True,'prefix':manifest['prefix'],'createdAt':datetime.now().astimezone().isoformat(),'source':'New DOCX derived from frozen complete.docx; only name and explicit time window differ','originalSha256':hashlib.sha256((original/'complete.docx').read_bytes()).hexdigest(),'expected':expected,'files':[{'name':'complete.docx','sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'size':file.stat().st_size}]}
(out/'manifest.json').write_text(json.dumps(new,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'source':str(file),'expectedName':expected['name'],'registrationClosesAt':a.closes,'startsAt':a.starts,'endsAt':a.ends},ensure_ascii=False))
