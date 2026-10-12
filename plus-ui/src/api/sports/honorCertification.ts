import request from '@/utils/request';
import { performAction } from './phase1';

export type CertificationStatus = 'draft' | 'submitted' | 'correction' | 'approved' | 'rejected' | 'revoked';
export interface ApplicantHonorIdentity { accountId: string; personId: string; legalName: string; birthYear?: number; documentType?: string; hasIdentityDocument: boolean; profileVerificationStatus: string; personVersion: number; }
export interface HonorClaim { eventYear: number; eventName: string; sportId: string; place: number; level: 'world'; sourceUrl: string; proofFileIds: string[]; }
export interface VerifiedHonorFacts { eventYear: number; eventName: string; sportId: string; place: number; level: 'world'; officialIssuer: string; officialResultsUrl: string; sportName?: string; verifiedAt?: string; }
export interface CertificationHistory { state: string; reason: string; at: string; previousVersion: number; details: HonorClaim; verified?: VerifiedHonorFacts; }
export interface HonorApplication { honorId: string; title: string; status: CertificationStatus; version: number; publicVisible: boolean; worn: boolean; nickname: string; applicantIdentity: ApplicantHonorIdentity; details: HonorClaim; verified: Partial<VerifiedHonorFacts>; history: CertificationHistory[]; }
export interface CertifiedHonor { honorId: string; title: string; eventYear: number; eventName: string; sportId: string; sportName: string; place: number; worn: boolean; publicVisible: boolean; }
export interface HonorSport { id: string; name: string; }
const base = '/sports/honors/certifications';
export const certificationLabels: Record<CertificationStatus, string> = { draft: '草稿', submitted: '待核验', correction: '需补正', approved: '已认证', rejected: '未通过', revoked: '已撤销' };
export const listHonorApplications = () => request<HonorApplication[]>({ url: base });
export const getHonorApplication = (id: string) => request<HonorApplication>({ url: `${base}/${id}` });
export const reviewHonorApplications = (status: string) => request<HonorApplication[]>({ url: `${base}/review`, params: { status } });
export const myCertifiedHonors = (sportId?: string) => request<CertifiedHonor[]>({ url: `${base}/approved`, params: { sportId } });
export const getHonorSports = () => request<{ sports: HonorSport[] }>({ url: '/sports/types' });
export const saveHonorApplication = (details: HonorClaim, current?: HonorApplication) => performAction('honor.certification.save', { ...(current ? { honorId: current.honorId } : {}), expectedVersion: current?.version || 0, detailsJson: JSON.stringify(details) });
export const submitHonorApplication = (current: HonorApplication) => performAction('honor.certification.submit', { honorId: current.honorId, expectedVersion: current.version }, `将提交「${current.details.eventYear} ${current.details.eventName}」的世界赛事本人荣誉材料。申请档案：${current.applicantIdentity.legalName}。请确认信息真实、证明有权提供；提交后等待平台核验。`);
export const reviewHonorApplication = (current: HonorApplication, decision: 'approve' | 'correction' | 'reject' | 'revoke', reason: string, facts?: VerifiedHonorFacts) => performAction('honor.certification.review', { honorId: current.honorId, expectedVersion: current.version, decision, reason, ...(facts ? { verifiedDetailsJson: JSON.stringify(facts), expectedPersonVersion: String(current.applicantIdentity.personVersion) } : {}) }, decision === 'approve' && facts ? `确认已独立核验「${current.applicantIdentity.legalName}」本人归属及世界级赛事正式依据：${facts.eventYear}年「${facts.eventName}」，世界${['', '冠军', '亚军', '季军'][facts.place]}，公布单位「${facts.officialIssuer}」。通过后允许本人佩戴含真实年份、赛事及项目的认证称号。` : `确认${{ correction: '要求补正', reject: '不予通过', revoke: '撤销认证', approve: '通过认证' }[decision]}「${current.details.eventName}」？此次说明会通知申请人并保留历史。`);
export const wearCertifiedHonor = (current: HonorApplication, ready: boolean) => performAction('honor.certification.wear', { honorId: current.honorId, expectedVersion: current.version, ready });
export const setCertifiedHonorVisible = (current: HonorApplication, publicVisible: boolean) => performAction('honor.certification.visibility', { honorId: current.honorId, expectedVersion: current.version, publicVisible });
export const uploadHonorProof = (current: HonorApplication, file: File) => { const data = new FormData(); data.append('file', file); return request<{ fileId: string; version: number }>({ url: `${base}/${current.honorId}/proof`, method: 'post', params: { expectedVersion: current.version }, data, headers: { 'Content-Type': 'multipart/form-data', repeatSubmit: false } }); };
export async function readHonorProof(id: string, fileId: string) { const result = await request({ url: `${base}/${id}/proof/${fileId}`, responseType: 'blob' }) as unknown as Blob; if (!(result instanceof Blob) || /json/.test(result.type)) throw new Error('证明暂时无法读取'); return result; }
