import request from '@/utils/request';

export interface PromotionFee {
  name: string;
  amount: string;
  mode: string;
}

export interface PromotionCard {
  copySource?: 'basic' | 'ai';
  eventName?: string;
  projectName?: string;
  imageEnabled?: boolean;
  visualFileId?: string | null;
  visualStyle?: string;
  visualStale?: boolean;
  saved: boolean;
  stale: boolean;
  published: boolean;
  cancelled: boolean;
  imageAvailable: boolean;
  headline: string;
  invitation: string;
  groupBody: string;
  momentsCaption: string;
  groupPath: string;
  momentsPath: string;
  posterPath: string;
  whenText: string;
  location: string;
  organizationName: string;
  contactName: string;
  contactMethod: string;
  refundNote: string;
  bannerFileId: string | null;
  fees: PromotionFee[];
  factDigest: string;
}

export const getPromotion = (eventId: string) =>
  request<PromotionCard>({ url: '/sports/b/events/' + eventId + '/promotion', method: 'get' });

export const generatePromotion = (eventId: string, consent: boolean, note: string) =>
  request<PromotionCard>({
    url: '/sports/b/events/' + eventId + '/promotion',
    method: 'post',
    data: { consent, note },
    timeout: 75000,
    headers: { repeatSubmit: false }
  });

export const generatePromotionVisual = (eventId: string, data: { consent: boolean; style: string; audience: string; keywords: string }) =>
  request<PromotionCard>({ url: '/sports/b/events/' + eventId + '/promotion/visual', method: 'post', data, timeout: 205000, headers: { repeatSubmit: false } });
