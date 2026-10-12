"""AISports relational model: executable documentation, not approved event rules.

All tables/columns carry purpose and provenance. generate-model.py derives PostgreSQL
DDL and the dictionary. Cross-row money/capacity invariants still need application
transactions; this catalog intentionally does not pretend CHECK can enforce them.
"""
from dataclasses import dataclass, field, asdict
import importlib.util as _importlib_util
import sys as _sys


@dataclass(frozen=True)
class Column:
    name: str
    type: str
    description: str
    nullable: bool = False
    default: str | None = None
    reference: str | None = None
    check: str | None = None


@dataclass(frozen=True)
class Table:
    name: str
    domain: str
    description: str
    columns: list[Column]
    tenant: bool = True
    checks: list[str] = field(default_factory=list)
    unique: list[tuple[str, str | None]] = field(default_factory=list)
    responsibility: str = "应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。"


TABLES: list[Table] = []


def c(name, typ, desc, nullable=False, default=None, reference=None, check=None):
    return Column(name, typ, desc, nullable, default, reference, check)


def ref(name, table, desc, nullable=False):
    return c(name, "bigint", desc, nullable, reference=table)


def txt(name, desc, nullable=False, size=100):
    return c(name, f"varchar({size})", desc, nullable)


def time(name, desc, nullable=False):
    return c(name, "timestamptz", desc + "；有时区业务时间", nullable)


def js(name, desc, nullable=False):
    return c(name, "jsonb", desc + "；必须按版本校验结构", nullable)


def state(name, values, desc="独立业务状态；合法值不等于业务已获批准"):
    allowed = ", ".join("'" + v + "'" for v in values.split())
    return c(name, "varchar(32)", desc + "：" + values, check=f"{name} IN ({allowed})")


def money(name, desc, nullable=False):
    return c(name, "numeric(18,2)", desc + "；人民币元，不能用浮点", nullable, check=f"{name} >= 0")


def num(name, desc, nullable=False):
    return c(name, "integer", desc, nullable, check=f"{name} >= 0")


def table(name, domain, desc, columns, tenant=True, checks=(), unique=(), responsibility=None):
    TABLES.append(Table("asp_" + name, domain, desc, columns, tenant, list(checks), list(unique),
                        responsibility or Table.__dataclass_fields__["responsibility"].default))


# D02: one login owns one participant archive. Participants do not create other participants.
table("account", "D02", "平台账号。一名自然人一份。参赛档案可选。登录号使用本表主键，不把后台用户当成平台身份", [
    txt("display_name", "登录账号展示名"),
    txt("password_hash", "登录密码散列。只供平台登录校验，不写入日志", True, 100),
    c("backend_user_id", "bigint", "遗留的后台 sys_user。当前注册仍写入，平台登录不使用它判断身份", True),
    ref("person_id", "asp_person", "本人参赛档案；空表示尚未建档", True),
    state("status", "active restricted recovery closing closed"), time("closed_at", "账号服务停止时间", True)
], False, unique=[("backend_user_id", "backend_user_id IS NOT NULL"), ("person_id", "person_id IS NOT NULL")])
table("login_identity", "D02", "账号渠道绑定和解绑历史；手机号回收不直接转移历史档案", [
    ref("account_id", "asp_account", "绑定平台账号"), txt("channel", "phone/wechat/其他登录渠道"),
    txt("subject_hash", "渠道标识带密钥摘要；不得明文公开", size=128), txt("subject_cipher", "需要恢复时的加密标识", True, 1000),
    time("valid_from", "绑定生效"), time("valid_until", "绑定结束", True), txt("verification_source", "核验依据及方式")
], False, checks=["valid_until IS NULL OR valid_until > valid_from"], unique=[("channel, subject_hash", "valid_until IS NULL")])
table("person", "D02", "一名独立参赛者的稳定档案；同名不合并，资料更正不改写报名快照。通用联系和体貌资料在本表，不进赛事属性目录", [
    txt("legal_name", "真实姓名；必填"), txt("display_name", "活动展示名；空则对外使用真实姓名", True),
    c("birth_date", "date", "出生日期；必填。年龄按赛事自己的基准日判断"),
    state("gender", "male female other", "分组用性别；必填"),
    txt("mobile", "联系手机；必填，公开页不展示。当前因手机号注册尚未回填而手填。后续只回显注册时验证过的手机号，不能改成其他号码", size=20),
    c("id_doc_type", "varchar(32)", "证件类型：id_card passport hmt_pass other；可空", True,
      check="id_doc_type IS NULL OR id_doc_type IN ('id_card', 'passport', 'hmt_pass', 'other')"),
    txt("identity_hash", "证件号码带密钥摘要；一个有效证件只对应一份档案。未填证件时为空", True, 128),
    txt("identity_cipher", "证件号码加密值；不作为公开编号。未填证件时为空", True, 1000),
    txt("city", "所在城市；通用资料，可空", True),
    txt("address_detail", "详细地址；通用资料，可空", True, 200),
    c("blood_type", "varchar(32)", "血型：A B AB O unknown；通用资料，可空，不公开", True,
      check="blood_type IS NULL OR blood_type IN ('A', 'B', 'AB', 'O', 'unknown')"),
    c("clothing_size", "varchar(32)", "衣服尺码：XS S M L XL XXL XXXL；通用资料，可空", True,
      check="clothing_size IS NULL OR clothing_size IN ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL')"),
    txt("emergency_contact_name", "紧急联系人；通用资料，可空", True),
    txt("emergency_contact_phone", "紧急联系号码；通用资料，可空，不公开", True, 20),
    state("verification_status", "unverified pending verified disputed"), state("status", "active restricted merged archived"),
    ref("merged_into_id", "asp_person", "经平台核对后的合并目标；参赛者不能自行合并", True)
], False, checks=[
    "merged_into_id IS NULL OR merged_into_id <> id",
    "mobile ~ '^1[3-9][0-9]{9}$'",
    "(id_doc_type IS NULL) = (identity_hash IS NULL)",
    "(identity_hash IS NULL) = (identity_cipher IS NULL)",
    "emergency_contact_phone IS NULL OR emergency_contact_phone ~ '^1[3-9][0-9]{9}$'"
], unique=[("identity_hash", "status = 'active' AND identity_hash IS NOT NULL")])
table("attribute_definition", "D02", "跨项目参赛属性目录；新项目增加目录项，不改参赛人表结构", [
    txt("code", "稳定编码；一经参赛使用不改含义"), txt("name", "展示名称"),
    state("value_type", "text number date enum", "取值类型"), txt("unit", "数值单位；文本和日期可空", True, 32),
    state("sensitivity", "ordinary identity health", "可见范围"),
    state("storage_scope", "profile entry", "profile 可复用到个人档案；entry 只在当次报名采集"),
    ref("sport_id", "asp_sport", "建议适用的运动；空表示任何运动都可选用", True),
    js("enum_options", "枚举可选项及版本；非枚举为空", True), state("status", "active disabled")
], False, unique=[("code", None)])
table("person_attribute", "D02", "参赛者已保存的可复用属性；只接受目录中 storage_scope 为 profile 的项", [
    ref("person_id", "asp_person", "本人档案"), ref("attribute_id", "asp_attribute_definition", "属性目录项"),
    js("value", "按值类型校验后的取值"), time("measured_at", "测量或声明时间；体重等会变化的属性使用", True)
], False, unique=[("person_id, attribute_id", None)], responsibility="应用拒绝把 storage_scope=entry 的属性写入个人档案；报名使用名单快照，不回写本表。")
table("consent", "D02", "本人对具体用途的告知确认；保存档案和以后的报名材料分别记录", [
    ref("person_id", "asp_person", "本人参赛人"), ref("actor_account_id", "asp_account", "作出确认的本人账号"),
    txt("purpose", "明确处理用途"), txt("document_version", "告知材料版本"), js("scope", "行为和资料范围"),
    time("accepted_at", "确认时间"), time("revoked_at", "撤回时间", True), txt("evidence_hash", "确认内容摘要", size=128)
], False)

