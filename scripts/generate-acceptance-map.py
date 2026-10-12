"""Derive acceptance navigation from source while preserving explicit status records."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/99-raw_materials/保定体育综合服务平台_全域业务母版_V1.0.md'
target = ROOT / 'docs/04-verification'
target.mkdir(parents=True, exist_ok=True)
items = [(code, title, text.count('\n', 0, start)+1) for text in [SOURCE.read_text(encoding='utf-8')]
         for start, code, title in [(m.start(), m[1], m[2]) for m in re.finditer(r'^### (TC\d{2}) (.+)$', text, re.M)]]
assert [code for code, _, _ in items] == [f'TC{i:02}' for i in range(1, 81)]
status_path = target / 'acceptance-status.json'
statuses = json.loads(status_path.read_text(encoding='utf-8')) if status_path.exists() else {}
for code, title, line in items:
    statuses.setdefault(code, {'status': '待实现/待业务验收', 'evidence': '', 'owner': '待指定'})
status_path.write_text(json.dumps(statuses,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
rows = ['# 业务验收映射\n',
        '依据业务母版的 TC01—TC80。场景清单、表结构、框架登录和管理员演示不代表业务验收通过。当前全部业务场景待实现及实际验收；准备阶段工程证据单独保存在交接记录。\n',
        '更新 `acceptance-status.json` 的状态、证据与实际负责人，再运行本脚本；不覆盖已有状态。通过状态必须提供版本、规则、操作者、数据来源、结果和证据，普通角色完成业务路径。\n',
        '| 编号 | 母版场景 | 来源行 | 当前状态 | 证据 | 负责人 |',
        '| --- | --- | --- | --- | --- | --- |']
for code,title,line in items:
    s=statuses[code]
    rows.append(f'| {code} | {title} | {line} | {s["status"]} | {s["evidence"] or "待补"} | {s["owner"]} |')
rows.extend(['', '来源：[业务母版](../99-raw_materials/保定体育综合服务平台_全域业务母版_V1.0.md)。',
             '工程准备验证：[交接记录](../01-development/交接记录.md)。不得将合成数据、结构测试或未实际执行的验证记为真实业务完成。'])
(target/'验收映射.md').write_text('\n'.join(rows)+'\n',encoding='utf-8',newline='\n')
print('Acceptance map generated: 80 source scenarios, explicit status preserved.')
