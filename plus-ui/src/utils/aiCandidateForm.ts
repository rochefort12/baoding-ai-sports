import type { AiTaskCard, ProposalField } from '@/api/sports/aiTask';
import { businessPickerTime } from '@/utils/business';

export const candidateFields = [
  { key: 'name', label: '赛事名称' },
  { key: 'projectName', label: '运动项目说明（发布必填）' },
  { key: 'location', label: '比赛地点' },
  { key: 'registrationOpensAt', label: '报名开始', date: true },
  { key: 'registrationClosesAt', label: '报名截止', date: true },
  { key: 'startsAt', label: '比赛开始', date: true },
  { key: 'endsAt', label: '比赛结束', date: true },
  { key: 'contactName', label: '公开联系人' },
  { key: 'contactMethod', label: '公开联系方式' },
  { key: 'feeDescription', label: '公开收费说明', long: true },
  { key: 'rulesText', label: '竞赛规程', long: true },
  { key: 'refundTerms', label: '退改说明', long: true },
  { key: 'declarationText', label: '参赛声明原文', long: true, optional: true }
];
export const unitFields = ['name', 'entryType', 'limitCount', 'minMembers', 'maxMembers', 'feeAmount', 'feeBasis'];

/** 回填项目必须逐项命中已创建的实际项目；缺失身份时只回填赛事字段。 */
export const candidateUnitIds = (units: { createdUnitId?: unknown }[] = []) => units.map(unit => String(unit.createdUnitId ?? ''));
export function canRestoreCandidateUnits(previous: string[], current: string[]) {
  return previous.length > 0 && previous.length === current.length && new Set(previous).size === previous.length &&
    previous.every((id, index) => /^[1-9]\d*$/.test(id) && id === current[index]);
}

export function readCandidateForm(task: AiTaskCard) {
  const proposal = JSON.parse(task.proposal || '{}');
  const value = (node?: ProposalField) => String(node?.value ?? '');
  const event: Record<string, string> = Object.fromEntries(Object.entries(proposal.event || {}).map(([key, node]) => [key, value(node as ProposalField)]));
  for (const field of candidateFields) {
    event[field.key] = field.date ? businessPickerTime(event[field.key] || '') : event[field.key] || '';
  }
  event.registrationReview ||= 'none';
  const units: Record<string, string>[] = (proposal.units || []).map((unit: Record<string, ProposalField>) =>
    Object.fromEntries(unitFields.map(key => [key, value(unit[key])]))
  );
  return { event, units, cover: proposal.cover ? { fileId: String(proposal.cover.fileId), index: proposal.cover.index } : { fileId: '0' }, proposal };
}

/** 明确点击“应用到所有项目”才覆盖；按整单金额保存，不从备注推测到账。 */
export function applyUniformCandidateValues(units: Record<string, string>[], price: string, capacity: string) {
  if (price.trim() && !/^\d+(?:\.\d{1,2})?$/.test(price.trim())) throw new Error('整单价格请填写非负金额，最多两位小数。');
  if (capacity.trim() && !/^[1-9]\d*$/.test(capacity.trim())) throw new Error('报名上限请填写至少 1 单的整数。');
  if (!price.trim() && !capacity.trim()) throw new Error('请填写整单价格或报名上限。');
  for (const unit of units) {
    if (price.trim()) { unit.feeAmount = price.trim(); unit.feeBasis = 'order'; }
    if (capacity.trim()) unit.limitCount = capacity.trim();
  }
}
