import { reactive } from 'vue';

export interface AuthValues {
  phone: string;
  password: string;
  confirmPassword?: string;
  smsCode?: string;
  code?: string;
}
export interface AuthOptions {
  newPassword?: boolean;
  sms?: boolean;
  captcha?: () => boolean;
}
export function authFieldError(field: string, values: AuthValues, options: AuthOptions): string {
  if (field === 'phone') return !values.phone ? '请输入手机号' : !/^1[3-9]\d{9}$/.test(values.phone) ? '请输入中国大陆11位手机号' : '';
  if (field === 'password') {
    if (!values.password) return options.newPassword ? '请输入新密码' : '请输入密码';
    if (options.newPassword && (values.password.length < 5 || values.password.length > 20)) return '密码长度为5到20位';
    if (options.newPassword && /[<>"'|\\]/.test(values.password)) return '密码不能包含 < > " \' \\ |';
  }
  if (field === 'confirmPassword' && options.newPassword)
    return !values.confirmPassword ? '请再次输入密码' : values.confirmPassword !== values.password ? '两次密码不一致' : '';
  if (field === 'smsCode' && options.sms) return !values.smsCode ? '请输入验证码' : !/^\d{6}$/.test(values.smsCode) ? '验证码为6位数字' : '';
  if (field === 'code' && options.captcha?.() && !values.code) return '请输入图形验证码';
  return '';
}
/** Validate on blur/submit. Loading a captcha must never mark untouched fields as invalid. */
export function useAuthFields(values: AuthValues, options: AuthOptions = {}) {
  const errors = reactive<Record<string, string>>({});
  function validateField(field: string) {
    errors[field] = authFieldError(field, values, options);
  }
  function validate() {
    const fields = [
      'phone',
      'password',
      ...(options.newPassword ? ['confirmPassword'] : []),
      ...(options.sms ? ['smsCode'] : []),
      ...(options.captcha?.() ? ['code'] : [])
    ];
    fields.forEach(validateField);
    return fields.every((field) => !errors[field]);
  }
  return { errors, validateField, validate };
}
