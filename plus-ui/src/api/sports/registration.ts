import request from '@/utils/request';
import type { InvitationDelivery } from '@/utils/invitation';

export interface UnitCard {
  id: string;
  eventId: string;
  name: string;
  entryType: string;
  minMembers: number;
  maxMembers: number;
  limitCount: number;
  usedCount: number;
}

export interface MemberCard {
  id: string;
  accountId: string;
  status: string;
  selfMember: boolean;
  legalName: string | null;
  inviteToken: string | null;
  notice?: InvitationDelivery | null;
  /** 当前已授权邀请对象的展示名；不是本人已确认的参赛快照。 */
  invitationName?: string | null;
  /** 仅报名办理人可见的手机末四位。 */
  mobileTail?: string | null;
}

export interface SubmittedMember {
  id: string; legalName: string; gender: string; birthDate: string; mobile: string;
  fieldsCaptured: boolean; fields: { label: string; value: string }[];
}
export const getSubmittedRoster = (id: string) => request({ url: `/sports/b/registrations/${id}/submitted-roster`, method: 'get' });

export interface EntryCard {
  maxMembers?: number;
  id: string;
  eventId: string;
  unitId: string;
  unitName: string;
  entryType: string;
  status: string;
  requestKey: string;
  rosterRevision: number;
  requestKeyConsumed: boolean;
  submittedAt: string | null;
  members: MemberCard[];
  teamId: string | null;
  teamName: string | null;
  canManage: boolean;
  feeAmount: number | null;
  paymentMode: string | null;
  obligationStatus: string | null;
  payInstruction: string | null;
  obligationId: string | null;
  paymentDeclared: boolean;
  pendingActionId: string | null;
  eventHolding: string | null;
  eventPublication: string | null;
  declarationConfirmRequired?: boolean;
  declarationText?: string | null;
  declarationImageAvailable?: boolean;
  declarationAcknowledged?: boolean;
  fundsPending?: boolean;
}

export const feeLabel = (entry: EntryCard) => {
  if (!entry.obligationStatus) {
    return '';
  }
  if (entry.obligationStatus === 'not_required' || entry.paymentMode === 'free') {
    return '免费';
  }
  const amount = entry.feeAmount == null ? '' : `¥${entry.feeAmount}`;
  const mode = entry.paymentMode === 'organizer_qr' ? '运营方二维码' : entry.paymentMode === 'offline' ? '线下付款' : '';
  const state = entry.obligationStatus === 'open' && entry.paymentDeclared
    ? '待确认到账'
    : (({ open: '待付款', settled: '已付款', void: '已失效' } as Record<string, string>)[entry.obligationStatus] || '');
  return [amount, mode, state].filter(Boolean).join(' · ');
};

export interface ManagedEventOption {
  eventId: string;
  name: string | null;
  publicationStatus: string;
  holdingStatus: string;
  unitOpen: boolean;
}

export interface InviteView {
  /** 仅本人收到的邀请列表返回；打开详情仍由服务端校验本人身份。 */
  inviteToken?: string | null;
  registrationId: string;
  eventId: string | null;
  eventName: string;
  unitName: string;
  entryType: string;
  registrationStatus: string;
  memberStatus: string;
  canRespond: boolean;
  inviteeName?: string | null;
  inviteeMobileTail?: string | null;
  initiatorName?: string | null;
  members?: { legalName: string | null; status: string; selfMember: boolean }[];
  declarationConfirmRequired?: boolean;
  declarationText?: string | null;
  declarationImageAvailable?: boolean;
  declarationAcknowledged?: boolean;
}

export const inviteSituation = (row: InviteView) => {
  if (row.registrationStatus === 'approved') {
    return '承办方已通过这条报名。';
  }
  if (row.registrationStatus === 'submitted') {
    return '邀请人已提交，正在等待承办方审核。';
  }
  if (row.registrationStatus === 'rejected') {
    return row.memberStatus === 'pending_confirmation'
      ? '承办方已拒绝。你可以重新确认，邀请人才能再次提交。'
      : '承办方已拒绝。邀请人可以修改后重新提交。';
  }
  if (row.memberStatus === 'pending_confirmation') {
    return '邀请人还没提交。确认参加后，对方才能提交这条报名。';
  }
  if (row.memberStatus === 'confirmed') {
    return '你已确认参加。邀请人还没提交报名。';
  }
  return '你已拒绝参加。邀请人还没提交报名。';
};

export const entryTypeLabel = (value: string) => ({ individual: '单打', pair: '双打', team: '团体' })[value] || value;

export const entryStatusLabel = (value: string) =>
  ({ draft: '草稿', submitted: '已提交', approved: '已通过', rejected: '已拒绝', withdrawn: '已撤回' })[value] || value;

