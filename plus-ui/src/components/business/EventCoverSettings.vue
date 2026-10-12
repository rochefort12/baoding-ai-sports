<template><section class="cover-settings"><p class="cover-setting-note">只更新赛事展示封面，报名规则、名单和费用保持原有依据。</p><EventCoverEditor v-model="fileId" :event-id="eventId"/><p v-if="error" role="alert" class="cover-setting-error">{{error}}</p><footer><span>{{loading?'正在核对赛事…':dirty?'有新的封面选择':'当前封面'}}</span><el-button :disabled="loading||!ready||saving||!dirty" :loading="saving" type="primary" data-testid="cover-save" @click="save">保存封面</el-button></footer></section></template>
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { getEventMaterials } from '@/api/sports/organizerMaterials';
import { performAction } from '@/api/sports/phase1';
import EventCoverEditor from './EventCoverEditor.vue';
const props=defineProps<{eventId:string;initialFileId?:string|null}>(),emit=defineEmits<{saved:[]}>();
const fileId=ref(props.initialFileId||null),baseline=ref(props.initialFileId||null),version=ref(0),ready=ref(false),loading=ref(true),saving=ref(false),error=ref('');const dirty=computed(()=>fileId.value!==baseline.value);
onMounted(async()=>{try{const r=await getEventMaterials(props.eventId);version.value=r.data.eventVersion;ready.value=true;}catch{error.value='赛事版本未读到，请关闭后重试。';}finally{loading.value=false;}});
async function save(){if(saving.value||!ready.value||!dirty.value)return;saving.value=true;error.value='';try{await performAction('event.cover.save',{eventId:props.eventId,expectedVersion:version.value,...(fileId.value?{fileId:fileId.value}:{})});baseline.value=fileId.value;ElMessage.success('封面已保存');emit('saved');}catch{error.value='封面未保存，新选择保留。赛事版本变化时请关闭后重新核对。';}finally{saving.value=false;}}
</script>
<style scoped>.cover-setting-note{font-size:12px;color:var(--s-muted);line-height:1.8;margin:0 0 17px}.cover-setting-error{font-size:12px;color:#b13d2d;line-height:1.8}footer{display:flex;justify-content:space-between;align-items:center;border-top:1px solid var(--s-line);padding-top:18px;margin-top:18px;font-size:12px;color:var(--s-muted);}</style>
