<template>
  <div>
    <div v-if="!eventKey" class="b-heading">
      <div>
        <span class="b-eyebrow">组织设置</span>
        <h1>自定义字段目录</h1>
        <p>维护本组织参赛字段，赛事选用后由成员本人填写。</p>
      </div>
      <el-button type="primary" @click="open()">新增字段</el-button>
    </div>
    <el-alert v-if="locked && eventKey" title="已有正式报名，赛事采集配置已锁定；历史定义保持不变。" type="info" :closable="false" /><el-alert
      v-if="error"
      :title="error"
      type="error"
      :closable="false"
    />
    <section class="b-panel" v-loading="loading">
      <div class="b-toolbar">
        <el-input v-model="query" placeholder="搜索名称或编码" clearable /><el-button @click="load">刷新</el-button
        ><router-link v-if="eventKey" to="/org-desk/catalog"><el-button>维护组织目录</el-button></router-link>
      </div>
      <el-table :data="filtered"
        ><el-table-column v-if="eventKey" label="选用" width="70"
          ><template #default="{ row }"
            ><el-checkbox
              :model-value="Boolean(picks[row.id])"
              :disabled="locked || (!picks[row.id] && row.status !== 'active')"
              @change="toggle(row.id, $event)" /></template></el-table-column
        ><el-table-column prop="label" label="名称" min-width="140" /><el-table-column prop="code" label="编码" min-width="160" /><el-table-column
          label="类型"
          width="100"
          ><template #default="{ row }">{{ typeName(row.valueType) }}</template></el-table-column
        ><el-table-column label="状态" width="90"
          ><template #default="{ row }"
            ><el-tag :type="row.status === 'active' ? 'success' : 'info'">{{ row.status === 'active' ? '可选用' : '已停用' }}</el-tag></template
          ></el-table-column
        ><el-table-column v-if="!eventKey" label="操作" width="130" fixed="right"
          ><template #default="{ row }"
            ><el-button link type="primary" @click="open(row)">编辑</el-button
            ><el-button v-if="row.status === 'active'" link type="danger" @click="stop(row)">停用</el-button></template
          ></el-table-column
        ></el-table
      >
      <template v-if="eventKey"
        ><h3>本场采集项与顺序</h3>
        <p class="b-muted">全赛事统一配置；仅排序变化不要求成员重新确认。</p>
        <article v-for="(item, index) in selection" :key="item.orgFieldId" class="b-record">
          <div class="b-toolbar">
            <strong>{{ rows.find((f) => f.id === item.orgFieldId)?.label }}</strong
            ><el-checkbox v-model="item.required" :disabled="locked">必填</el-checkbox
            ><el-button :disabled="locked || index === 0" @click="move(index, -1)">上移</el-button
            ><el-button :disabled="locked || index === selection.length - 1" @click="move(index, 1)">下移</el-button>
          </div>
          <el-input v-model="item.note" :disabled="locked" placeholder="向参赛者说明用途或填写要求" maxlength="500" />
        </article>
        <p v-if="!selection.length" class="b-muted">尚未选用采集项。</p>
        <el-button type="primary" :disabled="locked" :loading="saving" @click="save" style="margin-top: 18px">保存赛事配置</el-button></template
      >
    </section>
    <el-dialog v-model="visible" :title="editing ? '编辑字段' : '新增字段'" width="500px" class="b-dialog"
      ><p class="b-muted">正式使用后不能更改类型或枚举含义，保存时由服务端复核。</p>
      <el-form label-position="top"
        ><el-form-item label="编码" required
          ><el-input v-model="form.code" :disabled="Boolean(editing)" maxlength="64" placeholder="如 shoe_size" /></el-form-item
        ><el-form-item label="名称" required><el-input v-model="form.label" maxlength="100" /></el-form-item
        ><el-form-item label="类型" required
          ><el-select v-model="form.valueType"
            ><el-option v-for="(label, key) in types" :key="key" :label="label" :value="key" /></el-select></el-form-item
        ><el-form-item v-if="form.valueType === 'enum'" label="选项" required
          ><el-input v-model="form.options" placeholder="逗号分隔，如 S,M,L" /></el-form-item></el-form
      ><template #footer
        ><el-button @click="visible = false">取消</el-button
        ><el-button type="primary" :loading="saving" @click="saveDefinition">保存字段</el-button></template
      ></el-dialog
    >
  </div>
