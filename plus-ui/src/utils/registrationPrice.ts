/** All public registration views use the server's active fee policy, including event-wide collection. */
export interface RegistrationPrice { amount: number | null; paymentMode: string | null; }
export const registrationPriceReady = (price: RegistrationPrice) => {
  if (price.amount == null || !Number.isFinite(Number(price.amount))) return false;
  return price.paymentMode === 'free' ? Number(price.amount) === 0
    : ['event', 'offline', 'organizer_qr'].includes(price.paymentMode || '') && Number(price.amount) > 0;
};
export const registrationPriceText = (price: RegistrationPrice) => !registrationPriceReady(price)
  ? '收费信息待公布' : price.paymentMode === 'free' ? '免费' : `¥${Number(price.amount).toFixed(2)} / 单`;
