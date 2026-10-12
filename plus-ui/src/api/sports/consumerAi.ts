import request from '@/utils/request';
export interface PublicAiSource {
  eventId: string;
  name: string;
  projectName: string | null;
  location: string | null;
  startsAt: string | null;
  registrationClosesAt: string | null;
  phase: string | null;
  holdingStatus: string;
  feeDescription: string | null;
  href: string;
}
export interface PublicAiReply {
  reply: string;
  sources: PublicAiSource[];
  hasMore: boolean;
  refreshedAt: string;
}
/** 已登录时带上当前令牌，便于同一段对话读取本人报名；匿名请求没有令牌。 */
export const askConsumerAi = (data: { eventId?: string; message: string; consent: boolean; history?: { user: boolean; text: string }[] }) =>
  request<PublicAiReply>({ url: '/sports/public/ai/assistant', method: 'post', data, timeout: 100000, headers: { repeatSubmit: false } });
