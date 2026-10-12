"""Lightweight reproducibility, architecture and documentation checks (stdlib only)."""
from pathlib import Path
import json
import hashlib
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
lock = json.loads((ROOT/'source-lock.json').read_text(encoding='utf-8'))
for name, checksum in lock['migrationSnapshots'].items():
    assert hashlib.sha256((ROOT/'database/migrations'/name).read_bytes()).hexdigest() == checksum, f'Frozen migration changed: {name}'
ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
api = ROOT/'backend/aisports-api'
pom = ET.parse(api/'pom.xml').getroot()
assert pom.find('m:dependencies',ns) is None, 'API module must not acquire infrastructure dependencies'
for file in api.rglob('*.java'):
    for package in re.findall(r'^import\s+([\w.]+)',file.read_text(encoding='utf-8'),re.M):
        assert package.startswith(('java.','org.dromara.sports.api.')), (file,package)
style = ROOT/'plus-ui/src/assets/styles/generated-crud.scss'
template = ROOT/'backend/ruoyi-modules/ruoyi-generator/src/main/resources/vm/styles/generated-crud.scss.vm'
assert style.read_text(encoding='utf-8') == template.read_text(encoding='utf-8'), 'Shared stylesheet/template drift'
index = (ROOT/'plus-ui/src/assets/styles/index.scss').read_text(encoding='utf-8')
assert index.count("@use './generated-crud.scss';") == 1
catalog = json.loads((ROOT/'database/model/catalog.json').read_text(encoding='utf-8'))
tables = catalog['tables'] if isinstance(catalog,dict) else catalog
shared = {t['name'] for t in tables if not t['tenant']}
application = (ROOT/'backend/ruoyi-admin/src/main/resources/application.yml').read_text(encoding='utf-8')
exclusions = set(re.findall(r'^    - (asp_\w+)\s*$',application,re.M))
assert shared == exclusions, 'Shared-table tenant exclusion drift'
for file in [ROOT/'README.md', ROOT/'docs/README.md', *list((ROOT/'docs/01-development').glob('*.md')),
             *list((ROOT/'docs/03-architecture').glob('*.md'))]:
    for link in re.findall(r'\[[^\]]+\]\(([^)]+)\)',file.read_text(encoding='utf-8')):
        if link.startswith(('http:','https:','app:','#')):continue
        target = link.split('#')[0]
        assert (file.parent/target).exists(), f'Broken document link: {file} -> {link}'
statuses=json.loads((ROOT/'docs/04-verification/acceptance-status.json').read_text(encoding='utf-8'))
assert len(statuses)==80
for code,value in statuses.items():
    if value['status'] == '通过':
        assert value['evidence'] and value['owner'] != '待指定', f'Missing business acceptance evidence: {code}'
print(f'PASS: JDK-only API, shared styles, {len(shared)} tenant exclusions, documentation links and 80 acceptance records.')
