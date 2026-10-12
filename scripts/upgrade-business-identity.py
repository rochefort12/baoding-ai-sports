from generate_table_helpers import ROOT
methods=('getUserId','getUserIdStr','getTenantId','getUserType','isSuperAdmin','isLogin')
count=0
for path in (ROOT/'backend/aisports-domains').rglob('*.java'):
 if '/src/main/' not in path.as_posix() or '/service/' not in path.as_posix() or '/org/dromara/sports/tables/' in path.as_posix():continue
 text=path.read_text('utf-8');updated=text
 for method in methods:updated=updated.replace('LoginHelper.'+method+'()', 'org.dromara.sports.platform.core.BusinessIdentity.'+method+'()')
 if updated!=text:path.write_text(updated,'utf-8');count+=1
print(f'Upgraded {count} business services to verified run-aware identity')