export const memberStatusLabel = (value: string) =>
  ({ pending_confirmation: '待确认', confirmed: '已确认', declined: '已拒绝' })[value] || value;

export const listPublicUnits = (eventId: string) => request({ url: '/sports/c/registrations/units', method: 'get', params: { eventId } });

export const listMyEntries = (eventId?: string) =>
  request({ url: '/sports/c/registrations', method: 'get', params: eventId ? { eventId } : {} });

export const listReceivedInvites = () => request({ url: '/sports/c/registrations/received', method: 'get' });

export const createEntry = (unitId: string, requestKey: string, teamId?: string, memberAccountIds?: string[]) =>
  request({ url: '/sports/c/registrations', method: 'post', data: { unitId, requestKey, teamId: teamId || undefined, memberAccountIds } });

export const addTeammate = (registrationId: string, accountId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/roster', method: 'post', data: { accountId } });

export const inviteMember = (registrationId: string, phone: string, requestSms = false) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/members', method: 'post', data: { phone, requestSms } });

export const removeMember = (registrationId: string, memberId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/members/' + memberId, method: 'delete' });

export const remindRegistrationInvite = (registrationId: string, memberId: string) =>
  request({ url: `/sports/c/registrations/${registrationId}/members/${memberId}/remind`, method: 'post' });

export const submitEntry = (registrationId: string, requestKey: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/submit', method: 'post', data: { requestKey } });

export const withdrawEntry = (registrationId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/withdraw', method: 'post' });

export const deleteRegistrationDraft = (registrationId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId, method: 'delete' });

export const declarePaid = (registrationId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/payment-declared', method: 'post' });

export interface PaymentProof { id: string; obligationId: string; fileId: string; uploadedAt: string }
export const listPaymentProofs = (registrationId: string, organizer = false) =>
  request({ url: `/sports/${organizer ? 'b' : 'c'}/registrations/${registrationId}/payment-proofs`, method: 'get' });
export const paymentProofImage = (registrationId: string, proofId: string, organizer = false) =>
  request({ url: `/sports/${organizer ? 'b' : 'c'}/registrations/${registrationId}/payment-proofs/${proofId}/image`, method: 'get', responseType: 'blob' });
export const uploadPaymentProof = (registrationId: string, file: File, requestKey: string) => {
  const data = new FormData(); data.append('file', file);
  return request({ url: `/sports/c/registrations/${registrationId}/payment-proofs`, method: 'post', params: { requestKey }, data,
    headers: { 'Content-Type': 'multipart/form-data', repeatSubmit: false } });
};

export const getInvite = (token: string) => request({ url: '/sports/c/registrations/invites/' + token, method: 'get' });

export const acknowledgeDeclaration = (registrationId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/declaration-ack', method: 'post' });

export const registrationDeclarationImage = (registrationId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/declaration-image', method: 'get', responseType: 'blob' });

export const confirmInvite = (token: string) =>
  request({ url: '/sports/c/registrations/invites/' + token + '/confirm', method: 'post' });

export const declineInvite = (token: string) =>
  request({ url: '/sports/c/registrations/invites/' + token + '/decline', method: 'post' });

export const listRegistrationEvents = () => request({ url: '/sports/b/registrations/events', method: 'get' });

export const listManagedUnits = (eventId: string) =>
  request({ url: '/sports/b/registrations/units', method: 'get', params: { eventId } });

export const createUnit = (data: {
  eventId: string;
  name: string;
  entryType: string;
  minMembers: number | null;
  maxMembers: number | null;
  limitCount: number;
  requestKey: string;
  charged: boolean;
  amount: number;
  paymentMode: string;
  payInstruction: string;
  qrFileId?: string | null;
}) => request({ url: '/sports/b/registrations/units', method: 'post', data });

export const listUnitEntries = (unitId: string) =>
  request({ url: '/sports/b/registrations/units/' + unitId + '/entries', method: 'get' });

export const approveEntry = (registrationId: string) =>
  request({ url: '/sports/b/registrations/' + registrationId + '/approve', method: 'post' });

export const rejectEntry = (registrationId: string, reason: string) =>
  request({ url: '/sports/b/registrations/' + registrationId + '/reject', method: 'post', data: { reason } });

export const adjustUnitLimit = (unitId: string, limitCount: number) =>
  request({ url: '/sports/b/registrations/units/' + unitId + '/limit', method: 'post', data: { limitCount } });

export const updateUnit = (id: string, data: { name: string; entryType: string; minMembers: number; maxMembers: number }) => request({ url: '/sports/b/registrations/units/' + id + '/edit', method: 'post', data });
export const removeUnit = (id: string) => request({ url: '/sports/b/registrations/units/' + id + '/remove', method: 'post' });
