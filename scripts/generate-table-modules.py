"""Deterministic one-table modules. Managed files only; never touches handwritten action/extend code.

--dry-run reports changes; --check fails on drift; default assembles generated files.
Every output resolves inside this checkout. Prior generated hashes protect manual edits.
"""
from pathlib import Path
from dataclasses import asdict
import argparse, hashlib, importlib.util, json, re, sys, uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('aisports_table_catalog', ROOT/'database/model/catalog.py')
model = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = model
spec.loader.exec_module(model)
BASE = ROOT/'backend/aisports-domains'
MANIFEST = BASE/'manifest.json'
PLANNED = {'asp_attribute_definition', 'asp_person_attribute', 'asp_attribute_requirement'}
ANCHORS = {'identity':'account','organization':'organization_application','event':'event',
           'registration':'registration','team':'team','finance':'fee_obligation','competition':'match'}

def safe(path):
    resolved = path.resolve()
    if not resolved.is_relative_to(ROOT.resolve()) or path.is_symlink():
        raise ValueError(f'Output escapes checkout: {path}')
    return path

def sha(data): return hashlib.sha256(data).hexdigest()

def render():
    outputs, entries = {}, []
    modules = []
    types = ['// GENERATED object shapes; read/write channels remain capability controlled.\n',
             'export type SportsLong = string;\nexport type SportsMoney = string;\n']
    for table in sorted(model.TABLES, key=lambda t:(t.domain,t.name)):
        if not re.fullmatch(r'asp_[a-z][a-z0-9_]*', table.name): raise ValueError('Invalid table name')
        name = table.name[4:]
        artifact = 'aisports-table-'+name.replace('_','-')
        directory = f'{table.domain.lower()}/{artifact}'
        modules.append(directory)
        root = BASE/directory
        metadata = asdict(table)
        metadata.update(moduleId=artifact, lifecycle='planned' if table.name in PLANNED else 'schema',
                        genericWrites=False, queryOpen=False)
        columns=[dict(name='id',type='bigint',description='稳定编号')]
        if table.tenant: columns.append(dict(name='tenant_id',type='varchar(20)',description='组织管理范围'))
        metadata['columns']=columns+metadata['columns']
        type_name=''.join(part.title() for part in name.split('_'))+'Object'
        types.append(f'/** {table.description.replace("*/", "")} */\nexport interface {type_name} {{\n')
        for column in metadata['columns']:
            sql_type=column['type'].lower()
            ts_type=('SportsLong' if sql_type=='bigint' else 'SportsMoney' if sql_type.startswith('numeric')
                     else 'boolean' if sql_type=='boolean' else 'number' if sql_type in ('integer','smallint')
                     else 'unknown' if sql_type in ('json','jsonb') else 'string')
            optional='' if column['name']=='id' else '?'
            types.append(f'  {column["name"]}{optional}: {ts_type} | null;\n')
        types.append('}\n')
        metadata_text=json.dumps(metadata,ensure_ascii=False,indent=2)+'\n'
        class_name='OwnedTableModule'
        pkg=f'org.dromara.sports.tables.{table.domain.lower()}.{name}'
        java=f'''// GENERATED. Handwritten business actions belong outside generated/.
package {pkg};
import org.dromara.sports.platform.core.TableModule;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
@Component("table_{table.name}")
public class {class_name} implements TableModule {{
    public String tableName() {{ return "{table.name}"; }}
    public String domain() {{ return "{table.domain}"; }}
    public String metadataJson() {{
        try (var stream = getClass().getResourceAsStream("/aisports/tables/{table.name}.json")) {{
            if (stream == null) throw new IllegalStateException("Missing table metadata");
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        }} catch (IOException e) {{ throw new IllegalStateException("Unreadable table metadata", e); }}
    }}
}}
'''
        pom=f'''<!-- GENERATED: one table, one module. Only core and test dependencies. -->
<project xmlns="http://maven.apache.org/POM/4.0.0"><modelVersion>4.0.0</modelVersion>
 <parent><groupId>org.dromara</groupId><artifactId>aisports-domains</artifactId><version>${{revision}}</version><relativePath>../../pom.xml</relativePath></parent>
 <artifactId>{artifact}</artifactId>
 <dependencies>
  <dependency><groupId>org.dromara</groupId><artifactId>aisports-platform-core</artifactId><version>${{revision}}</version></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
 </dependencies>
</project>
'''
        card=f'# {table.name}\n\n{table.description}\n\n域：{table.domain}。模块：{artifact}。状态：{metadata["lifecycle"]}。\n\n生成区为对象元数据与模块描述，业务代码放 src/main/java；已有跨表投影仅供完整入口动作私用。默认不开通用写入或Agent查询。\n'
        for path,text in [(root/'pom.xml',pom),(root/'MODULE.md',card),
                          (root/'src/main/java'/Path(*pkg.split('.'))/f'generated/{class_name}.java',java),
                          (root/f'src/main/resources/aisports/tables/{table.name}.json',metadata_text)]:
            outputs[safe(path)]=text.encode('utf-8')
        entries.append(dict(table=table.name,domain=table.domain,moduleId=artifact,path=directory,lifecycle=metadata['lifecycle']))
    domain_pom='''<!-- GENERATED aggregate. No executable business in this project. -->
<project xmlns="http://maven.apache.org/POM/4.0.0"><modelVersion>4.0.0</modelVersion>
 <parent><groupId>org.dromara</groupId><artifactId>ruoyi-vue-plus</artifactId><version>${revision}</version></parent>
 <artifactId>aisports-domains</artifactId><packaging>pom</packaging><modules>
'''+''.join(f'  <module>{m}</module>\n' for m in modules)+''' </modules></project>
'''
    outputs[BASE/'pom.xml']=domain_pom.encode()
    deps='\n'.join(f'        <dependency><groupId>org.dromara</groupId><artifactId>{e["moduleId"]}</artifactId><version>${{revision}}</version></dependency>' for e in entries)
    outputs[BASE/'admin-dependencies.xml']=deps.encode()
    outputs[safe(ROOT/'plus-ui/src/api/sports/generated/tableObjects.ts')]=''.join(types).encode('utf-8')
    manifest=dict(schemaVersion=1,modelSha256=sha((ROOT/'database/model/catalog.py').read_bytes()+(ROOT/'database/model/phase1.py').read_bytes()),tables=entries,
                  files={str(p.relative_to(ROOT)).replace('\\','/'):sha(v) for p,v in sorted(outputs.items())})
    outputs[MANIFEST]=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    return outputs

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--dry-run',action='store_true'); parser.add_argument('--check',action='store_true')
    args=parser.parse_args(); outputs=render()
    prior=json.loads(MANIFEST.read_text('utf-8')) if MANIFEST.exists() else {'files':{}}
    changes=[]
    for path,data in outputs.items():
        if path.exists() and path.read_bytes()==data: continue
        rel=str(path.relative_to(ROOT)).replace('\\','/')
        if path.exists() and path!=MANIFEST:
            expected=prior['files'].get(rel)
            if expected!=sha(path.read_bytes()): raise ValueError(f'Manual change in generated file: {rel}')
        changes.append((path,data))
    if not args.dry_run and not args.check:
        backup=ROOT/'.local/table-module-backups'/uuid.uuid4().hex
        for path,data in changes:
            if path.exists():
                previous=backup/path.relative_to(ROOT); safe(previous).parent.mkdir(parents=True,exist_ok=True); previous.write_bytes(path.read_bytes())
            path.parent.mkdir(parents=True,exist_ok=True)
            temp=path.with_name('.gen-'+uuid.uuid4().hex[:8]+'.tmp'); safe(temp).write_bytes(data); temp.replace(path)
    print(json.dumps({'tableModules':len(model.TABLES),'changedFiles':len(changes),'mode':'check' if args.check else 'dry-run' if args.dry_run else 'assembled'}))
    if args.check and changes: sys.exit(1)

if __name__=='__main__': main()
