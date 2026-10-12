import { describe, expect, it } from 'vitest';
import { withoutStructuredNextStep } from './assistantReadiness';

const step = '还不能保存赛事草稿。下一步：请补充赛事名称';

describe('就绪提示只保留一处', () => {
  it('去掉回复末尾拼上的同一句', () => {
    expect(withoutStructuredNextStep(`已经记下地点。\n\n${step}`, step)).toBe('已经记下地点。');
    expect(withoutStructuredNextStep(step, step)).toBe('');
  });

  it('正文里提到下一步时保留原文', () => {
    const reply = '下一步可以先看规程，再决定是否保存。';
    expect(withoutStructuredNextStep(reply, step)).toBe(reply);
  });

  it('历史问题改变后仍移除独立的下一步尾句', () => {
    expect(withoutStructuredNextStep('费用按每项100元记下了。\n下一步：请确认整单总价', '请补充地点')).toBe('费用按每项100元记下了。');
    expect(withoutStructuredNextStep('已记下。\r\n\r\n' + step + '  ', step)).toBe('已记下。');
    expect(withoutStructuredNextStep('下一步：请补充赛事名称')).toBe('');
  });

  it('没有结构化尾句时不截断普通回复', () => {
    expect(withoutStructuredNextStep('我会说明下一步：先核对规程，再补充材料。')).toBe('我会说明下一步：先核对规程，再补充材料。');
    expect(withoutStructuredNextStep('已填地点\n下一步可以核对项目')).toBe('已填地点\n下一步可以核对项目');
  });
});
