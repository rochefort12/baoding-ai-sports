import { describe, expect, it } from 'vitest';
import { canDeleteRegistrationDraft } from './registrationDraft';

const draft = {
  canManage: true,
  status: 'draft',
  submittedAt: null,
  requestKeyConsumed: false,
  obligationId: null,
  obligationStatus: null,
  paymentDeclared: false
};

describe('报名草稿删除入口', () => {
  it('从未提交的本人草稿可以显示删除', () => {
    expect(canDeleteRegistrationDraft(draft)).toBe(true);
  });

  it('已提交、已通过、已撤回或已有付款义务不显示删除', () => {
    expect(canDeleteRegistrationDraft({ ...draft, status: 'submitted', submittedAt: '2026-10-09T10:00:00+08:00', requestKeyConsumed: true })).toBe(false);
    expect(canDeleteRegistrationDraft({ ...draft, status: 'approved' })).toBe(false);
    expect(canDeleteRegistrationDraft({ ...draft, status: 'withdrawn' })).toBe(false);
    expect(canDeleteRegistrationDraft({ ...draft, requestKeyConsumed: true })).toBe(false);
    expect(canDeleteRegistrationDraft({ ...draft, obligationId: '801', obligationStatus: 'open' })).toBe(false);
    expect(canDeleteRegistrationDraft({ ...draft, canManage: false })).toBe(false);
  });
});