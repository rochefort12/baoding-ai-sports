<template>
  <section class="consumer-card team-growth">
    <div class="between"><h3>{{teamName}} · 队伍成长</h3><router-link class="btn" to="/portal/rooms">参赛房间</router-link></div>
    <template v-if="card"><div class="team-rank"><SportsRankBadge :rank-name="card.rank" size="large"/><div><b>{{card.points}} 成长分</b><small>{{card.nextThreshold===card.points ? '已达最高段位' : '下一段位 '+card.nextRank+' · 还差 '+Math.max(0,card.nextThreshold-card.points)+' 分'}}</small></div></div><div class="team-titles"><button v-for="title in card.titles" :key="title.id" :disabled="!captain||busy" :aria-pressed="card.equipment?.title_code===title.title_code" @click="equip(title.title_code)"><SportsTitleBadge :title="title.title" :code="title.title_code"/><small>{{card.equipment?.title_code===title.title_code?'正在佩戴':captain?'佩戴称号':'队伍称号'}}</small></button><small v-if="!card.titles.length">暂无队伍称号</small></div></template>
    <GrowthTitleGoals :goals="card?.titleGoals"/><h4>队内成长榜</h4><div class="team-athletes"><article v-for="member in board" :key="member.account_id"><SportsAvatar :nickname="member.nickname" :account-id="member.account_id" :avatar-file-id="member.avatar_file_id" :tone="member.avatar_style" :title="titleLabels[member.title_code||'']" :title-code="member.title_code" :points="Number(member.points)" :rank-level="member.rank_index" :rank-name="member.rank_name" compact/><small>{{member.points}} 分</small></article></div><p v-if="error" class="consumer-muted">{{error}} <button type="button" class="retry-board" @click="load">重试</button></p>
  </section>
</template>
<script setup lang="ts">
import SportsAvatar from './SportsAvatar.vue';
import GrowthTitleGoals from './GrowthTitleGoals.vue';
import SportsRankBadge from './SportsRankBadge.vue';
import SportsTitleBadge from './SportsTitleBadge.vue';
import { getTeamBoard, performAction, titleLabels } from '@/api/sports/phase1';
import { getGrowthRankCard, type GrowthRankCard } from '@/api/sports/growth';
interface BoardMember {sport_id?:string;account_id:string;nickname:string;avatar_style:string;avatar_file_id?:string|null;points:number;rank_index?:number;rank_name?:string;title_code:string|null}
const emit=defineEmits<{members:[BoardMember[]]}>();
const props=defineProps<{teamId:string;teamName:string;captain:boolean}>();
const card=ref<GrowthRankCard>(),board=ref<BoardMember[]>([]),sportId=ref(''),busy=ref(false),error=ref('');
let revision=0;
async function load(){const generation=++revision;try{const result=await getTeamBoard(props.teamId);if(generation!==revision)return;const members=result.data as BoardMember[];const sport=members[0]?.sport_id;if(!sport)throw new Error('无法确定队伍所属运动');board.value=members;emit('members',members);sportId.value=String(sport);const growth=await getGrowthRankCard(sportId.value,props.teamId);if(generation!==revision)return;card.value=growth.data;error.value='';}catch{if(generation===revision)error.value='队伍成长暂时无法读取。';}}
async function equip(titleCode:string){if(busy.value||!props.captain)return;busy.value=true;try{await performAction('growth.equip',{sportId:sportId.value,teamId:props.teamId,titleCode,...(card.value?.equipment?{expectedVersion:card.value.equipment.version}:{})});await load();}finally{busy.value=false;}}
onMounted(load);watch(()=>props.teamId,()=>{card.value=undefined;board.value=[];emit('members',[]);load();});
</script>
<style scoped>
.team-growth h3{font-size:18px;margin:0}.team-growth h4{font-size:14px;margin:24px 0 0}.team-rank{display:flex;gap:18px;align-items:center;flex-wrap:wrap;padding:23px;background:#f7f4ec;color:#8b734c;border-radius:18px;margin:23px 0}.team-rank>div{display:flex;flex-direction:column;gap:9px}.team-rank b{font-size:14px;font-weight:500}.team-rank small{font-size:11px;color:#a08c67}.team-titles{display:flex;gap:12px;margin:19px 0;flex-wrap:wrap}.team-titles button{display:flex;align-items:flex-start;flex-direction:column;gap:10px;border:1px solid #e7dbc0;border-radius:14px;background:#fffdf7;padding:14px;cursor:pointer}.team-titles button[aria-pressed=true]{border-color:#bba165;background:#fcf4dd}.team-titles button:disabled{cursor:default;opacity:.85}.team-titles small{font-size:11px;color:#95886e}.team-athletes{display:flex;gap:30px;flex-wrap:wrap;padding:24px 0}.team-athletes article{text-align:center;min-width:90px}.team-athletes small{color:#8d9788;display:block;margin-top:12px;font-size:11px}.retry-board{border:0;background:none;color:var(--s-primary);cursor:pointer}@media(max-width:600px){.team-athletes{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:25px 18px}.team-rank{padding:20px}.team-growth>.between{gap:12px;flex-wrap:wrap}}
</style>