# D01: a platform tenant is a management boundary, not the user's whole identity.
table("organization", "D01", "承办责任主体与租户映射。本期只在办赛申请通过后创建", [
    txt("name", "主体名称", size=200),
    txt("subject_type", "企业/学校/协会/俱乐部等。本期办赛申请不采集，可空", True),
    txt("subject_hash", "主体标识受控摘要。空摘要不互相占用", True, 128),
    state("status", "draft pending correction certified expired restricted"),
    txt("contact_cipher", "必要联系资料加密值", True, 1000), c("current_qualification_id", "bigint", "当前适用资质版本；服务核验归属", True)
], unique=[("subject_hash", "subject_hash IS NOT NULL")])
table("organization_application", "D01", "办赛申请。平台级数据，没有业务租户。审核只决定是否开放办赛，不表示主体已验真", [
    ref("applicant_account_id", "asp_account", "申请人。本期一人一份"),
    state("status", "draft pending approved rejected"),
    txt("name", "组织名称。草稿可空，提交必填", True, 200),
    txt("contact_name", "联系人。可以和登录用户不同。草稿可空，提交必填", True),
    txt("contact_cipher", "联系方式加密值。不要求是手机号，不发送短信", True, 1000),
    txt("statement", "申请说明", True, 1000),
    js("file_ids", "当前稿附件编号。结构为 fileIds 数组。更换附件不删除旧文件", True),
    c("organization_id", "bigint", "通过后写入的组织编号。组织属于租户，这里不建外键", True),
    txt("organization_tenant_id", "通过后的组织租户编号", True, 20),
], False, checks=[
    "organization_tenant_id IS NULL OR length(organization_tenant_id) > 0",
    "status <> 'approved' OR (organization_id IS NOT NULL AND organization_tenant_id IS NOT NULL)"
], unique=[("applicant_account_id", None)])
table("organization_application_version", "D01", "办赛申请每次提交时冻结的内容和附件。拒绝后的旧版不改", [
    ref("application_id", "asp_organization_application", "申请"),
    num("revision", "从 1 开始的提交版本"),
    txt("name", "该版组织名称", size=200),
    txt("contact_name", "该版联系人"),
    txt("contact_cipher", "该版联系方式加密值", size=1000),
    txt("statement", "该版申请说明", True, 1000),
    js("file_ids", "该版附件编号。结构为 fileIds 数组"),
    state("status", "pending approved rejected"),
    c("reviewer_id", "bigint", "审核人后台用户编号。只有超级管理员", True),
    txt("review_reason", "拒绝理由。通过时可空", True, 1000),
], False, checks=["revision > 0"], unique=[("application_id, revision", None)])
table("account_tenant_principal", "D01", "平台账号在一个租户里的若依用户映射。映射存在不等于可以进入组织", [
    ref("account_id", "asp_account", "平台账号"),
    txt("tenant_id", "组织租户编号。由服务写入和查询，不作为租户拦截条件", size=20),
    c("sys_user_id", "bigint", "该租户内的若依用户。不是平台自然人"),
    state("status", "active revoked"),
], False, checks=["length(tenant_id) > 0"], unique=[("account_id, tenant_id", None), ("sys_user_id", None)])
table("qualification", "D01", "组织资质申请及审核版本；失效不删除未完责任", [
    ref("organization_id", "asp_organization", "申请主体"), num("revision", "申请版本"), js("proof_snapshot", "审核时材料与经办授权"),
    js("business_scope", "可办业务范围"), state("status", "draft pending correction approved rejected expired restricted"),
    time("valid_from", "有效开始", True), time("valid_until", "有效截止", True), c("reviewer_id", "bigint", "平台审核人后台账号", True),
    txt("review_reason", "结论依据", True, 1000)
], checks=["revision > 0", "valid_until IS NULL OR valid_from IS NULL OR valid_until > valid_from"], unique=[("organization_id, revision", None)])
table("staff_grant", "D01", "工作人员组织、赛事、动作及材料范围授权", [
    ref("organization_id", "asp_organization", "授权组织"), ref("account_id", "asp_account", "工作人员平台账号"),
    c("event_id", "bigint", "限定赛事 ID；为空为组织范围，应用核验", True), js("permissions", "动作与材料范围"),
    state("status", "invited active revoked expired"), time("valid_from", "生效"), time("valid_until", "到期", True)
], checks=["valid_until IS NULL OR valid_until > valid_from"])
table("collaboration", "D01", "多方办赛展示与业务授权分离", [
    ref("event_id", "asp_event", "主责组织赛事"), ref("organization_id", "asp_organization", "授权发出组织；同租户"),
    txt("partner_tenant_id", "合作组织所在租户；跨租户访问需独立授权", size=20), c("partner_organization_id", "bigint", "合作主体 ID；跨租户 API 核验"),
    txt("display_role", "主办/承办/协办展示身份"), js("authorized_scope", "明确可见赛事、动作、材料"),
    time("valid_from", "合作生效"), time("valid_until", "合作终止", True)
], checks=["valid_until IS NULL OR valid_until > valid_from"])

# D03: permanent teams are shared platform objects, unlike event rosters.
table("sport", "D04", "开放运动目录与变体；收录不等于自动规则已验证", [
    txt("code", "稳定运动或变体编码"), txt("name", "名称"), txt("rule_family", "对抗/计时/评分/综合等规则族"),
    state("capability_status", "catalog registration manual automatic verified"), state("status", "active disabled")
], False, unique=[("code", None)])
table("team", "D03", "长期项目队伍。一期只有有效和解散，解散后不恢复，不归属组织", [
    txt("name", "当前队名。已提交报名使用自己的队名快照", size=200),
    ref("sport_id", "asp_sport", "项目。一期创建时写入羽毛球，之后不改"),
    ref("captain_person_id", "asp_person", "当前队长档案。解散后保留最后一任，有效队伍还必须有一条有效队长成员"),
    ref("creator_account_id", "asp_account", "创建人。不代表当前能否代表队伍报名"),
    state("join_policy", "open application invitation closed", "一期创建写 open。申请和邀请同时开放，服务不按这列分支"),
    state("visibility", "private members public", "一期创建写 members。不做队伍广场，服务不按这列分支"),
    state("status", "active disbanded"),
    txt("region", "活动区域。一期页面不维护", True), js("profile", "非敏感展示资料。一期页面不维护", True)
], False)
table("team_member", "D03", "队伍成员的一段关系。结束后不重新激活，再次加入另起一行", [
    ref("team_id", "asp_team", "长期队伍"), ref("person_id", "asp_person", "现实成员"),
    state("role", "captain member"), state("status", "active ended"),
    c("end_reason", "varchar(32)", "结束原因。有效成员必须为空：member_left captain_removed team_disbanded", True,
      check="end_reason IS NULL OR end_reason IN ('member_left', 'captain_removed', 'team_disbanded')"),
    txt("join_source", "create、application 或 invitation"), time("joined_at", "入队时间"), time("left_at", "离队时间", True)
], False, checks=[
    "left_at IS NULL OR left_at >= joined_at",
    "(status = 'active' AND left_at IS NULL AND end_reason IS NULL) OR (status = 'ended' AND left_at IS NOT NULL AND end_reason IS NOT NULL)"
], unique=[("team_id, person_id", "status = 'active'"), ("team_id", "status = 'active' AND role = 'captain'")])
table("team_join_request", "D03", "入队申请。待处理不是成员，失效不能记成申请人撤销或队长拒绝", [
    ref("team_id", "asp_team", "申请队伍"), ref("person_id", "asp_person", "申请者"),
    state("status", "pending approved rejected cancelled invalidated"),
    ref("reviewer_account_id", "asp_account", "处理人。申请人撤销和系统失效时为空", True), txt("reason", "处理依据", True, 500)
], False, unique=[("team_id, person_id", "status = 'pending'")])
table("team_invitation", "D03", "指定本人邀请、队长可转发分享授权及本人接受事实。分享不公开队内名单；离队后不重放旧授权", [
    ref("team_id", "asp_team", "邀请队伍"), ref("inviter_account_id", "asp_account", "邀请者"),
    ref("inviter_person_id", "asp_person", "分享授权时的队长稳定档案，转让或账号停止后失效；旧定向邀请为空", True),
    ref("target_person_id", "asp_person", "指定受邀人；share 分享授权为空，接受后另插指定本人事实", True),
    c("invitation_kind", "varchar(32)", "direct 定向邀请或分享接受事实；share 可转发队伍授权", default="'direct'", check="invitation_kind IN ('direct', 'share')"),
    c("invite_token", "varchar(64)", "256位随机业务链接凭据，仅当前队长回显；不进日志、通知或匿名预览，不授予成员资料权限", True, check="invite_token IS NULL OR invite_token ~ '^[a-f0-9]{64}$'"),
    time("expires_at", "分享授权七天到期；旧定向邀请不设到期", True),
    ref("share_invitation_id", "asp_team_invitation", "本人接受分享的来源；同来源同本人仅一次，结束成员后不复活", True),
    state("status", "pending accepted declined revoked invalidated")
], False, checks=[
    "(invitation_kind = 'direct' AND target_person_id IS NOT NULL AND invite_token IS NULL AND expires_at IS NULL) OR (invitation_kind = 'share' AND target_person_id IS NULL AND inviter_person_id IS NOT NULL AND invite_token IS NOT NULL AND expires_at IS NOT NULL AND share_invitation_id IS NULL AND status IN ('pending', 'revoked', 'invalidated'))",
    "share_invitation_id IS NULL OR (invitation_kind = 'direct' AND status = 'accepted' AND share_invitation_id <> id)"
], unique=[("team_id, target_person_id", "status = 'pending'"), ("invite_token", "invite_token IS NOT NULL"),
    ("team_id", "invitation_kind = 'share' AND status = 'pending'"), ("share_invitation_id, target_person_id", "share_invitation_id IS NOT NULL")])
table("team_history", "D03", "队伍改名、转让、解散的事实和快照。不代替成员终止行，也不回写已提交报名", [
    ref("team_id", "asp_team", "长期队伍"), txt("action", "变更动作"), js("before_snapshot", "原事实"), js("after_snapshot", "新事实"),
    txt("reason", "变更依据", size=1000), time("effective_at", "生效时间")
], False)
table("team_quota", "D03", "账户建队与入队配额。一期没有已批准数值，服务不读不写", [
    ref("account_id", "asp_account", "受配额账号"), num("create_limit", "有效自建队上限；非固定 3"), num("join_limit", "有效加入队上限；非固定 10"),
    txt("policy_version", "平台公开配额版本"), txt("exception_basis", "扩额批准依据", True, 500), time("valid_until", "豁免或规则到期", True)
], False, unique=[("account_id", None)])

