<template>
  <div class="app-container">
    <TestJourney :steps="organizerSteps" />
    <el-card shadow="never" class="mb-4">
      <template #header>关联已关闭账号的证件</template>
      <p>新账号还没有档案，且这份证件只挂在已关闭的账号上时，才能关联。不会恢复旧账号登录。</p>
      <el-form label-position="top" style="max-width: 640px">
        <el-form-item label="新账号编号">
          <el-input v-model="form.accountId" />
        </el-form-item>
        <el-form-item label="证件类型">
          <el-select v-model="form.idDocType">
            <el-option label="居民身份证" value="id_card" />
            <el-option label="护照" value="passport" />
            <el-option label="港澳台通行证" value="hmt_pass" />
            <el-option label="其他" value="other" />
          </el-select>
        </el-form-item>
        <el-form-item label="证件号码">
          <el-input v-model="form.idNumber" maxlength="40" />
        </el-form-item>
        <el-form-item label="核验理由">
          <el-input v-model="form.reason" type="textarea" maxlength="500" />
        </el-form-item>
        <el-button type="primary" @click="link">关联档案</el-button>
      </el-form>
    </el-card>
    <el-card shadow="never">
      <template #header>档案修改和反馈记录</template>
      <el-button class="mb-4" @click="load">刷新</el-button>
      <el-table :data="rows">
        <el-table-column prop="action" label="动作" width="140" />
        <el-table-column prop="objectId" label="对象" width="180" />
        <el-table-column prop="occurredAt" label="时间" min-width="180" />
        <el-table-column prop="summary" label="摘要" min-width="280" />
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts" name="PlatformTools">
import { onMounted, reactive, ref } from 'vue';
import { ElMessage } from 'element-plus';
import TestJourney from '@/components/TestJourney.vue';
import { organizerSteps } from '@/utils/testJourney';
import request from '@/utils/request';

const form = reactive({ accountId: '', idDocType: 'id_card', idNumber: '', reason: '' });
const rows = ref<{ action: string; objectId: string; occurredAt: string; summary: string }[]>([]);

const load = async () => {
  const res = await request({ url: '/sports/platform/identity/traces', method: 'get' });
  rows.value = res.data || [];
};

const link = async () => {
  await request({
    url: '/sports/platform/identity/link',
    method: 'post',
    data: { ...form, accountId: form.accountId.trim() }
  });
  ElMessage.success('已关联');
  form.idNumber = '';
  form.reason = '';
  await load();
};

onMounted(load);
</script>
