import request from '@/utils/request';

export interface FeeEvent {
  eventId: string;
  name: string | null;
}

export type PaymentChannelType = 'wechat' | 'alipay' | 'bank' | 'custom_qr' | 'offline';
export interface PaymentChannel {
  type: PaymentChannelType;
  label: string;
  qrFileId: string | null;
  accountName: string | null;
  bankName: string | null;
  bankAccount: string | null;
  instruction: string;
}
export interface PaymentSettings { revision: number; instruction: string; channels: PaymentChannel[] }
export const getEventPaymentConfig = (eventId: string) => request<PaymentSettings>({url: `/sports/b/fees/events/${eventId}/payment-config`, method: 'get'});
export const saveEventPaymentConfig = (eventId: string, data: PaymentSettings) => request<PaymentSettings>({url: `/sports/b/fees/events/${eventId}/payment-config`, method: 'put', data});
export const eventPaymentQrBlob = (eventId: string, type: PaymentChannelType) => request({url: `/sports/b/fees/events/${eventId}/payment-config/${type}/qr`, method: 'get', responseType: 'blob'});
export const getPaymentInstructions = (registrationId: string) => request<PaymentSettings>({url: `/sports/c/registrations/${registrationId}/payment-instructions`, method: 'get'});
export const paymentChannelQrBlob = (registrationId: string, type: PaymentChannelType) => request({url: `/sports/c/registrations/${registrationId}/payment-channels/${type}/qr`, method: 'get', responseType: 'blob'});

export interface UnitPrice {
  unitId: string;
  unitName: string;
  amount: number | null;
  paymentMode: string | null;
  payInstruction: string | null;
  qrFileId: string | null;
}

export interface ObligationCard {
  obligationId: string;
  registrationId: string;
  registrationStatus: string;
  obligationStatus: string;
  amount: number;
  paymentMode: string;
  payerName: string | null;
  paidAt: string | null;
  confirmerName: string | null;
  actionId: string | null;
  actionStatus: string | null;
}

export interface ObligationHistory {
  obligationId: string;
  rosterRevision: number | null;
  createdAt: string | null;
  dueAmount: number;
  netAmount: number;
  status: string;
  paymentMode: string;
  current: boolean;
  pending: boolean;
}
export const getFundHistory = (registrationId: string) =>
  request<ObligationHistory[]>({ url: `/sports/b/fees/registrations/${registrationId}/history`, method: 'get' });

export const paymentModeLabel = (value: string | null) =>
  (({ free: '免费', offline: '线下付款', organizer_qr: '运营方二维码', event: '赛事统一收款' }) as Record<string, string>)[value || ''] || '未设置';

export const paymentDisplay = (row: Pick<ObligationCard, 'obligationStatus' | 'actionStatus'>) => {
  if (row.actionStatus === 'pending') {
    return '待处理';
  }
  if (row.actionStatus === 'refunded') {
    return '已退款';
  }
  return (
    ({ not_required: '免费', open: '待付款', settled: '已付款', void: '已失效' } as Record<string, string>)[row.obligationStatus] ||
    row.obligationStatus
  );
};

export const listFeeEvents = () => request({ url: '/sports/b/fees/events', method: 'get' });

export const listFeeUnits = (eventId: string) => request({ url: '/sports/b/fees/units', method: 'get', params: { eventId } });

export const publishFee = (unitId: string, amount: number, paymentMode: string, payInstruction: string, qrFileId?: string | null) =>
  request({ url: '/sports/b/fees/units/' + unitId, method: 'post', data: { amount, paymentMode, payInstruction, qrFileId: qrFileId || null } });

export const listObligations = (unitId: string) => request({ url: '/sports/b/fees/units/' + unitId + '/obligations', method: 'get' });

export const confirmPayment = (obligationId: string, payerName: string, amount: number, occurredAt: string, note: string, requestKey: string) =>
  request({
    url: '/sports/b/fees/obligations/' + obligationId + '/confirm',
    method: 'post',
    data: { payerName, amount, occurredAt, note, requestKey }
  });

export const reversePayment = (obligationId: string, requestKey: string, paymentId: string) =>
  request({ url: '/sports/b/fees/obligations/' + obligationId + '/reverse', method: 'post', data: { requestKey, paymentId } });

export const closeWithoutRefund = (actionId: string, note?: string) =>
  request({ url: '/sports/b/fees/actions/' + actionId + '/no-refund', method: 'post', data: { note } });

export const fundRecords = (obligationId: string) => request({ url: `/sports/b/fees/obligations/${obligationId}/records`, method: 'get' });
export interface ReceiptRecord { paymentId: string; amount: number; allocatedAmount: number; status: string; payerName: string; occurredAt: string; refundedAmount: number; pendingActionId: string | null }
export interface PaymentExceptionRecord {
  exceptionId: string;
  paymentId: string | null;
  exceptionType: string;
  externalReference: string | null;
  reportedAmount: number | null;
  status: string;
  version: number;
  resolutionNote: string | null;
  resolvedAt: string | null;
  responsibleUserId: string | null;
}
export interface FundRecords { receipts: ReceiptRecord[]; refunds: unknown[]; exceptions: PaymentExceptionRecord[]; netAmount: number; dueAmount: number }
export const resolvePaymentException = (obligationId: string, exceptionId: string, data: { note: string; expectedVersion: number; requestKey: string }) =>
  request<PaymentExceptionRecord>({ url: `/sports/b/fees/obligations/${obligationId}/exceptions/${exceptionId}/resolve`, method: 'post', headers: { repeatSubmit: false }, data });

export const recordActualRefund = (actionId: string, data: { amount: number; occurredAt: string; recipientName: string; recipientBasis: string; note: string; requestKey: string }) => request({url: '/sports/b/fees/actions/' + actionId + '/refund', method:'post', data});
