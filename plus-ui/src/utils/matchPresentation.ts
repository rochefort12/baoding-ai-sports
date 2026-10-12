/** Display recorded scores without guessing a winner or rewriting custom result text. */
export interface MatchPerformance {
  summary?: string | null;
  games?: string | null;
  outcomeA?: string | null;
  outcomeB?: string | null;
}
export interface ScorePair { a: string; b: string }
export interface GameScore extends ScorePair { number: number }

export const recordedScorePair = (value?: string | null): ScorePair | null => {
  const match = value?.trim().match(/^(\d{1,4})\s*[:：]\s*(\d{1,4})$/);
  return match ? { a: match[1], b: match[2] } : null;
};

/** A partially parsed custom note must stay visible in full instead of losing unknown parts. */
export const recordedGameScores = (value?: string | null): GameScore[] | null => {
  if (!value?.trim()) return [];
  const parts = value.split('|');
  const scores = parts.map(recordedScorePair);
  if (scores.some(score => !score)) return null;
  return scores.map((score, index) => ({ ...score!, number: index + 1 }));
};

export const recordedOutcomeLabel = (value?: string | null): string =>
  ({ win: '获胜', loss: '失利', draw: '平局' } as Record<string, string>)[value || ''] || '未记录胜负';

export const readMatchPerformance = (value?: string | null): MatchPerformance | null => {
  if (!value) return {};
  try {
    const record = JSON.parse(value);
    if (!record || typeof record !== 'object' || Array.isArray(record)) return null;
    if (['summary', 'games', 'outcomeA', 'outcomeB'].some(key => record[key] != null && typeof record[key] !== 'string')) return null;
    return record;
  } catch { return null; }
};
