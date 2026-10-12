import request from '@/utils/request';

export const uploadOrganizerImage = (purpose: string, file: File) => {
  const data = new FormData();
  data.append('file', file);
  return request({
    url: '/sports/b/media',
    method: 'post',
    params: { purpose },
    data,
    headers: { 'Content-Type': 'multipart/form-data', repeatSubmit: false }
  });
};

export const publicMediaUrl = (eventId: string, slot: string) =>
  `${import.meta.env.VITE_APP_BASE_API}/sports/public/events/${eventId}/media/${slot}`;

export const paymentQrBlob = (registrationId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/payment-qr', method: 'get', responseType: 'blob' });
