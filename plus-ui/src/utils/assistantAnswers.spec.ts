import { describe, expect, it } from 'vitest';
import { hasAssistantAnswer, toggleAssistantAnswer, toggleAssistantTopic } from './assistantAnswers';

describe('助手选项合并到可编辑消息', () => {
  it('连续选择保留之前的选项和本人文字', () => {
    const first = toggleAssistantAnswer('我想周末参加', '羽毛球');
    expect(toggleAssistantAnswer(first, '双打')).toBe('我想周末参加\n羽毛球\n双打');
    expect(hasAssistantAnswer(first, '羽毛球')).toBe(true);
    expect(hasAssistantAnswer(first, '羽毛')).toBe(false);
  });
  it('重复点击取消该选项，其他选项和自由输入仍保留', () => {
    expect(toggleAssistantAnswer('我想周末参加\r\n羽毛球\r\n双打', '羽毛球')).toBe('我想周末参加\n双打');
    expect(toggleAssistantAnswer('羽毛球', '羽毛球')).toBe('');
  });
  it('本人改写后不误删改写内容，空选项不改变输入', () => {
    expect(toggleAssistantAnswer('最好是羽毛球，单打也可以', '羽毛球')).toBe('最好是羽毛球，单打也可以\n羽毛球');
    expect(toggleAssistantAnswer('保留我的话\n', ' ')).toBe('保留我的话\n');
  });
  it('新消息从空稿开始，旧选择不附加到下一次发送', () => {
    expect(toggleAssistantAnswer('', '双打')).toBe('双打');
    expect(toggleAssistantTopic(['找比赛'], '看规程')).toEqual(['找比赛', '看规程']);
    expect(toggleAssistantTopic(['找比赛', '看规程'], '找比赛')).toEqual(['看规程']);
  });
});
