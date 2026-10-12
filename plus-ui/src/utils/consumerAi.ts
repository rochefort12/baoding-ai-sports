import { reactive } from 'vue';
/** 全局入口共用一个窗口；仅内存保存开关与问题，不缓存身份、报名或对话。 */
export const consumerAi = reactive({ open: false, prompt: '', mode: 'ask' as 'ask', revision: 0 });
export const openConsumerAi = (prompt = '') => {
  consumerAi.prompt = prompt;
  consumerAi.open = true;
  consumerAi.revision += 1;
};
