import type { InjectionKey, Ref } from 'vue';
/** 业务页面主动请求全局助手；写入完成只刷新数据，不改变当前路由。 */
export const businessAiKey: InjectionKey<(command: string) => void> = Symbol('business-ai');
export const businessRevisionKey: InjectionKey<Ref<number>> = Symbol('business-revision');