# D04: rules and prices are versioned immutable inputs once referenced.
table("event", "D04", "赛事容器。M1.3 的发布和举办状态分开，时间阶段按北京时间计算，不改这一列的旧生命周期取值", [
    ref("organization_id", "asp_organization", "主责组织"),
    txt("name", "赛事名称。草稿可空，发布时必填", True, 200),
    c("series_id", "bigint", "系列/联赛业务关联；后续系列服务核验", True),
    time("starts_at", "开赛时间。发布时必填", True), time("ends_at", "结束时间。发布时必填", True),
    time("registration_opens_at", "报名开始。报名是否接受以报名流程为准，时间记在赛事上", True),
    time("registration_closes_at", "报名结束。报名是否接受以报名流程为准，时间记在赛事上", True),
    txt("location", "比赛地点。公开文字，不引用场馆", True, 200),
    txt("project_name", "赛事项目。公开文字，不建竞赛单元", True, 200),
    txt("fee_description", "收费方式或收费说明。公开文字，不产生付款", True, 1000),
    c("banner_file_id", "bigint", "宣传图文件编号。可空，不建外键", True),
    txt("rules_text", "竞赛规程文字。可与图片同时存在", True, 4000),
    c("rules_file_id", "bigint", "竞赛规程图片文件编号。可空，不建外键", True),
    txt("notice_text", "报名须知文字。可与图片同时存在", True, 4000),
    c("notice_file_id", "bigint", "报名须知图片文件编号。可空，不建外键", True),
    txt("declaration_text", "参赛声明文字。可与图片同时存在", True, 4000),
    c("declaration_file_id", "bigint", "参赛声明图片文件编号。可空，不建外键", True),
    c("declaration_ack_required", "boolean", "参赛声明是否必须由成员本人点击确认。不是证件核验，也不是电子签章", default="false"),
    txt("route_text", "比赛地点或路线说明。地图嵌入不在本期", True, 4000),
    c("route_file_id", "bigint", "比赛地点或路线图片文件编号。可空，不建外键", True),
    txt("cancel_reason", "取消原因。可空，有内容时出现在公开详情", True, 1000),
    c("sport_code", "varchar(32)", "运动编码。本期只能是 badminton", default="'badminton'", check="sport_code = 'badminton'"),
    c("publication_status", "varchar(32)", "发布状态：draft published offline。已发布不能直接改公开信息", default="'draft'",
      check="publication_status IN ('draft', 'published', 'offline')"),
    c("holding_status", "varchar(32)", "举办状态：normal cancelled。取消不等于下架，已结束不能取消", default="'normal'",
      check="holding_status IN ('normal', 'cancelled')"),
    c("registration_review", "varchar(16)", "报名资格审核：manual 人工审核，none 无需审核。与赛事发布审批无关", default="'manual'",
      check="registration_review IN ('manual', 'none')"),
    c("registration_review_locked", "boolean", "首笔正式提交后锁定审核方式。全部撤回也不解锁", default="false"),
    state("status", "draft pending published postponed cancelled completed archived", "后继生命周期。M1.3 不拿它判断公开"),
    state("registration_status", "closed scheduled open suspended ended"), state("payment_status", "disabled enabled suspended"),
    state("visibility", "private public", "旧可见性列。M1.3 公开与否不看它"),
    num("published_revision", "当前发布版本；0 为未发布"), js("contact_snapshot", "履约联系及退改承诺；state=draft为材料候选，明确发布确认后连同组织、联系渠道、退改原文和confirmedAt冻结；历史未标state快照保留原发布含义"),
    c("operations_materials", "jsonb", "主办方私有策划、脚本、公告和宣传草稿。每类独立版本、真实来源及最多10个历史版本；不自动发布", default="'{}'::jsonb", check="jsonb_typeof(operations_materials) = 'object'")
], checks=[
    "ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at",
    "registration_closes_at IS NULL OR registration_opens_at IS NULL OR registration_closes_at > registration_opens_at",
    "registration_closes_at IS NULL OR starts_at IS NULL OR registration_closes_at <= starts_at"
])
table("event_command", "D04", "赛事写操作幂等。同一租户、同一动作、同一请求键只生效一次，重复提交不再次发布", [
    ref("event_id", "asp_event", "已经处理过的赛事"),
    txt("action", "动作。本期只有 publish", size=32),
    txt("request_key", "客户端幂等键", size=128),
], unique=[("action, request_key", None)])
table("declaration_ack", "D05", "成员本人对当时参赛声明的点击确认。队长不能代确认，确认不是电子签章", [
    ref("registration_member_id", "asp_registration_member", "确认的报名成员"),
    ref("account_id", "asp_account", "点击确认的平台账号，必须是该成员本人"),
    ref("event_id", "asp_event", "声明所属赛事"),
    txt("content_digest", "确认时声明文字和文件的摘要。声明变化后需重新确认", size=64),
    time("acknowledged_at", "本人点击确认的时间")
], unique=[("registration_member_id", None)])
table("event_revision", "D04", "赛事对外承诺版本和重大变更说明", [
    ref("event_id", "asp_event", "赛事"), num("revision", "发布版本"), js("snapshot", "结构、规程、责任、资源与费用公开快照"),
    txt("reason", "变更依据", size=1000), time("published_at", "发布生效", True)
], checks=["revision > 0"], unique=[("event_id, revision", None)])
table("competition_unit", "D04", "报名坐标。M1.4 按整单占用名额，报名窗口仍在赛事上", [
    ref("event_id", "asp_event", "赛事"), ref("sport_id", "asp_sport", "运动及变体"), txt("name", "项目组别名称", size=200),
    state("entry_type", "individual pair team"), num("min_members", "最低成员人数"), num("max_members", "最高名单人数"),
    c("birth_from", "date", "允许出生日期下界，含边界", True), c("birth_until", "date", "允许出生日期上界，含边界", True),
    c("age_reference_date", "date", "年龄规程基准日", True), state("status", "draft open suspended closed cancelled"),
    c("current_rule_id", "bigint", "当前确认规则版本；应用核对单元归属", True), c("current_fee_policy_id", "bigint", "当前费用版本；应用核对归属", True)
], checks=["min_members > 0", "max_members >= min_members", "birth_until IS NULL OR birth_from IS NULL OR birth_until >= birth_from"], unique=[("event_id, lower(btrim(name))", "status = 'open'")], responsibility="同赛事有效项目名称去首尾空白并忽略大小写唯一；无正式提交可关闭删除，有历史只做名称一般更正。")
table("rule_version", "D04", "资格、赛制、晋级和排名规则版本与专业来源", [
    ref("unit_id", "asp_competition_unit", "适用竞赛单元"), num("revision", "规则版本"), txt("source", "专业/地方/特别规程来源", size=1000),
    js("parameters", "结构化规则；不得猜测缺项"), state("status", "draft confirmed retired"),
    state("verification_level", "unverified samples_verified professional_verified"), c("confirmed_by", "bigint", "有权确认人", True), time("confirmed_at", "确认时间", True)
], checks=["revision > 0"], unique=[("unit_id, revision", None)])
table("attribute_requirement", "D04", "某版规则要求报名时采集的属性；社区活动可以一条都不选", [
    ref("rule_version_id", "asp_rule_version", "规则版本"), ref("attribute_id", "asp_attribute_definition", "要采集的属性"),
    c("required", "boolean", "true 为该版本报名必填")
], unique=[("rule_version_id, attribute_id", None)], responsibility="新项目通过增选目录属性扩展报名表；不为此修改 asp_person。提交时抄入名单快照。")
table("org_field", "D04", "组织自有的参赛采集字段。未选用可停用；选用后不改类型和选项含义", [
    ref("organization_id", "asp_organization", "维护这个目录的组织"),
    txt("code", "组织内稳定编码", size=64), txt("label", "显示名称", size=100),
    state("value_type", "text number date enum"),
    js("options", "单选枚举的选项。其他类型为空数组"),
    state("status", "active stopped")
], unique=[("organization_id, code", None)])
table("event_field", "D04", "一场赛事选用的组织字段。一期全赛事同一套，首笔正式提交后不再改", [
    ref("event_id", "asp_event", "赛事"), ref("org_field_id", "asp_org_field", "组织字段"),
    c("required", "boolean", "true 为本人必须填写", default="false"),
    num("sort_order", "显示顺序"), txt("note", "给参赛者的说明", True, 500)
], unique=[("event_id, org_field_id", None)])
table("entry_field_value", "D05", "报名成员对赛事字段的填写。提交时保留当时的名称、类型和选项", [
    ref("registration_member_id", "asp_registration_member", "填写人"),
    ref("event_field_id", "asp_event_field", "当时选用的字段"),
    txt("value_text", "填写值", size=1000),
    txt("label_snapshot", "提交时的字段名称", size=100),
    txt("type_snapshot", "提交时的类型", size=16),
    js("options_snapshot", "提交时的枚举选项")
], unique=[("registration_member_id, event_field_id", None)])
table("material_requirement", "D04", "赛事文件材料、用途与各阶段前置；体检、保险和责任书走这里", [
    ref("rule_version_id", "asp_rule_version", "规则版本"), txt("code", "材料编码"), txt("purpose", "资料使用用途", size=500),
    state("sensitivity", "ordinary identity health finance"), js("gates", "占位/审核/检录/公开分别的前置及确认"),
    num("retention_days", "保留期限；0 须按政策明确解释", True)
], unique=[("rule_version_id, code", None)])
table("event_payment_config", "D06", "赛事统一收款指引，承办方资金授权维护；首次正式提交后锁定。金额仍按项目，指引不是到账", [
    ref("event_id", "asp_event", "所属赛事；同租户唯一，应用校验组织归属"),
    js("settings", "v1含channels及instruction；wechat/alipay/custom_qr引用payment-qr文件，bank含受保护账户，offline含办理指引。不得公开或发送模型")
], checks=["jsonb_typeof(settings) = 'object' AND settings ? 'schemaVersion' AND settings->>'schemaVersion' = '1' AND settings ? 'channels' AND jsonb_typeof(settings->'channels') = 'array'"],
    unique=[("event_id", None)], responsibility="资金授权、文件用途及租户校验、渠道结构及必填、与首笔正式提交串行；提交时指引及二维码文件编号复制到义务快照，旧版收费仍按原版本读取。")
