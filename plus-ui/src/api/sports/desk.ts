import request from '@/utils/request';
import type { PaymentExceptionRecord } from '@/api/sports/finance';
export interface DeskContext {
  organizationId: string;
  organizationName: string;
  organize: boolean;
  payment: boolean;
}
export const getDeskContext = () => request<DeskContext>({ url: '/sports/b/desk/context', method: 'get' });

export interface OperationsEvent {
  eventId: string;
  currentEntries: number;
  pendingReview: number;
  unpaidEntries: number;
  declaredEntries: number;
  pendingFunds: number;
  occupied: number;
  capacity: number;
  trend: { date: string; count: number }[];
}
export interface OperationsSnapshot {
  refreshedAt: string;
  events: OperationsEvent[];
}
export const getOperationsSummary = () => request<OperationsSnapshot>({ url: '/sports/b/operations/summary', method: 'get' });
export interface FundRecords {
  exceptions: PaymentExceptionRecord[];
  netAmount: number;
  dueAmount: number;
  receipts: {
    paymentId: string;
    payerName: string;
    amount: number;
    allocatedAmount: number;
    occurredAt: string;
    confirmedAt: string;
    status: string;
    allocationStatus: string;
    refundedAmount: number;
    pendingActionId?: string;
  }[];
  refunds: {
    refundId: string;
    paymentId: string;
    amount: number;
    completedAt: string;
    status: string;
    reason: string;
    recipientName?: string;
    recipientBasis?: string;
  }[];
}
export const getFundRecords = (id: string) => request<FundRecords>({ url: '/sports/b/fees/obligations/' + id + '/records', method: 'get' });
