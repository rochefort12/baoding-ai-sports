import { onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { firstQuery, sanitizeReturnTo } from '@/utils/returnTo';

/** 地址栏里的回跳如果不是站内业务页，立刻换成公开首页，避免外链留在查询参数里。 */
export const useCleanReturnTo = () => {
  const route = useRoute();
  const router = useRouter();
  onMounted(() => {
    const raw = firstQuery(route.query.returnTo);
    if (!raw) {
      return;
    }
    const safe = sanitizeReturnTo(raw);
    if (raw !== safe) {
      router.replace({ path: route.path, query: { returnTo: safe } });
    }
  });
};