table("fee_policy", "D06", "竞赛单元的收费版本。已生效的不改价，改价另起一版", [
    ref("unit_id", "asp_competition_unit", "适用单元"), num("revision", "费用版本"),
    state("pricing_unit", "free person pair team project combination entry", "一期生效版本使用 entry，表示整单固定价"),
    c("amount", "numeric(18,2)", "整单固定金额。免费为 0。草稿可空", True, check="amount IS NULL OR amount >= 0"),
    c("payment_mode", "varchar(32)", "free免费；event赛事统一渠道；offline/organizer_qr保留旧收费及历史付款依据。草稿可空", True,
      check="payment_mode IS NULL OR payment_mode IN ('free', 'offline', 'organizer_qr', 'event')"),
    txt("pay_instruction", "线下说明或收款二维码说明", True, 1000),
    c("qr_file_id", "bigint", "承办方收款二维码文件编号。可空，不建外键", True),
    js("pricing_rules", "旧的计价结构。一期金额以 amount 为准"), js("payer_modes", "旧的承担方式。一期不使用"),
    js("collection_paths", "旧的收款路径。一期收款主体固定为承办方"), js("refund_terms", "旧的退款条款。一期不自动退款"),
    state("status", "draft active retired")
], checks=["revision > 0",
    "status <> 'active' OR (amount IS NOT NULL AND payment_mode IS NOT NULL AND ((payment_mode = 'free' AND amount = 0) OR (payment_mode <> 'free' AND amount > 0)))"],
    unique=[("unit_id, revision", None), ("unit_id", "status = 'active'")])

# D05: entries, roster revisions, capacity and approval are separate facts.
table("registration_batch", "D05", "一次提交的报名批次；不等于一笔订单，也不能借此创建他人账号", [
    ref("submitter_account_id", "asp_account", "提交人"), txt("request_key", "请求幂等键", size=128),
    state("status", "processing completed partial failed"), num("total_count", "提交条目数"), num("success_count", "成功条目数")
], checks=["success_count <= total_count"], unique=[("submitter_account_id, request_key", None)])
table("registration", "D05", "竞赛单元报名。草稿不占名额；已提交和已通过占名额；撤回回到草稿", [
    ref("unit_id", "asp_competition_unit", "报名单元"), ref("rule_version_id", "asp_rule_version", "提交时规则。本期可空，不临时造规则版本", True), ref("fee_policy_id", "asp_fee_policy", "费用依据", True),
    ref("batch_id", "asp_registration_batch", "操作批次", True), ref("team_id", "asp_team", "可选长期代表队。空表示个人或临时双打", True),
    ref("submitter_account_id", "asp_account", "原提交人"), ref("operator_account_id", "asp_account", "当前办理人"),
    txt("request_key", "当前办理请求键。尚未完成提交时沿用创建键；完成后的重放不再占用，主动重提更换新键", size=128), state("status", "draft submitted approved rejected"),
    time("hold_expires_at", "旧的临时占位期限。本期不使用", True), num("roster_revision", "当前名单版本。草稿为 0"),
    txt("team_name_snapshot", "提交成功时的队名。之后队伍改名不回写", True, 200), time("submitted_at", "实际提交时间。草稿可空", True)
], unique=[("submitter_account_id, request_key", None), ("unit_id, submitter_account_id", None)], responsibility="同一提交人在同一单元只有一条报名。代表队伍的报名按 team_id 识别当前可办理的那一条，不另加一队一单元的唯一约束。已经完成提交的请求键只重放该次事实，不第二次占名额，撤回后也不复活报名。名额排队使用通用锁，used_count 只做上限。")
table("registration_submit_key", "D05", "已经完成的报名提交请求键。撤回或拒绝后重放旧键不得再次占用", [
    ref("registration_id", "asp_registration", "报名"),
    ref("submitter_account_id", "asp_account", "提交人"),
    txt("request_key", "已经完成一次提交的请求键", size=128),
    num("roster_revision", "这次提交冻结的名单版本")
], checks=["roster_revision > 0"], unique=[
    ("submitter_account_id, request_key", None),
    ("registration_id, roster_revision", None)
], responsibility="同一提交人的一个请求键只完成一次提交。主动重提使用新键并另记一行，对应这次的名单版本和独立付款义务。未完成提交的创建键不记入本表。")
table("registration_member", "D05", "报名成员确认。按平台账号记录，提交成功后才抄入名单快照", [
    ref("registration_id", "asp_registration", "报名"),
    ref("unit_id", "asp_competition_unit", "竞赛单元。冗余，用于同一人同一单元只有一条有效报名"),
    ref("account_id", "asp_account", "成员平台账号"),
    ref("person_id", "asp_person", "确认时的本人档案。待确认时可空", True),
    state("status", "pending_confirmation confirmed declined"),
    c("self_member", "boolean", "true 表示报名提交人本人", default="false"),
    txt("invite_token", "邀请确认令牌。本人成员为空", True, 64),
    js("person_snapshot", "确认时抄下的档案。提交名单时使用，之后改档案不回写", True),
    c("occupying", "boolean", "true 表示这条成员正在占用该单元的有效报名", default="false"),
], checks=["occupying = false OR status = 'confirmed'"], unique=[
    ("registration_id, account_id", None),
    ("unit_id, account_id", "occupying = true"),
    ("invite_token", "invite_token IS NOT NULL"),
], responsibility="邀请确认不是长期队伍邀请。已提交或已通过的成员才把 occupying 设为 true。")
table("roster_version", "D05", "赛事报名名单版本；替补和冻结依据", [
    ref("registration_id", "asp_registration", "报名"), num("revision", "名单版本"), ref("rule_version_id", "asp_rule_version", "核验规则。本期报名可空", True),
    state("status", "draft effective frozen superseded"), time("effective_at", "名单生效", True), txt("change_reason", "换人/补员/冻结依据", size=1000)
], checks=["revision > 0"], unique=[("registration_id, revision", None)])
table("roster_member", "D05", "名单内实际参赛人及资格快照", [
    ref("roster_version_id", "asp_roster_version", "名单版本"), ref("person_id", "asp_person", "现实选手"), state("role", "starter substitute leader"),
    js("person_snapshot", "报名当时的身份列和本场选中属性；之后修改档案不回写"), state("qualification_status", "pending supplement approved rejected restricted"),
    num("position", "顺序或位置；0 是否适用由规则解释", True)
], unique=[("roster_version_id, person_id", None)])
table("qualification_review", "D05", "逐成员/整单审核记录；材料与到账不互相替代", [
    ref("registration_id", "asp_registration", "报名"), ref("roster_member_id", "asp_roster_member", "审核成员；整单可为空", True),
    state("decision", "supplement approved rejected"), js("basis", "所见名单/材料/费用及规则版本"),
    c("reviewer_id", "bigint", "审核后台账号。无需审核的自动通过为空，不伪造人工审核人", True), time("reviewed_at", "确认时间"), txt("reason", "具体结论依据", size=1000)
])
table("capacity_pool", "D05", "总人数或项目容量；单位和去重范围显式", [
    ref("event_id", "asp_event", "赛事"), ref("unit_id", "asp_competition_unit", "项目容量；总量可为空", True),
    state("capacity_unit", "person pair team seat lane entry"), txt("dedupe_scope", "计数去重范围。M1.4 按 entry 整单计数"), num("limit_count", "上限"),
    num("used_count", "当前有效及临时占用数；同事务维护"), state("status", "active suspended closed")
], checks=["used_count <= limit_count"], unique=[("unit_id", "unit_id IS NOT NULL AND capacity_unit = 'entry'")])
table("capacity_occupation", "D05", "容量唯一占用对象；同人兼项总人数只占一次", [
    ref("pool_id", "asp_capacity_pool", "容量池"), txt("subject_key", "person:<ID> 或 entry:<ID> 等稳定单位键", size=128),
    ref("person_id", "asp_person", "按人占用时对应身份", True), state("status", "held effective released"),
    time("expires_at", "仅临时占用期限", True)
], unique=[("pool_id, subject_key", "status IN ('held','effective')")])
table("occupation_reference", "D05", "报名到容量占用的引用；取消最后引用才释放去重人数", [
    ref("occupation_id", "asp_capacity_occupation", "共享占用"), ref("registration_id", "asp_registration", "使用占用的报名"),
    state("status", "active released"), time("released_at", "解除引用", True)
], unique=[("occupation_id, registration_id", "status = 'active'")])
table("waitlist", "D05", "候补排序、获邀确认及期限", [
    ref("registration_id", "asp_registration", "候补申请"), ref("pool_id", "asp_capacity_pool", "容量池"),
    num("rank", "公布规则下候补排序"), txt("basis", "排序依据", size=500), state("status", "waiting invited confirmed expired withdrawn"),
    time("confirm_until", "递补确认期限", True)
], unique=[("registration_id, pool_id", "status IN ('waiting','invited')")])
table("withdrawal", "D05", "退赛申请、资格终止及退款义务接续", [
    ref("registration_id", "asp_registration", "报名"), ref("person_id", "asp_person", "允许局部退赛时对应成员", True),
    ref("applicant_account_id", "asp_account", "申请者"), state("status", "requested approved rejected completed"),
    txt("reason", "请求及批准依据", size=1000), js("impact", "资格、名单、名额、时间和资金影响"), time("effective_at", "退赛生效", True)
])

