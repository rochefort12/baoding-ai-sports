import type { EntryCard } from '@/api/sports/registration';

/** 只提示从未提交、且没有已知付款义务的本人草稿。最终能否删除由服务端复核。 */
export function canDeleteRegistrationDraft(entry: Pick<EntryCard, 'canManage' | 'status' | 'submittedAt' | 'requestKeyConsumed' | 'obligationId' | 'obligationStatus' | 'paymentDeclared'>) {
  return entry.canManage
    && entry.status === 'draft'
    && !entry.submittedAt
    && !entry.requestKeyConsumed
    && !entry.obligationId
    && !entry.paymentDeclared
    && entry.obligationStatus !== 'open';
}
