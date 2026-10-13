"""One-time Linux ECS infrastructure bootstrap; no business Flyway migrate.

Credentials are generated/stored on ECS only. Existing credentials/data are kept.
Invoke after importing the checksum-verified image archive and public source files.
"""
from pathlib import Path
import argparse
import hashlib
import hmac
import json
import os
import secrets
import subprocess
import urllib.request
import urllib.error
from datetime import datetime, timezone

ROOT = Path('/opt/aisports')
CONFIG = ROOT/'config'
NETWORK = 'aisports-dev-ecs-dependencies'
COMPOSE = ['docker', 'compose', '--env-file', str(CONFIG/'dependencies.env'), '-f', str(ROOT/'dependencies/compose.yml')]
IMAGES = ['postgres:17.11-bookworm', 'redis:7.4.11-bookworm', 'pgsty/silo:RELEASE.2026-09-16T00-00-00Z', 'flyway/flyway:11.7.2']

def private(path, text):
    if path.exists():
        raise RuntimeError('Refusing to overwrite existing private configuration: '+path.name)
    path.write_text(text, encoding='utf-8')
    path.chmod(0o600)

def run(args, label, data=None):
    result = subprocess.run(args, input=data, text=True, capture_output=True)
    if result.returncode:
        log = ROOT/'bootstrap'/f'{label}.log'
        log.write_text(result.stdout + result.stderr, encoding='utf-8')
        log.chmod(0o600)
        raise RuntimeError(label+' failed; inspect the private server log')
    return result.stdout.strip()

def settings():
    return dict(line.split('=', 1) for line in (CONFIG/'dependencies.env').read_text().splitlines() if line and not line.startswith('#'))

def configure():
    os.umask(0o077)
    CONFIG.mkdir(parents=True, exist_ok=True)
    if (CONFIG/'dependencies.env').exists():
        print('Existing dependency credentials retained')
        return
    for path in ('backend.env', 'backend.env.pending', 'minio.env', 'redis.conf', 'flyway.env'):
        if (CONFIG/path).exists():
            raise RuntimeError('Partial/existing configuration needs operator review before bootstrap')
    values = {name:secrets.token_hex(32) for name in ('PG_BOOTSTRAP_PASSWORD', 'PG_OWNER_PASSWORD', 'APP_DB_PASSWORD', 'PLATFORM_ADMIN_PASSWORD', 'REDIS_PASSWORD', 'MINIO_ROOT_PASSWORD', 'MINIO_APP_PASSWORD', 'JWT_SECRET', 'MONITOR_PASSWORD', 'PARTICIPANT_PHONE_PEPPER', 'AI_INTERNAL_TOKEN')}
    values.update(MINIO_ROOT_USER='aisports-storage-admin', MINIO_APP_USER='aisports-storage-app')
    private(CONFIG/'dependencies.env', ''.join(f'{k}={v}\n' for k,v in values.items()))
    private(CONFIG/'minio.env', ''.join(f'{k}={values[k]}\n' for k in ('MINIO_ROOT_USER','MINIO_ROOT_PASSWORD','MINIO_APP_USER','MINIO_APP_PASSWORD')))
    private(CONFIG/'redis.conf', 'bind 0.0.0.0\nprotected-mode yes\nport 6379\nappendonly yes\nappendfsync everysec\nmaxmemory 96mb\nmaxmemory-policy noeviction\nrequirepass '+values['REDIS_PASSWORD']+'\n')
    os.chown(CONFIG/'redis.conf', 0, 999)
    (CONFIG/'redis.conf').chmod(0o640)
    private(CONFIG/'flyway.env', 'FLYWAY_URL=jdbc:postgresql://postgres:5432/aisports\nFLYWAY_USER=aisports_owner\nFLYWAY_PASSWORD='+values['PG_OWNER_PASSWORD']+'\nFLYWAY_BASELINE_VERSION=0\nFLYWAY_BASELINE_DESCRIPTION=framework-only-initialization\nFLYWAY_CLEAN_DISABLED=true\nFLYWAY_BASELINE_ON_MIGRATE=false\nFLYWAY_PLACEHOLDER_REPLACEMENT=false\n')
    backend = {'DB_JDBC_URL':'jdbc:postgresql://postgres:5432/aisports?reWriteBatchedInserts=true','POSTGRES_USER':'aisports_owner','POSTGRES_PASSWORD':values['PG_OWNER_PASSWORD'],'APP_DB_USER':'aisports_app','APP_DB_PASSWORD':values['APP_DB_PASSWORD'],'REDIS_HOST':'redis','REDIS_PORT':'6379','REDIS_DATABASE':'0','REDIS_PASSWORD':values['REDIS_PASSWORD'],'PUBLIC_BASE_URL':'','JAVA_TOOL_OPTIONS':'-Xms256m -Xmx1024m -XX:+UseG1GC -Djava.awt.headless=true -Dfile.encoding=UTF-8','MCP_ENABLED':'false','PARTICIPANT_SMS_ECHO_CODE':'false','TENCENT_SMS_ENABLED':'false','DEEPSEEK_API_KEY':''}
    backend.update({k:values[k] for k in ('JWT_SECRET','MONITOR_PASSWORD','PARTICIPANT_PHONE_PEPPER','AI_INTERNAL_TOKEN')})
    private(CONFIG/'backend.env.pending', '# Complete PUBLIC_BASE_URL and supplier settings before renaming to backend.env.\n'+''.join(f'{k}={v}\n' for k,v in backend.items()))
    private(CONFIG/'gateway.env', 'DEEPSEEK_API_KEY=\nAI_INTERNAL_TOKEN='+values['AI_INTERNAL_TOKEN']+'\nAI_COMPAT_BASE_URL=https://api.deepseek.com\nAI_TEXT_MODEL=deepseek-flash\nAI_VISION_MODEL=deepseek-flash\nAI_GATEWAY_PORT=8091\n')
    private(CONFIG/'server.env', 'ECS_NETWORK='+NETWORK+'\nWEB_PORT=8088\nBACKEND_MEMORY_LIMIT=1792m\n')
    private(CONFIG/'platform-admin.json', json.dumps({'username':'admin','password':values['PLATFORM_ADMIN_PASSWORD'],'tenantId':'000000'}, indent=2)+'\n')
    print('Independent ECS credentials generated; application settings await HTTPS domain')

