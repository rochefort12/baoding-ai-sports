import { describe, expect, it } from 'vitest';
import { createdProposalState, publicationMessageIntent, publicationReviewSignature } from './assistantPublication';

describe('聊天内发布核对', () => {
  it('只有独立的确认句可以确认已显示的发布卡', () => {
    expect(publicationMessageIntent('确认发布')).toBe('confirm');
    expect(publicationMessageIntent('请确认发布赛事！')).toBe('confirm');
    expect(publicationMessageIntent('发布赛事')).toBe('preview');
    expect(publicationMessageIntent('不要确认发布')).toBeUndefined();
    expect(publicationMessageIntent('先改价，再确认发布')).toBeUndefined();
    expect(publicationMessageIntent('确认发布了吗？')).toBeUndefined();
    expect(publicationMessageIntent('确认发布？')).toBeUndefined();
    expect(publicationMessageIntent('确认发布?')).toBeUndefined();
  });
  it('字段顺序不产生假变化，实际费用或赛事版本变化必须重核对', () => {
    const initial=publicationReviewSignature({id:'12',name:'春季赛'},{units:[{amount:'100',unitName:'双打'}]},3);
    expect(publicationReviewSignature({name:'春季赛',id:'12'},{units:[{unitName:'双打',amount:'100'}]},3)).toBe(initial);
    expect(publicationReviewSignature({id:'12',name:'春季赛'},{units:[{amount:'120',unitName:'双打'}]},3)).not.toBe(initial);
    expect(publicationReviewSignature({id:'12',name:'春季赛'},{units:[{amount:'100',unitName:'双打'}]},4)).not.toBe(initial);
  });
  it('创建后的待同步候选和实际版本分别读取，不把保存候选当作赛事已更新', () => {
    expect(createdProposalState('{"createdDirty":true,"createdEventVersion":4}')).toEqual({dirty:true,eventVersion:4});
    expect(createdProposalState(null)).toEqual({dirty:false,eventVersion:undefined});
  });
});
