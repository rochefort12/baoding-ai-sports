<template>
  <form class="sport-event-filters" role="search" aria-label="筛选赛事" @submit.prevent>
    <label class="sport-event-filters__search"><span class="filter-sr">搜索赛事名称</span><svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="8.5" cy="8.5" r="5.5"/><path d="m13 13 4 4"/></svg><input type="search" :value="keyword" placeholder="赛事名称" @input="emit('update:keyword', ($event.target as HTMLInputElement).value)" /></label>
    <div class="sport-event-filters__select"><SportSelect :model-value="sport" :options="sports.map(option=>({value:option.id,label:option.name}))" aria-label="运动项目" @update:model-value="emit('update:sport', String($event))" /></div>
    <div class="sport-event-filters__select"><SportSelect :model-value="status" :options="statuses.map(option=>({value:option.id,label:option.name}))" aria-label="赛事状态" @update:model-value="emit('update:status', String($event))" /></div>
    <button v-if="keyword.trim() || sport !== 'all' || status !== 'all'" class="sport-event-filters__reset" type="button" aria-label="清除筛选" title="清除筛选" @click="emit('reset')"><svg viewBox="0 0 20 20" aria-hidden="true"><path d="m6 6 8 8M14 6l-8 8"/></svg></button>
  </form>
</template>
<script setup lang="ts">
import SportSelect from './SportSelect.vue';
defineProps<{ keyword: string; sport: string; status: string; sports: { id: string; name: string }[]; statuses: { id: string; name: string }[] }>();
const emit = defineEmits<{ 'update:keyword': [value: string]; 'update:sport': [value: string]; 'update:status': [value: string]; reset: [] }>();
</script>
<style scoped>
.sport-event-filters{display:flex;align-items:center;gap:8px;min-width:0;width:100%;margin:0 0 20px}
.sport-event-filters__search{display:flex;align-items:center;gap:9px;flex:1;min-width:0;height:42px;padding:0 12px;border:1px solid var(--s-line,#e6e8e4);border-radius:14px;background:var(--s-surface,#fff)}
.sport-event-filters__search>svg{width:15px;height:15px;flex-shrink:0;stroke:var(--s-muted,#737a75);stroke-width:1.5;fill:none}.sport-event-filters__search input{width:100%;min-width:0;border:0;background:transparent;color:var(--s-ink,#202321);font:400 12px var(--s-font,system-ui);outline:none}
.sport-event-filters__select{min-width:0;flex:0 0 132px}.sport-event-filters__select :deep(.sport-select__trigger){font-size:12px;border-radius:14px}
.sport-event-filters__search:focus-within{outline:none;box-shadow:var(--s-control-ring);border-color:#b2b8aa}.sport-event-filters__search:has(input:focus-visible){outline:2px solid #87917e60;outline-offset:3px}.sport-event-filters__reset{display:grid;place-items:center;flex:0 0 42px;height:42px;border:1px solid var(--s-line,#e6e8e4);border-radius:14px;background:var(--s-surface,#fff);color:var(--s-muted,#737a75);cursor:pointer}.sport-event-filters__reset svg{width:18px;height:18px;fill:none;stroke:currentColor;stroke-width:1.5}.sport-event-filters__reset:focus-visible{outline:2px solid #87917e70;outline-offset:3px}.filter-sr{position:absolute;width:1px;height:1px;clip:rect(0,0,0,0);overflow:hidden;white-space:nowrap}
@media(max-width:700px){.sport-event-filters{gap:6px;margin-bottom:16px}.sport-event-filters__select{flex-basis:86px}.sport-event-filters__select :deep(.sport-select__trigger){padding-inline:7px;font-size:11px;gap:4px;border-radius:12px}.sport-event-filters__search{padding:0 9px;gap:6px}.sport-event-filters__search input{font-size:11px}.sport-event-filters__reset{flex-basis:36px}.sport-event-filters__search,.sport-event-filters__reset{border-radius:12px}}
</style>