def prepare():
    lock_path = ROOT/'bootstrap/imported-images.json'
    actual = {image:run(['docker','image','inspect',image,'--format','{{.Id}}'],'inspect-image') for image in IMAGES}
    if lock_path.exists():
        if json.loads(lock_path.read_text()) != actual:
            raise RuntimeError('An imported dependency image changed; review before updating')
    else:
        private(lock_path, json.dumps(actual, indent=2)+'\n')
    for name in ('postgres','redis','minio'):
        container = 'aisports-dev-ecs-'+name
        exists = subprocess.run(['docker','container','inspect',container],capture_output=True).returncode == 0
        if exists:
            owner = run(['docker','inspect',container,'--format','{{index .Config.Labels "aisports.deployment.root"}}'],'container-owner')
            if owner != str(ROOT): raise RuntimeError('Container ownership mismatch')
    exists = subprocess.run(['docker','network','inspect',NETWORK],capture_output=True).returncode == 0
    if not exists:
        run(['docker','network','create','--label','aisports.deployment.root='+str(ROOT),NETWORK],'create-network')
    else:
        owner = run(['docker','network','inspect',NETWORK,'--format','{{index .Labels "aisports.deployment.root"}}'],'network-owner')
        if owner != str(ROOT): raise RuntimeError('Network ownership mismatch')
    for service in ('postgres','redis','minio'):
        name='aisports-dev-ecs-'+service+'-data'
        exists=subprocess.run(['docker','volume','inspect',name],capture_output=True).returncode == 0
        if not exists:
            run(['docker','volume','create','--label','aisports.deployment.root='+str(ROOT),'--label','com.docker.compose.project=aisports-dev-ecs-dependencies','--label','com.docker.compose.volume='+service+'-data',name],'create-volume')
        else:
            owner=run(['docker','volume','inspect',name,'--format','{{index .Labels "aisports.deployment.root"}}'],'volume-owner')
            if owner != str(ROOT): raise RuntimeError('Volume ownership mismatch')
    run(['docker','run','--rm','--name','aisports-dev-ecs-volume-init','--user','0:0','--cap-drop','ALL','--cap-add','CHOWN','-v','aisports-dev-ecs-minio-data:/data','--entrypoint','chown',IMAGES[0],'10001:10001','/data'],'minio-volume-owner')
    run(COMPOSE+['config','--quiet'],'compose-validate')
    run(COMPOSE+['up','-d','--wait','--wait-timeout','240'],'start-dependencies')
    print('Dependency containers started; data volumes retained')

