// GENERATED object shapes; read/write channels remain capability controlled.
export type SportsLong = string;
export type SportsMoney = string;
/** 平台账号在一个租户里的若依用户映射。映射存在不等于可以进入组织 */
export interface AccountTenantPrincipalObject {
  id: SportsLong | null;
  account_id?: SportsLong | null;
  tenant_id?: string | null;
  sys_user_id?: SportsLong | null;
  status?: string | null;
}
/** 多方办赛展示与业务授权分离 */
export interface CollaborationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  organization_id?: SportsLong | null;
  partner_tenant_id?: string | null;
  partner_organization_id?: SportsLong | null;
  display_role?: string | null;
  authorized_scope?: unknown | null;
  valid_from?: string | null;
  valid_until?: string | null;
}
/** 政府后台账号对指定主办方的管理范围；不能由模型或普通经办人自授 */
export interface GovernanceGrantObject {
  id: SportsLong | null;
  sys_user_id?: SportsLong | null;
  organization_id?: SportsLong | null;
  permissions?: unknown | null;
  status?: string | null;
  valid_until?: string | null;
}
/** 承办责任主体与租户映射。本期只在办赛申请通过后创建 */
export interface OrganizationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  name?: string | null;
  subject_type?: string | null;
  subject_hash?: string | null;
  status?: string | null;
  contact_cipher?: string | null;
  current_qualification_id?: SportsLong | null;
}
/** 办赛申请。平台级数据，没有业务租户。审核只决定是否开放办赛，不表示主体已验真 */
export interface OrganizationApplicationObject {
  id: SportsLong | null;
  applicant_account_id?: SportsLong | null;
  status?: string | null;
  name?: string | null;
  contact_name?: string | null;
  contact_cipher?: string | null;
  statement?: string | null;
  file_ids?: unknown | null;
  organization_id?: SportsLong | null;
  organization_tenant_id?: string | null;
  assigned_reviewer_id?: SportsLong | null;
}
/** 办赛申请每次提交时冻结的内容和附件。拒绝后的旧版不改 */
export interface OrganizationApplicationVersionObject {
  id: SportsLong | null;
  application_id?: SportsLong | null;
  revision?: number | null;
  name?: string | null;
  contact_name?: string | null;
  contact_cipher?: string | null;
  statement?: string | null;
  file_ids?: unknown | null;
  status?: string | null;
  reviewer_id?: SportsLong | null;
  review_reason?: string | null;
}
/** 组织资质申请及审核版本；失效不删除未完责任 */
export interface QualificationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  organization_id?: SportsLong | null;
  revision?: number | null;
  proof_snapshot?: unknown | null;
  business_scope?: unknown | null;
  status?: string | null;
  valid_from?: string | null;
  valid_until?: string | null;
  reviewer_id?: SportsLong | null;
  review_reason?: string | null;
}
/** 工作人员组织、赛事、动作及材料范围授权 */
export interface StaffGrantObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  organization_id?: SportsLong | null;
  account_id?: SportsLong | null;
  event_id?: SportsLong | null;
  permissions?: unknown | null;
  status?: string | null;
  valid_from?: string | null;
  valid_until?: string | null;
}
/** 平台账号。一名自然人一份。参赛档案可选。登录号使用本表主键，不把后台用户当成平台身份 */
export interface AccountObject {
  id: SportsLong | null;
  display_name?: string | null;
  password_hash?: string | null;
  backend_user_id?: SportsLong | null;
  person_id?: SportsLong | null;
  status?: string | null;
  closed_at?: string | null;
}
/** 跨项目参赛属性目录；新项目增加目录项，不改参赛人表结构 */
export interface AttributeDefinitionObject {
  id: SportsLong | null;
  code?: string | null;
  name?: string | null;
  value_type?: string | null;
  unit?: string | null;
  sensitivity?: string | null;
  storage_scope?: string | null;
  sport_id?: SportsLong | null;
  enum_options?: unknown | null;
  status?: string | null;
}
/** 本人对具体用途的告知确认；保存档案和以后的报名材料分别记录 */
export interface ConsentObject {
  id: SportsLong | null;
  person_id?: SportsLong | null;
  actor_account_id?: SportsLong | null;
  purpose?: string | null;
  document_version?: string | null;
  scope?: unknown | null;
  accepted_at?: string | null;
  revoked_at?: string | null;
  evidence_hash?: string | null;
}
/** 账号渠道绑定和解绑历史；手机号回收不直接转移历史档案 */
export interface LoginIdentityObject {
  id: SportsLong | null;
  account_id?: SportsLong | null;
  channel?: string | null;
  subject_hash?: string | null;
  subject_cipher?: string | null;
  valid_from?: string | null;
  valid_until?: string | null;
  verification_source?: string | null;
}
/** 一名独立参赛者的稳定档案；同名不合并，资料更正不改写报名快照。通用联系和体貌资料在本表，不进赛事属性目录 */
export interface PersonObject {
  id: SportsLong | null;
  legal_name?: string | null;
  display_name?: string | null;
  birth_date?: string | null;
  gender?: string | null;
  mobile?: string | null;
  id_doc_type?: string | null;
  identity_hash?: string | null;
  identity_cipher?: string | null;
  city?: string | null;
  address_detail?: string | null;
  blood_type?: string | null;
  clothing_size?: string | null;
  emergency_contact_name?: string | null;
  emergency_contact_phone?: string | null;
  verification_status?: string | null;
  status?: string | null;
  merged_into_id?: SportsLong | null;
}
/** 参赛者已保存的可复用属性；只接受目录中 storage_scope 为 profile 的项 */
export interface PersonAttributeObject {
  id: SportsLong | null;
  person_id?: SportsLong | null;
  attribute_id?: SportsLong | null;
  value?: unknown | null;
  measured_at?: string | null;
}
/** 公开运动名片与真实参赛档案分开；未选择公开时只向本人及必要队友展示 */
export interface ProfileDisplayObject {
  id: SportsLong | null;
  account_id?: SportsLong | null;
  nickname?: string | null;
  avatar_file_id?: SportsLong | null;
  avatar_style?: string | null;
  tagline?: string | null;
  public_visible?: boolean | null;
  sport_preferences?: unknown | null;
}
/** 匹配确认邀请；每名成员本人接受，120秒确认席位与正式报名名额分开 */
export interface MatchingOfferObject {
  id: SportsLong | null;
  unit_id?: SportsLong | null;
  room_id?: SportsLong | null;
  status?: string | null;
  expires_at?: string | null;
}
/** 匹配邀请的一名接收者；全部接受后才加入房间 */
export interface MatchingOfferMemberObject {
  id: SportsLong | null;
  offer_id?: SportsLong | null;
  account_id?: SportsLong | null;
  request_id?: SportsLong | null;
  status?: string | null;
  answered_at?: string | null;
}
/** 自动匹配排队意向；不占赛事正式报名名额 */
export interface MatchingRequestObject {
  id: SportsLong | null;
  unit_id?: SportsLong | null;
  account_id?: SportsLong | null;
  room_id?: SportsLong | null;
  preferences?: unknown | null;
  status?: string | null;
  expires_at?: string | null;
}
/** 缺员招募；只展示受控运动名片，不公开私有联系与材料 */
export interface RecruitmentObject {
  id: SportsLong | null;
  room_id?: SportsLong | null;
  creator_account_id?: SportsLong | null;
  message?: string | null;
  status?: string | null;
  expires_at?: string | null;
}
/** 房间内可见欢迎与鼓励；不是社区或私聊平台 */
export interface RoomInteractionObject {
  id: SportsLong | null;
  room_id?: SportsLong | null;
  account_id?: SportsLong | null;
  kind?: string | null;
  text?: string | null;
  request_key?: string | null;
}
/** 长期项目队伍。一期只有有效和解散，解散后不恢复，不归属组织 */
export interface TeamObject {
  id: SportsLong | null;
  name?: string | null;
  sport_id?: SportsLong | null;
  captain_person_id?: SportsLong | null;
  creator_account_id?: SportsLong | null;
  join_policy?: string | null;
  visibility?: string | null;
  status?: string | null;
  region?: string | null;
  profile?: unknown | null;
}
/** 队伍改名、转让、解散的事实和快照。不代替成员终止行，也不回写已提交报名 */
export interface TeamHistoryObject {
  id: SportsLong | null;
  team_id?: SportsLong | null;
  action?: string | null;
  before_snapshot?: unknown | null;
  after_snapshot?: unknown | null;
  reason?: string | null;
  effective_at?: string | null;
}
/** 指定本人邀请、队长可转发分享授权及本人接受事实。分享不公开队内名单；离队后不重放旧授权 */
export interface TeamInvitationObject {
  id: SportsLong | null;
  team_id?: SportsLong | null;
  inviter_account_id?: SportsLong | null;
  inviter_person_id?: SportsLong | null;
  target_person_id?: SportsLong | null;
  invitation_kind?: string | null;
  invite_token?: string | null;
  expires_at?: string | null;
  share_invitation_id?: SportsLong | null;
  status?: string | null;
}
/** 入队申请。待处理不是成员，失效不能记成申请人撤销或队长拒绝 */
export interface TeamJoinRequestObject {
  id: SportsLong | null;
  team_id?: SportsLong | null;
  person_id?: SportsLong | null;
  status?: string | null;
  reviewer_account_id?: SportsLong | null;
  reason?: string | null;
}
/** 队伍成员的一段关系。结束后不重新激活，再次加入另起一行 */
export interface TeamMemberObject {
  id: SportsLong | null;
  team_id?: SportsLong | null;
  person_id?: SportsLong | null;
  role?: string | null;
  status?: string | null;
  end_reason?: string | null;
  join_source?: string | null;
  joined_at?: string | null;
  left_at?: string | null;
}
/** 账户建队与入队配额。一期没有已批准数值，服务不读不写 */
export interface TeamQuotaObject {
  id: SportsLong | null;
  account_id?: SportsLong | null;
  create_limit?: number | null;
  join_limit?: number | null;
  policy_version?: string | null;
  exception_basis?: string | null;
  valid_until?: string | null;
}
/** 本场参赛房间，与长期队伍及已提交名单分开；房主计入成员人数 */
export interface TeamRoomObject {
  id: SportsLong | null;
  unit_id?: SportsLong | null;
  competition_type_id?: SportsLong | null;
  host_account_id?: SportsLong | null;
  team_id?: SportsLong | null;
  name?: string | null;
  status?: string | null;
  registration_id?: SportsLong | null;
  announcement?: string | null;
}
/** 参赛房间成员；加入不等于本人报名声明确认 */
export interface TeamRoomMemberObject {
  id: SportsLong | null;
  room_id?: SportsLong | null;
  unit_id?: SportsLong | null;
  account_id?: SportsLong | null;
  person_id?: SportsLong | null;
  status?: string | null;
  ready?: boolean | null;
  joined_at?: string | null;
  left_at?: string | null;
}
/** 历史网关工具调用摘要，来源V023；不记录参数、响应或原文，不表示当前路径启用 */
export interface AiGatewayCallObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  task_id?: SportsLong | null;
  tool_name?: string | null;
  phase?: string | null;
  outcome?: string | null;
}
/** 历史AI网关提案账本，来源V023；不等于当前ai_task实现，不保存原文或密钥 */
export interface AiGatewayTaskObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  organization_id?: SportsLong | null;
  domain_code?: string | null;
  status?: string | null;
  source_name?: string | null;
  source_media_type?: string | null;
  source_sha256?: string | null;
  proposal?: unknown | null;
  apply_request_key?: string | null;
  event_id?: SportsLong | null;
  confirmed_at?: string | null;
}
/** 模型或工具的一次调用。不保存密钥、登录令牌、资料正文和完整模型响应 */
export interface AiInvocationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  task_id?: SportsLong | null;
  kind?: string | null;
  tool_name?: string | null;
  model_name?: string | null;
  status?: string | null;
  attempt_no?: number | null;
  error_code?: string | null;
  summary?: unknown | null;
}
/** 通用 AI 任务。按场景和业务对象记录资料、候选方案和最终业务对象，模型不直接写业务表 */
export interface AiTaskObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  scene?: string | null;
  business_object?: string | null;
  organization_id?: SportsLong | null;
  initiator_account_id?: SportsLong | null;
  status?: string | null;
  bailian_consent?: boolean | null;
  extraction?: unknown | null;
  proposal?: unknown | null;
  error_code?: string | null;
  error_message?: string | null;
  attempt_count?: number | null;
  result_object_id?: SportsLong | null;
  confirm_key?: string | null;
  provider_consent?: boolean | null;
  provider_name?: string | null;
  consent_version?: string | null;
}
/** AI 任务附件引用。文件本体在对象存储，用途必须是 ai-source，不能借用收款码 */
export interface AiTaskFileObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  task_id?: SportsLong | null;
  file_id?: SportsLong | null;
  sort_order?: number | null;
  media_kind?: string | null;
  original_name?: string | null;
  page_count?: number | null;
}
/** 某版规则要求报名时采集的属性；社区活动可以一条都不选 */
export interface AttributeRequirementObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  rule_version_id?: SportsLong | null;
  attribute_id?: SportsLong | null;
  required?: boolean | null;
}
/** 运动下的比赛类型；人数和报名形式用于办赛、房间和报名的共同约束 */
export interface CompetitionTypeObject {
  id: SportsLong | null;
  sport_id?: SportsLong | null;
  code?: string | null;
  name?: string | null;
  entry_type?: string | null;
  min_members?: number | null;
  max_members?: number | null;
  capability_status?: string | null;
  status?: string | null;
}
/** 报名坐标。M1.4 按整单占用名额，报名窗口仍在赛事上 */
export interface CompetitionUnitObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  sport_id?: SportsLong | null;
  name?: string | null;
  entry_type?: string | null;
  min_members?: number | null;
  max_members?: number | null;
  birth_from?: string | null;
  birth_until?: string | null;
  age_reference_date?: string | null;
  status?: string | null;
  current_rule_id?: SportsLong | null;
  current_fee_policy_id?: SportsLong | null;
  competition_type_id?: SportsLong | null;
}
/** 赛事容器。M1.3 的发布和举办状态分开，时间阶段按北京时间计算，不改这一列的旧生命周期取值 */
export interface EventObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  organization_id?: SportsLong | null;
  name?: string | null;
  series_id?: SportsLong | null;
  starts_at?: string | null;
  ends_at?: string | null;
  registration_opens_at?: string | null;
  registration_closes_at?: string | null;
  location?: string | null;
  project_name?: string | null;
  fee_description?: string | null;
  banner_file_id?: SportsLong | null;
  rules_text?: string | null;
  rules_file_id?: SportsLong | null;
  notice_text?: string | null;
  notice_file_id?: SportsLong | null;
  declaration_text?: string | null;
  declaration_file_id?: SportsLong | null;
  declaration_ack_required?: boolean | null;
  route_text?: string | null;
  route_file_id?: SportsLong | null;
  cancel_reason?: string | null;
  sport_code?: string | null;
  publication_status?: string | null;
  holding_status?: string | null;
  registration_review?: string | null;
  registration_review_locked?: boolean | null;
  status?: string | null;
  registration_status?: string | null;
  payment_status?: string | null;
  visibility?: string | null;
  published_revision?: number | null;
  contact_snapshot?: unknown | null;
  operations_materials?: unknown | null;
  closure_status?: string | null;
}
/** 赛事写操作幂等。同一租户、同一动作、同一请求键只生效一次，重复提交不再次发布 */
export interface EventCommandObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  action?: string | null;
  request_key?: string | null;
}
/** 一场赛事选用的组织字段。一期全赛事同一套，首笔正式提交后不再改 */
export interface EventFieldObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  org_field_id?: SportsLong | null;
  required?: boolean | null;
  sort_order?: number | null;
  note?: string | null;
}
/** 赛事宣传材料，来源V021/V024；来源编号仅汇总打开次数，不关联账号 */
export interface EventPosterObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  channel_name?: string | null;
  format?: string | null;
  source_code?: string | null;
  copy_headline?: string | null;
  copy_invitation?: string | null;
  copy_body?: string | null;
  fact_digest?: string | null;
  link_path?: string | null;
  visual_file_id?: SportsLong | null;
  visual_subject_digest?: string | null;
  visual_request_digest?: string | null;
  visual_style?: string | null;
}
/** 宣传材料按上海日期汇总打开次数；来源V021；不记录账号、地址或浏览器标识 */
export interface EventPosterStatObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  poster_id?: SportsLong | null;
  stat_date?: string | null;
  hit_count?: number | null;
}
/** 赛事对外承诺版本和重大变更说明 */
export interface EventRevisionObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  revision?: number | null;
  snapshot?: unknown | null;
  reason?: string | null;
  published_at?: string | null;
}
/** 赛事文件材料、用途与各阶段前置；体检、保险和责任书走这里 */
export interface MaterialRequirementObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  rule_version_id?: SportsLong | null;
  code?: string | null;
  purpose?: string | null;
  sensitivity?: string | null;
  gates?: unknown | null;
  retention_days?: number | null;
}
/** 组织自有的参赛采集字段。未选用可停用；选用后不改类型和选项含义 */
export interface OrgFieldObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  organization_id?: SportsLong | null;
  code?: string | null;
  label?: string | null;
  value_type?: string | null;
  options?: unknown | null;
  status?: string | null;
}
/** 资格、赛制、晋级和排名规则版本与专业来源 */
export interface RuleVersionObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  unit_id?: SportsLong | null;
  revision?: number | null;
  source?: string | null;
  parameters?: unknown | null;
  status?: string | null;
  verification_level?: string | null;
  confirmed_by?: SportsLong | null;
  confirmed_at?: string | null;
}
/** 开放运动目录与变体；收录不等于自动规则已验证 */
export interface SportObject {
  id: SportsLong | null;
  code?: string | null;
  name?: string | null;
  rule_family?: string | null;
  capability_status?: string | null;
  status?: string | null;
}
/** 容量唯一占用对象；同人兼项总人数只占一次 */
export interface CapacityOccupationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  pool_id?: SportsLong | null;
  subject_key?: string | null;
  person_id?: SportsLong | null;
  status?: string | null;
  expires_at?: string | null;
}
/** 总人数或项目容量；单位和去重范围显式 */
export interface CapacityPoolObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  unit_id?: SportsLong | null;
  capacity_unit?: string | null;
  dedupe_scope?: string | null;
  limit_count?: number | null;
  used_count?: number | null;
  status?: string | null;
}
/** 成员本人对当时参赛声明的点击确认。队长不能代确认，确认不是电子签章 */
export interface DeclarationAckObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_member_id?: SportsLong | null;
  account_id?: SportsLong | null;
  event_id?: SportsLong | null;
  content_digest?: string | null;
  acknowledged_at?: string | null;
}
/** 报名成员对赛事字段的填写。提交时保留当时的名称、类型和选项 */
export interface EntryFieldValueObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_member_id?: SportsLong | null;
  event_field_id?: SportsLong | null;
  value_text?: string | null;
  label_snapshot?: string | null;
  type_snapshot?: string | null;
  options_snapshot?: unknown | null;
}
/** 报名材料提交版本、核验与现场验证分离 */
export interface MaterialSubmissionObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  roster_member_id?: SportsLong | null;
  requirement_id?: SportsLong | null;
  file_id?: SportsLong | null;
  revision?: number | null;
  status?: string | null;
  valid_until?: string | null;
}
/** 报名到容量占用的引用；取消最后引用才释放去重人数 */
export interface OccupationReferenceObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  occupation_id?: SportsLong | null;
  registration_id?: SportsLong | null;
  status?: string | null;
  released_at?: string | null;
}
/** 逐成员/整单审核记录；材料与到账不互相替代 */
export interface QualificationReviewObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  roster_member_id?: SportsLong | null;
  decision?: string | null;
  basis?: unknown | null;
  reviewer_id?: SportsLong | null;
  reviewed_at?: string | null;
  reason?: string | null;
}
/** 竞赛单元报名。草稿不占名额；已提交和已通过占名额；撤回回到草稿 */
export interface RegistrationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  unit_id?: SportsLong | null;
  rule_version_id?: SportsLong | null;
  fee_policy_id?: SportsLong | null;
  batch_id?: SportsLong | null;
  team_id?: SportsLong | null;
  submitter_account_id?: SportsLong | null;
  operator_account_id?: SportsLong | null;
  request_key?: string | null;
  status?: string | null;
  hold_expires_at?: string | null;
  roster_revision?: number | null;
  team_name_snapshot?: string | null;
  submitted_at?: string | null;
  manager_account_id?: SportsLong | null;
}
/** 一次提交的报名批次；不等于一笔订单，也不能借此创建他人账号 */
export interface RegistrationBatchObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  submitter_account_id?: SportsLong | null;
  request_key?: string | null;
  status?: string | null;
  total_count?: number | null;
  success_count?: number | null;
}
/** 报名成员确认。按平台账号记录，提交成功后才抄入名单快照 */
export interface RegistrationMemberObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  unit_id?: SportsLong | null;
  account_id?: SportsLong | null;
  person_id?: SportsLong | null;
  status?: string | null;
  self_member?: boolean | null;
  invite_token?: string | null;
  person_snapshot?: unknown | null;
  occupying?: boolean | null;
}
/** 已经完成的报名提交请求键。撤回或拒绝后重放旧键不得再次占用 */
export interface RegistrationSubmitKeyObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  submitter_account_id?: SportsLong | null;
  request_key?: string | null;
  roster_revision?: number | null;
}
/** 名单内实际参赛人及资格快照 */
export interface RosterMemberObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  roster_version_id?: SportsLong | null;
  person_id?: SportsLong | null;
  role?: string | null;
  person_snapshot?: unknown | null;
  qualification_status?: string | null;
  position?: number | null;
}
/** 赛事报名名单版本；替补和冻结依据 */
export interface RosterVersionObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  revision?: number | null;
  rule_version_id?: SportsLong | null;
  status?: string | null;
  effective_at?: string | null;
  change_reason?: string | null;
}
/** 候补排序、获邀确认及期限 */
export interface WaitlistObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  pool_id?: SportsLong | null;
  rank?: number | null;
  basis?: string | null;
  status?: string | null;
  confirm_until?: string | null;
}
/** 退赛申请、资格终止及退款义务接续 */
export interface WithdrawalObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  person_id?: SportsLong | null;
  applicant_account_id?: SportsLong | null;
  status?: string | null;
  reason?: string | null;
  impact?: unknown | null;
  effective_at?: string | null;
}
/** 赛事统一收款指引，承办方资金授权维护；首次正式提交后锁定。金额仍按项目，指引不是到账 */
export interface EventPaymentConfigObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  settings?: unknown | null;
}
/** 应收服务、选手及项目明细 */
export interface FeeItemObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  obligation_id?: SportsLong | null;
  person_id?: SportsLong | null;
  service_code?: string | null;
  quantity?: SportsMoney | null;
  unit?: string | null;
  unit_price?: SportsMoney | null;
  discount_amount?: SportsMoney | null;
  amount?: SportsMoney | null;
  basis?: unknown | null;
}
/** 一次正式提交产生的付款义务。免费也记一笔，但不产生付款 */
export interface FeeObligationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  fee_policy_id?: SportsLong | null;
  total_amount?: SportsMoney | null;
  currency?: string | null;
  status?: string | null;
  quote_snapshot?: unknown | null;
  request_key?: string | null;
  declared_at?: string | null;
}
/** 竞赛单元的收费版本。已生效的不改价，改价另起一版 */
export interface FeePolicyObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  unit_id?: SportsLong | null;
  revision?: number | null;
  pricing_unit?: string | null;
  amount?: SportsMoney | null;
  payment_mode?: string | null;
  pay_instruction?: string | null;
  qr_file_id?: SportsLong | null;
  pricing_rules?: unknown | null;
  payer_modes?: unknown | null;
  collection_paths?: unknown | null;
  refund_terms?: unknown | null;
  status?: string | null;
}
/** 经确认的承担者及代付范围 */
export interface FeeShareObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  obligation_id?: SportsLong | null;
  account_id?: SportsLong | null;
  person_id?: SportsLong | null;
  amount?: SportsMoney | null;
  status?: string | null;
  accepted_at?: string | null;
}
/** 已经确认的到账事实。未付款时不插入。冲正不是退款 */
export interface PaymentObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  payer_account_id?: SportsLong | null;
  payer_name?: string | null;
  payer_presence?: string | null;
  payment_mode?: string | null;
  confirmation_source?: string | null;
  payee_subject?: string | null;
  transaction_id?: string | null;
  amount?: SportsMoney | null;
  currency?: string | null;
  status?: string | null;
  evidence?: unknown | null;
  occurred_at?: string | null;
  confirmed_at?: string | null;
  request_key?: string | null;
}
/** 已付款报名失效后的资金后续。平台不发起退款 */
export interface PaymentActionObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  payment_id?: SportsLong | null;
  obligation_id?: SportsLong | null;
  status?: string | null;
  note?: string | null;
}
/** 付款到义务与分担的映射；支持多笔实收，超额需资金收尾，不新增资格 */
export interface PaymentAllocationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  payment_id?: SportsLong | null;
  obligation_id?: SportsLong | null;
  share_id?: SportsLong | null;
  amount?: SportsMoney | null;
  status?: string | null;
  request_key?: string | null;
}
/** 金额不符或第二笔真实付款。不自动结清义务 */
export interface PaymentExceptionObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  payment_id?: SportsLong | null;
  obligation_id?: SportsLong | null;
  exception_type?: string | null;
  external_reference?: string | null;
  reported_amount?: SportsMoney | null;
  status?: string | null;
  owner_id?: SportsLong | null;
  resolution?: unknown | null;
}
/** 已经发生的退款事实。不是平台发起的退款申请 */
export interface RefundObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  payment_id?: SportsLong | null;
  allocation_id?: SportsLong | null;
  withdrawal_id?: SportsLong | null;
  applicant_account_id?: SportsLong | null;
  requested_amount?: SportsMoney | null;
  approved_amount?: SportsMoney | null;
  completed_amount?: SportsMoney | null;
  status?: string | null;
  channel_reference?: string | null;
  reason?: string | null;
  request_key?: string | null;
  completed_at?: string | null;
  recipient_name?: string | null;
  recipient_basis?: string | null;
}
/** 报名管理人自愿上传的私有付款图片。只关联一次提交的义务，不代表到账，撤回重提不沿用 */
export interface RegistrationPaymentProofObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  registration_id?: SportsLong | null;
  obligation_id?: SportsLong | null;
  uploaded_by_account_id?: SportsLong | null;
  file_id?: SportsLong | null;
  request_key?: string | null;
  content_digest?: string | null;
  uploaded_at?: string | null;
}
/** 平台服务收入依据；不能将报名流水认作平台收入 */
export interface ServiceFeeObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  contract_reference?: string | null;
  calculation_basis?: unknown | null;
  amount?: SportsMoney | null;
  status?: string | null;
  confirmed_at?: string | null;
}
/** 收款方或支付机构结算证据；记账不证明已结算 */
export interface SettlementObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  subject?: string | null;
  due_amount?: SportsMoney | null;
  settled_amount?: SportsMoney | null;
  status?: string | null;
  evidence?: unknown | null;
  reference?: string | null;
}
/** 冲突发现与协调证据；通知已读不等于解决 */
export interface ConflictCaseObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  trigger_type?: string | null;
  trigger_id?: SportsLong | null;
  affected_refs?: unknown | null;
  severity?: string | null;
  status?: string | null;
  resolution?: unknown | null;
}
/** 受控跨赛事时间事实；与名额生命周期关联但独立 */
export interface TimeConstraintObject {
  id: SportsLong | null;
  person_id?: SportsLong | null;
  resource_id?: SportsLong | null;
  source_tenant_id?: string | null;
  source_type?: string | null;
  source_id?: SportsLong | null;
  parent_id?: SportsLong | null;
  starts_at?: string | null;
  ends_at?: string | null;
  certainty?: string | null;
  strength?: string | null;
  status?: string | null;
  buffer_before_seconds?: number | null;
  buffer_after_seconds?: number | null;
  expires_at?: string | null;
  basis?: unknown | null;
}
/** 确认结果驱动晋级；重复确认不重复产生席位 */
export interface AdvancementObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  result_version_id?: SportsLong | null;
  registration_id?: SportsLong | null;
  target_stage_id?: SportsLong | null;
  target_slot?: string | null;
  status?: string | null;
  basis?: unknown | null;
}
/** 抽签运行与可复核输入；不反复随机选择有利结果 */
export interface DrawRunObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  stage_id?: SportsLong | null;
  rule_version_id?: SportsLong | null;
  revision?: number | null;
  input_snapshot?: unknown | null;
  random_seed?: string | null;
  output_snapshot?: unknown | null;
  status?: string | null;
  reason?: string | null;
}
/** 有范围的个人或参赛单位名次 */
export interface RankingItemObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  ranking_run_id?: SportsLong | null;
  registration_id?: SportsLong | null;
  rank?: number | null;
  comparison_values?: unknown | null;
  explanation?: string | null;
}
/** 排名计算输入与同分规则版本；可独立复算 */
export interface RankingRunObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  unit_id?: SportsLong | null;
  rule_version_id?: SportsLong | null;
  revision?: number | null;
  input_results?: unknown | null;
  comparison_rules?: unknown | null;
  status?: string | null;
}
/** 约束编排草案、不可行原因及发布版本 */
export interface ScheduleRunObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  stage_id?: SportsLong | null;
  draw_run_id?: SportsLong | null;
  revision?: number | null;
  input_snapshot?: unknown | null;
  diagnostics?: unknown | null;
  status?: string | null;
  published_at?: string | null;
}
/** 竞赛阶段及已确认赛制关系 */
export interface StageObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  unit_id?: SportsLong | null;
  rule_version_id?: SportsLong | null;
  name?: string | null;
  format?: string | null;
  sequence?: number | null;
  status?: string | null;
}
/** 专业申诉与裁定；客服不能直接改赛果 */
export interface AppealObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  match_id?: SportsLong | null;
  registration_id?: SportsLong | null;
  applicant_account_id?: SportsLong | null;
  result_version_id?: SportsLong | null;
  reason?: string | null;
  evidence?: unknown | null;
  status?: string | null;
  submitted_at?: string | null;
  deadline_at?: string | null;
  decision?: unknown | null;
  fee_obligation_id?: SportsLong | null;
}
/** 逐现实选手按项目报到/检录；队长到场不代表全队 */
export interface CheckinObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  unit_id?: SportsLong | null;
  person_id?: SportsLong | null;
  match_id?: SportsLong | null;
  check_type?: string | null;
  status?: string | null;
  verification?: unknown | null;
  occurred_at?: string | null;
  request_key?: string | null;
}
/** 报到、录分和发奖的请求幂等。不替代赛事一个人一次报到，也不替代一场一条结果 */
export interface ExecutionCommandObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  action?: string | null;
  request_key?: string | null;
  payload_hash?: string | null;
  subject_type?: string | null;
  subject_id?: SportsLong | null;
}
/** 单场阵容及实际出场；不能从当前队伍直接拉人上场 */
export interface LineupMemberObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  match_entry_id?: SportsLong | null;
  roster_member_id?: SportsLong | null;
  role?: string | null;
  position?: number | null;
  status?: string | null;
}
/** 稳定比赛身份；时间变更不改场次身份 */
export interface MatchObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  stage_id?: SportsLong | null;
  schedule_run_id?: SportsLong | null;
  code?: string | null;
  round_number?: number | null;
  resource_id?: SportsLong | null;
  scheduled_start?: string | null;
  scheduled_end?: string | null;
  actual_start?: string | null;
  actual_end?: string | null;
  status?: string | null;
  court_name?: string | null;
}
/** 对阵或计时评分参赛集合；未来晋级席位可待定 */
export interface MatchEntryObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  match_id?: SportsLong | null;
  registration_id?: SportsLong | null;
  roster_version_id?: SportsLong | null;
  slot?: string | null;
  qualification_source?: unknown | null;
  status?: string | null;
}
/** 裁判、记录员及结果确认人员到场次的授权任务 */
export interface OfficialAssignmentObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  match_id?: SportsLong | null;
  person_id?: SportsLong | null;
  role?: string | null;
  status?: string | null;
  basis?: unknown | null;
}
/** 版本化成长规则；段位不是官方竞技实力评级 */
export interface GrowthPolicyObject {
  id: SportsLong | null;
  sport_id?: SportsLong | null;
  code?: string | null;
  revision?: number | null;
  rules?: unknown | null;
  status?: string | null;
}
/** 由可追溯成长事实汇总的个人或队伍运动成长；可重建，不是原始事实 */
export interface GrowthProfileObject {
  id: SportsLong | null;
  owner_type?: string | null;
  owner_id?: SportsLong | null;
  sport_id?: SportsLong | null;
  points?: number | null;
  checkin_count?: number | null;
  finish_count?: number | null;
  policy_version?: string | null;
}
/** 非竞技成长事实；规则有来源，防止刷空赛事 */
export interface GrowthRecordObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  person_id?: SportsLong | null;
  team_id?: SportsLong | null;
  policy_version?: string | null;
  achievement?: string | null;
  source?: unknown | null;
  status?: string | null;
  sport_id?: SportsLong | null;
  event_id?: SportsLong | null;
  milestone?: string | null;
  points_delta?: number | null;
  source_key?: string | null;
}
/** 分级荣誉及来源；当前佩戴不替代历史获得记录 */
export interface HonorObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_id?: SportsLong | null;
  registration_id?: SportsLong | null;
  person_id?: SportsLong | null;
  team_id?: SportsLong | null;
  award_key?: string | null;
  category?: string | null;
  title?: string | null;
  source?: unknown | null;
  status?: string | null;
  awarded_at?: string | null;
  display_until?: string | null;
  applicant_account_id?: SportsLong | null;
  certification_status?: string | null;
  certification_details?: unknown | null;
  verified_snapshot?: unknown | null;
  certification_history?: unknown | null;
  certification_public?: boolean | null;
  certification_worn?: boolean | null;
  sport_id?: SportsLong | null;
  title_code?: string | null;
}
/** 每参赛单位原始成绩及单位；零与缺失/未完赛分开 */
export interface ResultItemObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  result_version_id?: SportsLong | null;
  match_entry_id?: SportsLong | null;
  performance_status?: string | null;
  value?: SportsMoney | null;
  unit?: string | null;
  components?: unknown | null;
}
/** 原始表现、有效性、专业确认及修订链 */
export interface ResultVersionObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  match_id?: SportsLong | null;
  revision?: number | null;
  previous_id?: SportsLong | null;
  status?: string | null;
  raw_performance?: unknown | null;
  decision?: unknown | null;
  confirmer_id?: SportsLong | null;
  confirmed_at?: string | null;
  published_at?: string | null;
}
/** 本人或队长选择当前佩戴的成长称号；授予来源由荣誉事实保留 */
export interface TitleEquipmentObject {
  id: SportsLong | null;
  owner_type?: string | null;
  owner_id?: SportsLong | null;
  sport_id?: SportsLong | null;
  title_code?: string | null;
  honor_id?: SportsLong | null;
  frame_style?: string | null;
}
/** 业务通知内容版本及对象；不可夹带未授权营销 */
export interface NotificationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  recipient_account_id?: SportsLong | null;
  business_type?: string | null;
  business_id?: SportsLong | null;
  business_revision?: number | null;
  purpose?: string | null;
  content?: unknown | null;
  dedupe_key?: string | null;
  read_at?: string | null;
  confirmed_at?: string | null;
  response?: unknown | null;
}
/** 逐渠道发送和送达结果；失败需责任人跟进 */
export interface NotificationDeliveryObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  notification_id?: SportsLong | null;
  channel?: string | null;
  attempt?: number | null;
  status?: string | null;
  channel_reference?: string | null;
  sent_at?: string | null;
  delivered_at?: string | null;
  failure_reason?: string | null;
}
/** 可分配资源单元及容量；整体和半场不能重复占用 */
export interface ResourceObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  venue_id?: SportsLong | null;
  parent_id?: SportsLong | null;
  name?: string | null;
  resource_type?: string | null;
  capacity?: number | null;
  capacity_unit?: string | null;
  status?: string | null;
  sport_scope?: unknown | null;
}
/** 赛事资源使用确认；不冒充商业预约交易 */
export interface ResourceReservationObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  resource_id?: SportsLong | null;
  event_id?: SportsLong | null;
  starts_at?: string | null;
  ends_at?: string | null;
  quantity?: number | null;
  status?: string | null;
  confirmation?: unknown | null;
}
/** 场馆及实际管理责任 */
export interface VenueObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  name?: string | null;
  address?: string | null;
  operator?: string | null;
  contact_cipher?: string | null;
  status?: string | null;
}
/** 登录本人对特定能力、输入摘要和对象版本的一次确认 */
export interface ActionConfirmationObject {
  id: SportsLong | null;
  run_id?: SportsLong | null;
  actor_type?: string | null;
  actor_id?: SportsLong | null;
  action_code?: string | null;
  payload_hash?: string | null;
  object_versions?: unknown | null;
  status?: string | null;
  expires_at?: string | null;
  confirmed_at?: string | null;
}
/** 统一动作终态回执；成功与业务同事务，失败独立留痕，不存私有完整响应 */
export interface ActionExecutionObject {
  id: SportsLong | null;
  action_code?: string | null;
  actor_type?: string | null;
  actor_id?: SportsLong | null;
  tenant_scope?: string | null;
  channel?: string | null;
  request_key?: string | null;
  payload_hash?: string | null;
  status?: string | null;
  result_reference?: unknown | null;
  error_code?: string | null;
  run_id?: SportsLong | null;
  occurred_at?: string | null;
}
/** 智能体定义，按平台、业务域和职能分层；没有原始SQL能力 */
export interface AgentObject {
  id: SportsLong | null;
  code?: string | null;
  name?: string | null;
  layer?: string | null;
  domain_scope?: string | null;
  status?: string | null;
}
/** 智能体能力及委派上限；与委托人实时权限取交集 */
export interface AgentGrantObject {
  id: SportsLong | null;
  agent_id?: SportsLong | null;
  capability_code?: string | null;
  scope?: unknown | null;
  status?: string | null;
}
/** 本人可恢复的可见对话；用途受控，不向其他人共享 */
export interface AgentMessageObject {
  id: SportsLong | null;
  run_id?: SportsLong | null;
  role?: string | null;
  content?: string | null;
  blocks?: unknown | null;
}
/** 服务端签发的运行身份与进度；不保存密钥或隐藏思考 */
export interface AgentRunObject {
  id: SportsLong | null;
  agent_version_id?: SportsLong | null;
  actor_type?: string | null;
  actor_id?: SportsLong | null;
  parent_run_id?: SportsLong | null;
  root_run_id?: SportsLong | null;
  scope?: unknown | null;
  goal?: string | null;
  status?: string | null;
  depth?: number | null;
  tool_count?: number | null;
  tokens_used?: number | null;
  tokens_reserved?: number | null;
  round_key?: string | null;
  token_hash?: string | null;
  expires_at?: string | null;
  started_at?: string | null;
  ended_at?: string | null;
  stop_reason?: string | null;
}
/** 可见模型、工具和委派步骤摘要，不包含材料正文和隐藏思考 */
export interface AgentStepObject {
  id: SportsLong | null;
  run_id?: SportsLong | null;
  sequence?: number | null;
  kind?: string | null;
  name?: string | null;
  status?: string | null;
  summary?: unknown | null;
}
/** 智能体提示词与模型的可追溯版本；只记录可见业务指引 */
export interface AgentVersionObject {
  id: SportsLong | null;
  agent_id?: SportsLong | null;
  revision?: number | null;
  model_name?: string | null;
  instruction?: string | null;
  budget?: unknown | null;
  status?: string | null;
  tool_catalog?: unknown | null;
  skill_catalog?: unknown | null;
  business_map?: unknown | null;
  playbook_hash?: string | null;
}
/** 关键业务决定与资料访问审计；不写入原始敏感材料 */
export interface AuditEventObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  actor_account_id?: SportsLong | null;
  action?: string | null;
  object_type?: string | null;
  object_id?: SportsLong | null;
  request_id?: string | null;
  occurred_at?: string | null;
  summary?: unknown | null;
}
/** 能力在人工、Agent和系统渠道的明确开放指针 */
export interface CapabilityActivationObject {
  id: SportsLong | null;
  code?: string | null;
  capability_version_id?: SportsLong | null;
  channel?: string | null;
  enabled?: boolean | null;
}
/** 经过实现与测试的能力版本；描述不是授权 */
export interface CapabilityVersionObject {
  id: SportsLong | null;
  code?: string | null;
  revision?: number | null;
  definition?: unknown | null;
  source_hash?: string | null;
  status?: string | null;
}
/** 重大变更旧新版本、影响及责任接续 */
export interface ChangeCaseObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  object_type?: string | null;
  object_id?: SportsLong | null;
  before_snapshot?: unknown | null;
  after_snapshot?: unknown | null;
  impact?: unknown | null;
  status?: string | null;
  reason?: string | null;
}
/** 平台投诉、反馈及分派；专业结果争议移交申诉 */
export interface ComplaintObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  applicant_account_id?: SportsLong | null;
  object_type?: string | null;
  object_id?: SportsLong | null;
  request?: string | null;
  evidence?: unknown | null;
  status?: string | null;
  owner_id?: SportsLong | null;
  resolution?: unknown | null;
}
/** 投诉回复、处理与重新打开的追加记录；只向获授权当事方展示 */
export interface ComplaintMessageObject {
  id: SportsLong | null;
  complaint_id?: SportsLong | null;
  actor_type?: string | null;
  actor_id?: SportsLong | null;
  action?: string | null;
  message?: string | null;
  occurred_at?: string | null;
}
/** 个人资料查询、更正、撤回、注销及删除请求 */
export interface DataRequestObject {
  id: SportsLong | null;
  account_id?: SportsLong | null;
  person_id?: SportsLong | null;
  request_type?: string | null;
  scope?: unknown | null;
  status?: string | null;
  resolution?: unknown | null;
}
/** 共享文件元数据；无永久公开凭据，访问由用途授权 */
export interface FileObject {
  id: SportsLong | null;
  owner_account_id?: SportsLong | null;
  owning_tenant_id?: string | null;
  object_key?: string | null;
  sha256?: string | null;
  purpose?: string | null;
  sensitivity?: string | null;
  retain_until?: string | null;
  status?: string | null;
}
/** 请求去重及不确定响应恢复；不得只靠页面按钮防重 */
export interface IdempotencyObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  account_id?: SportsLong | null;
  operation?: string | null;
  request_key?: string | null;
  payload_hash?: string | null;
  status?: string | null;
  result_reference?: unknown | null;
  expires_at?: string | null;
}
/** 旧系统来源、授权及数量金额差异核对 */
export interface MigrationBatchObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  source_system?: string | null;
  source_version?: string | null;
  authorization_snapshot?: unknown | null;
  reconciliation?: unknown | null;
  status?: string | null;
  cutover_at?: string | null;
}
/** 旧新记录映射、差异及未完责任；不虚构调平 */
export interface MigrationMappingObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  batch_id?: SportsLong | null;
  object_type?: string | null;
  source_key?: string | null;
  target_id?: SportsLong | null;
  status?: string | null;
  difference?: unknown | null;
}
/** 本地事务提交的跨模块通知/事件；消费必须幂等 */
export interface OutboxObject {
  id: SportsLong | null;
  tenant_id?: string | null;
  event_key?: string | null;
  aggregate_type?: string | null;
  aggregate_id?: SportsLong | null;
  aggregate_revision?: number | null;
  event_type?: string | null;
  payload?: unknown | null;
  status?: string | null;
  attempts?: number | null;
  next_attempt_at?: string | null;
}
