import request from '@/utils/request';
import type { GrowthCard } from './phase1';
import type { SportsRankStep } from '@/utils/sportsRank';

export interface GrowthTitleGoal {
  code: string;
  title: string;
  milestone: 'checkin' | 'finish' | 'team_finish';
  required: number;
  current: number;
  remaining: number;
  awarded: boolean;
  eligible: boolean;
}
export interface GrowthRankCard extends GrowthCard {
  maxRankIndex?: number;
  policyVersion?: string;
  ranks?: SportsRankStep[];
  titleGoals?: GrowthTitleGoal[];
}
export const getGrowthRankCard = (sportId: string, teamId?: string) => request<GrowthRankCard>({
  url: '/sports/growth/card', params: { sportId, teamId }
});
