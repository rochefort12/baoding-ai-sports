import request from '@/utils/request';
import { ElMessageBox } from 'element-plus';
import { sha256Hex } from '@/utils/actionFingerprint';
import { newRequestKey } from '@/utils/requestKey';

export type ActionInput = Record<string, string | number | boolean | null>;
export interface Receipt { receiptId: string; actionCode: string; status: string; replayed: boolean; result: Record<string, string>; }
export const performAction = async (code: string, input: ActionInput, confirmText?: string) => {
  const frozen = JSON.parse(JSON.stringify(input));
  const bytes = new TextEncoder().encode(JSON.stringify(Object.fromEntries(Object.entries(frozen).sort(([a], [b]) => a.localeCompare(b)))));
  const hash = await sha256Hex(bytes);
  const retrySlot = `sports-action:${code}:${hash}`;
  const requestKey = sessionStorage.getItem(retrySlot) || newRequestKey();
  sessionStorage.setItem(retrySlot, requestKey);
  let confirmationId: string | undefined;
  if (confirmText) {
    await request({ url: `/sports/platform/actions/${code}/preview`, method: 'post', data: frozen });
    await ElMessageBox.confirm(confirmText, '确认操作', { confirmButtonText: '确认', cancelButtonText: '取消', type: 'info' });
    confirmationId = (await request({ url: `/sports/platform/actions/${code}/confirm`, method: 'post', data: frozen })).data;
  }
  const result = await request<Receipt>({ url: `/sports/platform/actions/${code}/execute`, method: 'post', data: { input: frozen, requestKey, confirmationId } });
  sessionStorage.removeItem(retrySlot);
  return result;
};
export interface RoomSummary { id: string; unit_id: string; event_id: string; host_account_id: string; team_id: string | null; team_name?:string|null; team_title?:string|null; name: string; status: string; registration_id: string | null; announcement: string | null; version: number; max_members: number; min_members: number; type_name: string; unit_name: string; event_name: string; member_count: number; sport_id: string; }
export interface RoomMember { account_id: string; nickname: string; avatar_style: string; avatar_file_id?: string | null; points: number; rank_index?:number; rank_name?:string; title: string | null; title_code: string | null; ready: boolean; }
export interface Offer { id: string; unit_id: string; room_id: string | null; expires_at: string; my_status: string; unit_name: string; event_name: string; }
export interface MatchingRequest { id: string; unit_id: string; room_id: string | null; status: string; expires_at: string; }
export interface RoomHome { accountId: string; rooms: RoomSummary[]; offers: Offer[]; requests: MatchingRequest[]; }
export interface RoomDetail { accountId: string; room: RoomSummary; members: RoomMember[]; interactions: { kind: string; text: string; nickname: string; create_time: string }[]; }
export interface Recruitment { room_id: string; name: string; team_id: string | null; message: string; expires_at: string; host_account_id?: string; host_nickname: string; avatar_style: string; avatar_file_id?: string | null; member_count: number; max_members: number; }
export interface RoomOptions { unit: RoomSummary; recruitments: Recruitment[]; }
export interface DisplayProfile { accountId: string; display: { nickname: string; avatar_style: string; avatar_file_id?: string | null; tagline: string; public_visible: boolean; version: number }; }
export interface GrowthCard { ownerId: string; ownerType: string; sportId: string; points: number; rank: string; rankIndex: number; nextRank: string; nextThreshold: number; rankThreshold: number; titles: { id: string; title: string; title_code: string; awarded_at: string; reason: string }[]; equipment: { title_code: string; frame_style: string; version: number } | null; facts: { id: string; event_id: string; milestone: string; points_delta: number; create_time: string }[]; }
export const getRooms = () => request<RoomHome>({ url: '/sports/rooms' });
export const getRoom = (id: string) => request<RoomDetail>({ url: `/sports/rooms/${id}` });
export const getRoomOptions = (unit: string) => request<RoomOptions>({ url: `/sports/rooms/units/${unit}` });
export const getDisplay = () => request<DisplayProfile>({ url: '/sports/display' });
export const getGrowthCard = (sportId: string, teamId?: string) => request<GrowthCard>({ url: '/sports/growth/card', params: { sportId, teamId } });
export const getGrowthHome = () => request({ url: '/sports/growth' });
export const getTeamBoard = (id: string) => request({ url: `/sports/growth/teams/${id}/board` });
export const titleLabels: Record<string, string> = { first_checkin: '首次登场', first_finish: '首次完赛', regular: '赛场常客', team_first: '默契初成', team_partners: '默契搭档', team_veterans: '久经赛场' };
export const rankLabels = ['新星', '青铜', '白银', '黄金', '铂金', '钻石', '荣耀'];
export const rankIndex = (points: number) => [0, 40, 120, 400, 1000, 2400, 4800].filter((n) => points >= n).length - 1;
