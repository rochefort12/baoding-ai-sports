<template>
  <div class="app-container product-admin">
    <div class="b-heading"><div><h1>平台工作台</h1><p>管理主办方责任、业务开放范围与运动成长规则。</p></div><el-button :loading="loading" @click="load">刷新</el-button></div>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <div class="product-metrics">
      <SportMetric label="业务对象" :value="loading ? '—' : data?.modules.length || 0" note="查看对象与字段" />
      <SportMetric label="已开放页面操作" :value="loading ? '—' : data?.activations.filter(item => item.channel === 'ui' && item.enabled).length || 0" note="管理开放范围" featured />
      <SportMetric label="已启用助手定义" :value="loading ? '—' : data?.agents.filter(item => item.status === 'active').length || 0" note="查看分工与调用渠道" />
    </div>
    <el-tabs v-model="activeTab">
      <el-tab-pane name="objects" :label="'业务对象 · '+(data?.modules.length||0)">
        <div class="b-toolbar product-object-filter">
          <el-input v-model="search" placeholder="搜索对象名称或业务表" clearable />
          <el-select v-model="domain" placeholder="全部业务域" clearable><el-option v-for="(label,code) in domains" :key="code" :label="label" :value="code" /></el-select>
          <span class="b-muted">共 {{ filtered.length }} 个对象</span>
        </div>
        <el-table :data="pageModules" v-loading="loading" :max-height="560">
          <el-table-column label="业务对象" min-width="230"><template #default="{row}"><strong>{{ objectName(row) }}</strong><small class="product-object-code">{{ row.name }}</small></template></el-table-column>
          <el-table-column label="业务域" min-width="120"><template #default="{row}">{{ domains[row.domain]||row.domain }}</template></el-table-column>
          <el-table-column label="详情" width="85" fixed="right"><template #default="{row}"><el-button link type="primary" @click="selectedObject=row">查看</el-button></template></el-table-column>
        </el-table>
        <el-pagination v-model:current-page="page" :page-size="20" :total="filtered.length" layout="prev, pager, next" class="product-object-pagination" />
      </el-tab-pane>
      <el-tab-pane name="capabilities" label="能力与开放渠道">
        <el-table :data="data?.definitions||[]" :max-height="650">
          <el-table-column label="能力" min-width="190"><template #default="{row}">{{ row.definition.title }}</template></el-table-column>
          <el-table-column label="办理前确认" min-width="150"><template #default="{row}">{{ row.definition.confirmation?'需本人确认':'按本人操作办理' }}</template></el-table-column>
          <el-table-column label="开放渠道" min-width="130"><template #default="{row}">{{ channels(row.definition.code) }}</template></el-table-column>
          <el-table-column label="管理" min-width="165" fixed="right"><template #default="{row}"><el-button link type="primary" @click="release(row,'ui')">人工渠道</el-button><el-button v-if="row.definition.agent" link type="primary" @click="release(row,'agent')">助手渠道</el-button></template></el-table-column>
        </el-table>
      </el-tab-pane>
      <el-tab-pane name="agents" label="智能体分工">
        <el-table :data="data?.agents||[]">
          <el-table-column prop="name" label="助手" min-width="160" />
          <el-table-column label="分工" min-width="110"><template #default="{row}">{{ layers[row.layer]||row.layer }}</template></el-table-column>
          <el-table-column prop="model_name" label="模型" min-width="160" />
          <el-table-column prop="revision" label="版本" width="80" />
          <el-table-column label="状态" min-width="110"><template #default="{row}">{{ agentStates[row.status]||row.status }}</template></el-table-column>
        </el-table>
      </el-tab-pane>
      <el-tab-pane name="government" label="政府责任分配"><GovernmentAssignments /></el-tab-pane>
      <el-tab-pane name="growth" label="成长规则"><GrowthRules /></el-tab-pane>
      <el-tab-pane name="honor" label="荣誉认证"><HonorCertificationReview /></el-tab-pane>
    </el-tabs>
    <el-drawer :model-value="!!selectedObject" :title="selectedObject?objectName(selectedObject):'对象详情'" size="min(680px,100vw)" @close="selectedObject=undefined">
      <template v-if="selectedObject">
        <p>{{ selectedObject.description }}</p>
        <el-descriptions :column="1" border class="product-object-description"><el-descriptions-item label="业务域">{{ domains[selectedObject.domain] }}</el-descriptions-item><el-descriptions-item label="业务表">{{ selectedObject.name }}</el-descriptions-item><el-descriptions-item label="独立模块">{{ selectedObject.moduleId }}</el-descriptions-item><el-descriptions-item label="开放方式">具体业务由已开放能力办理，结构登记不代表已开放通用读写。</el-descriptions-item></el-descriptions>
        <h3>字段定义</h3>
        <el-table :data="selectedObject.columns"><el-table-column prop="name" label="字段" min-width="150" /><el-table-column prop="description" label="用途" min-width="230" /></el-table>
      </template>
    </el-drawer>
  </div>
