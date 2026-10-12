<template>
  <div class="event-cover" :class="{ photo: showPhoto, two }">
    <span v-if="tag" class="event-cover-tag">{{ tag }}</span>
    <img v-if="showPhoto" class="event-banner" :src="banner" alt="" draggable="false" @dragstart.prevent @error="failed = true" />
    <img v-else-if="isRacketSport" class="event-banner event-cover-fallback" src="/images/sports/badminton-hero-v1.webp" alt="" draggable="false" @dragstart.prevent />
    <div v-else class="mini-art"><ConsumerIcon name="events"/><span>{{ tag || '运动赛事' }}</span></div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import ConsumerIcon from './ConsumerIcon.vue';

const props = defineProps<{
  banner?: string;
  tag?: string;
  title?: string;
  two?: boolean;
}>();

const failed = ref(false);
watch(
  () => props.banner,
  () => {
    failed.value = false;
  }
);
const showPhoto = computed(() => Boolean(props.banner) && !failed.value);
const isRacketSport = computed(() => /羽毛球|网球|乒乓球/.test(props.tag || '') || !props.tag || props.tag === '运动赛事');
</script>
<style scoped>
.event-cover{position:relative;overflow:hidden;background:#e8ebe3;isolation:isolate}.event-banner{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:center;display:block}.event-cover-fallback{object-position:72% center}.event-cover.two .event-cover-fallback{object-position:86% center}.event-cover-tag{position:absolute;z-index:1;top:13px;left:14px;border-radius:20px;padding:5px 9px;background:#fafbf4c9;border:1px solid #fdfef887;backdrop-filter:blur(10px);color:#6c7764;font-size:9px;line-height:1.3}.mini-art{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;flex-direction:column;gap:10px;background:radial-gradient(ellipse at 70% 30%,#efdecd,transparent 60%),#e5e9e0;color:#9ca68c}.mini-art svg{width:55px;height:55px}.mini-art span{font-size:11px;letter-spacing:.1em}@media(max-width:600px){.event-cover-tag{font-size:8px;padding:4px 7px;left:8px;top:9px}.event-cover-fallback{object-position:77% center}}
</style>