</template>
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import request from '@/utils/request';
import {
  listOrgFields,
  listEventFields,
  createOrgField,
  stopOrgField,
  saveEventFields,
  type OrgFieldCard,
  type EventFieldCard
} from '@/api/sports/field';
const props = defineProps<{ eventKey?: string; locked?: boolean }>();
const rows = ref<OrgFieldCard[]>([]),
  query = ref(''),
  loading = ref(false),
  error = ref(''),
  visible = ref(false),
  editing = ref(''),
  saving = ref(false);
const types: Record<string, string> = { text: '文本', number: '数字', date: '日期', enum: '单选枚举' };
const typeName = (s: string) => types[s] || s;
const form = reactive({ code: '', label: '', valueType: 'text', options: '' });
const selection = ref<{ orgFieldId: string; required: boolean; note: string }[]>([]);
const picks = computed(() => Object.fromEntries(selection.value.map((s) => [s.orgFieldId, true])));
const filtered = computed(() => rows.value.filter((f) => !query.value || f.label.includes(query.value) || f.code.includes(query.value)));
const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    const res = await listOrgFields();
    rows.value = res.data;
    if (props.eventKey) {
      const r = await listEventFields(props.eventKey);
      selection.value = (r.data as EventFieldCard[])
        .sort((a, b) => a.sortOrder - b.sortOrder)
        .map((f) => ({ orgFieldId: f.orgFieldId, required: f.required, note: f.note || '' }));
    }
  } catch {
    error.value = '字段读取失败，请重试。';
  } finally {
    loading.value = false;
  }
};
const toggle = (id: string, value: unknown) => {
  if (value) selection.value.push({ orgFieldId: id, required: false, note: '' });
  else selection.value = selection.value.filter((s) => s.orgFieldId !== id);
};
const move = (i: number, n: number) => {
  const items = selection.value;
  [items[i], items[i + n]] = [items[i + n], items[i]];
};
const open = (row?: OrgFieldCard) => {
  editing.value = row?.id || '';
  form.code = row?.code || '';
  form.label = row?.label || '';
  form.valueType = row?.valueType || 'text';
  form.options = row?.options?.join(',') || '';
  visible.value = true;
};
const saveDefinition = async () => {
  if (!form.code.trim() || !form.label.trim()) {
    ElMessage.warning('请填写编码与名称');
    return;
  }
  const options = form.options
    .split(/[,，]/)
    .map((s) => s.trim())
    .filter(Boolean);
  saving.value = true;
  try {
    if (editing.value) await request({ url: '/sports/b/fields/' + editing.value, method: 'put', data: { ...form, options } });
    else await createOrgField(form.code.trim(), form.label.trim(), form.valueType, options);
    visible.value = false;
    ElMessage.success('字段已保存');
    await load();
  } finally {
    saving.value = false;
  }
};
const stop = async (row: OrgFieldCard) => {
  try {
    await ElMessageBox.confirm('停用后禁止新选用，既有赛事配置和历史答案仍保留。', '停用字段');
  } catch {
    return;
  }
  await stopOrgField(row.id);
  await load();
};
const save = async () => {
  if (!props.eventKey || props.locked) return;
  saving.value = true;
  try {
    await saveEventFields(props.eventKey, selection.value);
    ElMessage.success('赛事字段配置已保存');
    await load();
  } finally {
    saving.value = false;
  }
};
onMounted(load);
</script>
