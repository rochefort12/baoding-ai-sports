import request from '@/utils/request';
import { businessTime } from '@/utils/business';

export interface EventCard {
  id: string;
  name: string | null;
  location: string | null;
  projectName: string | null;
  feeDescription: string | null;
  contactName?: string | null;
  contactMethod?: string | null;
  refundTerms?: string | null;
  registrationOpensAt: string | null;
  registrationClosesAt: string | null;
  startsAt: string | null;
  endsAt: string | null;
  publicationStatus: string;
  holdingStatus: string;
  phase: string | null;
  cancelReason: string | null;
  editable: boolean;
  registrationReview: string;
  registrationReviewLocked: boolean;
  bannerFileId: string | null;
  rulesText: string | null;
  rulesFileId: string | null;
  noticeText: string | null;
  noticeFileId: string | null;
  declarationText: string | null;
  declarationFileId: string | null;
  declarationAckRequired?: boolean;
  routeText: string | null;
  routeFileId: string | null;
}

export interface EventDraft {
  name: string;
  location: string;
  projectName: string;
  feeDescription: string;
  contactName?: string | null;
  contactMethod?: string | null;
  refundTerms?: string | null;
  registrationOpensAt: string;
  registrationClosesAt: string;
  startsAt: string;
  endsAt: string;
  registrationReview: string;
  bannerFileId?: string | null;
  rulesText?: string | null;
  rulesFileId?: string | null;
  noticeText?: string | null;
  noticeFileId?: string | null;
  declarationText?: string | null;
  declarationFileId?: string | null;
  declarationAckRequired?: boolean;
  routeText?: string | null;
  routeFileId?: string | null;
}

export const listManagedEvents = () => request({ url: '/sports/b/events', method: 'get' });
export const getManagedEvent = (id: string) => request<EventCard>({ url: '/sports/b/events/' + id, method: 'get' });

export const createEvent = (data: EventDraft) => request({ url: '/sports/b/events', method: 'post', data });

export const updateEvent = (id: string, data: EventDraft) => request({ url: '/sports/b/events/' + id, method: 'put', data });

export const changeRegistrationReview = (id: string, registrationReview: string) =>
  request({ url: '/sports/b/events/' + id + '/registration-review', method: 'post', data: { registrationReview } });

export const publishEvent = (id: string, requestKey: string, contactName: string, contactMethod: string, expectedVersion?: number, expectedPreviewHash?: string) =>
  // 窗口已有进行中保护，服务端按请求键幂等；失败后允许立即重试同一次发布。
  request<EventCard>({ url: '/sports/b/events/' + id + '/publish', method: 'post', headers: { repeatSubmit: false }, data: { requestKey, contactConfirmed: true, contactName, contactMethod, ...(expectedVersion == null ? {} : { expectedVersion }), ...(expectedPreviewHash ? { expectedPreviewHash } : {}) } });

export const offlineEvent = (id: string) => request({ url: '/sports/b/events/' + id + '/offline', method: 'post' });

export const cancelEvent = (id: string, reason: string) =>
  request({ url: '/sports/b/events/' + id + '/cancel', method: 'post', data: { reason } });

export const deleteEventDraft = (id: string) =>
  request({ url: '/sports/b/events/' + id + '/delete-draft', method: 'post' });

export const listPublicEvents = () =>
  request({ url: '/sports/public/events', method: 'get', headers: { isToken: false } });

export const getPublicEvent = (id: string) =>
  request({ url: '/sports/public/events/' + id, method: 'get', headers: { isToken: false } });

export const phaseLabel = (phase: string | null) => {
  const labels: Record<string, string> = {
    pre_registration: '报名前',
    registration: '报名中',
    registration_closed: '报名已截止',
    ongoing: '进行中',
    finished: '已结束'
  };
  return phase ? labels[phase] || phase : '时间未齐';
};

export const publicationLabel = (status: string) => {
  const labels: Record<string, string> = { draft: '草稿', published: '已发布', offline: '已下架' };
  return labels[status] || status;
};

export const showTime = (value: string | null) => {
  if (!value) {
    return '未填';
  }
  return businessTime(value);
};
