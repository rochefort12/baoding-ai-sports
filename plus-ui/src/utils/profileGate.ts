import type { Router } from 'vue-router';
import { getIdentity, IdentityHome } from '@/api/sports/identity';
import { sanitizeReturnTo } from '@/utils/returnTo';

const today = () => {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${now.getFullYear()}-${month}-${day}`;
};

/** 与服务端报名快照条件一致：姓名、出生日期、性别、已验证手机号。选填资料不在这里拦截。 */
export const profileReady = (home: IdentityHome | null | undefined): boolean => {
  const self = home?.self;
  const phone = home?.loginPhone || self?.mobile || '';
  if (!self?.legalName?.trim() || !self.birthDate || !self.gender?.trim()) {
    return false;
  }
  if (self.birthDate > today()) {
    return false;
  }
  return /^1[3-9]\d{9}$/.test(phone);
};

/** 返回 false 表示已经改去档案页。调用方不要继续创建报名或入队。 */
export const ensureProfile = async (router: Router, returnTo: string): Promise<boolean> => {
  const res = await getIdentity();
  if (profileReady(res.data)) {
    return true;
  }
  await router.push({ path: '/portal/identity', query: { returnTo: sanitizeReturnTo(returnTo) } });
  return false;
};
