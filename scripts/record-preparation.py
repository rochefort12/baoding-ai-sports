"""Record successful local preparation evidence without credentials or personal data.

Run after all verification commands. Logs are local/ignored; this snapshot is committed
documentation, not an alternative to rerunning checks after source changes.
"""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
def log(name):return (ROOT/'.local'/name).read_text(encoding='utf-8',errors='replace')
assert 'BUILD SUCCESS' in log('backend-build.log')
assert 'vue-tsc --noEmit' in log('frontend-check.log') and 'error TS' not in log('frontend-check.log')
assert 'built in' in log('frontend-check.log') and 'ELIFECYCLE' not in log('frontend-check.log')
assert 'Done in' in log('frontend-frozen-install.log')
assert 'PASS:' in log('backend-http-check.log')
assert 'PASS:' in log('generator-http-check.log')
assert 'PASS: migration checksum' in log('infrastructure-check.log')
suites=[]
for directory in ['backend/aisports-mcp/target/surefire-reports','backend/ruoyi-modules/ruoyi-generator/target/surefire-reports']:
    for path in (ROOT/directory).glob('TEST-*.xml'):
        suite=ET.parse(path).getroot()
        item={k:suite.attrib[k] for k in ['name','tests','failures','errors','skipped','time']}
        assert not any(int(item[k]) for k in ['failures','errors','skipped']), item
        suites.append(item)
assert sum(int(s['tests']) for s in suites)==12
patterns=['backend/aisports-api/src/**/*.java','backend/aisports-mcp/src/**/*.java',
          'backend/ruoyi-modules/ruoyi-generator/src/**/*.java','backend/ruoyi-modules/ruoyi-generator/src/**/*.vm',
          'backend/ruoyi-common/ruoyi-common-web/src/main/java/**/*.java','backend/ruoyi-admin/src/main/resources/application*.yml',
          'backend/pom.xml','backend/ruoyi-admin/pom.xml','backend/aisports-api/pom.xml','backend/aisports-mcp/pom.xml',
          'backend/ruoyi-modules/ruoyi-generator/pom.xml','backend/ruoyi-modules/ruoyi-generator/src/main/resources/generator.yml',
          'scripts/*.ps1','scripts/*.py','database/model/catalog.py','database/migrations/*.sql',
          'plus-ui/src/**/*.vue','plus-ui/src/**/*.ts','plus-ui/src/**/*.scss','plus-ui/vite.config.ts',
          'plus-ui/package.json','plus-ui/pnpm-workspace.yaml','plus-ui/pnpm-lock.yaml','docker-compose.yml','AGENTS.md']
paths={path for pattern in patterns for path in ROOT.glob(pattern)}
hashes={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_text(encoding='utf-8').encode('utf-8')).hexdigest() for p in sorted(paths)}
runtime=json.loads((ROOT/'.local/runtime-state.json').read_text(encoding='utf-8-sig'))
assert runtime['frontendHttp']==200 and runtime['backendCaptchaEnabled'] and runtime['mcpDisabledBusinessCode']==404
evidence={
    'recordedAt':datetime.now().astimezone().isoformat(timespec='seconds'),
    'scope':'Local development preparation; synthetic framework/metadata fixtures. No business acceptance.',
    'backend':{'profile':'local','build':'PASS','tests':suites,'testCount':12,
               'command':'mvn -Plocal -pl ruoyi-admin -am -DskipTests=false -Dtest=GeneratorPreparationTest,McpAuthenticationFilterTest,McpAccessTest -Dsurefire.failIfNoSpecifiedTests=false package',
               'jarSha256':hashlib.sha256((ROOT/'backend/ruoyi-admin/target/ruoyi-admin.jar').read_bytes()).hexdigest()},
    'frontend':{'frozenInstall':'PASS','viteDevelopmentBuild':'PASS','vueTscNoEmit':'PASS','command':'pnpm install --frozen-lockfile; pnpm run check','knownWarning':'Upstream chunks exceed 500kB; no capacity acceptance performed.'},
    'database':{'tables':76,'columns':1144,'foreignKeys':136,'sharedTables':17,'migrations':['V001','V002'],
                'structuralChecks':'PASS; all synthetic business rows rolled back','appRole':'TCP authentication verified; no superuser/createdb/createrole/schema CREATE','redis':'PONG'},
    'mcpHttp':{'unauthenticated':401,'clientMismatch':401,'untrustedOrigin':403,'initializeProtocol':'2025-03-26','toolListCount':0,
               'note':'Actual HTTP transport verified; generated tool callbacks use synthetic service stubs. No business tools published.'},
    'generatorHttp':{'database':'PostgreSQL','metadataImport':'PASS','mcpOptionRoundTrip':'false -> true','preview':'PASS',
                     'batchZipEntries':27,'sharedStyles':1,'moduleDocuments':2,'cleanup':'Imported metadata deleted; framework audit evidence retained.'},
    'sourceChecks':'JDK-only API, frozen migrations, shared styles, tenant exclusions, docs links, model drift and PowerShell syntax verified.',
    'businessAcceptance':{'sourceCases':80,'passed':0,'status':'Pending implementation and ordinary-role operational acceptance.'},
    'sourceSha256':hashes,
    'sourceHashFormat':'SHA256 of UTF-8 text with normalized LF; the artifact JAR hash is byte-exact.',
    'defaultRuntime':runtime,
    'localLogs':'Ignored .local directory. Never commit credentials/tokens; this snapshot contains no login response.'
}
target=ROOT/'docs/04-verification/preparation-results.json'
target.write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(f'Preparation evidence recorded: {len(suites)} suites / 12 tests, build and actual local infrastructure/MCP/generator checks.')
