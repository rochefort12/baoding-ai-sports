import { ElMessage, ElMessageBox } from 'element-plus';
export interface InvitationDelivery { inboxStatus: string; smsStatus: string; smsReason: string | null }
export const invitationDeliveryText = (notice?: InvitationDelivery | null) => {
  if (!notice || notice.inboxStatus !== 'delivered') return '历史邀请未生成站内信，可复制链接联系对方';
  return '站内信已生成' + (notice.smsStatus === 'not_requested' ? ' · 未申请短信' : notice.smsStatus === 'delivered' ? ' · 短信已送达' : ' · ' + (notice.smsReason || '短信未送达'));
};
export const copyInvitation = async (path: string, recipientLabel?: string) => {
  const address = window.location.origin + path;
  try { await navigator.clipboard.writeText(address); ElMessage.success(recipientLabel ? `已复制给${recipientLabel}的邀请链接，仅该本人可办理` : '邀请链接已复制，仅受邀本人可办理'); }
  catch { await ElMessageBox.alert(address, recipientLabel ? `发给${recipientLabel}的邀请链接` : '请复制邀请链接', { confirmButtonText: '知道了' }); }
};
