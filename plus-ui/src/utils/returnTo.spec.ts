import { describe, expect, it } from 'vitest';
import { PLATFORM_HOME, sanitizeAdminTarget, sanitizeReturnTo, sanitizeOrganizerTarget } from './returnTo';

describe('sanitizeReturnTo', () => {
  it('keeps an event and unit on the apply page', () => {
    expect(sanitizeReturnTo('/portal/registration/apply?eventId=12&unitId=34')).toBe(
      '/portal/registration/apply?eventId=12&unitId=34'
    );
  });

  it('keeps an event and unit on the registration page', () => {
    expect(sanitizeReturnTo('/portal/registration?eventId=12&unitId=34')).toBe('/portal/registration?eventId=12&unitId=34');
  });

  it('drops unrelated query values', () => {
    expect(sanitizeReturnTo('/portal/registration?eventId=12&phone=13900000000&smsCode=123456')).toBe(
      '/portal/registration?eventId=12'
    );
  });

  it('keeps an invite path and drops a non-numeric unit', () => {
    expect(sanitizeReturnTo('/portal/registration/invite/abc-DEF_1?unitId=no')).toBe('/portal/registration/invite/abc-DEF_1');
  });

  it('preserves a valid team share across login/profile and drops unrelated query parameters', () => {
    const target = '/portal/teams/join/' + 'a1'.repeat(32);
    expect(sanitizeReturnTo(target + '?phone=13900000000&redirect=https://evil.example')).toBe(target);
    expect(sanitizeReturnTo(encodeURIComponent(target))).toBe(target);
    for (const value of ['/portal/teams/join/short', '/portal/teams/join/' + 'G'.repeat(64), target + '/../../login'])
      expect(sanitizeReturnTo(value)).toBe(PLATFORM_HOME);
  });

  it('rejects external, protocol-relative, encoded and admin targets', () => {
    expect(sanitizeReturnTo('https://evil.example/portal/home')).toBe(PLATFORM_HOME);
    expect(sanitizeReturnTo('//evil.example')).toBe(PLATFORM_HOME);
    expect(sanitizeReturnTo('/\\evil.example')).toBe(PLATFORM_HOME);
    expect(sanitizeReturnTo('javascript:alert(1)')).toBe(PLATFORM_HOME);
    expect(sanitizeReturnTo('%2F%2Fevil.example')).toBe(PLATFORM_HOME);
    expect(sanitizeReturnTo('%252F%252Fevil.example')).toBe(PLATFORM_HOME);
    expect(sanitizeReturnTo('/index')).toBe(PLATFORM_HOME);
    expect(sanitizeReturnTo('/login?redirect=/portal/home')).toBe(PLATFORM_HOME);
    expect(sanitizeReturnTo('/portal/home/../../index')).toBe(PLATFORM_HOME);
  });
});

describe('sanitizeAdminTarget', () => {
  it('keeps an internal admin path', () => {
    expect(sanitizeAdminTarget('/system/user?pageNum=1')).toBe('/system/user?pageNum=1');
  });

  it('rejects external targets and auth pages', () => {
    expect(sanitizeAdminTarget('https://evil.example/index')).toBe('/index');
    expect(sanitizeAdminTarget('/portal/login')).toBe('/index');
    expect(sanitizeAdminTarget('//evil.example/index')).toBe('/index');
  });
});

describe('organizer task recovery', () => {
  it('restores registration, competition, complaint and closure tasks after session exchange', () => {
    expect(sanitizeOrganizerTarget('/org-desk/registrations?filter=refund')).toBe('/org-desk/registrations?filter=refund');
    expect(sanitizeOrganizerTarget('/org-desk/competition')).toBe('/org-desk/competition');
    expect(sanitizeOrganizerTarget('/org-desk/issues')).toBe('/org-desk/issues');
    expect(sanitizeOrganizerTarget('/org-desk/workspace/12?task=closure')).toBe('/org-desk/workspace/12?task=closure');
  });
  it('continues to reject external and platform targets and discards sensitive queries', () => {
    for (const target of ['//evil.example/org-desk/registrations','%252F%252Fevil.example','/sports-platform','/org-desk/../sports-platform'])
      expect(sanitizeOrganizerTarget(target)).toBe('/org-desk/home');
    expect(sanitizeOrganizerTarget('/org-desk/issues?phone=13900000000&smsCode=123456')).toBe('/org-desk/issues');
  });
});
