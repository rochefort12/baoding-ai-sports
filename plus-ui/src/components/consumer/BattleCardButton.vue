<template>
  <el-button plain :loading="busy" @click="prepare">生成战绩卡</el-button>
  <el-dialog v-model="visible" title="个人战绩卡" width="min(92vw, 440px)" @closed="clear">
    <img v-if="image" :src="image" class="battle-card-image" draggable="false" @dragstart.prevent alt="根据当前正式赛果生成的个人战绩卡" />
    <p class="consumer-note">卡片只展示运动昵称与本场赛果；生成后发生更正，以本人赛果页的最新状态为准。</p>
    <template #footer><el-button @click="visible=false">关闭</el-button><el-button type="primary" @click="download">保存战绩卡</el-button></template>
  </el-dialog>
</template>
<script setup lang="ts">
import {getDisplay} from '@/api/sports/phase1';
import {ElMessage} from 'element-plus';
const props=defineProps<{result:{eventName:string;unitName:string;matchCode:string;summary:string;games?:string;eventCancelled:boolean}}>();
const busy=ref(false),visible=ref(false),image=ref('');
const escape=(s:string)=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'})[c]!);
const trim=(s:string,n:number)=>[...s].slice(0,n).join('');
function clear(){if(image.value)URL.revokeObjectURL(image.value);image.value='';}
async function prepare(){busy.value=true;try{
  const profile=(await getDisplay()).data;const r=props.result;const time=new Date().toLocaleString('zh-CN',{timeZone:'Asia/Shanghai',hour12:false});
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="720" height="980" viewBox="0 0 720 980"><defs><linearGradient id="paper" x2="1" y2="1"><stop stop-color="#f7f5f0"/><stop offset="1" stop-color="#ebe6d9"/></linearGradient></defs><rect width="720" height="980" rx="36" fill="url(#paper)"/><circle cx="644" cy="100" r="190" fill="#e5d392" opacity=".25"/><g font-family="Microsoft YaHei, sans-serif" fill="#292b28"><text x="60" y="82" font-size="18" letter-spacing="4">AI体育</text><text x="60" y="173" font-size="46" font-weight="700">个人战绩</text><text x="60" y="219" font-size="20" fill="#70896c">正式赛果记录</text><rect x="48" y="273" width="624" height="562" rx="28" fill="#ffffff" opacity=".9"/><circle cx="360" cy="356" r="43" fill="#b9dcca"/><circle cx="360" cy="346" r="15" fill="#39826a"/><path d="M333 380c0-30 54-30 54 0" fill="#39826a"/><text x="360" y="439" text-anchor="middle" font-size="29" font-weight="700">${escape(trim(profile.display.nickname,16))}</text><text x="360" y="488" text-anchor="middle" font-size="18" fill="#8e783c">${r.eventCancelled?'取消赛事 · 保留历史':'本人参与场次 · 正式赛果'}</text><line x1="98" y1="528" x2="622" y2="528" stroke="#e1e8dc"/><text x="360" y="579" text-anchor="middle" font-size="24">${escape(trim(r.eventName,23))}</text><text x="360" y="623" text-anchor="middle" font-size="18" fill="#77896e">${escape(trim(r.unitName+' · '+r.matchCode,32))}</text><text x="360" y="697" text-anchor="middle" font-size="38" font-weight="700">${escape(trim(r.summary||'正式结果已确认',22))}</text><text x="360" y="749" text-anchor="middle" font-size="18" fill="#8d987e">${escape(trim(r.games||'未提供分局比分',33))}</text><text x="60" y="881" font-size="15" fill="#809176">生成于 ${escape(time)}（北京时间）</text><text x="60" y="915" font-size="13" fill="#87977d">最新状态：${escape(trim(location.origin+'/portal/results',68))}</text><text x="60" y="947" font-size="13" fill="#87977d">登录本人账号可查最新赛果；本卡片不替代获奖证明</text></g></svg>`;
  const source=URL.createObjectURL(new Blob([svg],{type:'image/svg+xml'}));try{const picture=new Image();picture.src=source;await picture.decode();const canvas=document.createElement('canvas');canvas.width=720;canvas.height=980;canvas.getContext('2d')!.drawImage(picture,0,0);const blob=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(new Error('卡片无法生成')),'image/png'));clear();image.value=URL.createObjectURL(blob);visible.value=true;}finally{URL.revokeObjectURL(source);}
 }catch{ElMessage.error('战绩卡暂时无法生成，请稍后重试');}finally{busy.value=false;}}
function download(){const a=document.createElement('a');a.href=image.value;a.download='运动战绩卡-'+new Date().toISOString().slice(0,10)+'.png';a.click();}
onBeforeUnmount(clear);
</script>
<style scoped>.battle-card-image{width:100%;border-radius:20px;display:block;box-shadow:0 12px 32px #38523716}</style>
