"""Build gate for actual one-table ownership and generator/handwritten boundaries."""
from pathlib import Path
import json,re,sys,xml.etree.ElementTree as ET
from generate_table_helpers import ROOT,load_catalog
manifest=json.loads((ROOT/'backend/aisports-domains/manifest.json').read_text('utf-8'))
catalog=load_catalog(); errors=[]
expected={t.name for t in catalog.TABLES}; actual={t['table'] for t in manifest['tables']}
if expected!=actual or len(actual)!=len(manifest['tables']): errors.append('Table ownership differs from catalog')
ns={'m':'http://maven.apache.org/POM/4.0.0'}
owners={}
for entry in manifest['tables']:
 for file in (ROOT/'backend/aisports-domains'/entry['path']/'src/main/java').rglob('*.java'):
  text=file.read_text('utf-8-sig')
  package=re.search(r'package\s+([\w.]+);',text)
  if package: owners[package[1]+'.'+file.stem]=entry['table']
for entry in manifest['tables']:
 p=ROOT/'backend/aisports-domains'/entry['path']
 tree=ET.parse(p/'pom.xml')
 for artifact in tree.findall('./m:dependencies/m:dependency/m:artifactId',ns):
  if artifact.text not in ('aisports-platform-core','spring-boot-starter-test'): errors.append(f'Illegal table dependency {entry["table"]}: {artifact.text}')
 for file in (p/'src/main/java').rglob('*.java'):
  for imported in re.findall(r'import\s+(?:static\s+)?([\w.]+)(?:\.\*)?;',file.read_text('utf-8-sig')):
   owner=owners.get(imported)
   if owner and owner!=entry['table']: errors.append(f'Cross-table implementation import: {file.relative_to(ROOT)} -> {owner}')
  for foreign in re.findall(r'import\s+org\.dromara\.sports\.tables\.([^;]+);',file.read_text('utf-8')):
   if not foreign.startswith(entry['domain'].lower()+'.'+entry['table'][4:]+'.'): errors.append(f'Foreign table class: {file.relative_to(ROOT)}')
if errors:
 print('\n'.join(errors)); sys.exit(1)
print(json.dumps({'tableModules':len(actual),'tableDependencyViolations':0,'catalogOwnership':'PASS'}))
