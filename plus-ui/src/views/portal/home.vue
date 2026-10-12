<template>
  <ConsumerShell>
    <div class="premium-home">
      <header class="home-greeting"><div><span>保定 · 赛事与队友</span><h1>找到下一场比赛</h1></div></header>
      <ConsumerState v-if="loading" loading title="正在寻找身边的赛事" />
      <ConsumerState v-else-if="error" error title="赛事暂时无法读取" :description="error"><button class="btn" @click="load">重新加载</button></ConsumerState>
      <div v-else class="home-feature-grid">
        <section class="home-feature">
          <img class="home-feature-art" :src="heroImage" alt="" draggable="false" @error="heroFailed=true" />
          <div class="home-feature-copy">
            <span class="feature-tag"><i />{{ featured ? featured.projectName || '运动赛事' : 'AI体育 · AI SPORTS' }}<span v-if="featured">{{ featured.holdingStatus==='cancelled' ? '已取消' : phaseLabel(featured.phase) }}</span></span>
            <h2 :title="featured?.name || '查看近期比赛'">{{ featured?.name || '查看近期比赛' }}</h2>
            <p v-if="featured" class="feature-location"><ConsumerIcon name="pin" />{{ featured.location || '地点待公布' }}</p>
            <p v-else class="feature-location">按项目、时间和地点选择比赛。</p>
            <p v-if="featured?.startsAt" class="feature-date">{{ showTime(featured.startsAt) }}</p>
            <div class="feature-bottom"><div v-if="featured"><strong :title="featured.feeDescription || '费用见赛事详情'">{{ featured.feeDescription || '费用见赛事详情' }}</strong><small>按比赛项目查看报名安排</small></div><SportArtAction art="registration" tone="primary" :to="featured ? '/public/events/'+featured.id : '/public/events'">{{ featured ? '查看赛事' : '发现赛事' }}</SportArtAction></div>
          </div>
        </section>
        <aside class="home-personal">
          <section class="home-squad">
            <span class="home-small-label">我的集结</span><h3>{{ firstRoom?.name || '寻找参赛搭档' }}</h3>
            <p>{{ firstRoom ? firstRoom.event_name+' · '+firstRoom.unit_name : '双打缺一位？发布招募或寻找搭档。' }}</p>
            <div class="squad-summary"><span v-if="firstRoom">{{ firstRoom.member_count+' / '+firstRoom.max_members+' 人' }}</span><SportArtAction art="rooms" small :to="firstRoom ? '/portal/rooms/'+firstRoom.id : '/portal/rooms'">{{ firstRoom ? '查看房间' : '招募与匹配' }}</SportArtAction></div>
          </section>
          <div class="home-next"><ConsumerNextStep /></div>
        </aside>
      </div>
      <nav class="home-services" aria-label="常用服务"><SportArtAction v-for="service in services" :key="service.path" :art="service.art" :to="service.path" layout="tile">{{ service.label }}</SportArtAction></nav>
      <section class="home-event-section"><div class="home-section-title"><div><h2>近期赛事</h2><span>{{ rows.length }} 场公开赛事</span></div><router-link to="/public/events">查看全部 <ConsumerIcon name="arrow"/></router-link></div>
        <SportEventFilters v-model:keyword="keyword" v-model:sport="sport" v-model:status="feedMode" :sports="sports" :statuses="statuses" @reset="resetFilters" />
        <div class="home-event-grid"><ConsumerState v-if="!loading && !error && !filtered.length" title="暂时没有符合条件的赛事" description="可以清除筛选，或查看已有报名。"><button v-if="feedMode!=='all'||sport!=='all'||keyword.trim()" class="btn" @click="resetFilters">清除筛选</button><router-link v-else class="btn" to="/portal/registration">我的报名</router-link></ConsumerState><PublicEventCard v-for="row in filtered" :key="row.id" :event="row" /></div>
      </section>
      <div class="home-host"><span>主办方服务</span><router-link to="/portal/organization">组织入驻与办赛 <ConsumerIcon name="arrow"/></router-link></div>
    </div>
  </ConsumerShell>
