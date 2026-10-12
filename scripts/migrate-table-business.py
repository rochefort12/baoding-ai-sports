"""Move verified legacy business slices to their entry-table modules; preserve packages and HTTP contracts.

Cross-table domain classes are private projections of a complete action, not imports from another module.
This one-time migration validates every path; originals remain recoverable in Git and a local hash receipt.
"""
from pathlib import Path
import argparse, hashlib, json, re, shutil
from generate_table_helpers import ROOT, load_catalog, module_path

ANCHORS={'identity':'account','organization':'organization_application','event':'event','registration':'registration',
         'team':'team','finance':'fee_obligation','competition':'match'}

def snake(s): return re.sub(r'(?<!^)(?=[A-Z])','_',s).lower()
def valid(path):
    if not path.resolve().is_relative_to(ROOT.resolve()) or path.is_symlink(): raise ValueError('Unsafe migration path')
    return path

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--apply',action='store_true'); args=parser.parse_args()
    catalog=load_catalog(); moves=[]
    for domain,anchor in ANCHORS.items():
        source=ROOT/f'backend/ruoyi-modules/ruoyi-sports-{domain}'
        target=module_path(next(t for t in catalog.TABLES if t.name=='asp_'+anchor))
        files=list((source/'src').rglob('*')) if (source/'src').exists() else []
        tables=sorted(set(re.findall(r'@TableName\((?:value\s*=\s*)?"([^"]+)"','\n'.join(f.read_text('utf-8') for f in files if f.suffix=='.java'))))
        for f in files:
            if not f.is_file(): continue
            dest=valid(target/f.relative_to(source))
            raw=f.read_bytes(); content=raw.decode('utf-8') if f.suffix=='.java' else None
            if content and '/main/' in str(f).replace('\\','/') and '/service/' in str(f).replace('\\','/'):
                def annotate(m):
                    if 'readOnly = true' in m.group(1) or 'readOnly=true' in m.group(1): return m.group(0)
                    name=m.group(2)
                    scope='{'+', '.join('"'+t+'"' for t in tables)+'}'
                    annotation=f'@org.dromara.sports.platform.core.SportsAction(value="legacy.{anchor}.{snake(f.stem)}.{snake(name)}", title="{f.stem}.{name}", reads={scope}, writes={scope})\n    '
                    return annotation+m.group(0)
                content=re.sub(r'(@Transactional(?:\([^)]*\))?\s*)public\s+[\w.<>, ?\[\]]+\s+(\w+)\s*\(',annotate,content)
                if domain=='organization':
                    content=content.replace('import org.dromara.system.domain.vo.TenantOpening;', 'import org.dromara.sports.api.OrganizationProvisioningApi.Opening;')
                    content=content.replace('import org.dromara.system.service.ISysTenantService;', 'import org.dromara.sports.api.OrganizationProvisioningApi;')
                    content=content.replace('ISysTenantService tenantService','OrganizationProvisioningApi tenantService')
                    content=content.replace('TenantOpening opening = tenantService.openForPlatformAccount(', 'Opening opening = tenantService.open(')
                raw=content.encode('utf-8')
            if dest.exists():
                if dest.read_bytes()!=raw: raise ValueError(f'Target collision: {dest}')
            moves.append((valid(f),dest,raw))
    if args.apply:
        receipt=[]
        backup=valid(ROOT/'.local/phase1-implementation/legacy-source')
        for source,dest,raw in moves:
            original=backup/source.relative_to(ROOT); original.parent.mkdir(parents=True,exist_ok=True)
            if not original.exists(): original.write_bytes(source.read_bytes())
            dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(raw)
            if dest.read_bytes()!=raw: raise ValueError('Migration verification failed')
            receipt.append(dict(source=str(source.relative_to(ROOT)),target=str(dest.relative_to(ROOT)),sha256=hashlib.sha256(raw).hexdigest()))
            source.unlink()
        if receipt:
            receipt_path=backup.parent/'business-source-migration.json'
            prior=json.loads(receipt_path.read_text('utf-8')) if receipt_path.exists() else []
            receipt_path.write_text(json.dumps(prior+receipt,indent=2,ensure_ascii=False),'utf-8')
        modules_pom=ROOT/'backend/ruoyi-modules/pom.xml'
        text=modules_pom.read_text('utf-8'); text=re.sub(r'\s*<module>ruoyi-sports-[^<]+</module>','',text); modules_pom.write_text(text,'utf-8')
        root_pom=ROOT/'backend/pom.xml'; text=root_pom.read_text('utf-8')
        if '<module>aisports-platform</module>' not in text:
            text=text.replace('<module>aisports-api</module>','<module>aisports-api</module>\n        <module>aisports-platform</module>\n        <module>aisports-domains</module>')
        root_pom.write_text(text,'utf-8')
        admin_pom=ROOT/'backend/ruoyi-admin/pom.xml'; text=admin_pom.read_text('utf-8')
        text=re.sub(r'\s*<dependency>\s*<groupId>org.dromara</groupId>\s*<artifactId>ruoyi-sports-[^<]+</artifactId>\s*(?:<version>\$\{revision\}</version>\s*)?</dependency>','',text)
        deps=(ROOT/'backend/aisports-domains/admin-dependencies.xml').read_text('utf-8')
        for artifact in ('aisports-platform-registry','aisports-platform-authz','aisports-platform-executor'):
            deps+=f'\n        <dependency><groupId>org.dromara</groupId><artifactId>{artifact}</artifactId><version>${{revision}}</version></dependency>'
        if 'aisports-table-account' not in text: text=text.replace('</dependencies>',deps+'\n    </dependencies>')
        admin_pom.write_text(text,'utf-8')
    print(json.dumps({'movedFiles':len(moves),'entryModules':ANCHORS,'applied':args.apply},ensure_ascii=False))

if __name__=='__main__': main()
