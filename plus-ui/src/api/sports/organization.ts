import request from '@/utils/request';
import { sanitizeOrganizerTarget } from '@/utils/returnTo';
import { getPlatformToken, getToken, setPlatformToken, setToken, removePlatformToken } from '@/utils/auth';

export interface OrgFile {
  fileId: string;
  fileName: string;
}

export interface OrgVersion {
  revision: number;
  status: string;
  name: string;
  contactName: string;
  contactMethod: string;
  statement: string;
  files: OrgFile[];
  reviewReason: string;
}

export interface OrgApplication {
  applicationId: string | null;
  status: string | null;
  name: string | null;
  contactName: string | null;
  contactMethod: string | null;
  statement: string | null;
  files: OrgFile[];
  reviewReason: string | null;
  organizationId: string | null;
  canEnter: boolean;
  versions: OrgVersion[];
}

export interface OrgDraft {
  name: string;
  contactName: string;
  contactMethod: string;
  statement: string;
  fileIds: string[];
}

export interface PendingApplication {
  applicationId: string;
  name: string;
  contactName: string;
  revision: number;
}

export const getApplication = () => request({ url: '/sports/c/organization/application', method: 'get' });

export const saveApplication = (data: OrgDraft) => request({ url: '/sports/c/organization/application', method: 'put', data });

export const submitApplication = (data: OrgDraft) => request({ url: '/sports/c/organization/application/submit', method: 'post', data });

export const uploadApplicationFile = (file: File) => {
  const data = new FormData();
  data.append('file', file);
  return request({
    url: '/sports/c/organization/files',
    method: 'post',
    data,
    headers: { 'Content-Type': 'multipart/form-data', repeatSubmit: false }
  });
};

export const downloadOwnFile = (fileId: string) => request({ url: '/sports/c/organization/files/' + fileId, method: 'get', responseType: 'blob' });

export const listPending = () => request({ url: '/sports/organization-review/pending', method: 'get' });

export const getReview = (applicationId: string) => request({ url: '/sports/organization-review/' + applicationId, method: 'get' });

export const approveReview = (applicationId: string) => request({ url: '/sports/organization-review/' + applicationId + '/approve', method: 'post' });

export const rejectReview = (applicationId: string, reason: string) =>
  request({ url: '/sports/organization-review/' + applicationId + '/reject', method: 'post', data: { reason } });

export const downloadReviewFile = (applicationId: string, fileId: string) =>
  request({
    url: '/sports/organization-review/' + applicationId + '/files/' + fileId,
    method: 'get',
    responseType: 'blob'
  });

export const enterOrganization = async () => {
  const current = getToken();
  const res = await request({ url: '/auth/organization/enter', method: 'post' });
  if (current) {
    setPlatformToken(current);
  }
  setToken(res.data.access_token);
  const target = sanitizeOrganizerTarget(sessionStorage.getItem('organizerReturnTo'));
  sessionStorage.removeItem('organizerReturnTo');
  window.location.href = target;
};

export const returnToPlatform = (target = '/portal/home') => {
  const platform = getPlatformToken();
  if (!platform) {
    window.location.href = '/portal/home';
    return;
  }
  setToken(platform); removePlatformToken();
  window.location.href = target.startsWith('/portal/') || target.startsWith('/public/events') ? target : '/portal/home';
};

export const saveBlob = (blob: Blob, fileName: string) => {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  link.click();
  URL.revokeObjectURL(url);
};
