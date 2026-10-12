import request from '@/utils/request';

export interface PersonCard {
  personId: string;
  legalName: string;
  displayName?: string;
  birthDate?: string;
  gender: string;
  mobile?: string;
  idDocType?: string;
  idNumber?: string;
  city?: string;
  addressDetail?: string;
  bloodType?: string;
  clothingSize?: string;
  emergencyContactName?: string;
  emergencyContactPhone?: string;
  boundToMe: boolean;
}

export interface IdentityHome {
  loginPhone?: string | null;
  accountId: string;
  displayName: string;
  self?: PersonCard;
}

export interface PersonRequest {
  legalName: string;
  birthDate?: string;
  gender?: string;
  mobile: string;
  idDocType?: string;
  idNumber?: string;
  city?: string;
  addressDetail?: string;
  bloodType?: string;
  clothingSize?: string;
  emergencyContactName?: string;
  emergencyContactPhone?: string;
}

export const getIdentity = () => request({ url: '/sports/c/identity', method: 'get' });

export const bindSelf = (data: PersonRequest) => request({ url: '/sports/c/identity/self', method: 'post', data });

export const changePlatformPassword = (oldPassword: string, newPassword: string) =>
  request({
    url: '/sports/c/identity/password',
    method: 'put',
    headers: {
      isEncrypt: true,
      repeatSubmit: false
    },
    data: { oldPassword, newPassword }
  });
