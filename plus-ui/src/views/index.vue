<template>
  <GovernmentWorkbench v-if="government" />
  <div v-else class="app-container product-admin">
    <div class="b-heading"><div><h1>{{platform ? '平台工作台' : '工作台'}}</h1><p>{{platform ? '处理主办方入驻，管理平台业务与助手权限。' : '查看当前岗位可办理的业务。'}}</p></div><el-button v-if="platform" :loading="loading" @click="load">刷新</el-button></div>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <template v-if="platform">
      <div class="product-metrics"><router-link to="/sports-platform?tab=government"><span>待分配审核申请</span><strong>{{loading?'—':applications}}</strong><small>分配审核责任 →</small></router-link><router-link to="/sports-platform"><span>已开放人工办理能力</span><strong>{{loading?'—':manualCount}}</strong><small>管理业务能力 →</small></router-link><router-link to="/sports-platform?tab=agents"><span>已开放助手办理能力</span><strong>{{loading?'—':agentCount}}</strong><small>管理助手权限 →</small></router-link></div>
      <section class="product-workbench"><h2>平台管理</h2><div class="product-shortcuts"><router-link to="/sports-platform?tab=government"><strong>政府职责分配</strong><small>审核人 · 主办方管理范围</small></router-link><router-link to="/sports-platform?tab=objects"><strong>业务对象</strong><small>对象目录 · 所属业务域</small></router-link><router-link to="/sports-platform?tab=capabilities"><strong>办理权限</strong><small>人工与助手渠道</small></router-link><router-link to="/sports-platform?tab=agents"><strong>智能体</strong><small>职能 · 版本 · 开放状态</small></router-link><router-link to="/sports-platform?tab=growth"><strong>成长规则</strong><small>积分 · 段位 · 称号</small></router-link></div></section>
    </template>
    <section v-else class="product-workbench"><h2>业务入口</h2><nav class="product-shortcuts"><router-link v-for="entry in entries" :key="entry.path" :to="entry.path"><strong>{{entry.title}}</strong></router-link></nav><p v-if="!entries.length">当前岗位尚未分配业务菜单，请联系平台管理人员。</p></section>
  </div>
</template>
<script setup lang="ts" name="Index">
import {useUserStore} from '@/store/modules/user';import {usePermissionStore} from '@/store/modules/permission';import request from '@/utils/request';import GovernmentWorkbench from '@/views/sports/government/index.vue';
const user=useUserStore();const platform=computed(()=>user.permissions.includes('*:*:*'));const government=computed(()=>!platform.value&&(user.roles.includes('sports_government')||user.permissions.includes('sports:government:summary')));
const applications=ref(0),manualCount=ref(0),agentCount=ref(0),loading=ref(true),error=ref('');
const entries=computed(()=>{const items:{path:string;title:string}[]=[];function visit(rows:any[],prefix=''){for(const row of rows||[]){const path=(row.path?.startsWith('/')?row.path:prefix+'/'+row.path).replace(/\/+/g,'/');if(row.children)visit(row.children,path);else if(!row.hidden&&row.meta?.title&&path!=='/index'&&!path.includes(':')&&!/^(https?:)/.test(path))items.push({path,title:String(row.meta.title)});}}visit(usePermissionStore().sidebarRouters);return items.slice(0,10);});
async function load(){loading.value=true;try{const responses=await Promise.all([request<{activations:{channel:string;enabled:boolean}[]}>({url:'/sports/platform/management'}),request<{applications:unknown[]}>({url:'/sports/government/administration'})]);manualCount.value=responses[0].data.activations.filter(a=>a.enabled&&a.channel==='ui').length;agentCount.value=responses[0].data.activations.filter(a=>a.enabled&&a.channel==='agent').length;applications.value=responses[1].data.applications.length;error.value='';}catch{error.value='工作台数据读取失败，请重试。';}finally{loading.value=false;}}
onMounted(()=>{if(platform.value)load();else loading.value=false;});
</script>