def sql(statement):
    return run(['docker','exec','-i','aisports-dev-ecs-postgres','psql','-X','-U','aisports_bootstrap','-d','aisports','-At','-v','ON_ERROR_STOP=1'],'database-check',statement+'\n')

def initialize():
    history=sql("SELECT to_regclass('public.flyway_schema_history') IS NOT NULL")
    if history == 'f':
        if sql("SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'asp_%'") != '0':
            raise RuntimeError('An existing business schema cannot be marked as a fresh framework database')
        run(['docker','run','--rm','--name','aisports-dev-ecs-flyway-baseline','--network',NETWORK,'--security-opt','no-new-privileges:true','--env-file',str(CONFIG/'flyway.env'),IMAGES[3],'baseline'],'framework-baseline')
        sql('REVOKE ALL ON TABLE flyway_schema_history FROM aisports_app;')
    # mcli uses a private environment alias; no credential output is returned.
    commands = '''set -eu
export MC_HOST_bootstrap="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@127.0.0.1:9000"
mcli --config-dir /tmp/aisports-mcli mb --ignore-existing bootstrap/aisports-ecs
mcli --config-dir /tmp/aisports-mcli anonymous set none bootstrap/aisports-ecs
mcli --config-dir /tmp/aisports-mcli admin user add bootstrap "$MINIO_APP_USER" "$MINIO_APP_PASSWORD"
cat >/tmp/aisports-app-policy.json <<'POLICY'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetBucketLocation","s3:ListBucket","s3:ListBucketMultipartUploads"],"Resource":["arn:aws:s3:::aisports-ecs"]},{"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:AbortMultipartUpload","s3:ListMultipartUploadParts"],"Resource":["arn:aws:s3:::aisports-ecs/*"]}]}
POLICY
mcli --config-dir /tmp/aisports-mcli admin policy create bootstrap aisports-private /tmp/aisports-app-policy.json
mcli --config-dir /tmp/aisports-mcli admin policy attach bootstrap aisports-private --user "$MINIO_APP_USER"
'''
    run(['docker','exec','-i','aisports-dev-ecs-minio','sh'], 'private-storage-bootstrap', commands)
    values=settings()
    # Initial framework storage configuration uses the restricted application key.
    # External signing domain remains disabled until HTTPS is configured.
    sql("UPDATE sys_oss_config SET endpoint='minio:9000',domain=NULL,access_key='"+values['MINIO_APP_USER']+"',secret_key='"+values['MINIO_APP_PASSWORD']+"',bucket_name='aisports-ecs',is_https='N',access_policy='0',status='0' WHERE config_key='minio';")
    print('Framework-only Flyway marker and restricted private storage prepared; business migrations await Spring Boot')

