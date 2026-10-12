export type PromotionStyle = 'competitive' | 'junior' | 'community';
/** 仅决定视觉语气，不推断参赛资格；具体运动项目由服务器传给生图服务。 */
export function promotionStyle(name = '', project = '', audience = '', keywords = ''): PromotionStyle {
  const text = [name, project, audience, keywords].join(' ');
  if (/青少年|少年|儿童|校园|学生|亲子|家长|junior|youth/i.test(text)) return 'junior';
  if (/社区|交流|友谊|球友|周末|公益|休闲|community|friendly/i.test(text)) return 'community';
  return 'competitive';
}
