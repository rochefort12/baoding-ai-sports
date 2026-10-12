import { describe, expect, it } from 'vitest';
import { promotionStyle } from './promotionStyle';
describe('宣传视觉语气兼容多项目', () => {
  it('篮球、跑步、游泳不会固定使用羽毛球受众', () => {
    expect(promotionStyle('校园三人篮球赛', '篮球')).toBe('junior');
    expect(promotionStyle('社区健康跑', '跑步')).toBe('community');
    expect(promotionStyle('城市游泳锦标赛', '游泳')).toBe('competitive');
    expect(promotionStyle('开放挑战赛', '飞盘', '青少年与家长')).toBe('junior');
  });
  it('不明项目保持通用竞技，关键词可以调整氛围', () => {
    expect(promotionStyle()).toBe('competitive');
    expect(promotionStyle('公开赛', '新运动', '', '周末交流')).toBe('community');
  });
});
