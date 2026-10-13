"""Generate current PostgreSQL DDL, JSON catalog and Markdown dictionary.

Usage through PowerShell 7: python scripts/generate-model.py [--check].
Check compares generated text without mutating existing migrations/documents.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("aisports_model", ROOT / "database/model/catalog.py")
model = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = model
spec.loader.exec_module(model)
TABLES = model.TABLES
by_name = {t.name: t for t in TABLES}
# Explicit cross-tenant platform references: each action revalidates the referenced
# public event or owning organization. These do not grant tenant access.
PLATFORM_REFERENCES = {
    ('asp_team_room', 'unit_id'), ('asp_team_room', 'competition_type_id'),
    ('asp_team_room_member', 'unit_id'), ('asp_matching_request', 'unit_id'),
    ('asp_matching_offer', 'unit_id'), ('asp_governance_grant', 'organization_id'),
    ('asp_complaint_message', 'complaint_id'), ('asp_title_equipment', 'honor_id'),
}


def ident(value):
    if not re.fullmatch(r"[a-z][a-z0-9_]*", value) or len(value) > 63:
        raise ValueError(f"Invalid PostgreSQL identifier: {value}")
    return value


def quote(value):
    return "'" + value.replace("'", "''") + "'"


def short(prefix, table, fields):
    suffix = hashlib.sha256((table + fields).encode()).hexdigest()[:10]
    return ident(f"{prefix}_{table[:38]}_{suffix}")


def common(t):
    cols = [model.c("id", "bigint", "应用分配的稳定雪花 ID；不能随变更重建")]
    if t.tenant:
        cols.append(model.c("tenant_id", "varchar(20)", "业务管理租户，必填；不代表拥有全平台个人档案", check="length(tenant_id) > 0"))
    cols.extend(t.columns)
    cols.extend([
        model.c("create_dept", "bigint", "操作创建部门；上游审计字段", True),
        model.c("create_by", "bigint", "创建操作后台主体或服务主体；不是实际参赛人", True),
        model.c("create_time", "timestamptz", "记录创建时间；不同于实际发生时间", default="CURRENT_TIMESTAMP"),
        model.c("update_by", "bigint", "最近更新操作主体", True),
        model.c("update_time", "timestamptz", "最近更新记录时间；由服务维护", default="CURRENT_TIMESTAMP"),
        model.c("version", "integer", "乐观并发版本；不替代业务规则/名单版本", default="0", check="version >= 0"),
    ])
    return cols


def render():
    if len(by_name) != len(TABLES):
        raise ValueError("Duplicate table")
    sql = ["-- GENERATED from database/model/catalog.py. Do not hand edit.",
           "-- Current model, not the applied baseline. Ship structure changes as a new migration after review.",
           "-- PostgreSQL 17; bigint IDs supplied by application; NO cascading deletes.",
           "BEGIN;", "SET LOCAL TIME ZONE 'Asia/Shanghai';"]
    docs = ["# AISports 数据字典（生成）", "",
            "模型源：`database/model/catalog.py`。请运行 `scripts/generate-model.py` 同步；已应用迁移需要新版本。",
            "", f"共 {len(TABLES)} 张业务表，覆盖 D01—D13；框架 sys_*、gen_* 沿用上游 PostgreSQL 初始化。",
            "", "主键为应用分配的 bigint；金额为人民币元 numeric(18,2)；有时区时间按 Asia/Shanghai 展示。",
            "外键不等于授权，JSONB 必须按版本校验。数据库不能代替跨记录资金/容量事务、专业裁定或真实外部准入。", "",
            "## 表目录", "", "| 表 | 域 | 范围 | 业务责任 |", "| --- | --- | --- | --- |"]
    for t in TABLES:
        ident(t.name)
        docs.append(f"| {t.name} | {t.domain} | {'租户隔离' if t.tenant else '平台共享，必须应用授权'} | {t.description} |")
    all_fks = []
    for t in TABLES:
        cols = common(t)
        if len({c.name for c in cols}) != len(cols):
            raise ValueError(f"Duplicate column: {t.name}")
        fields = []
        for c in cols:
            ident(c.name)
            fields.append(f"    {c.name} {c.type}" + (" NOT NULL" if not c.nullable else "") +
                          (f" DEFAULT {c.default}" if c.default is not None else ""))
        fields.append("    PRIMARY KEY (id)")
        if t.tenant:
            fields.append("    UNIQUE (tenant_id, id)")
        for check in t.checks + [c.check for c in cols if c.check]:
            fields.append(f"    CHECK ({check})")
        sql.extend(["", f"-- {t.domain}: {t.description}", f"CREATE TABLE {t.name} (", ",\n".join(fields), ");",
                    f"COMMENT ON TABLE {t.name} IS {quote(t.description + '；来源：母版 ' + t.domain + '；' + t.responsibility)};"])
        docs.extend(["", f"## {t.name}", "", f"{t.description}。来源：母版 {t.domain}、第 17 章业务事实字典。", "",
                     f"范围：{'租户业务' if t.tenant else '平台共享，查询必须明确用途和授权'}。{t.responsibility}", "",
                     "| 字段 | 类型 | 可空 | 默认 | 关联 | 意义 |", "| --- | --- | --- | --- | --- | --- |"])
        for c in cols:
            sql.append(f"COMMENT ON COLUMN {t.name}.{c.name} IS {quote(c.description)};")
            docs.append(f"| {c.name} | {c.type} | {'是' if c.nullable else '否'} | {c.default or '—'} | {c.reference or '—'} | {c.description} |")
            if c.reference:
                target = by_name[c.reference]
                cross_scope = target.tenant and not t.tenant
                if cross_scope and (t.name, c.name) not in PLATFORM_REFERENCES:
                    raise ValueError(f"Shared record cannot silently FK tenant object: {t.name}.{c.name}")
                local = f"tenant_id, {c.name}" if target.tenant and not cross_scope else c.name
                remote = "tenant_id, id" if target.tenant and not cross_scope else "id"
                all_fks.append(f"ALTER TABLE {t.name} ADD CONSTRAINT {short('fk', t.name, c.name)} FOREIGN KEY ({local}) REFERENCES {target.name} ({remote});")
                sql.append(f"CREATE INDEX {short('ix', t.name, c.name)} ON {t.name} ({local});")
        for fields, predicate in t.unique:
            scoped_fields = ("tenant_id, " if t.tenant else "") + fields
            sql.append(f"CREATE UNIQUE INDEX {short('uq', t.name, fields + (predicate or ''))} ON {t.name} ({scoped_fields})" +
                       (f" WHERE {predicate}" if predicate else "") + ";")
            docs.extend(["", f"唯一：`{scoped_fields}`" + (f"，条件 `{predicate}`" if predicate else "") + "。"])
        checks = t.checks + [c.check for c in cols if c.check]
        if checks:
            docs.extend(["", "CHECK：" + "；".join(f"`{v}`" for v in checks) + "。"])
    sql.extend(["", "-- Add foreign keys after all tables exist, including forward references."] + all_fks + ["", "COMMIT;", ""])
    shared = [t.name for t in TABLES if not t.tenant]
    config = "# GENERATED: shared ASP tables only; merge with upstream exclusions.\ntenant:\n  excludes:\n" + "".join(f"    - {v}\n" for v in shared)
    return {
        ROOT / "database/schema/current.sql": "\n".join(sql),
        ROOT / "database/model/catalog.json": json.dumps(model.catalog(), ensure_ascii=False, indent=2) + "\n",
        ROOT / "docs/02-modeling/数据字典.md": "\n".join(docs) + "\n",
        ROOT / "database/model/shared-tables.yml": config,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bootstrap-migration", action="store_true", help="Create V001 once; never overwrite an existing migration")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    artifacts = render()
    if args.bootstrap_migration:
        if args.check:
            parser.error("--bootstrap-migration cannot be combined with --check")
        migration = ROOT / "database/migrations/V001__schema_baseline.sql"
        if migration.exists():
            raise SystemExit("V001 already exists; model generation never overwrites applied migrations")
        artifacts[migration] = artifacts[ROOT / "database/schema/current.sql"]
    failures = []
    for path, content in artifacts.items():
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                failures.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    if failures:
        raise SystemExit("Generated artifacts drifted: " + ", ".join(failures))
    print(f"Model {'checked' if args.check else 'generated'}: {len(TABLES)} tables, {sum(len(common(t)) for t in TABLES)} columns.")


if __name__ == "__main__":
    main()
