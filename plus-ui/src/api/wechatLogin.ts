import request from '@/utils/request';

export interface WeChatAuthorization {
  available: boolean;
  authorizationUrl?: string;
  message?: string;
}

interface WorkLoginMethods {
  wechat: { available: boolean };
}

/** 只读取服务端公开渠道状态，不能以匿名浏览器参数指定组织或绑定账号。 */
export async function authorizeWorkWeChat(): Promise<WeChatAuthorization> {
  const response = await request<WorkLoginMethods>({
    url: '/auth/work-methods',
    method: 'get',
    headers: { isToken: false, repeatSubmit: false }
  });
  // 本期工作微信尚未开放授权及绑定链路；不借用旧social接口签发工作Token。
  return {
    available: response.data.wechat?.available === true,
    message: '微信登录暂不可用，请使用工作账号登录。'
  };
}
