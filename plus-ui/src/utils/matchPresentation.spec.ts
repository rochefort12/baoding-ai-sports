import { describe, expect, it } from 'vitest';
import { readMatchPerformance, recordedGameScores, recordedOutcomeLabel, recordedScorePair } from './matchPresentation';
import { businessPickerTime } from './business';

describe('录分展示保留完整原始内容', () => {
  it('标准三局按两方排列，含空格与中文冒号的原记录可阅读', () => {
    expect(recordedGameScores('21:18|18:21|21:17')).toEqual([{ a: '21', b: '18', number: 1 }, { a: '18', b: '21', number: 2 }, { a: '21', b: '17', number: 3 }]);
    expect(recordedScorePair(' 2 ： 1 ')).toEqual({ a: '2', b: '1' });
  });
  it.each(['21:18|退赛说明', '21:18|', '21:18|-1:4', '21:18|10000:4'])('自定义或异常原文不被部分解析丢失：%s', value => {
    expect(recordedGameScores(value)).toBeNull();
  });
  it('没有结果不能根据比分推断胜方', () => {
    expect(recordedOutcomeLabel()).toBe('未记录胜负');
    expect(recordedOutcomeLabel('draw')).toBe('平局');
    expect(recordedGameScores('')).toEqual([]);
  });
  it('损坏或非对象结果不伪装成已读取，保留自定义摘要', () => {
    expect(readMatchPerformance('{invalid')).toBeNull();
    expect(readMatchPerformance('[]')).toBeNull();
    expect(readMatchPerformance('{"summary":{"a":2}}')).toBeNull();
    expect(readMatchPerformance('{"summary":"对方退赛，核定获胜"}')?.summary).toBe('对方退赛，核定获胜');
  });
});

describe('场次时间回显与北京时间保持一致', () => {
  it('UTC与显式上海偏移回填同一个日期，跨日仍正确', () => {
    expect(businessPickerTime('2026-10-13T01:30:00Z')).toBe('2026-10-13 09:30:00');
    expect(businessPickerTime('2026-10-13T09:30:00+08:00')).toBe('2026-10-13 09:30:00');
    expect(businessPickerTime('2026-10-12T17:30:00Z')).toBe('2026-10-13 01:30:00');
  });
  it('无时区的旧业务日期按上海解释，未排期不补默认时间', () => {
    expect(businessPickerTime('2026-10-13 09:30:00')).toBe('2026-10-13 09:30:00');
    expect(businessPickerTime(null)).toBe('');
    expect(businessPickerTime('invalid')).toBe('');
  });
});