# D06: payment obligations and actual money cannot collapse into a paid flag.
table("fee_obligation", "D06", "一次正式提交产生的付款义务。免费也记一笔，但不产生付款", [
    ref("registration_id", "asp_registration", "报名"), ref("fee_policy_id", "asp_fee_policy", "提交时的收费版本"),
    money("total_amount", "当时解析出的整单金额。免费为 0"), txt("currency", "币种。一期固定 CNY", size=3),
    state("status", "not_required open settled void"), js("quote_snapshot", "当次提交的整单金额、方式和说明；新快照rosterRevision记录当次实际冻结名单版本，历史缺值不回填或按顺序推定，展示原创建时间；统一收款含paymentSettings渠道及二维码文件编号快照，账户仅授权付款用途可见，不随配置改变"),
    txt("request_key", "义务幂等键。不复用报名请求键", size=128),
    time("declared_at", "参赛者点击模拟付款完成的时间。不是到账确认", True)
], unique=[("registration_id, request_key", None), ("registration_id", "status IN ('not_required', 'open')")])
table("registration_payment_proof", "D06", "报名管理人自愿上传的私有付款图片。只关联一次提交的义务，不代表到账，撤回重提不沿用", [
    ref("registration_id", "asp_registration", "凭证所属报名"),
    ref("obligation_id", "asp_fee_obligation", "本次提交的付款义务"),
    ref("uploaded_by_account_id", "asp_account", "本人或当前队长的上传账号"),
    ref("file_id", "asp_file", "私有 payment-proof 图片，金融敏感材料，不公开 URL"),
    txt("request_key", "上传幂等键，同键不能更换内容", size=128),
    c("content_digest", "varchar(64)", "图片 SHA-256，用于重复请求核验", check="length(content_digest) = 64"),
    time("uploaded_at", "上传完成时间，不是到账时间")
], unique=[("obligation_id, uploaded_by_account_id, request_key", None), ("file_id", None)])
table("fee_item", "D06", "应收服务、选手及项目明细", [
    ref("obligation_id", "asp_fee_obligation", "义务"), ref("person_id", "asp_person", "按人计价对应选手", True),
    txt("service_code", "收费项目"), c("quantity", "numeric(12,4)", "数量与计价单位", check="quantity > 0"),
    txt("unit", "计价单位"), money("unit_price", "单价"), money("discount_amount", "优惠"), money("amount", "最终明细金额"), js("basis", "计价顺序与优惠依据")
])
table("fee_share", "D06", "经确认的承担者及代付范围", [
    ref("obligation_id", "asp_fee_obligation", "费用义务"), ref("account_id", "asp_account", "承担账号"), ref("person_id", "asp_person", "对应选手", True),
    money("amount", "承担金额"), state("status", "pending accepted cancelled"), time("accepted_at", "分担确认", True)
])
table("payment", "D06", "已经确认的到账事实。未付款时不插入。冲正不是退款", [
    ref("payer_account_id", "asp_account", "付款人平台账号。不是平台账号时为空", True),
    txt("payer_name", "实际付款人名称。外部付款人用它", True, 200),
    state("payer_presence", "known external unavailable"),
    state("payment_mode", "free offline organizer_qr event", "付款义务的收费路径，不表示实际渠道到账") ,
    state("confirmation_source", "manual callback"),
    txt("payee_subject", "一期固定 organizer", size=200),
    txt("transaction_id", "外部付款单号。人工确认可空", True, 200), money("amount", "实际金额"), txt("currency", "币种。一期固定 CNY", size=3),
    state("status", "confirmed reversed"), js("evidence", "确认依据。不保存支付密钥"),
    time("occurred_at", "实际发生", True), time("confirmed_at", "确认时间", True), txt("request_key", "确认幂等键", size=128)
], unique=[("request_key", None), ("payee_subject, transaction_id", "transaction_id IS NOT NULL")])
table("payment_allocation", "D06", "付款到义务与分担的映射；支持多笔实收，超额需资金收尾，不新增资格", [
    ref("payment_id", "asp_payment", "实际付款"), ref("obligation_id", "asp_fee_obligation", "覆盖义务"), ref("share_id", "asp_fee_share", "对应分担", True),
    money("amount", "有效分配金额"), state("status", "effective reversed"), txt("request_key", "分配幂等键", size=128)
], checks=["amount > 0"], unique=[("payment_id, request_key", None)], responsibility="事务锁定付款和义务，累计有效分配不能超过确认收款；实际超额保留原款并人工收尾，分担须属于义务。")
table("payment_exception", "D06", "金额不符或第二笔真实付款。不自动结清义务", [
    ref("payment_id", "asp_payment", "已有付款。金额不符时为空", True),
    ref("obligation_id", "asp_fee_obligation", "相关义务", True),
    txt("exception_type", "amount_mismatch 或 duplicate_payment"),
    txt("external_reference", "外部单号", True, 200),
    c("reported_amount", "numeric(18,2)", "申报金额", True, check="reported_amount IS NULL OR reported_amount >= 0"),
    state("status", "open investigating resolved disputed"),
    c("owner_id", "bigint", "实际处理责任人", True), js("resolution", "核对和处置证据", True)
], checks=["payment_id IS NOT NULL OR obligation_id IS NOT NULL"])
table("payment_action", "D06", "已付款报名失效后的资金后续。平台不发起退款", [
    ref("payment_id", "asp_payment", "已确认的付款"), ref("obligation_id", "asp_fee_obligation", "当时的义务"),
    state("status", "pending closed_no_refund refunded"), txt("note", "承办方说明", True, 1000)
], unique=[("payment_id", "status = 'pending'")])
table("refund", "D06", "已经发生的退款事实。不是平台发起的退款申请", [
    ref("payment_id", "asp_payment", "原实际付款"), ref("allocation_id", "asp_payment_allocation", "被退服务分配", True),
    ref("withdrawal_id", "asp_withdrawal", "相关退赛", True), ref("applicant_account_id", "asp_account", "申请者。一期可空", True),
    money("requested_amount", "申请金额"), money("approved_amount", "批准金额", True), money("completed_amount", "已核实退款金额", True),
    state("status", "requested approved rejected executing completed failed"), txt("channel_reference", "渠道退款唯一号", True, 200),
    txt("reason", "规则和退款责任依据", size=1000), txt("request_key", "幂等键", size=128), time("completed_at", "实际退款发生时间；北京时间输入，存时区时间", True), txt("recipient_name", "实际退款接收人；旧记录未采集可空", True, 200), txt("recipient_basis", "接收人变更的核验授权依据；用途受控", True, 1000)
], checks=["approved_amount IS NULL OR approved_amount <= requested_amount", "completed_amount IS NULL OR (approved_amount IS NOT NULL AND completed_amount <= approved_amount)"],
    unique=[("payment_id, request_key", None)], responsibility="累计退款在锁定原确认付款后核对可退余额，原付款人不随队长变更；执行失败保留待办。")
table("service_fee", "D06", "平台服务收入依据；不能将报名流水认作平台收入", [
    ref("event_id", "asp_event", "赛事"), txt("contract_reference", "真实服务及合同依据", size=200), js("calculation_basis", "固定额/基数/费率/税及退费政策"),
    money("amount", "确认服务费"), state("status", "calculated confirmed reversed"), time("confirmed_at", "收入核对", True)
])
table("settlement", "D06", "收款方或支付机构结算证据；记账不证明已结算", [
    ref("event_id", "asp_event", "赛事"), txt("subject", "结算主体", size=200), money("due_amount", "应结算"), money("settled_amount", "已核实结算"),
    state("status", "pending partial completed failed disputed"), js("evidence", "真实结算依据"), txt("reference", "结算唯一号", size=200)
], checks=["settled_amount <= due_amount"], unique=[("subject, reference", None)])