</template>
<script setup lang="ts" name="PortalHome">
import { computed, onMounted, ref } from 'vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import PublicEventCard from '@/components/consumer/PublicEventCard.vue';
import ConsumerNextStep from '@/components/consumer/ConsumerNextStep.vue';
import SportArtAction from '@/components/sport-ui/SportArtAction.vue';
import SportEventFilters from '@/components/sport-ui/SportEventFilters.vue';
import { type EventCard, listPublicEvents, phaseLabel, showTime } from '@/api/sports/event';
import { getRooms, type RoomSummary } from '@/api/sports/phase1';
import { getPlatformToken } from '@/utils/auth';
import { publicMediaUrl } from '@/api/sports/media';
const rows=ref<EventCard[]>([]),loading=ref(true),error=ref(''),feedMode=ref('all'),sport=ref('all'),keyword=ref(''),firstRoom=ref<RoomSummary>(),heroFailed=ref(false);
const featured=computed(()=>rows.value.find(e=>e.holdingStatus!=='cancelled'&&e.phase==='registration')||rows.value.find(e=>e.holdingStatus!=='cancelled'));
const heroImage=computed(()=>featured.value?.bannerFileId&&!heroFailed.value?publicMediaUrl(featured.value.id,'banner'):'/images/sports/badminton-hero-v1.webp');
const services=[{path:'/portal/registration',art:'registration',label:'我的报名'},{path:'/portal/rooms',art:'rooms',label:'找队友'},{path:'/portal/teams',art:'teams',label:'我的小队'},{path:'/portal/growth',art:'growth',label:'成长与荣誉'},{path:'/portal/results',art:'results',label:'赛果与证明'}] as const;
const sports=computed(()=>[{id:'all',name:'全部项目'},...Array.from(new Set(rows.value.map(e=>e.projectName).filter((name):name is string=>Boolean(name)))).map(name=>({id:name,name}))]);
const statuses=[{id:'all',name:'全部赛事'},{id:'open',name:'可报名'},{id:'ongoing',name:'进行中'},{id:'finished',name:'已结束'}];
const filtered=computed(()=>rows.value.filter(e=>{
  if(sport.value!=='all'&&e.projectName!==sport.value)return false;
  if(keyword.value.trim()&&!(e.name||'').toLocaleLowerCase().includes(keyword.value.trim().toLocaleLowerCase()))return false;
  if(feedMode.value==='open')return e.phase==='registration'&&e.holdingStatus!=='cancelled';
  if(feedMode.value==='ongoing')return e.phase==='ongoing'&&e.holdingStatus!=='cancelled';
  if(feedMode.value==='finished')return e.phase==='finished';
  return true;
}).slice(0,6));
const resetFilters=()=>{feedMode.value='all';sport.value='all';keyword.value='';};
const priority=(e:EventCard)=>e.holdingStatus==='cancelled'?9:({registration:0,pre_registration:1,ongoing:2,registration_closed:3,finished:4} as Record<string,number>)[e.phase||'']??5;
const load=async()=>{loading.value=true;error.value='';try{const res=await listPublicEvents();rows.value=[...(res.data||[])].sort((a,b)=>priority(a)-priority(b));heroFailed.value=false;}catch(cause){error.value=cause instanceof Error?cause.message:'公开赛事暂时无法读取。';}finally{loading.value=false;}if(getPlatformToken()){try{firstRoom.value=(await getRooms()).data.rooms[0];}catch{firstRoom.value=undefined;}}};
onMounted(load);
</script>
<style scoped>
.premium-home{padding-top:8px;min-width:0}
.home-greeting{display:flex;justify-content:space-between;align-items:center;gap:20px;margin-bottom:28px}
.home-greeting>div{min-width:0}.home-greeting>div>span{font-size:12px;color:var(--s-muted);display:block;margin-bottom:8px}
.home-greeting h1{font-size:32px;letter-spacing:-.05em;font-weight:600;margin:0}
.home-feature-grid{display:grid;grid-template-columns:minmax(0,1fr) 310px;gap:22px;align-items:stretch}
.home-feature{position:relative;height:auto;min-height:560px;border-radius:26px;background:#e8e9e2;overflow:hidden;isolation:isolate}
.home-feature-art{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:58% center;z-index:-2}
.home-feature:after{content:'';position:absolute;inset:0;background:linear-gradient(90deg,#eeefe8 0%,#eeefe8ed 25%,#eeefe850 52%,transparent 75%);z-index:-1}
.home-feature-copy{padding:30px 34px;width:66%;height:100%;min-height:0;min-width:0;display:flex;align-items:flex-start;flex-direction:column}
.feature-tag{display:inline-flex;align-items:center;gap:7px;font-size:11px;color:#687663;background:#f8f9f4bf;border:1px solid #dde3d3;padding:6px 11px;border-radius:20px;max-width:100%;flex-wrap:wrap}
.feature-tag i{width:5px;height:5px;border-radius:50%;background:#90a476}.feature-tag>span{border-left:1px solid #bbc7af;padding-left:8px}
.home-feature h2{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;font-size:39px;line-height:1.25;font-weight:600;letter-spacing:-.055em;margin:24px 0 14px;overflow-wrap:anywhere;color:#32382e;max-width:100%}
.feature-location{display:flex;align-items:flex-start;gap:7px;color:#67715d;font-size:12px;line-height:1.8;margin:0;max-width:270px;overflow-wrap:anywhere}
.feature-location svg{width:14px;height:14px;margin-top:4px;flex-shrink:0}.feature-date{font-size:12px;color:#67715d;margin:8px 0 0}
.feature-bottom{display:grid;grid-template-columns:minmax(0,1fr) auto;align-items:center;gap:16px;margin-top:auto;padding-top:22px;width:100%;min-width:0}
.feature-bottom>div{display:flex;flex-direction:column;gap:6px;min-width:0}.feature-bottom strong{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;overflow-wrap:anywhere;font-size:18px;line-height:1.45;letter-spacing:-.03em;color:#454d3c}
.feature-bottom small{font-size:10px;color:#727965}
.home-personal{display:grid;grid-template-rows:auto auto;gap:16px;min-width:0;align-items:stretch}
.home-squad{display:flex;flex-direction:column;min-width:0;min-height:0;border:1px solid var(--s-line);border-radius:24px;background:var(--s-surface);padding:16px;color:var(--s-ink);transition:border-color .2s,transform .24s var(--s-ease)}
.home-squad:hover{border-color:#d0d6c8;transform:translateY(-1px)}
.home-small-label{font-size:var(--s-type-caption,13px);color:var(--s-muted)}.home-squad h3{font-size:18px;letter-spacing:-.04em;line-height:1.4;margin:8px 0 6px;overflow-wrap:anywhere}
.home-squad p{font-size:var(--s-type-body,16px);color:var(--s-muted);line-height:1.55;margin:0;overflow-wrap:anywhere}
.squad-summary{display:flex;align-items:center;gap:10px;margin-top:auto;padding-top:8px;font-size:12px;min-width:0}
.squad-summary>span{font-size:11px;color:var(--s-muted)}
.squad-summary :deep(.sport-art-action){--action-art-size:28px;gap:4px;padding:4px 9px 4px 4px}.squad-summary :deep(.sport-art-action__label){white-space:normal}
.home-next{display:flex;min-width:0;min-height:0}
.home-next :deep(.c-next-step){display:flex;flex-direction:column;flex:1;min-width:0;min-height:100%;border:1px solid var(--s-line);background:var(--s-surface);border-radius:24px;padding:16px}
.home-next :deep(.section-head){flex-shrink:0;gap:8px;margin:0 0 8px}.home-next :deep(.section-head h2){font-size:13px;font-weight:500;color:var(--s-muted);min-width:0}
.home-next :deep(.section-head .btn){font-size:10px;padding:0;min-height:24px}
.home-next :deep(.c-task-card){display:flex;flex-direction:column;flex:1;min-width:0;padding:0;background:none;border:0;box-shadow:none}
.home-next :deep(.c-task-card h3){font-size:17px;line-height:1.5;margin:6px 0;overflow-wrap:anywhere}
.home-next :deep(.c-task-card p){font-size:var(--s-type-body,16px);line-height:1.55;margin:4px 0 8px;overflow-wrap:anywhere}
.home-next :deep(.c-task-card>.sport-art-action){align-self:flex-start;margin-top:auto}
.home-next :deep(.c-task-symbol){display:none}.home-next :deep(.c-task-progress){display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;padding-top:6px;margin-bottom:10px}.home-next :deep(.c-task-progress span){padding:2px 0;white-space:normal;overflow-wrap:anywhere}
.home-next :deep(.c-task-members){margin:4px 0 8px;gap:8px}.home-next :deep(.c-task-members .account-avatar){width:26px;height:26px;flex:0 0 26px}.home-next :deep(.c-help-card){margin-top:12px;font-size:11px;padding:12px}
.home-services{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px;margin:25px 0 35px}
.home-section-title{display:flex;align-items:center;gap:18px;margin:0 0 19px}.home-section-title>div{flex:1;display:flex;align-items:baseline;gap:12px}
.home-section-title h2{font-size:21px;font-weight:600;letter-spacing:-.035em;margin:0}.home-section-title span{font-size:11px;color:var(--s-muted)}
.home-section-title>a{font-size:12px;display:flex;align-items:center;gap:6px;color:var(--s-muted)}.home-section-title>a svg{width:14px;height:14px}
.home-event-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));gap:20px}.home-event-grid :deep(>.sport-empty){grid-column:1/-1}
.home-host{display:flex;justify-content:space-between;align-items:center;padding:25px 0 4px;margin-top:25px;border-top:1px solid var(--s-line);font-size:12px;color:var(--s-muted)}
.home-host>a{display:flex;align-items:center;gap:10px;color:var(--s-ink)}.home-host svg{width:14px;height:14px}
@media(max-width:1100px){
 .home-feature-grid{grid-template-columns:minmax(0,1fr) 300px}.home-feature-copy{padding:28px;width:76%}.home-feature h2{font-size:34px}
}
@media(max-width:800px){
 .home-greeting{margin-bottom:22px;gap:12px}.home-greeting h1{font-size:27px}
 .home-feature-grid{grid-template-columns:minmax(0,1fr)}.home-feature{height:auto;min-height:340px;border-radius:22px}.home-feature-copy{width:100%;height:auto;min-height:340px;padding:24px}
 .home-feature:after{background:linear-gradient(90deg,#eeefe8 0%,#eeefe8e6 26%,#eeefe88f 62%,transparent 100%)}
 .home-feature h2{font-size:32px;max-width:100%;margin-top:20px}.home-feature-art{object-position:66% center;opacity:.86}
 .feature-location,.feature-date{max-width:220px;font-size:11px}.feature-bottom{gap:12px;padding-top:20px}.feature-bottom strong{font-size:16px}.feature-bottom small{display:none}
 .home-personal{grid-template-columns:repeat(2,minmax(0,1fr));grid-template-rows:auto;gap:13px}
 .home-squad{padding:20px;border-radius:19px}.home-squad h3{font-size:17px}.home-squad p{font-size:11px}.squad-summary{font-size:10px;gap:7px;flex-wrap:wrap}
 .home-next :deep(.c-next-step){padding:20px;border-radius:19px}.home-next :deep(.section-head h2){font-size:12px}.home-next :deep(.section-head .btn){display:none}
 .home-next :deep(.c-task-card h3){font-size:15px}.home-next :deep(.c-task-card p){font-size:11px;margin-bottom:12px}
 .home-services{gap:7px;margin:20px 0 29px}
 .home-section-title{flex-wrap:wrap;gap:12px}.home-section-title>div{flex-basis:100%}.home-section-title h2{font-size:20px}.home-section-title>a{margin-left:auto}
 .home-event-grid{gap:15px}
}
@media(max-width:560px){.home-feature h2{max-width:100%}.home-personal{grid-template-columns:minmax(0,1fr)}.home-squad,.home-next :deep(.c-next-step){padding:18px}.squad-summary{padding-top:12px}.home-services{grid-template-columns:repeat(3,minmax(0,1fr))}.home-services :deep(.sport-art-action__label){white-space:normal}}
@media(prefers-reduced-motion:reduce){.home-squad{transition:none}.home-squad:hover{transform:none}}
</style>
