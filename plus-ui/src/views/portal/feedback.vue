<template>
  <ConsumerShell
    ><ConsumerPageHeader title="意见反馈" eyebrow="我的 · 帮助与反馈" description="遇到问题或有改进建议，欢迎告诉我们。" />
    <section class="consumer-card feedback-form">
      <h2>留下你的反馈</h2>
      <p class="consumer-muted">请说明问题发生的场景，避免填写密码或完整证件信息。</p>
      <el-form label-position="top" style="max-width: 640px">
        <el-form-item label="问题类型">
          <el-radio-group v-model="topic">
            <el-radio value="event">赛事 / 报名 / 收费</el-radio>
            <el-radio value="account">账号 / 平台</el-radio>
            <el-radio value="other">其他</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="detail" type="textarea" maxlength="1000" />
        </el-form-item>
        <el-button type="primary" @click="submit">提交反馈</el-button>
      </el-form>
    </section></ConsumerShell
  >
</template>
<script setup lang="ts" name="PortalFeedback">
import { ref } from 'vue';
import { ElMessage } from 'element-plus';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import request from '@/utils/request';

const topic = ref('event');
const detail = ref('');

const submit = async () => {
  await request({ url: '/sports/c/identity/feedback', method: 'post', data: { topic: topic.value, detail: detail.value } });
  detail.value = '';
  ElMessage.success('反馈已提交');
};
</script>