# D12/D07: actual resources and uncertain paths, with no private-calendar promises.
table("venue", "D12", "场馆及实际管理责任", [
    txt("name", "场馆名", size=200), txt("address", "地址", size=500), txt("operator", "实际责任主体", size=200),
    txt("contact_cipher", "受控联络", True, 1000), state("status", "active maintenance disabled")
])
table("resource", "D12", "可分配资源单元及容量；整体和半场不能重复占用", [
    ref("venue_id", "asp_venue", "场馆"), ref("parent_id", "asp_resource", "整体/拆分父资源", True), txt("name", "场地或泳道等名称", size=200),
    txt("resource_type", "court/table/lane/track/judge_group 等"), num("capacity", "可同时使用容量"),
    txt("capacity_unit", "容量单位"), state("status", "available unconfirmed maintenance disabled"), js("sport_scope", "运动适配及必要限制")
], checks=["capacity > 0", "parent_id IS NULL OR parent_id <> id"])
table("resource_reservation", "D12", "赛事资源使用确认；不冒充商业预约交易", [
    ref("resource_id", "asp_resource", "具体资源"), ref("event_id", "asp_event", "赛事"), time("starts_at", "使用开始"), time("ends_at", "使用结束"),
    num("quantity", "占用容量"), state("status", "requested confirmed cancelled"), js("confirmation", "场地方和赛事方确认依据")
], checks=["ends_at > starts_at", "quantity > 0"])
table("time_constraint", "D07", "受控跨赛事时间事实；与名额生命周期关联但独立", [
    ref("person_id", "asp_person", "实际相关人员", True), c("resource_id", "bigint", "资源 ID；source_tenant_id 标识资源所属方", True),
    txt("source_tenant_id", "来源租户；只返回受限冲突结果", size=20), txt("source_type", "报名/阶段/场次/裁判任务"), c("source_id", "bigint", "来源业务 ID"),
    ref("parent_id", "asp_time_constraint", "父子安排，避免自冲突", True), time("starts_at", "约束开始"), time("ends_at", "约束结束"),
    state("certainty", "tentative conditional confirmed"), state("strength", "soft hard"), state("status", "held active released cancelled"),
    num("buffer_before_seconds", "确认的准备或转场缓冲"), num("buffer_after_seconds", "确认的恢复缓冲"),
    time("expires_at", "临时约束期限", True), js("basis", "来源版本、晋级路径与排他条件")
], False, checks=["ends_at > starts_at", "(person_id IS NOT NULL) <> (resource_id IS NOT NULL)", "parent_id IS NULL OR parent_id <> id"])
table("conflict_case", "D07", "冲突发现与协调证据；通知已读不等于解决", [
    txt("trigger_type", "提交/换人/改期/编排等"), c("trigger_id", "bigint", "触发业务 ID"), js("affected_refs", "受影响来源及授权摘要"),
    state("severity", "soft hard"), state("status", "open coordinating resolved rejected"), js("resolution", "选择方案与授权依据", True)
])

# D08-D10: tournament topology, raw results and published honors.
table("stage", "D08", "竞赛阶段及已确认赛制关系", [
    ref("unit_id", "asp_competition_unit", "竞赛单元"), ref("rule_version_id", "asp_rule_version", "适用规则。手工场次的内部阶段可空，不制造虚假规则", True), txt("name", "阶段名称"),
    txt("format", "淘汰/循环/分组/计时/评分等确认格式"), num("sequence", "阶段顺序"), state("status", "draft ready published running completed cancelled")
], unique=[("unit_id, sequence", None)])
table("draw_run", "D08", "抽签运行与可复核输入；不反复随机选择有利结果", [
    ref("stage_id", "asp_stage", "阶段"), ref("rule_version_id", "asp_rule_version", "规则版本"), num("revision", "抽签版本"),
    js("input_snapshot", "有效名单版本、种子、轮空与回避依据"), txt("random_seed", "复核随机来源及种子", size=200),
    js("output_snapshot", "签位及约束检查"), state("status", "draft confirmed superseded failed"), txt("reason", "运行或重抽依据", size=1000)
], unique=[("stage_id, revision", None)])
table("schedule_run", "D08", "约束编排草案、不可行原因及发布版本", [
    ref("stage_id", "asp_stage", "阶段"), ref("draw_run_id", "asp_draw_run", "抽签依据", True), num("revision", "排程版本"),
    js("input_snapshot", "规则、人员、资源、窗口、时长和缓冲"), js("diagnostics", "已排/未排/冲突及取舍"),
    state("status", "draft feasible infeasible published superseded"), time("published_at", "生效发布", True)
], unique=[("stage_id, revision", None)])
table("match", "D09", "稳定比赛身份；时间变更不改场次身份", [
    ref("stage_id", "asp_stage", "阶段"), ref("schedule_run_id", "asp_schedule_run", "当前排程版本", True), txt("code", "阶段内稳定比赛编号"),
    num("round_number", "轮次"), ref("resource_id", "asp_resource", "安排资源", True), time("scheduled_start", "预计开始", True), time("scheduled_end", "预计结束", True),
    time("actual_start", "实际开始", True), time("actual_end", "实际结束", True), state("status", "draft published checkin running completed abandoned cancelled")
], checks=["scheduled_end IS NULL OR scheduled_start IS NULL OR scheduled_end > scheduled_start", "actual_end IS NULL OR actual_start IS NULL OR actual_end >= actual_start"], unique=[("stage_id, code", None)])
table("match_entry", "D09", "对阵或计时评分参赛集合；未来晋级席位可待定", [
    ref("match_id", "asp_match", "场次"), ref("registration_id", "asp_registration", "参赛报名；尚未晋级可为空", True),
    ref("roster_version_id", "asp_roster_version", "本场名单依据", True), txt("slot", "对阵位置/道次/试次等"),
    js("qualification_source", "已确认报名或条件晋级路径"), state("status", "pending confirmed withdrawn disqualified")
], unique=[("match_id, slot", None)])
table("lineup_member", "D09", "单场阵容及实际出场；不能从当前队伍直接拉人上场", [
    ref("match_entry_id", "asp_match_entry", "场次参赛单位"), ref("roster_member_id", "asp_roster_member", "冻结赛事名单成员"),
    state("role", "starter substitute"), num("position", "规程要求顺序", True), state("status", "planned confirmed replaced appeared")
], unique=[("match_entry_id, roster_member_id", None)])
table("checkin", "D09", "逐现实选手按项目报到/检录；队长到场不代表全队", [
    ref("event_id", "asp_event", "赛事"), ref("unit_id", "asp_competition_unit", "赛事项目；旧赛事级记录项目未知，保留为空待核对", True),
    ref("person_id", "asp_person", "实际到场人"), ref("match_id", "asp_match", "单场检录；项目报到为空", True),
    txt("check_type", "unit 项目报到、event 历史赛事级报到、match 单场检录"), state("status", "confirmed corrected rejected"), js("verification", "授权核查方式及必要证据"), time("occurred_at", "现场发生时间"),
    txt("request_key", "扫码/离线补录幂等键", size=128)
], checks=["check_type <> 'unit' OR (unit_id IS NOT NULL AND match_id IS NULL)"], unique=[("request_key", None),
    ("event_id, person_id", "unit_id IS NULL AND match_id IS NULL AND status = 'confirmed'"),
    ("event_id, unit_id, person_id", "unit_id IS NOT NULL AND match_id IS NULL AND status = 'confirmed'")])
