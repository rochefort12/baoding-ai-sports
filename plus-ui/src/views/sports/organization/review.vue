<template>
  <div class="app-container product-admin admission-review">
    <div class="b-heading">
      <div><h1>入驻审核</h1><p>查看分配给你的申请，完成审核或通知主办方补充材料。</p></div>
      <el-button :loading="loading" @click="load">刷新</el-button>
    </div>
    <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" show-icon class="mb-4" />
    <SportCard flat class="sport-art-paper">
      <template #header><div class="b-toolbar"><h2>待审核申请 <span class="admission-count">{{ rows.length }}</span></h2>
        <el-input v-model="query" placeholder="搜索主办方或联系人" clearable aria-label="搜索入驻申请" class="admission-search" /></div></template>
      <el-table :data="filteredRows" v-loading="loading" :empty-text="query ? '没有符合条件的申请' : '当前没有待审核申请'">
        <el-table-column prop="name" label="主办方" min-width="190" />
        <el-table-column prop="contactName" label="联系人" min-width="120" />
        <el-table-column prop="revision" label="材料版本" width="100" />
        <el-table-column label="操作" width="130" fixed="right">
          <template #default="{ row }"><el-button link type="primary" :loading="openingId === row.applicationId" :disabled="!!openingId" @click="open(row.applicationId)">查看申请</el-button></template>
        </el-table-column>
      </el-table>
    </SportCard>
    <el-dialog v-model="visible" title="入驻申请" width="min(720px,95vw)" :close-on-click-modal="!saving" :close-on-press-escape="!saving" :show-close="!saving">
      <template v-if="detail">
        <div class="admission-summary"><span class="admission-label">申请主办方</span><h2>{{ detail.name }}</h2></div>
        <el-descriptions :column="1" border>
          <el-descriptions-item label="联系人">{{ detail.contactName }}</el-descriptions-item>
          <el-descriptions-item label="联系方式">{{ detail.contactMethod }}</el-descriptions-item>
          <el-descriptions-item label="申请说明"><span class="admission-statement">{{ detail.statement || '未填写' }}</span></el-descriptions-item>
        </el-descriptions>
        <section class="admission-section">
          <h3>申请材料 <small>{{ detail.files.length }} 份</small></h3>
          <div v-if="detail.files.length" class="admission-files">
            <button v-for="file in detail.files" :key="file.fileId" type="button" :disabled="!!downloadingId" @click="download(file)">
              <ConsumerIcon name="file" /><span>{{ file.fileName }}</span><small>{{ downloadingId === file.fileId ? '下载中' : '下载' }}</small>
            </button>
          </div>
          <p v-else class="b-muted">没有附加材料。</p>
        </section>
        <section class="admission-section">
          <label for="admission-reason">补充要求</label>
          <p class="b-muted">退回时请写清缺少的材料或需要修改的内容，申请人会收到这条说明。</p>
          <el-input id="admission-reason" v-model="reason" :disabled="!!saving" type="textarea" :rows="4" maxlength="1000" show-word-limit placeholder="例如：请补充赛事联系人电话，以及计划开展的比赛类型。" />
        </section>
      </template>
      <template #footer>
        <el-button :disabled="!!saving" @click="visible = false">稍后处理</el-button>
        <el-button :loading="saving === 'reject'" :disabled="!!saving" @click="reject">退回补充</el-button>
        <el-button type="primary" :loading="saving === 'approve'" :disabled="!!saving" @click="approve">通过入驻</el-button>
      </template>
    </el-dialog>
  </div>
