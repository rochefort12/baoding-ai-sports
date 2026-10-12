<template>
  <BusinessFrame applicant
    ><div class="b-heading">
      <div>
        <span class="b-eyebrow">保定 · 办赛服务</span>
        <h1>我要办赛</h1>
        <p>提交组织申请，查看审核进度，获准后进入办赛工作台。</p>
      </div>
      <el-tag>{{ statusLabel || '尚未申请' }}</el-tag>
    </div>
    <nav class="b-task-tabs">
      <router-link :to="{ path: '/portal/organization', query: { tab: 'apply' } }" :class="{ active: page === 'apply' }">申请资料</router-link
      ><router-link :to="{ path: '/portal/organization', query: { tab: 'status' } }" :class="{ active: page === 'status' }"
        >审核进度与记录</router-link
      >
    </nav>
    <section v-if="loading" class="b-state">正在读取申请…</section>
    <section v-else-if="loadError" class="b-state">
      <h2>暂时无法读取申请</h2>
      <p>{{ loadError }}</p>
      <el-button @click="load">重试</el-button>
    </section>
    <template v-else
      ><div class="b-progress">
        <span :class="{ active: true }">1 填写申请</span
        ><span :class="{ active: ['pending', 'approved', 'rejected'].includes(view.status || '') }">2 平台审核</span
        ><span :class="{ active: view.canEnter }">3 进入工作台</span>
      </div>
      <div v-if="page === 'apply'" class="b-applicant-grid">
        <section class="b-panel sport-art-paper">
          <h3>组织申请资料</h3>
          <el-alert v-if="!editable" title="申请已提交。审核未通过时可修改并重新提交。" type="info" :closable="false" /><el-form
            label-position="top"
            ><el-form-item label="组织名称" required
              ><el-input v-model="form.name" maxlength="200" :disabled="!editable" placeholder="填写实际办赛主体名称" /></el-form-item
            ><el-form-item label="联系人" required><el-input v-model="form.contactName" maxlength="100" :disabled="!editable" /></el-form-item
            ><el-form-item label="联系方式" required
              ><el-input v-model="form.contactMethod" maxlength="50" :disabled="!editable" placeholder="方便平台联系的电话或其他方式" /></el-form-item
            ><el-form-item label="申请说明"
              ><el-input
                v-model="form.statement"
                type="textarea"
                :rows="4"
                maxlength="1000"
                :disabled="!editable"
                placeholder="介绍计划举办的赛事及运营情况" /></el-form-item
            ><el-form-item label="申请附件"
              ><el-upload v-if="editable" :show-file-list="false" :http-request="uploadFile"><el-button>上传附件</el-button></el-upload>
              <div v-for="file in form.files" :key="file.fileId" class="b-toolbar">
                <el-button link type="primary" @click="download(file)">{{ file.fileName }}</el-button
                ><el-button v-if="editable" link type="danger" @click="removeFile(file.fileId)">移除</el-button>
              </div></el-form-item
            >
            <div class="b-toolbar">
              <el-button v-if="editable" :loading="busy" @click="save">保存草稿</el-button
              ><el-button v-if="editable" type="primary" :loading="busy" @click="submit">{{
                view.status === 'rejected' ? '修改后重新提交' : '提交申请'
              }}</el-button
              ><el-button v-if="view.canEnter" type="primary" @click="enter">进入办赛工作台</el-button>
            </div></el-form
          >
        </section>
        <aside class="b-panel" style="padding: 22px !important">
          <h3>提交前核对</h3>
          <p>填写组织名称、联系人和联系方式后提交，未填完时可保存草稿。</p>
          <p>无需先填写个人参赛资料。</p>
          <p>入驻审核不等同于主体真实性或外部资质认证。</p>
          <p class="b-muted">赛事将使用联系人信息，请确认可以公开的联系方式。</p>
          <el-alert
            v-if="view.status === 'rejected'"
            :title="'审核未通过：' + (view.reviewReason || '请核对申请资料')"
            type="warning"
            :closable="false"
          />
        </aside>
      </div>
      <template v-else
        ><section class="b-panel">
          <h3>
            {{
              view.status === 'approved'
                ? '申请已通过'
                : view.status === 'rejected'
                  ? '申请未通过'
                  : view.status === 'pending'
                    ? '等待平台审核'
                    : '申请尚未提交'
            }}
          </h3>
          <p v-if="view.status === 'pending'">平台审核期间资料保持只读，结果将在这里显示。</p>
          <p v-if="view.reviewReason">审核说明：{{ view.reviewReason }}</p>
          <p v-if="view.status === 'approved'">可以进入工作台创建和管理赛事。</p>
          <el-button v-if="view.canEnter" type="primary" @click="enter">进入办赛工作台</el-button
          ><router-link v-else :to="{ path: '/portal/organization', query: { tab: 'apply' } }"
            ><el-button>{{ view.status === 'rejected' ? '修改申请' : '查看申请资料' }}</el-button></router-link
          >
        </section>
        <section class="b-panel">
          <h3>提交版本记录</h3>
          <p v-if="!view.versions.length" class="b-muted">尚未正式提交，没有版本记录。</p>
          <article v-for="item in view.versions" :key="item.revision" class="b-version">
            <el-tag>V{{ item.revision }}</el-tag>
            <div style="flex: 1">
              <strong>{{ item.name }}</strong>
              <p class="b-muted">{{ versionStatus(item.status) }} · {{ item.reviewReason || '暂无审核说明' }}</p>
            </div>
            <el-button
              link
              type="primary"
              @click="
                version = item;
                versionVisible = true;
              "
              >查看版本</el-button
            >
          </article>
        </section></template
      ></template
    ><el-drawer v-model="versionVisible" title="申请版本 · 只读" size="560px" class="b-drawer"
      ><template v-if="version"
        ><h2>V{{ version.revision }} · {{ version.name }}</h2>
        <el-tag>{{ versionStatus(version.status) }}</el-tag>
        <p>联系人：{{ version.contactName }}</p>
        <p>联系方式：{{ version.contactMethod }}</p>
        <p style="white-space: pre-wrap">{{ version.statement }}</p>
        <p>审核说明：{{ version.reviewReason || '暂无' }}</p>
        <div v-for="file in version.files" :key="file.fileId">
          <el-button link type="primary" @click="download(file)">{{ file.fileName }}</el-button>
        </div></template
      ></el-drawer
    ></BusinessFrame
  >
