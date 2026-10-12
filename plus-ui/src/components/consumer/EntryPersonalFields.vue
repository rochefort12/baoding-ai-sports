<template>
  <section class="entry-personal-fields" data-testid="invite-personal-fields" aria-label="本人参赛资料">
    <h3 v-if="fields.length || loading || error">本人参赛资料</h3>
    <p v-if="loading" role="status" class="consumer-muted">正在读取本场需要的资料…</p>
    <div v-else-if="error" class="notice warn" role="alert"><p>{{ error }}</p><button class="btn" type="button" @click="load">重新读取</button></div>
    <el-form v-else-if="fields.length" label-position="top" class="form-two-columns">
      <el-form-item v-for="field in fields" :key="field.eventFieldId" :label="field.label + (field.required ? '（必填）' : '')" :error="missing.includes(field.eventFieldId) ? '请填写这一项' : ''">
        <el-input v-if="field.valueType === 'text'" v-model="field.valueText" maxlength="1000" :disabled="!editable || busy" />
        <el-input v-else-if="field.valueType === 'number'" v-model="field.valueText" inputmode="decimal" :disabled="!editable || busy" />
        <el-date-picker v-else-if="field.valueType === 'date'" v-model="field.valueText" value-format="YYYY-MM-DD" type="date" :disabled="!editable || busy" />
        <el-select v-else v-model="field.valueText" clearable :disabled="!editable || busy"><el-option v-for="option in field.options" :key="option" :label="option" :value="option" /></el-select>
        <p v-if="field.note" class="consumer-note">{{ field.note }}</p>
      </el-form-item>
      <el-button v-if="editable" :loading="busy" @click="save(false)">保存本人资料</el-button>
    </el-form>
    <p v-if="fields.length" class="consumer-muted">仅你本人填写与确认，队长不能代填。{{ editable ? '可先保存，确认后仍需队长正式提交。' : '报名已经提交，以下资料为本次参赛依据。' }}</p>
  </section>
</template>
<script setup lang="ts">
import { ref, watch } from 'vue';
import { ElMessage } from 'element-plus';
import { listEntryFields, saveEntryFields, type EntryFieldCard } from '@/api/sports/field';
const props = defineProps<{ registrationId: string; editable: boolean }>();
const fields = ref<EntryFieldCard[]>([]), loading = ref(false), busy = ref(false), error = ref(''), missing = ref<string[]>([]);
let generation = 0;
const load = async () => {
  const current = ++generation; loading.value = true; error.value = ''; missing.value = [];
  try { const response = await listEntryFields(props.registrationId); if (current === generation) fields.value = response.data; }
  catch { if (current === generation) error.value = '本场参赛资料暂时无法读取，请重试。'; }
  finally { if (current === generation) loading.value = false; }
};
const save = async (requireComplete = false): Promise<boolean> => {
  if (loading.value || busy.value || error.value) return false;
  if (!props.editable) return true;
  missing.value = requireComplete ? fields.value.filter(field => field.required && !String(field.valueText || '').trim()).map(field => field.eventFieldId) : [];
  if (missing.value.length) { ElMessage.warning('请补齐本人必填资料，再确认参加。'); return false; }
  busy.value = true;
  try {
    const response = await saveEntryFields(props.registrationId, fields.value.map(field => ({ eventFieldId: field.eventFieldId, valueText: field.valueText || '' })));
    fields.value = response.data; if (!requireComplete) ElMessage.success('本人资料已保存'); return true;
  } catch { return false; }
  finally { busy.value = false; }
};
watch(() => props.registrationId, load, { immediate: true });
defineExpose({ save });
</script>
<style scoped>
.entry-personal-fields{margin:24px 0;min-width:0}.entry-personal-fields h3{margin:0 0 16px}.entry-personal-fields :deep(.el-form-item){min-width:0}.entry-personal-fields :deep(.el-date-editor){width:100%}.entry-personal-fields :deep(.el-form-item__content){gap:8px}.entry-personal-fields .consumer-note{font-size:12px;line-height:1.7;margin:0}
</style>
