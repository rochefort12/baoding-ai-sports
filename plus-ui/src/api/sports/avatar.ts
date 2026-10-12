import request from '@/utils/request';

/** 裁剪后的本人头像；文件用途、身份与版本均由服务端核对。 */
export const uploadSportsAvatar = (file: Blob, expectedVersion: number) => {
  const data = new FormData();
  data.append('file', file, 'sports-avatar.png');
  return request<{ fileId: string; version: number }>({
    url: '/sports/display/avatar', method: 'post', params: { expectedVersion }, data,
    headers: { 'Content-Type': 'multipart/form-data', repeatSubmit: false }
  });
};

export const readSportsAvatar = (accountId: string) =>
  request<Blob>({ url: `/sports/display/avatar/${accountId}`, responseType: 'blob' });

export const publicSportsAvatarUrl = (accountId: string) =>
  `${import.meta.env.VITE_APP_BASE_API}/sports/display/public/${accountId}/avatar`;
