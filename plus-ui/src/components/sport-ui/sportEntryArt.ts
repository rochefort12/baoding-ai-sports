/** Project-authored navigation scenes. They decorate actions; labels remain live text. */
export const sportEntryArt = {
  registration: { src: '/images/sports/v3/entries/registration.svg', label: '我的报名' },
  rooms: { src: '/images/sports/v3/entries/rooms.svg', label: '找队友' },
  teams: { src: '/images/sports/v3/entries/teams.svg', label: '我的小队' },
  growth: { src: '/images/sports/v3/entries/growth.svg', label: '成长与荣誉' },
  results: { src: '/images/sports/v3/entries/results.svg', label: '赛果与证明' }
} as const;
export type SportEntryArtKey = keyof typeof sportEntryArt;
