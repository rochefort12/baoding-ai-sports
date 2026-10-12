import { describe, it, expect } from 'vitest';
import { authFieldError } from './useAuthFields';
const original = { phone: '13900000000', password: 'abcde', confirmPassword: 'abcde', smsCode: '123456', code: 'a1b2' };
describe('native auth form preserves server-facing validation boundaries', () => {
  it('requires an actual mainland mobile format', () => {
    expect(authFieldError('phone', { ...original, phone: '123' }, {})).toBeTruthy();
    expect(authFieldError('phone', original, {})).toBe('');
  });
  it('does not impose new password-creation rules on existing-account login', () => {
    expect(authFieldError('password', { ...original, password: 'old' }, {})).toBe('');
  });
  it('retains creation length limits', () => {
    for (const password of ['a', 'a'.repeat(21)]) expect(authFieldError('password', { ...original, password }, { newPassword: true })).toBeTruthy();
  });
  it('retains restricted characters', () => {
    for (const password of ['abc<de', 'abc\\de', 'abc|de'])
      expect(authFieldError('password', { ...original, password }, { newPassword: true })).toBeTruthy();
  });
  it('requires matching confirmation', () => {
    expect(authFieldError('confirmPassword', { ...original, confirmPassword: 'different' }, { newPassword: true })).toBeTruthy();
  });
  it('retains six-digit SMS requirement', () => {
    expect(authFieldError('smsCode', { ...original, smsCode: 'a23456' }, { sms: true })).toBeTruthy();
    expect(authFieldError('smsCode', original, { sms: true })).toBe('');
  });
  it('requires image code only when captcha is enabled', () => {
    expect(authFieldError('code', { ...original, code: '' }, { captcha: () => true })).toBeTruthy();
    expect(authFieldError('code', { ...original, code: '' }, { captcha: () => false })).toBe('');
  });
});
