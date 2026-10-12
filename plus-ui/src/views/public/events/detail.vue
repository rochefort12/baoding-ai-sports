<template>
  <ConsumerShell>
    <EventDetailContent v-if="event" :event="event" :fees="fees" :fee-error="feeError" :media="publicImages" />
    <ConsumerState v-else-if="error" error title="赛事暂时无法查看" :description="error"><button class="btn" @click="load">重新读取</button><router-link class="btn" to="/public/events">返回赛事列表</router-link></ConsumerState>
    <ConsumerState v-else loading title="正在读取赛事安排" />
  </ConsumerShell>
</template>

<script setup lang="ts" name="PublicEventDetail">
import { registrationPriceReady, registrationPriceText } from '@/utils/registrationPrice';
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import EventDetailContent from '@/components/consumer/EventDetailContent.vue';
import { EventCard, getPublicEvent, phaseLabel, showTime } from '@/api/sports/event';
import { paymentModeLabel } from '@/api/sports/finance';
import { publicMediaUrl } from '@/api/sports/media';
import request from '@/utils/request';

interface PublicUnitPrice {
  unitId: string;
  unitName: string;
  amount: number | null;
  paymentMode: string | null;
  payInstruction: string | null;
}

interface PublicFees {
  organizationName: string | null;
  contactName: string | null;
  contactMethod: string | null;
  refundNote: string;
  units: PublicUnitPrice[];
}

const route = useRoute();
const event = ref<EventCard>();
const publicImages = computed(() =>
  Object.fromEntries(
    ['banner', 'rules', 'notice', 'declaration', 'route'].map((k) => [
      k,
      event.value && (event.value as unknown as Record<string, unknown>)[k + 'FileId'] ? publicMediaUrl(event.value.id, k) : ''
    ])
  )
);
const fees = ref<PublicFees>();
const error = ref('');
const feeError = ref('');

const bannerFailed = ref(false);
const banner = computed(() => (event.value?.bannerFileId ? publicMediaUrl(event.value.id, 'banner') : ''));
const showBanner = computed(() => Boolean(banner.value) && !bannerFailed.value);
watch(banner, () => {
  bannerFailed.value = false;
});
const canRegister = computed(() => event.value?.holdingStatus !== 'cancelled' && event.value?.phase === 'registration');
const registrationHint = computed(() =>
  event.value?.holdingStatus === 'cancelled' ? '赛事已取消' : canRegister.value ? '报名正在进行' : phaseLabel(event.value?.phase || null)
);
const holdingText = computed(() => (event.value?.holdingStatus === 'cancelled' ? '已取消' : '正常举办'));
const holdingClass = computed(() => (event.value?.holdingStatus === 'cancelled' ? 'red' : ''));

const priceReady = registrationPriceReady;
const priceText = registrationPriceText;

const load = async () => {
  const id = String(route.params.id);
  event.value = undefined;
  fees.value = undefined;
  error.value = '';
  feeError.value = '';
  try {
    const res = await getPublicEvent(id);
    if (id !== String(route.params.id)) return;
    event.value = res.data;
  } catch (cause) {
    if (id === String(route.params.id)) error.value = cause instanceof Error ? cause.message : '这场赛事暂时无法查看。';
    return;
  }
  try {
    const feeRes = await request({ url: '/sports/public/events/' + id + '/fees', method: 'get', headers: { isToken: false } });
    if (id === String(route.params.id)) fees.value = feeRes.data;
  } catch {
    if (id === String(route.params.id)) feeError.value = '暂时无法读取项目收费，请稍后重新查看。';
  }
};
watch(() => route.params.id, load, { immediate: true });
</script>
