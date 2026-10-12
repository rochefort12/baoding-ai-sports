<template>
  <div class="app-container product-admin">
    <div class="b-heading">
      <div>
        <h1>主办方管理</h1>
        <p>处理分配给本岗位的入驻申请、办赛资格和投诉。</p>
      </div>
      <el-button :loading="loading" @click="load">刷新</el-button>
    </div>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <div class="product-metrics">
      <SportMetric label="待审核入驻" :value="loading ? '—' : pending" note="查看申请" to="/organization-review/index" featured />
      <SportMetric
        label="管理的主办方"
        :value="loading ? '—' : rows.length"
        :note="rows.filter((r) => r.status !== 'certified').length + ' 家资格已暂停'"
      />
      <SportMetric
        label="待处理投诉"
        :value="loading ? '—' : rows.reduce((sum, r) => sum + Number(r.open_complaints), 0)"
        note="进入投诉协调"
        to="/government/issues"
      />
    </div>
    <SportCard flat class="sport-art-paper"
      ><template #header
        ><div class="b-toolbar">
          <strong>管理范围内的主办方</strong><router-link to="/organization-review/index"><el-button>审核入驻申请</el-button></router-link>
        </div></template
      ><div class="government-filter"><el-input v-model="query" placeholder="搜索主办方名称" clearable aria-label="搜索管理范围内的主办方" /><el-select v-model="qualification" clearable placeholder="全部资格"><el-option value="certified" label="正常办赛" /><el-option value="restricted" label="资格已暂停" /></el-select><span class="b-muted">{{ filteredRows.length }} 家</span></div>
      <el-table :data="filteredRows" v-loading="loading" :empty-text="query || qualification ? '没有符合条件的主办方' : '尚未分配主办方管理范围'"
        ><el-table-column prop="name" label="主办方" min-width="200" /><el-table-column label="办赛资格" min-width="100"
          ><template #default="{ row }"
            ><el-tag :type="row.status === 'certified' ? 'success' : 'warning'">{{
              row.status === 'certified' ? '正常' : '已暂停'
            }}</el-tag></template
          ></el-table-column
        ><el-table-column prop="event_count" label="赛事数" min-width="80" /><el-table-column
          prop="registration_count"
          label="有效报名"
          min-width="90"
        /><el-table-column prop="open_complaints" label="待处理投诉" min-width="100" /><el-table-column label="操作" min-width="150" fixed="right"
          ><template #default="{ row }"
            ><el-button link :type="row.status === 'certified' ? 'warning' : 'primary'" :loading="actingId === row.id" :disabled="!!actingId || loading" @click="qualify(row)">{{
              row.status === 'certified' ? '暂停办赛资格' : '恢复办赛资格'
            }}</el-button></template
          ></el-table-column
        ></el-table
      ></SportCard
    >
  </div>
</template>
<script setup lang="ts">
import SportMetric from '@/components/sport-ui/SportMetric.vue';
import SportCard from '@/components/sport-ui/SportCard.vue';
import request from '@/utils/request';
import { performAction } from '@/api/sports/phase1';
import { ElMessageBox } from 'element-plus';
interface Organization {
  id: string;
  name: string;
  status: string;
  version: number;
  event_count: number;
  registration_count: number;
  open_complaints: number;
}
const rows = ref<Organization[]>([]);
const query = ref(''), qualification = ref(''), actingId = ref('');
const filteredRows = computed(() => rows.value.filter(row => row.name.toLowerCase().includes(query.value.trim().toLowerCase()) && (!qualification.value || (qualification.value === 'certified' ? row.status === 'certified' : row.status !== 'certified'))));
const error = ref('');
const pending = ref(0);
const loading = ref(true);
async function load() {
  if (loading.value && rows.value.length) return;
  loading.value = true;
  try {
    const responses = await Promise.all([
      request<Organization[]>({ url: '/sports/government' }),
      request<unknown[]>({ url: '/sports/organization-review/pending' })
    ]);
    rows.value = responses[0].data;
    pending.value = responses[1].data.length;
    error.value = '';
  } catch {
    error.value = '读取失败，请重试或联系平台核对管理权限。';
  } finally {
    loading.value = false;
  }
}
async function qualify(row: Organization) {
  if (actingId.value) return;
  actingId.value = row.id;
  try {
    const reason = await ElMessageBox.prompt('填写依据，主办方会收到这条说明。', '资格管理', {
      inputType: 'textarea',
      inputValidator: (value) => (!!value?.trim() && value.length <= 1000) || '请填写1000字内的依据'
    });
    await performAction(
      'government.qualify',
      { organizationId: row.id, status: row.status === 'certified' ? 'restricted' : 'certified', reason: reason.value, expectedVersion: row.version },
      `确认${row.status === 'certified' ? '暂停' : '恢复'}「${row.name}」的办赛资格？暂停后仍保留历史查询、退款和问题处理。`
    );
    await load();
  } catch {
    /* cancellation or server presents its rejection */
  } finally {
    actingId.value = '';
  }
}
onMounted(load);
</script>
<style scoped>
.government-filter{display:flex;align-items:center;gap:12px;margin-bottom:22px;flex-wrap:wrap}.government-filter .el-input{max-width:320px}.government-filter .el-select{width:160px}.government-filter>span{font-size:12px;white-space:nowrap}
@media(max-width:600px){.government-filter .el-input{max-width:none}.government-filter .el-select{flex:1}.government-filter{gap:10px}}
</style>