</template>
<script setup lang="ts" name="OrganizationReview">
import { computed, onMounted, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import SportCard from '@/components/sport-ui/SportCard.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import { approveReview, downloadReviewFile, getReview, listPending, type OrgApplication, type OrgFile, type PendingApplication, rejectReview, saveBlob } from '@/api/sports/organization';
const rows = ref<PendingApplication[]>([]), visible = ref(false), detail = ref<OrgApplication>(), reason = ref(''), currentId = ref('');
const query = ref(''), loading = ref(false), loadError = ref(''), openingId = ref(''), downloadingId = ref(''), saving = ref<'' | 'approve' | 'reject'>('');
const filteredRows = computed(() => rows.value.filter(row => [row.name, row.contactName].join(' ').toLowerCase().includes(query.value.trim().toLowerCase())));
async function load() {
  if (loading.value) return;
  loading.value = true;
  loadError.value = '';
  try { rows.value = (await listPending()).data; }
  catch { loadError.value = '无法读取申请，请刷新或联系平台核对审核范围。'; }
  finally { loading.value = false; }
}
async function open(applicationId: string) {
  if (openingId.value) return;
  openingId.value = applicationId;
  try {
    const response = await getReview(applicationId);
    currentId.value = applicationId; reason.value = ''; detail.value = response.data; visible.value = true;
  } finally { openingId.value = ''; }
}
async function approve() {
  if (saving.value || !detail.value) return;
  saving.value = 'approve';
  try {
    await ElMessageBox.confirm('通过「' + detail.value.name + '」的入驻申请后，该主办方可以自主创建和发布赛事。', '确认通过入驻', { confirmButtonText: '通过入驻', cancelButtonText: '继续查看', type: 'info' });
    await approveReview(currentId.value);
    ElMessage.success('入驻已通过，主办方可以开始办赛');
    visible.value = false; await load();
  } catch { /* 取消保留材料，接口错误由统一提示展示。 */ }
  finally { saving.value = ''; }
}
async function reject() {
  if (saving.value) return;
  if (!reason.value.trim()) { ElMessage.warning('请写清需要补充或修改的内容'); return; }
  saving.value = 'reject';
  try {
    await rejectReview(currentId.value, reason.value.trim());
    ElMessage.success('已退回，补充要求已记录'); visible.value = false; await load();
  } finally { saving.value = ''; }
}
async function download(file: OrgFile) {
  if (downloadingId.value) return;
  downloadingId.value = file.fileId;
  try { saveBlob((await downloadReviewFile(currentId.value, file.fileId)) as unknown as Blob, file.fileName); }
  finally { downloadingId.value = ''; }
}
onMounted(load);
</script>
<style scoped>
.admission-search{max-width:300px}.admission-count{display:inline-flex;min-width:24px;height:24px;align-items:center;justify-content:center;border-radius:8px;background:var(--s-subtle);font-size:12px;color:var(--s-muted);vertical-align:middle;margin-left:7px}
.admission-summary{padding:0 0 22px}.admission-summary h2{font-size:25px;color:var(--s-ink);font-weight:600;margin:8px 0 0;letter-spacing:-.6px}.admission-label{font-size:12px;color:var(--s-muted)}.admission-statement{white-space:pre-wrap;overflow-wrap:anywhere}
.admission-section{margin-top:26px}.admission-section h3,.admission-section>label{font-size:15px;font-weight:550;color:var(--s-ink);display:block;margin:0 0 12px}.admission-section h3 small{font-size:12px;font-weight:400;color:var(--s-muted);margin-left:8px}.admission-section p{font-size:12px;line-height:1.8}
.admission-files{display:flex;flex-direction:column;gap:8px}.admission-files button{display:flex;align-items:center;gap:11px;padding:14px 16px;background:var(--s-paper);border:1px solid var(--s-line);border-radius:13px;font:inherit;text-align:left;cursor:pointer;color:var(--s-ink)}.admission-files button:disabled{opacity:.6;cursor:wait}.admission-files button:hover:not(:disabled){border-color:#cecec5}.admission-files button span{flex:1;min-width:0;overflow-wrap:anywhere}.admission-files button small{color:var(--s-primary);font-size:12px}.admission-files svg{width:20px;height:20px;color:var(--s-muted)}
@media(max-width:600px){.admission-search{max-width:none;width:100%}.admission-summary h2{font-size:22px}}
</style>
