import type { EntryCard } from '@/api/sports/registration';
/** 首页和报名详情使用同一规则解释，实际办理仍由原服务端校验。 */
export const registrationNextAction = (entry: EntryCard) =>
  entry.eventHolding === 'cancelled'
    ? '赛事已取消：保留历史，请联系承办方处理资金。'
    : entry.status === 'approved'
      ? '报名成功，已取得参赛资格。请按赛事安排参加比赛。'
      : ['rejected', 'withdrawn'].includes(entry.status)
        ? '当前报名未取得资格，原资金由承办方按退改规则处理。'
        : entry.status === 'draft'
          ? '下一步：填写并确认本人资料，然后正式提交。草稿不占名额。'
          : entry.obligationStatus === 'open'
            ? entry.paymentDeclared
              ? '下一步：等待承办方核对实际到账。通知已提交，不代表取得资格。'
              : '下一步：按指引付款，付款后通知承办方；足额到账及资格确认后才报名成功。'
            : '下一步：等待承办方审核参赛资格。';