table("official_assignment", "D09", "裁判、记录员及结果确认人员到场次的授权任务", [
    ref("match_id", "asp_match", "场次"), ref("person_id", "asp_person", "现实执行人员"), txt("role", "录入/确认/发布等"),
    state("status", "proposed accepted replaced completed"), js("basis", "职责与专业资格来源")
])
table("result_version", "D10", "原始表现、有效性、专业确认及修订链", [
    ref("match_id", "asp_match", "比赛"), num("revision", "结果版本"), ref("previous_id", "asp_result_version", "更正前版本", True),
    state("status", "draft confirmed appealed published superseded void"), js("raw_performance", "比分/计时/计量/评分等原始分项"),
    js("decision", "弃权、处罚、取消及结果专业依据"), c("confirmer_id", "bigint", "有权确认人员", True), time("confirmed_at", "确认", True), time("published_at", "发布", True)
], checks=["revision > 0", "previous_id IS NULL OR previous_id <> id"], unique=[("match_id, revision", None)])
table("result_item", "D10", "每参赛单位原始成绩及单位；零与缺失/未完赛分开", [
    ref("result_version_id", "asp_result_version", "结果版本"), ref("match_entry_id", "asp_match_entry", "实际参赛单位"),
    state("performance_status", "valid did_not_start did_not_finish forfeited disqualified invalid"),
    c("value", "numeric(20,6)", "可比较主数值；分项另存，缺失不是零", True), txt("unit", "second/metre/point/kg 等确认单位", True),
    js("components", "局、试次、裁判分项和处罚", True)
], unique=[("result_version_id, match_entry_id", None)])
table("advancement", "D08", "确认结果驱动晋级；重复确认不重复产生席位", [
    ref("result_version_id", "asp_result_version", "上游已确认结果"), ref("registration_id", "asp_registration", "晋级报名单位"),
    ref("target_stage_id", "asp_stage", "下一阶段"), txt("target_slot", "下一阶段稳定席位"), state("status", "pending confirmed superseded revoked"), js("basis", "名次或成绩资格依据")
], unique=[("target_stage_id, target_slot", "status = 'confirmed'")])
table("ranking_run", "D08", "排名计算输入与同分规则版本；可独立复算", [
    ref("unit_id", "asp_competition_unit", "统计单元"), ref("rule_version_id", "asp_rule_version", "排名规则"), num("revision", "排名版本"),
    js("input_results", "有效原始结果引用与处罚"), js("comparison_rules", "比较顺序、范围和并列"), state("status", "draft confirmed published superseded")
], unique=[("unit_id, revision", None)])
table("ranking_item", "D08", "有范围的个人或参赛单位名次", [
    ref("ranking_run_id", "asp_ranking_run", "排名运行"), ref("registration_id", "asp_registration", "参赛单位"), num("rank", "允许并列的名次"),
    js("comparison_values", "独立复算需要的原值和单位"), txt("explanation", "并列/取消/规则说明", True, 1000)
], checks=["rank > 0"], unique=[("ranking_run_id, registration_id", None)])
table("appeal", "D09", "专业申诉与裁定；客服不能直接改赛果", [
    ref("match_id", "asp_match", "比赛", True), ref("registration_id", "asp_registration", "相关报名"), ref("applicant_account_id", "asp_account", "获授权申请者"),
    ref("result_version_id", "asp_result_version", "争议结果", True), txt("reason", "申诉理由", size=2000), js("evidence", "受控证据"),
    state("status", "submitted accepted rejected reviewing decided withdrawn"), time("submitted_at", "实际提交"), time("deadline_at", "规程期限"),
    js("decision", "专业裁定及后续晋级影响", True), c("fee_obligation_id", "bigint", "如规程要求申诉费，另行费用义务核验", True)
], checks=["match_id IS NOT NULL OR result_version_id IS NULL"])
table("honor", "D10", "分级荣誉及来源；当前佩戴不替代历史获得记录", [
    ref("event_id", "asp_event", "来源赛事", True), ref("registration_id", "asp_registration", "获奖报名。同一 award_key 的个人证明行属于这一条报名获奖事实", True),
    ref("person_id", "asp_person", "个人获得者", True), ref("team_id", "asp_team", "队伍获得者", True),
    txt("award_key", "同一条报名获奖事实的编号。双打和团体的多行个人证明共用", True, 64),
    state("category", "official event achievement self_reported"), txt("title", "含项目、届次、层级和范围的名称", size=200),
    js("source", "授予或公布主体、证据和实际获奖成员快照"), state("status", "pending verified suspended revised revoked"),
    time("awarded_at", "获得时间"), time("display_until", "当前展示期限", True),
    ref("applicant_account_id", "asp_account", "外部荣誉申请本人账号；旧赛事及成长荣誉为空", True),
    c("certification_status", "varchar(32)", "外部荣誉认证流程 draft submitted correction approved rejected revoked；历史荣誉为空", True),
    c("certification_details", "jsonb", "本人申请事实与私有honor-proof编号；只限本人及平台审核人", default="'{}'::jsonb"),
    c("verified_snapshot", "jsonb", "审核人独立确认的真实年份赛事项目名次及公布依据；公开投影不含证明及审核隐私", default="'{}'::jsonb"),
    c("certification_history", "jsonb", "追加的提交与审核快照，不覆写既有历史；只限本人及平台审核人", default="'[]'::jsonb"),
    c("certification_public", "boolean", "本人公开同意；仅审核通过且运动名片也公开时生效", default="false"),
    c("certification_worn", "boolean", "本人选择佩戴的已通过认证荣誉；每人每运动最多一项", default="false")
], checks=["(person_id IS NOT NULL) <> (team_id IS NOT NULL)",
    "jsonb_typeof(certification_details) = 'object' AND jsonb_typeof(verified_snapshot) = 'object' AND jsonb_typeof(certification_history) = 'array'",
    "certification_status IS NULL OR (certification_status IN ('draft','submitted','correction','approved','rejected','revoked') AND applicant_account_id IS NOT NULL AND person_id IS NOT NULL AND team_id IS NULL AND category = 'self_reported' AND sport_id IS NOT NULL AND ((certification_status = 'approved' AND status = 'verified' AND verified_snapshot <> '{}'::jsonb) OR (certification_status = 'revoked' AND status = 'revoked') OR (certification_status IN ('draft','submitted','correction','rejected') AND status = 'pending')))",
    "NOT certification_worn OR (certification_status = 'approved' AND status = 'verified')",
    "NOT certification_public OR (certification_status = 'approved' AND status = 'verified')"], unique=[("award_key, person_id", "award_key IS NOT NULL"), ("registration_id, person_id, title", "registration_id IS NOT NULL AND status = 'verified'"), ("person_id, sport_id", "certification_status = 'approved' AND certification_worn")])
table("execution_command", "D09", "报到、录分和发奖的请求幂等。不替代赛事一个人一次报到，也不替代一场一条结果", [
    txt("action", "动作。checkin match result result_finalize result_import award", size=32),
    txt("request_key", "客户端幂等键", size=128),
    txt("payload_hash", "请求内容摘要。相同键不同摘要视为冲突", size=64),
    txt("subject_type", "指向的事实类型", size=32),
    c("subject_id", "bigint", "已经生效的业务事实编号"),
], unique=[("action, request_key", None)])
table("growth_record", "D10", "非竞技成长事实；规则有来源，防止刷空赛事", [
    ref("person_id", "asp_person", "个人", True), ref("team_id", "asp_team", "队伍", True), txt("policy_version", "成长规则版本"),
    txt("achievement", "参与/完赛/志愿等经确认行为"), js("source", "原业务事实及范围"), state("status", "effective disputed revoked")
], checks=["(person_id IS NOT NULL) <> (team_id IS NOT NULL)"])

# D11/D13: governance, evidence and external irreversible outputs.
table("change_case", "D13", "重大变更旧新版本、影响及责任接续", [
    txt("object_type", "赛事/名单/收费/结果等"), c("object_id", "bigint", "业务对象"), js("before_snapshot", "原事实"), js("after_snapshot", "草案或已确认事实"),
    js("impact", "受影响人员、资源、金额、晋级、证书及通知"), state("status", "draft reviewing approved published coordinating completed rejected"), txt("reason", "变更依据", size=2000)
])
table("notification", "D11", "业务通知内容版本及对象；不可夹带未授权营销", [
    ref("recipient_account_id", "asp_account", "目标账号"), txt("business_type", "来源业务类型"), c("business_id", "bigint", "来源业务对象"),
    num("business_revision", "来源版本"), txt("purpose", "必要服务或经同意营销"), js("content", "允许告知范围"),
    txt("dedupe_key", "重复处理防重键", size=200), time("read_at", "已读", True), time("confirmed_at", "用户作出决定", True), js("response", "接受/协调/退赛等业务决定", True)
], unique=[("recipient_account_id, dedupe_key", None)])
table("notification_delivery", "D11", "逐渠道发送和送达结果；失败需责任人跟进", [
    ref("notification_id", "asp_notification", "通知"), txt("channel", "站内/短信/小程序等"), num("attempt", "尝试次数"),
    state("status", "pending sent delivered failed"), txt("channel_reference", "渠道回执", True, 200), time("sent_at", "发送", True), time("delivered_at", "送达", True), txt("failure_reason", "失败原因", True, 1000)
], unique=[("notification_id, channel, attempt", None)])
table("file", "D13", "共享文件元数据；无永久公开凭据，访问由用途授权", [
    ref("owner_account_id", "asp_account", "上传及权利主体"), txt("owning_tenant_id", "组织资料归属租户；个人资料可为空", True, 20),
    txt("object_key", "存储键；不能直接形成无鉴权 URL", size=500), txt("sha256", "内容摘要", size=64), txt("purpose", "必要用途", size=200),
    state("sensitivity", "public ordinary identity guardian health finance result"), time("retain_until", "保留政策截止", True), state("status", "active restricted expired deleted")
], False, unique=[("object_key", None)])
table("material_submission", "D05", "报名材料提交版本、核验与现场验证分离", [
    ref("registration_id", "asp_registration", "报名"), ref("roster_member_id", "asp_roster_member", "相关成员", True),
    ref("requirement_id", "asp_material_requirement", "规程要求"), ref("file_id", "asp_file", "受控材料"), num("revision", "提交版本"),
    state("status", "submitted correction accepted rejected expired"), time("valid_until", "材料有效截止", True)
], unique=[("registration_id, requirement_id, roster_member_id, revision", None)])
table("complaint", "D13", "平台投诉、反馈及分派；专业结果争议移交申诉", [
    ref("applicant_account_id", "asp_account", "投诉人"), txt("object_type", "组织/赛事/队伍/付款/资料"), c("object_id", "bigint", "关联对象"),
    txt("request", "诉求", size=2000), js("evidence", "最小披露证据"), state("status", "submitted accepted investigating resolved rejected appealed"),
    c("owner_id", "bigint", "处理责任人", True), js("resolution", "处理及告知", True)
])
table("data_request", "D13", "个人资料查询、更正、撤回、注销及删除请求", [
    ref("account_id", "asp_account", "请求人"), ref("person_id", "asp_person", "资料对象"), txt("request_type", "明确权利请求类型"),
    js("scope", "范围和授权"), state("status", "submitted verifying approved rejected processing completed"), js("resolution", "公开下架、必要留存及未完义务接续", True)
], False)
table("audit_event", "D13", "关键业务决定与资料访问审计；不写入原始敏感材料", [
    ref("actor_account_id", "asp_account", "操作人", True), txt("action", "业务或资料访问动作"), txt("object_type", "对象类型"),
    c("object_id", "bigint", "对象 ID", True), txt("request_id", "调用追踪 ID", size=128), time("occurred_at", "发生时间"),
    js("summary", "理由、版本及允许的最小变化摘要")
])
table("outbox", "D13", "本地事务提交的跨模块通知/事件；消费必须幂等", [
    txt("event_key", "稳定事件去重 ID", size=128), txt("aggregate_type", "来源聚合"), c("aggregate_id", "bigint", "来源 ID"),
    num("aggregate_revision", "来源业务版本"), txt("event_type", "版本化事件名"), js("payload", "最小必要跨模块契约"),
    state("status", "pending processing delivered failed"), num("attempts", "尝试数"), time("next_attempt_at", "下次尝试", True)
], unique=[("event_key", None)])
table("idempotency", "D13", "请求去重及不确定响应恢复；不得只靠页面按钮防重", [
    ref("account_id", "asp_account", "调用者"), txt("operation", "动作"), txt("request_key", "客户端重试键", size=128),
    txt("payload_hash", "输入摘要；同键不同输入拒绝", size=128), state("status", "processing completed failed"),
    js("result_reference", "原业务结果引用；不存敏感完整响应", True), time("expires_at", "去重记录保留截止")
], unique=[("account_id, operation, request_key", None)])
table("migration_batch", "D13", "旧系统来源、授权及数量金额差异核对", [
    txt("source_system", "来源系统"), txt("source_version", "导出及切换版本"), js("authorization_snapshot", "迁移范围及接收责任"),
    js("reconciliation", "身份、名单、金额、退款、赛程及结果汇总"), state("status", "importing checking verified blocked cutover rolled_back"), time("cutover_at", "唯一生效切换时间", True)
])
table("migration_mapping", "D13", "旧新记录映射、差异及未完责任；不虚构调平", [
    ref("batch_id", "asp_migration_batch", "迁移批次"), txt("object_type", "业务对象类型"), txt("source_key", "旧系统稳定键", size=200),
    c("target_id", "bigint", "新对象 ID", True), state("status", "matched missing conflict reconciled"), js("difference", "来源、差异和处理人", True)
], unique=[("batch_id, object_type, source_key", None)])