def storage_request(method, key, body=b''):
    values=settings()
    now=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    date=now[:8]
    path='/aisports-ecs/'+key
    digest=hashlib.sha256(body).hexdigest()
    headers=f'host:127.0.0.1:9000\nx-amz-content-sha256:{digest}\nx-amz-date:{now}\n'
    signed='host;x-amz-content-sha256;x-amz-date'
    canonical='\n'.join((method,path,'',headers,signed,digest))
    scope=date+'/us-east-1/s3/aws4_request'
    def hm(key,text): return hmac.new(key,text.encode(),hashlib.sha256).digest()
    signing=hm(hm(hm(hm(('AWS4'+values['MINIO_APP_PASSWORD']).encode(),date),'us-east-1'),'s3'),'aws4_request')
    signature=hmac.new(signing,('AWS4-HMAC-SHA256\n'+now+'\n'+scope+'\n'+hashlib.sha256(canonical.encode()).hexdigest()).encode(),hashlib.sha256).hexdigest()
    auth=f'AWS4-HMAC-SHA256 Credential={values["MINIO_APP_USER"]}/{scope}, SignedHeaders={signed}, Signature={signature}'
    request=urllib.request.Request('http://127.0.0.1:9000'+path,data=body if method=='PUT' else None,method=method,headers={'x-amz-date':now,'x-amz-content-sha256':digest,'Authorization':auth})
    with urllib.request.urlopen(request,timeout=15) as response: return response.status,response.read()

def verify():
    states=run(COMPOSE+['ps','--format','json'],'container-readiness')
    # Compose v2 emits one JSON document per service rather than a JSON array.
    services=[json.loads(line) for line in states.splitlines() if line]
    result={'at':datetime.now(timezone.utc).isoformat(),'host':'47.92.212.93','services':services}
    result['businessTables']=int(sql("SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'asp_%'"))
    result['flywayVersions']=sql('SELECT version FROM flyway_schema_history ORDER BY installed_rank').splitlines()
    result['restrictedRoles']=sql("SELECT rolname||':'||rolsuper||':'||rolcreatedb||':'||rolcreaterole FROM pg_roles WHERE rolname IN ('aisports_owner','aisports_app') ORDER BY rolname").splitlines()
    result['applicationSchemaCreate']=sql("SELECT has_schema_privilege('aisports_app','public','CREATE')")
    result['applicationLedgerRead']=sql("SELECT has_table_privilege('aisports_app','flyway_schema_history','SELECT')")
    result['applicationLogin']=run(['docker','exec','aisports-dev-ecs-postgres','bash','-c','PGPASSWORD="$APP_PASSWORD" exec psql -X -h 127.0.0.1 -U aisports_app -d aisports -At -v ON_ERROR_STOP=1 -c "SELECT current_user"'],'application-login')=='aisports_app'
    result['redisAuthenticated']=run(['docker','exec','aisports-dev-ecs-redis','redis-cli','ping'],'redis-auth')=='PONG'
    result['redisAnonymousDenied']='NOAUTH' in run(['docker','exec','aisports-dev-ecs-redis','env','-u','REDISCLI_AUTH','redis-cli','ping'],'redis-no-auth')
    key='.healthcheck/'+secrets.token_hex(8)
    payload=b'aisports-dependency-healthcheck'
    storage_request('PUT',key,payload)
    try:
        result['storageSignedRead']=storage_request('GET',key)[1]==payload
        try:
            urllib.request.urlopen('http://127.0.0.1:9000/aisports-ecs/'+key,timeout=15)
            result['storageAnonymousDenied']=False
        except urllib.error.HTTPError as error:
            result['storageAnonymousDenied']=error.code==403
    finally: storage_request('DELETE',key)
    assert result['flywayVersions']==['0'] and result['businessTables']==0
    assert result['applicationSchemaCreate']=='f' and result['applicationLedgerRead']=='f'
    assert all(result[k] for k in ('applicationLogin','redisAuthenticated','redisAnonymousDenied','storageSignedRead','storageAnonymousDenied'))
    assert len(services)==3 and all(s.get('Health')=='healthy' for s in services)
    receipt=ROOT/'bootstrap'/('dependencies-ready-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'.json')
    private(receipt,json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='services'},ensure_ascii=False,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('command',choices=('configure','prepare','initialize','verify'))
    command=parser.parse_args().command
    if os.name!='posix' or os.geteuid()!=0: raise SystemExit('Run as root on the Linux ECS only')
    if not ROOT.is_dir(): raise SystemExit('Prepare the dedicated /opt/aisports directory first')
    {'configure':configure,'prepare':prepare,'initialize':initialize,'verify':verify}[command]()
