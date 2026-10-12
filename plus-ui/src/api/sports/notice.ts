import request from '@/utils/request';

export interface NoticeCard {
  id: string;
  purpose: string;
  title: string;
  body: string;
  businessType: string;
  businessId: string;
  read: boolean;
  targetPath?: string | null;
}

export const listNotices = () => request({ url: '/sports/c/notices', method: 'get' });

export const markNoticeRead = (id: string) => request({ url: '/sports/c/notices/' + id + '/read', method: 'post' });
