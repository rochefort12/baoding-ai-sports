"""Publish sanitized local verification evidence. Never read private session/credential files."""
import hashlib
import json
import re
import shutil
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / '.local/phase1-implementation'
DOCS = ROOT / 'docs/04-verification'
FINAL = DOCS / '羽毛球一期闭环本机验证-20261010.json'
if FINAL.exists():
    raise RuntimeError('Published evidence is immutable. Record a linked supplemental receipt instead.')


def read(name):
    return json.loads((LOCAL / name).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


jar = ROOT / 'backend/ruoyi-admin/target/ruoyi-admin.jar'
manifest = read('verified-ui-capabilities.json')
java = read('java-product-suite-result.json')
screens = read('product-screens-receipt.json')
latest = read('product-screens-targeted-receipt.json')
navigation = read('product-navigation-receipt.json')
experience = read('real-experience-receipt.json')
operators = read('real-operator-experience-receipt.json')
flow = read('http-flow-progress.json')
baseline = read('baseline-receipt.json')
migration = read('migration-phase1-receipt.json')
architecture = json.loads((LOCAL / 'product-architecture.log').read_text(encoding='utf-8-sig').strip())
generation = json.loads((LOCAL / 'product-generation.log').read_text(encoding='utf-8-sig').strip())
ai_log = (LOCAL / 'product-ai-all-tests-second.log').read_text(encoding='utf-8-sig')
ai_counts = {key: int(re.search(r'^# '+key+r' (\d+)$', ai_log, re.M)[1]) for key in ('tests', 'pass', 'fail', 'skipped')}
require(java['tests'] == 212 and all(java[k] == 0 for k in ('failures', 'errors', 'skipped')), 'Java suite incomplete')
require(len(screens['rows']) == 98 and not screens['failures'] and not latest['failures'], 'Page inspection incomplete')
require(not navigation['errors'] and not navigation['writes'] and len(navigation['checks']) == 3, 'Navigation inspection incomplete')
require(not experience['failures'] and len(experience['checks']) == 7 and len(operators['checks']) == 5, 'Role/experience evidence incomplete')
require(baseline['restoredCountsMatch'] and migration['repeatApplied'], 'Backup/migration verification incomplete')
require(architecture['tableDependencyViolations'] == 0 and generation['changedFiles'] == 0, 'Table assembly check incomplete')
require(ai_counts['tests'] == ai_counts['pass'] and ai_counts['fail'] == ai_counts['skipped'] == 0, 'AI unit suite incomplete')
require(sha(jar) == manifest['jarSha256'] and len(manifest['definitions']) == 47, 'Unverified build/capability inventory')
require((LOCAL / 'product-delivery-ui-typecheck.log').read_text(encoding='utf-8-sig').strip() == '', 'UI types failed')
require('✓ built in' in (LOCAL / 'product-delivery-ui-build.log').read_text(encoding='utf-8-sig'), 'UI build incomplete')
evidence_files = ['baseline-receipt.json', 'migration-phase1-receipt.json', 'java-product-suite-result.json',
                  'product-final-java.log', 'product-room-context-package.log', 'product-architecture.log', 'product-generation.log',
                  'product-ai-all-tests-second.log', 'product-screens-receipt.json', 'product-screens-targeted-receipt.json',
                  'product-navigation-receipt.json', 'real-experience-receipt.json', 'real-operator-experience-receipt.json',
                  'http-flow-progress.json', 'verified-ui-capabilities.json', 'product-delivery-ui-typecheck.log', 'product-delivery-ui-build.log']
screens_dir = ROOT / 'docs/05-ui/phase1-product'
screens_dir.mkdir(parents=True, exist_ok=True)
image_names = [('product-screens/desktop-public-home.png', 'participant-home.png'),
               ('product-screens/mobile-room-detail.png', 'room-mobile.png'),
               ('product-screens/mobile-growth.png', 'growth-mobile.png'),
               ('product-screens/desktop-government-organizers.png', 'government-organizers.png'),
               ('product-screens/desktop-platform-objects.png', 'platform-objects.png'),
               ('product-screens/mobile-event-closure.png', 'event-closure-mobile.png'),
               ('product-navigation-registrations-mobile.png', 'registration-detail-mobile.png')]
images = []
for source, target in image_names:
    source_path = LOCAL / source
    target_path = screens_dir / target
    shutil.copyfile(source_path, target_path)
    images.append({'path': str(target_path.relative_to(ROOT)).replace('\\', '/'), 'sha256': sha(target_path)})
result = {
    'timestamp': datetime.now(timezone.utc).isoformat(), 'scope': 'local-controlled-trial',
    'completion': 'Implemented and locally verified paths only; not full phase-one or real-business acceptance',
    'sourceCommit': baseline['sourceCommit'], 'jarSha256': sha(jar), 'failures': 0,
    'database': {'baselineTables': baseline['tableCount'], 'baselineSportsTables': baseline['sportsTableCount'],
                 'sportsTables': 118, 'modelTables': 121, 'plannedTables': 3, 'migrations': 'V030-V033',
                 'restoredCountsMatch': True, 'replayVerified': True},
    'tests': {'java': java, 'aiUnit': {**ai_counts, 'boundary': 'Mocked model/tool transport; not live DeepSeek'},
              'isolatedHttpChecks': len(flow['checks']), 'pageInspection': {'routes': 49, 'desktopAndMobile': 98, 'failures': 0},
              'finalPageInspection': {'checks': len(latest['rows']), 'failures': 0}, 'readOnlyNavigation': 3,
              'participantBrowser': 7, 'ordinaryRoleBrowser': 5, 'tableArchitecture': architecture, 'repeatAssembly': generation,
              'frontendTypecheck': 'PASS', 'frontendBuild': 'PASS with existing chunk-size warning'},
    'capabilities': {'humanUi': 47, 'mutationsWithActualReceipt': 39, 'queryChecks': 8,
                     'agentActivation': 'CLOSED pending live model verification', 'genericSqlWriteGuard': 'NOT globally enforced'},
    'businessEvidenceBoundary': 'Actual isolated PostgreSQL/Redis/MinIO/HTTP/MCP and Vue. Fictional users/events/materials and simulated money/match facts. No real transfer, SMS, model recognition or actual event asserted.',
    'remainingGates': ['DPAPI model credential and live model/vision/tool tests', 'Business SMS templates and actual delivery/recovery',
                       'Specified operators with a real event, verified real funds and complaint closure',
                       'Legacy AI/async writer hardening and global action-context enforcement',
                       'Full 21/17/7 ordinary-role acceptance and privacy/account recovery/closure checks'],
    'screenshots': images,
    'evidence': [{'path': '.local/phase1-implementation/'+name, 'sha256': sha(LOCAL / name)} for name in evidence_files]
}
DOCS.mkdir(parents=True, exist_ok=True)
stage = DOCS / ('.phase1-evidence-'+uuid.uuid4().hex+'.tmp')
with stage.open('xb') as stream:
    stream.write((json.dumps(result, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
    stream.flush()
    os.fsync(stream.fileno())
os.replace(stage, FINAL)
(screens_dir / 'README.md').write_text('# 一期产品页面截图\n\n参赛、主办方、政府和平台的实际Vue页面，连接隔离服务。昵称、赛事、资金、比赛及证明均为虚构演练；保留测试标记。不是生产业务或真实赛事验收。\n\n截图校验值见本机验证JSON。\n', encoding='utf-8')
print(json.dumps({'scope': result['scope'], 'failures': 0, 'java': java['tests'], 'aiUnit': ai_counts['tests'], 'isolatedHttp': len(flow['checks']), 'pageInspection': 98, 'humanCapabilities': 47}, ensure_ascii=False))
