/** Artwork is presentation only. The server's current rule/name controls the participant's rank. */
export type SportsRankKey = 'bronze' | 'silver' | 'gold' | 'platinum' | 'diamond' | 'stellar' | 'king' | 'legend';
export interface SportsRankStep { index: number; name: string; threshold: number; }
const rankKeys: Record<string, SportsRankKey> = {
  青铜: 'bronze', 白银: 'silver', 黄金: 'gold', 铂金: 'platinum', 钻石: 'diamond', 星耀: 'stellar', 王者: 'king', 传奇: 'legend',
  // The historical 4800-point name retains its original text while using the matching high-tier artwork.
  荣耀: 'stellar'
};
export const rankArtworkKey = (name?: string | null): SportsRankKey | undefined => {
  const label=name?.trim() || '';
  return Object.prototype.hasOwnProperty.call(rankKeys,label) ? rankKeys[label] : undefined;
};
export const rankBadgePath = (name?: string | null) => { const key=rankArtworkKey(name); return key ? `/images/sports/ranks/${key}.webp` : ''; };
export const rankFramePath = (name?: string | null) => { const key=rankArtworkKey(name); return key ? `/images/sports/frames-v2/${key}.webp` : ''; };
export const titleArtworkPath = (code?: string | null) => {
  const codes = new Set(['first_checkin', 'first_finish', 'regular', 'team_first', 'team_partners', 'team_veterans']);
  return code && codes.has(code) ? `/images/sports/titles/${code}.svg` : '';
};

/** Only an explicit official award label selects a placement medal; match wins and growth ranks do not. */
export const officialMedalPath = (title?: string | null) => {
  const awards: Record<string, string> = {
    冠军: 'gold', 第一名: 'gold', '第1名': 'gold', 金牌: 'gold',
    亚军: 'silver', 第二名: 'silver', '第2名': 'silver', 银牌: 'silver',
    季军: 'bronze', 第三名: 'bronze', '第3名': 'bronze', 铜牌: 'bronze'
  };
  const label=title?.trim() || '';
  const key = Object.prototype.hasOwnProperty.call(awards,label) ? awards[label] : undefined;
  return key ? `/images/sports/medals/${key}.webp` : '';
};
