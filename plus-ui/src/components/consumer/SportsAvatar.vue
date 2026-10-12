<template>
  <div class="sports-avatar" :class="['tone-' + tone, { compact }]">
    <div class="avatar-title"><SportsTitleBadge v-if="title" :title="title" :code="titleCode" :compact="compact"/><span v-else class="title-unworn">未佩戴称号</span></div>
    <AvatarFrame :rank-name="rank">
      <img v-if="image && !failed" class="avatar-photo" :src="image" :alt="nickname + '的运动头像'" draggable="false" @dragstart.prevent @error="failed = true" />
      <span v-else class="avatar-initial" aria-hidden="true">{{ initial }}</span>
      <template #markers>
        <span v-if="captain" class="captain-mark" :aria-label="captainLabel">{{captainLabel}}</span>
        <span v-if="rank" class="avatar-rank"><SportsRankBadge :rank-name="rank" size="small"/></span>
      </template>
    </AvatarFrame>
    <strong>{{ nickname || '球友' }}</strong>
    <span v-if="ready !== undefined" class="avatar-ready" :class="{ yes: ready }">{{ ready ? '✓ 准备就绪' : '等待准备' }}</span>
  </div>
</template>
<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { publicSportsAvatarUrl, readSportsAvatar } from '@/api/sports/avatar';
import AvatarFrame from './AvatarFrame.vue';
import SportsRankBadge from './SportsRankBadge.vue';
import SportsTitleBadge from './SportsTitleBadge.vue';
const props = withDefaults(defineProps<{ nickname?: string; accountId?: string; avatarFileId?: string | null; publicAvatar?: boolean; tone?: string; title?: string | null; titleCode?:string|null; points?: number; rankLevel?: number; rankName?: string; captain?: boolean; captainLabel?: string; ready?: boolean; compact?: boolean }>(), { tone: 'mint', nickname: '', captainLabel: '队长', ready: undefined });
const image = ref(''), failed = ref(false);
let generation = 0;
// Use the server's sport-specific rank. An avatar without a loaded rank never invents a level from a default score.
const rank = computed(() => props.rankName || undefined);
const initial = computed(() => Array.from(props.nickname.trim() || '球友')[0]);
const release = () => { if (image.value.startsWith('blob:')) URL.revokeObjectURL(image.value); image.value = ''; };
watch(() => [props.accountId, props.avatarFileId, props.publicAvatar], async () => {
  const current = ++generation; release(); failed.value = false;
  if (!props.accountId || !props.avatarFileId) return;
  if (props.publicAvatar) { image.value = publicSportsAvatarUrl(props.accountId); return; }
  try {
    const body = await readSportsAvatar(props.accountId);
    if (current !== generation) return;
    image.value = URL.createObjectURL(body as unknown as Blob);
  } catch { if (current === generation) failed.value = true; }
}, { immediate: true });
onBeforeUnmount(() => { generation++; release(); });
</script>
<style scoped>
.sports-avatar{display:flex;flex-direction:column;align-items:center;gap:13px;min-width:110px;text-align:center;color:var(--s-ink,#202321);--avatar-size:100px}.avatar-title{min-height:31px;display:flex;align-items:center;justify-content:center;max-width:185px;margin-bottom:8px}.title-unworn{color:var(--s-muted,#737a75);font-size:10px;line-height:20px;opacity:.7}.avatar-initial{display:grid;place-items:center;width:100%;height:100%;font-size:34px;font-weight:600;letter-spacing:-.04em}.captain-mark{position:absolute;z-index:3;top:0;right:-17px;background:var(--s-surface,#fff);border:1px solid #d7c6ab;color:#856b45;border-radius:6px;padding:3px 6px;font-size:10px}.avatar-rank{position:absolute;z-index:3;bottom:-15px;left:50%;transform:translateX(-50%);background:var(--s-surface,#fff);border:1px solid #e8dfcf;border-radius:15px;padding:1px 7px;white-space:nowrap;box-shadow:0 2px 8px #392a1110}.sports-avatar>strong{margin-top:10px;font-size:15px;font-weight:600;max-width:170px;overflow-wrap:anywhere}.avatar-ready{font-size:12px;color:var(--s-muted,#737a75)}.avatar-ready.yes{color:#598458}.tone-mint{--avatar-fill:#e0e7dd;--avatar-ink:#62745b}.tone-violet{--avatar-fill:#e8e3ed;--avatar-ink:#81708d}.tone-sun{--avatar-fill:#efe7d3;--avatar-ink:#9c7d43}.tone-sky{--avatar-fill:#e0e9ea;--avatar-ink:#607f83}.tone-coral{--avatar-fill:#efe2da;--avatar-ink:#b4795c}.tone-ink{--avatar-fill:#e1e4e0;--avatar-ink:#656f65}.compact{min-width:76px;gap:9px;--avatar-size:64px}.compact .avatar-initial{font-size:25px}.compact>strong{font-size:13px;margin-top:9px}.compact .avatar-title{margin-bottom:3px;min-height:25px}.compact .avatar-rank{padding:0 4px;bottom:-13px}.compact .captain-mark{right:-13px;font-size:9px;padding:2px 4px}@media(max-width:600px){.sports-avatar:not(.compact){min-width:90px;--avatar-size:82px}.sports-avatar>strong{font-size:14px}.avatar-initial{font-size:29px}.avatar-title{max-width:145px;margin-bottom:4px}}
</style>