</template>
<script setup lang="ts" name="PortalOrganization">
import { computed, onMounted, reactive, ref } from 'vue';
import { ElMessage, ElMessageBox, UploadRequestOptions } from 'element-plus';
import BusinessFrame from '@/layout/business/BusinessFrame.vue';
import { useRoute } from 'vue-router';
import type { OrgVersion } from '@/api/sports/organization';
const route = useRoute();
const page = computed(() => (route.query.tab === 'status' ? 'status' : 'apply'));
const versionVisible = ref(false),
  version = ref<OrgVersion>(),
  loading = ref(true),
  loadError = ref(''),
  busy = ref(false);
const versionStatus = (s: string) =>
  (({ draft: '草稿', pending: '待审核', approved: '已通过', rejected: '未通过' }) as Record<string, string>)[s] || s;
import {
  downloadOwnFile,
  enterOrganization,
  getApplication,
  OrgApplication,
  OrgFile,
  saveApplication,
  saveBlob,
  submitApplication,
  uploadApplicationFile
} from '@/api/sports/organization';

const empty = (): OrgApplication => ({
  applicationId: null,
  status: null,
  name: null,
  contactName: null,
  contactMethod: null,
  statement: null,
  files: [],
  reviewReason: null,
  organizationId: null,
  canEnter: false,
  versions: []
});

const view = ref<OrgApplication>(empty());
const form = reactive({
  name: '',
  contactName: '',
  contactMethod: '',
  statement: '',
  files: [] as OrgFile[]
});

const editable = computed(() => !view.value.status || view.value.status === 'draft' || view.value.status === 'rejected');
const statusLabel = computed(() => {
  const labels: Record<string, string> = { draft: '草稿', pending: '待审', approved: '已通过', rejected: '已拒绝' };
  return view.value.status ? labels[view.value.status] || view.value.status : '';
});

const fill = (data: OrgApplication) => {
  view.value = data;
  form.name = data.name || '';
  form.contactName = data.contactName || '';
  form.contactMethod = data.contactMethod || '';
  form.statement = data.statement || '';
  form.files = data.files || [];
};

const load = async () => {
  loading.value = true;
  loadError.value = '';
  try {
    const res = await getApplication();
    fill(res.data);
  } catch {
    loadError.value = '申请读取失败，请重试。';
  } finally {
    loading.value = false;
  }
};

const payload = () => ({
  name: form.name,
  contactName: form.contactName,
  contactMethod: form.contactMethod,
  statement: form.statement,
  fileIds: form.files.map((file) => file.fileId)
});

const save = async () => {
  busy.value = true;
  try {
    const res = await saveApplication(payload());
    fill(res.data);
    ElMessage.success('草稿已保存');
  } finally {
    busy.value = false;
  }
};
const submit = async () => {
  if (!form.name.trim() || !form.contactName.trim() || !form.contactMethod.trim()) {
    ElMessage.warning('请填写组织名称、联系人和联系方式');
    return;
  }
  try {
    await ElMessageBox.confirm('提交后本版本冻结，审核未通过时可以修改重提。审核决定平台准入，不代表外部资质认证。', '提交办赛申请');
  } catch {
    return;
  }
  busy.value = true;
  try {
    const res = await submitApplication(payload());
    fill(res.data);
    ElMessage.success('已提交，等待平台审核');
  } finally {
    busy.value = false;
  }
};
const uploadFile = async (options: UploadRequestOptions) => {
  const res = await uploadApplicationFile(options.file as File);
  form.files.push(res.data);
  ElMessage.success('附件已上传。保存或提交后才会进入本申请。');
};

const removeFile = (fileId: string) => {
  form.files = form.files.filter((file) => file.fileId !== fileId);
};

const download = async (file: OrgFile) => {
  const blob = (await downloadOwnFile(file.fileId)) as unknown as Blob;
  saveBlob(blob, file.fileName);
};

const enter = () => enterOrganization();

onMounted(load);
</script>
