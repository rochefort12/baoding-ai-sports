import request from '@/utils/request';
import type { InvitationDelivery } from '@/utils/invitation';

export interface MembershipCard {
  teamId: string;
  name: string;
  teamStatus: string;
  role: string;
  membershipStatus: string;
  endReason: string | null;
}

export interface ApplicationCard {
  id: string;
  teamId: string;
  teamName: string;
  status: string;
  personName: string;
}

export interface InvitationCard {
  notice?: InvitationDelivery | null;
  id: string;
  teamId: string;
  teamName: string;
  status: string;
  personName: string;
}

export interface TeamHome {
  memberships: MembershipCard[];
  myApplications: ApplicationCard[];
  myInvitations: InvitationCard[];
  incomingApplications: ApplicationCard[];
}

export interface MemberCard {
  id: string;
  personId: string;
  accountId: string | null;
  legalName: string;
  role: string;
  status: string;
  endReason: string | null;
  selectable: boolean;
}

export interface TeamDetail {
  id: string;
  name: string;
  status: string;
  myRole: string;
  myMembershipStatus: string;
  myEndReason: string | null;
  captain: boolean;
  canLeave: boolean;
  members: MemberCard[];
  applications: ApplicationCard[];
  invitations: InvitationCard[];
}

export interface CandidateCard {
  personId: string;
  accountId: string;
  legalName: string;
  role: string;
  selectable: boolean;
}

export interface PreviewCard {
  id: string;
  name: string;
  status: string;
}

export const teamStatusLabel = (value: string) => ({ active: '有效', disbanded: '已解散' })[value] || value;

export const roleLabel = (value: string) => ({ captain: '队长', member: '队员' })[value] || value;

export const membershipStatusLabel = (value: string) => ({ active: '有效', ended: '已结束' })[value] || value;

export const endReasonLabel = (value: string | null) =>
  ({ member_left: '主动退队', captain_removed: '被队长移除', team_disbanded: '队伍解散' })[value || ''] || '';

export const listTeams = () => request({ url: '/sports/c/teams', method: 'get' });

export const createTeam = (name: string) => request({ url: '/sports/c/teams', method: 'post', data: { name } });

export const previewTeam = (teamId: string) => request({ url: '/sports/c/teams/' + teamId + '/preview', method: 'get' });

export const getTeam = (teamId: string) => request({ url: '/sports/c/teams/' + teamId, method: 'get' });

export const listCandidates = (teamId: string) => request({ url: '/sports/c/teams/' + teamId + '/candidates', method: 'get' });

export const renameTeam = (teamId: string, name: string) =>
  request({ url: '/sports/c/teams/' + teamId + '/name', method: 'post', data: { name } });

export const applyTeam = (teamId: string) => request({ url: '/sports/c/teams/' + teamId + '/applications', method: 'post' });

export const cancelApplication = (requestId: string) =>
  request({ url: '/sports/c/teams/applications/' + requestId + '/cancel', method: 'post' });

export const approveApplication = (requestId: string) =>
  request({ url: '/sports/c/teams/applications/' + requestId + '/approve', method: 'post' });

export const rejectApplication = (requestId: string, reason: string) =>
  request({ url: '/sports/c/teams/applications/' + requestId + '/reject', method: 'post', data: { reason } });

export const inviteTeammate = (teamId: string, phone: string, requestSms = false) =>
  request({ url: '/sports/c/teams/' + teamId + '/invitations', method: 'post', data: { phone, requestSms } });

export const acceptInvitation = (invitationId: string) =>
  request({ url: '/sports/c/teams/invitations/' + invitationId + '/accept', method: 'post' });

export const declineInvitation = (invitationId: string) =>
  request({ url: '/sports/c/teams/invitations/' + invitationId + '/decline', method: 'post' });

export const revokeInvitation = (invitationId: string) =>
  request({ url: '/sports/c/teams/invitations/' + invitationId + '/revoke', method: 'post' });

export const leaveTeam = (teamId: string) => request({ url: '/sports/c/teams/' + teamId + '/leave', method: 'post' });

export const removeTeammate = (teamId: string, memberId: string) =>
  request({ url: '/sports/c/teams/' + teamId + '/members/' + memberId + '/remove', method: 'post' });

export const transferCaptain = (teamId: string, memberId: string) =>
  request({ url: '/sports/c/teams/' + teamId + '/captain', method: 'post', data: { memberId } });

export const disbandTeam = (teamId: string) => request({ url: '/sports/c/teams/' + teamId + '/disband', method: 'post' });

export const getInvitation = (id: string) => request({ url: '/sports/c/teams/invitations/' + id, method: 'get' });

export interface TeamShareLink { id: string; path: string; expiresAt: string }
export interface TeamSharePreview { teamId: string; teamName: string; status: string; expiresAt: string }
export interface TeamShareConfirmation extends TeamSharePreview { currentMember: boolean; previouslyUsed: boolean }
export const getTeamShare = (teamId: string) => request({ url: `/sports/c/teams/${teamId}/share-invitation`, method: 'get' });
export const createTeamShare = (teamId: string, replace = false) =>
  request({ url: `/sports/c/teams/${teamId}/share-invitation`, method: 'post', data: { replace } });
export const revokeTeamShare = (teamId: string) => request({ url: `/sports/c/teams/${teamId}/share-invitation/revoke`, method: 'post' });
export const previewTeamShare = (token: string) => request({ url: `/sports/public/team-invitations/${token}`, method: 'get', headers: { isToken: false } });
export const getTeamShareConfirmation = (token: string) => request({ url: `/sports/c/teams/share-invitations/${token}`, method: 'get' });
export const acceptTeamShare = (token: string) =>
  request({ url: `/sports/c/teams/share-invitations/${token}/accept`, method: 'post', data: { confirmed: true } });