</template>
<script setup lang="ts">
import {useRoute} from 'vue-router';
import request from '@/utils/request';
import GovernmentAssignments from './GovernmentAssignments.vue';
import GrowthRules from './GrowthRules.vue';
import HonorCertificationReview from '@/components/business/HonorCertificationReview.vue';
import SportMetric from '@/components/sport-ui/SportMetric.vue';
import {ElMessageBox} from 'element-plus';
interface Definition {definition:{code:string;title:string;confirmation:boolean;agent:boolean};definitionHash:string}
interface ObjectModule {name:string;domain:string;description:string;moduleId:string;lifecycle:string;columns:{name:string;description:string}[]}
interface Catalog {modules:ObjectModule[];definitions:Definition[];activations:{code:string;channel:string;enabled:boolean}[];agents:Record<string,string>[]}
const domains:Record<string,string>={D01:'主办方与授权',D02:'账号与个人',D03:'队伍与匹配',D04:'赛事与规则',D05:'报名与资格',D06:'资金与收款',D07:'冲突与约束',D08:'赛制与编排',D09:'现场与比赛',D10:'成绩与荣誉',D11:'通知与送达',D12:'场馆与资源',D13:'平台与智能体'};
const layers:Record<string,string>={platform:'平台助手',domain:'业务助手',function:'职能助手'};
const agentStates:Record<string,string>={active:'已配置',draft:'待配置',disabled:'已停用',suspended:'已暂停'};
const activeTab=ref(String(useRoute().query.tab||'objects')),data=ref<Catalog>(),error=ref(''),loading=ref(false),search=ref(''),domain=ref(''),page=ref(1),selectedObject=ref<ObjectModule>();
const filtered=computed(()=>data.value?.modules.filter(m=>(!domain.value||m.domain===domain.value)&&[m.name,m.description,domains[m.domain]].join(' ').toLowerCase().includes(search.value.toLowerCase()))||[]);
const pageModules=computed(()=>filtered.value.slice((page.value-1)*20,page.value*20));
watch([search,domain],()=>{page.value=1;});
function objectName(row:ObjectModule){return row.description.split(/[。；]/)[0];}
function channels(code:string){const values=data.value?.activations.filter(a=>a.code===code&&a.enabled).map(a=>a.channel==='ui'?'页面':a.channel==='agent'?'助手':'后台任务')||[];return values.length?values.join('、'):'未开放';}
async function load(){if(loading.value)return;loading.value=true;try{data.value=(await request<Catalog>({url:'/sports/platform/management'})).data;error.value='';}catch{error.value='无法读取平台管理目录，请核对权限。';}finally{loading.value=false;}}
async function release(row:Definition,channel:string){const enabled=!data.value?.activations.some(a=>a.code===row.definition.code&&a.channel===channel&&a.enabled);try{const result=await ElMessageBox.prompt('填写已完成验收记录的SHA256校验值，绑定此次能力开放。',`${enabled?'开放':'关闭'}「${row.definition.title}」`,{inputValidator:value=>/^[a-f0-9]{64}$/.test(value)||'请填写64位小写校验值'});await request({url:'/sports/platform/management/release',method:'post',data:{code:row.definition.code,channel,enabled,definitionHash:row.definitionHash,evidenceHash:result.value}});await load();}catch{/* Cancellation and server rejection preserve the current gate. */}}
onMounted(load);
</script>

