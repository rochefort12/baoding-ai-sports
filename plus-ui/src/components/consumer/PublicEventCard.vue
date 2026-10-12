<template>
  <router-link class="event-card premium-event-card" :to="preview ? '#' : '/public/events/' + event.id" @click="preview && $event.preventDefault()">
    <EventCover class="event-cover-media" :banner="cover" :tag="tag" :title="coverTitle" :two="two" />
    <div class="event-body">
      <div class="between event-kicker"><span>{{ event.projectName || '运动赛事' }}</span><span class="card-status" :class="badgeClass">{{ badge }}</span></div>
      <h3>{{ event.name }}</h3>
      <div class="event-meta">
        <span class="event-when"><ConsumerIcon name="calendar" />{{ when }}</span>
        <span class="event-place"><ConsumerIcon name="pin" />{{ event.location || '地点待公布' }}</span>
      </div>
      <div class="event-bottom event-extra">
        <span class="money">{{ feeLine }}</span>
        <span class="small">查看赛事<ConsumerIcon name="arrow" /></span>
      </div>
    </div>
  </router-link>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import ConsumerIcon from './ConsumerIcon.vue';
import EventCover from '@/components/consumer/EventCover.vue';
import { EventCard, phaseLabel, showTime } from '@/api/sports/event';
import { publicMediaUrl } from '@/api/sports/media';

const props = defineProps<{ event: EventCard; two?: boolean; preview?: boolean; bannerOverride?: string }>();

const cover = computed(() => (props.bannerOverride !== undefined ? props.bannerOverride : props.event.bannerFileId ? publicMediaUrl(props.event.id, 'banner') : ''));
const coverTitle = computed(() => props.event.name || '运动赛事');
const tag = computed(() => props.event.projectName || '运动赛事');
const badge = computed(() => (props.event.holdingStatus === 'cancelled' ? '已取消' : phaseLabel(props.event.phase)));
const badgeClass = computed(() => {
  if (props.event.holdingStatus === 'cancelled') {
    return 'red';
  }
  if (props.event.phase === 'registration') {
    return '';
  }
  return 'gray';
});
const when = computed(() => {
  const start = props.event.startsAt ? showTime(props.event.startsAt).slice(0, 10) : null;
  const end = props.event.endsAt ? showTime(props.event.endsAt).slice(0, 10) : null;
  if (start && end) {
    return `${start} — ${end}`;
  }
  return phaseLabel(props.event.phase);
});
const feeLine = computed(() => props.event.feeDescription || '收费见详情');
</script>
<style scoped>
.event-card.premium-event-card{display:block;border:1px solid var(--s-line,#e6e8e4);background:var(--s-surface,#fff);border-radius:21px;overflow:hidden;color:var(--s-ink,#202321);box-shadow:none;transition:transform .3s cubic-bezier(.2,.8,.2,1),box-shadow .3s,border-color .3s}
.premium-event-card:hover{transform:translateY(-4px);box-shadow:0 15px 30px #20232108;border-color:#d4d8ce}
/* The component owns cover and information layout, including on legacy consumer pages. */
.event-card.premium-event-card .event-cover-media{display:block;height:165px;min-width:0;border-radius:0}
.premium-event-card .event-body{padding:21px 23px;min-width:0}
.premium-event-card .event-kicker{margin:0 0 10px;font-size:10px;color:var(--s-muted,#737a75)}
.card-status{display:flex;align-items:center;gap:5px;color:#738565}
.card-status:before{content:'';height:5px;width:5px;border-radius:50%;background:currentColor}
.card-status.gray{color:#939990}.card-status.red{color:#bb634e}
.premium-event-card h3{font-size:17px;line-height:1.5;letter-spacing:-.03em;font-weight:600;margin:0 0 10px;overflow-wrap:anywhere}
.premium-event-card .event-meta{display:flex;flex-direction:column;gap:7px;font-size:11px;color:var(--s-muted,#737a75);margin:0}
.event-card.premium-event-card .event-meta>span{display:flex;align-items:flex-start;gap:6px;line-height:1.6;min-width:0;overflow-wrap:anywhere}
.premium-event-card .event-meta svg{height:13px;width:13px;flex-shrink:0;margin-top:2px}
.event-card.premium-event-card .event-bottom{margin:19px 0 0;padding:13px 0 0;border-top:1px solid var(--s-line,#e6e8e4);display:flex;justify-content:space-between;gap:10px;align-items:center}
.premium-event-card .money{font-size:12px;color:var(--s-ink,#202321);font-weight:600;line-height:1.5}
.premium-event-card .event-bottom .small{display:flex;align-items:center;gap:5px;font-size:10px;white-space:nowrap;color:var(--s-muted,#737a75)}
.premium-event-card .event-bottom svg{height:14px;width:14px}
@media(max-width:600px){
  .event-card.premium-event-card{display:grid;grid-template-columns:104px minmax(0,1fr);border-radius:18px}
  .event-card.premium-event-card .event-cover-media{height:100%;min-height:193px;grid-column:1}
  .premium-event-card .event-body{padding:17px;grid-column:2}
  .premium-event-card h3{font-size:14px;margin-bottom:8px}
  .premium-event-card .event-kicker{font-size:9px;gap:5px;margin-bottom:8px;flex-wrap:wrap}
  .premium-event-card .event-meta{font-size:10px;gap:5px}
  .event-card.premium-event-card .event-bottom{margin-top:13px;padding-top:10px}
  .premium-event-card .money{font-size:11px}
  .premium-event-card .event-bottom .small{font-size:0}
  .premium-event-card .event-bottom .small svg{font-size:12px}
}
@media(max-width:380px){
  .event-card.premium-event-card{display:block}
  .event-card.premium-event-card .event-cover-media{height:132px;min-height:0}
}
@media(prefers-reduced-motion:reduce){.premium-event-card{transition:none}.premium-event-card:hover{transform:none}}
</style>