# 通用 AI 任务。首个场景是从资料创建赛事，表本身不绑定某一项赛事写接口。
table("ai_task", "D04", "通用 AI 任务。按场景和业务对象记录资料、候选方案和最终业务对象，模型不直接写业务表", [
    txt("scene", "场景编码。首个为 event.create_from_document", size=64),
    txt("business_object", "业务对象类型。首个为 event", size=32),
    ref("organization_id", "asp_organization", "发起任务的组织"),
    c("initiator_account_id", "bigint", "发起人平台账号。账号表无租户列，这里不建外键"),
    state("status", "UPLOADED PROCESSING PENDING_CONFIRMATION CREATED FAILED ABANDONED"),
    c("bailian_consent", "boolean", "已同意把本次资料发给阿里云百炼"),
    js("extraction", "本地解析出的原文块和位置。放弃任务后清空", True),
    js("proposal", "候选方案、来源、缺失、冲突和建议。放弃任务后清空", True),
    txt("error_code", "失败代码。可空", True, 64),
    txt("error_message", "给操作者看的失败说明。不含密钥和堆栈", True, 500),
    c("attempt_count", "integer", "已经执行的识别次数", default="0", check="attempt_count >= 0"),
    c("result_object_id", "bigint", "确认后写入的业务对象编号。可空，不建跨模块外键", True),
    txt("confirm_key", "确认幂等键。同一任务成功后重复确认不再创建", True, 128),
], checks=["bailian_consent = true"], unique=[("confirm_key", "confirm_key IS NOT NULL")])
table("ai_task_file", "D04", "AI 任务附件引用。文件本体在对象存储，用途必须是 ai-source，不能借用收款码", [
    ref("task_id", "asp_ai_task", "所属任务"),
    c("file_id", "bigint", "asp_file 编号。文件表无租户列，这里不建外键"),
    num("sort_order", "同一任务内从 0 开始的顺序"),
    txt("media_kind", "嗅探后的类型：docx xlsx pdf-text pdf-scan jpeg png webp", size=32),
    txt("original_name", "上传时的文件名，只用于展示", True, 200),
    num("page_count", "PDF 页数。其他类型为空", True),
], checks=["media_kind IN ('docx', 'xlsx', 'pdf-text', 'pdf-scan', 'jpeg', 'png', 'webp')"], unique=[("task_id, sort_order", None)])
table("ai_invocation", "D04", "模型或工具的一次调用。不保存密钥、登录令牌、资料正文和完整模型响应", [
    ref("task_id", "asp_ai_task", "所属任务"),
    txt("kind", "model 或 tool", size=16),
    txt("tool_name", "工具名。模型调用可空", True, 64),
    txt("model_name", "实际请求的模型名。工具调用可空", True, 80),
    state("status", "started succeeded failed refused"),
    c("attempt_no", "integer", "对应任务上的第几次识别", default="0", check="attempt_no >= 0"),
    txt("error_code", "失败或拒绝代码", True, 64),
    js("summary", "耗时毫秒和是否降级。不存资料正文"),
], checks=["kind IN ('model', 'tool')"])


# D04: mirror existing V021/V023/V024 structures; this is documentation, not a new migration.
# Gateway proposal tables are retained historical storage, distinct from the active ai_task flow.
table("event_poster", "D04", "赛事宣传材料，来源V021/V024；来源编号仅汇总打开次数，不关联账号", [
    ref("event_id", "asp_event", "所属赛事"),
    txt("channel_name", "承办方渠道名称", size=40),
    state("format", "wechat_group moments a4", "资料版式"),
    txt("source_code", "公开链接来源编号，不含个人信息", size=16),
    c("copy_headline", "varchar(80)", "模型生成标题，金额日期由赛事事实填入", default="''"),
    c("copy_invitation", "varchar(300)", "模型生成邀请句", default="''"),
    c("copy_body", "varchar(2000)", "群消息或朋友圈正文，海报可为空", default="''"),
    c("fact_digest", "varchar(64)", "生成时事实摘要，与当前赛事不符则过期", default="''"),
    c("link_path", "varchar(240)", "已发布的公开路径含来源编号，未发布为空", default="''"),
    ref("visual_file_id", "asp_file", "模型生成的无字宣传主视觉，复用event-banner图片用途及组织隔离，不替换赛事封面；来源V025", nullable=True),
    c("visual_subject_digest", "varchar(64)", "生成时名称与运动项目摘要，变化后主视觉不可复用；来源V025", default="''"),
    c("visual_request_digest", "varchar(64)", "名称项目受众关键词风格摘要，相同请求复用不重复生图；来源V025", default="''"),
    c("visual_style", "varchar(24)", "主视觉风格competitive junior community，未生成为空；来源V025", default="''", check="visual_style IN ('', 'competitive', 'junior', 'community')"),
], unique=[("source_code", None), ("event_id, channel_name", None)])
table("event_poster_stat", "D04", "宣传材料按上海日期汇总打开次数；来源V021；不记录账号、地址或浏览器标识", [
    ref("poster_id", "asp_event_poster", "所属宣传材料"),
    c("stat_date", "date", "上海时区统计日"),
    c("hit_count", "integer", "当日打开次数", check="hit_count >= 0"),
], unique=[("poster_id, stat_date", None)])
table("ai_gateway_task", "D04", "历史AI网关提案账本，来源V023；不等于当前ai_task实现，不保存原文或密钥", [
    ref("organization_id", "asp_organization", "提出提案的组织"),
    c("domain_code", "varchar(64)", "业务域编码，域内语义由服务定义", check="domain_code ~ '^[a-z][a-z0-9-]{0,63}$'"),
    state("status", "extracted applying confirmed discarded", "提案状态"),
    txt("source_name", "上传文件名，不保存正文", size=200),
    txt("source_media_type", "上传媒体类型", size=100),
    c("source_sha256", "varchar(64)", "文件内容SHA-256摘要", check="source_sha256 ~ '^[0-9a-f]{64}$'"),
    c("proposal", "jsonb", "结构化候选、缺失项及短引用，必须校验结构"),
    txt("apply_request_key", "生成草稿的幂等键", True, 128),
    ref("event_id", "asp_event", "生成的赛事草稿，确认前为空", True),
    time("confirmed_at", "办赛人员确认的有时区时间", True),
], checks=["(status <> 'confirmed') OR (event_id IS NOT NULL AND confirmed_at IS NOT NULL AND apply_request_key IS NOT NULL)",
           "(status <> 'applying') OR (apply_request_key IS NOT NULL)"], unique=[("event_id", "event_id IS NOT NULL")])
table("ai_gateway_call", "D04", "历史网关工具调用摘要，来源V023；不记录参数、响应或原文，不表示当前路径启用", [
    ref("task_id", "asp_ai_gateway_task", "所属历史提案"),
    txt("tool_name", "业务域工具名称", size=80),
    state("phase", "read apply", "读取或用户确认后的应用阶段"),
    state("outcome", "ok rejected", "工具调用结果"),
])


_phase_spec = _importlib_util.spec_from_file_location('aisports_phase1_model', __import__('pathlib').Path(__file__).with_name('phase1.py'))
_phase_model = _importlib_util.module_from_spec(_phase_spec)
_phase_spec.loader.exec_module(_phase_model)
_phase_model.extend(_sys.modules[__name__])

# V036 stores the trusted skill/tool/map bundle on the existing agent version; no new table or automatic channel opening.
_agent_version = next(t for t in TABLES if t.name == 'asp_agent_version')
_agent_version.columns.extend([
    c('tool_catalog', 'jsonb', '受控MCP工具名、参数与调用方式；不能注册原始SQL、Shell或任意网络', default="'{}'::jsonb"),
    c('skill_catalog', 'jsonb', '可信平台技能目录与办理指引，版本化且不存模型正文或隐藏思考', default="'{}'::jsonb"),
    c('business_map', 'jsonb', '按角色和依赖组织的业务地图；动作可用性须实时核对注册表', default="'{}'::jsonb"),
    c('playbook_hash', 'varchar(64)', '三个目录的规范JSON摘要；与锁定智能体版本共同溯源', default="''")
])
_agent_version.checks.extend(["jsonb_typeof(tool_catalog) = 'object'", "jsonb_typeof(skill_catalog) = 'object'", "jsonb_typeof(business_map) = 'object'"])


def catalog():
    """Return machine-readable source for SQL/dictionary/config generation."""
    return [asdict(t) for t in TABLES]
