import { describe, expect, it, vi, afterEach } from 'vitest';
import { businessTime } from './business';
import { sanitizeReturnTo, sanitizeOrganizerTarget, reauthLocation } from './returnTo';

afterEach(() => vi.unstubAllGlobals());
describe('真实任务的登录恢复边界', () => {
  it('保留入队邀请，去掉手机号及未知参数', () => {
    expect(sanitizeReturnTo('/portal/teams/invitations/611?phone=fixture&redirect=/index')).toBe('/portal/teams/invitations/611');
  });
  it.each(['%25252f%25252fevil.example', '/portal/home%00', '/portal/home%5cfoo', '/org-desk/workspace/901', '/portal/home?x=%ZZ'])('拒绝编码绕过或组织地址 %s', (target) => {
    expect(sanitizeReturnTo(target)).toBe('/portal/home');
  });
  it('恢复组织赛事任务，同时过滤任意功能和越权地址', () => {
    expect(sanitizeOrganizerTarget('/org-desk/workspace/901?task=registrations&filter=refund&unitId=501&phone=fixture')).toBe('/org-desk/workspace/901?task=registrations&filter=refund&unitId=501');
    expect(sanitizeOrganizerTarget('/system/user')).toBe('/org-desk/home');
    expect(sanitizeOrganizerTarget('/org-desk/workspace/901?task=admin&filter=all&unitId=bad')).toBe('/org-desk/workspace/901');
  });
  it('会话过期先回平台登录，组织任务仅放会话中等待换取授权', () => {
    const setItem = vi.fn(); vi.stubGlobal('sessionStorage', {setItem});
    expect(reauthLocation('/org-desk/workspace/901?task=registrations')).toEqual({path:'/portal/login',query:{returnTo:'/portal/organization'}});
    expect(setItem).toHaveBeenCalledWith('organizerReturnTo','/org-desk/workspace/901?task=registrations');
    expect(reauthLocation('/portal/teams/invitations/611')).toEqual({path:'/portal/login',query:{returnTo:'/portal/teams/invitations/611'}});
  });
});
describe('资金记录北京时间', () => {
  it('UTC跨日边界按北京时间归属', () => {
    expect(businessTime('2026-10-07T15:59:00Z')).toMatch(/2026[\/-]10[\/-]07.*23:59/);
    expect(businessTime('2026-10-07T16:00:00Z')).toMatch(/2026[\/-]10[\/-]08.*00:00/);
  });
  it('既有无偏移响应与显式北京时间保持一致', () => {
    expect(businessTime('2026-10-08 09:20:00')).toBe(businessTime('2026-10-08T09:20:00+08:00'));
    expect(businessTime('2026-10-08')).toBe('2026-10-08');
  });
});
