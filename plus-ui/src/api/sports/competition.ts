import request from '@/utils/request';

export interface CompetitionEvent {
  eventId: string;
  name: string | null;
}

export interface CompetitionUnit {
  unitId: string;
  name: string;
}

export interface EligiblePerson {
  personId: string;
  legalName: string;
  unitName: string;
  registrationId: string;
  checkedIn: boolean;
  unitId: string;
  legacyEventCheckin: boolean;
}

export interface EntryChoice {
  registrationId: string;
  label: string;
}

export interface MatchCard {
  matchId: string;
  code: string;
  sideA: string;
  sideB: string;
  resultStatus: string | null;
  summary: string | null;
  games: string | null;
  outcomeA: string | null;
  outcomeB: string | null;
}

export interface AwardCard {
  awardKey: string;
  registrationId: string;
  unitName: string;
  title: string;
  names: string;
  people: number;
}

export interface ProofCard {
  honorId: string;
  awardKey: string;
  eventName: string;
  unitName: string;
  title: string;
  names: string;
  awardedAt: string;
  self: boolean;
  status: string;
  current: boolean;
  reason: string | null;
}

export const resultStatusLabel = (value: string | null) =>
  ({ draft: '草稿', confirmed: '已确认' } as Record<string, string>)[value || ''] || '未录入';

export const listCompetitionEvents = () => request({ url: '/sports/b/competition/events', method: 'get' });

export const listCompetitionUnits = (eventId: string) =>
  request({ url: '/sports/b/competition/units', method: 'get', params: { eventId } });

export const listEligible = (eventId: string) =>
  request({ url: '/sports/b/competition/events/' + eventId + '/eligible', method: 'get' });

export const checkInPerson = (eventId: string, personId: string, requestKey: string, unitId: string) =>
  request({ url: '/sports/b/competition/events/' + eventId + '/check-ins', method: 'post', data: { personId, requestKey, unitId } });

export const listMatchEntries = (unitId: string) =>
  request({ url: '/sports/b/competition/units/' + unitId + '/entries', method: 'get' });

export const listMatches = (unitId: string) =>
  request({ url: '/sports/b/competition/units/' + unitId + '/matches', method: 'get' });

export const createMatch = (unitId: string, code: string, registrationA: string, registrationB: string, requestKey: string) =>
  request({
    url: '/sports/b/competition/units/' + unitId + '/matches',
    method: 'post',
    data: { code, registrationA, registrationB, requestKey }
  });

export const saveResult = (
  matchId: string,
  summary: string,
  games: string,
  outcomeA: string,
  outcomeB: string,
  requestKey: string
) =>
  request({
    url: '/sports/b/competition/matches/' + matchId + '/result',
    method: 'post',
    data: { summary, games, outcomeA, outcomeB, requestKey }
  });

export const finalizeResult = (matchId: string, requestKey: string) =>
  request({ url: '/sports/b/competition/matches/' + matchId + '/finalize', method: 'post', data: { requestKey } });

export const importResults = (eventId: string, unitId: string, text: string, requestKey: string) =>
  request({ url: '/sports/b/competition/events/' + eventId + '/result-import', method: 'post', data: { unitId, text, requestKey } });

export const listAwards = (unitId: string) =>
  request({ url: '/sports/b/competition/units/' + unitId + '/awards', method: 'get' });

export const listMyResults = () => request({ url: '/sports/c/results', method: 'get' });

export const grantAward = (registrationId: string, title: string, basis: string, requestKey: string, awardKind?: string, basisMatchIds?: string[]) =>
  request({ url: '/sports/b/competition/awards', method: 'post', data: { registrationId, title, basis, requestKey, awardKind, basisMatchIds } });

export const listMyProofs = (history = false) => request({ url: '/sports/c/proofs', method: 'get', params: {history} });
