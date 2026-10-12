<template>
  <div class="b-inline-fee">
    <FeeChoice v-model="charged" :disabled="disabled || saving" />
    <div v-if="charged" class="b-fee-amount"><span>¥</span><el-input-number v-model="amount" :controls="false" :min="0.01" :max="999999999" :precision="2" :disabled="disabled || saving" aria-label="项目报名费" placeholder="输入金额" /><small>元／单</small></div>
    <small v-if="charged == null" class="b-muted">请选择免费或收费</small>
    <small v-if="paymentMode && !['event', 'free'].includes(paymentMode)" class="b-muted">暂用旧指引；配置赛事收款后统一使用赛事渠道</small>
    <el-button v-if="dirty && !disabled" size="small" type="primary" :loading="saving" @click="save">保存</el-button>
    <small v-else-if="disabled" class="b-muted">已锁定</small>
  </div>
</template>
<script setup lang="ts">
import {computed, ref, watch} from 'vue';
import {ElMessage} from 'element-plus';
import FeeChoice from './FeeChoice.vue';
import {publishFee} from '@/api/sports/finance';
const props = defineProps<{unitId: string; paymentMode: string | null; amount: number | null; disabled?: boolean}>();
const emit = defineEmits<{saved: []}>();
const charged = ref<boolean | null>(null), amount = ref<number>(), saving = ref(false);
watch(() => [props.unitId, props.paymentMode, props.amount], () => {
  charged.value = props.paymentMode ? props.paymentMode !== 'free' : null;
  amount.value = props.amount != null && Number(props.amount) > 0 ? Number(props.amount) : undefined;
}, {immediate: true});
const dirty = computed(() => charged.value != null && (props.paymentMode == null || charged.value !== (props.paymentMode !== 'free') || charged.value && Number(props.amount) !== amount.value));
const save = async () => {
  if (props.disabled || saving.value || charged.value == null) return;
  if (charged.value && (!amount.value || amount.value <= 0)) {ElMessage.warning('请填写大于0的报名费'); return;}
  saving.value = true;
  try {await publishFee(props.unitId, charged.value ? amount.value! : 0, charged.value ? 'event' : 'free', ''); ElMessage.success('已保存项目费用'); emit('saved');}
  finally {saving.value = false;}
};
</script>
