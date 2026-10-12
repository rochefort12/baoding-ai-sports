<template>
  <ConsumerAuthLayout title="重设密码" description="验证手机号后，设置新的登录密码。">
    <form class="sport-auth-native" novalidate @submit.prevent="submit">
      <SportField
        v-model="form.phone"
        label="手机号"
        name="phone"
        :maxlength="11"
        placeholder="请输入手机号"
        autocomplete="username"
        inputmode="tel"
        required
        :disabled="loading"
        :error="errors.phone"
        @blur="validateField('phone')"
      />
      <p v-if="captchaError" class="sport-inline-message" role="alert">{{ captchaError }}</p>
      <div :id="elementId" />
      <button :id="buttonId" type="button" tabindex="-1" style="display: none" />
      <div v-if="imageCaptcha" class="sport-auth-code">
        <SportField v-model="imageCode" label="图形验证码" :maxlength="10" placeholder="输入右侧字符" /><button
          type="button"
          class="sport-auth-captcha"
          aria-label="更换图形验证码"
          @click="refreshImage"
        >
          <img v-if="imageUrl" :src="imageUrl" alt="图形验证码" draggable="false" />
        </button>
      </div>
      <div class="sport-auth-code">
        <SportField
          v-model="form.smsCode"
          label="重置验证码"
          name="sms-code"
          :maxlength="6"
          placeholder="6位验证码"
          autocomplete="one-time-code"
          inputmode="numeric"
          required
          :disabled="loading"
          :error="errors.smsCode"
          @blur="validateField('smsCode')"
        /><SportButton variant="secondary" :disabled="smsWaiting || smsSending || loading" @click="send(form.phone)">{{
          smsSending ? '发送中' : smsWaiting ? smsSeconds + '秒后重试' : '获取验证码'
        }}</SportButton>
      </div>
      <p v-if="smsHint" class="sport-inline-message" role="status">{{ smsHint }}</p>
      <p v-if="debugCode" class="sport-inline-message">本地模拟验证码：{{ debugCode }}。本次为模拟验证，未发送短信。</p>
      <SportField
        v-model="form.password"
        label="新密码"
        name="new-password"
        type="password"
        placeholder="5到20位"
        autocomplete="new-password"
        required
        :disabled="loading"
        :error="errors.password"
        @blur="validateField('password')"
      />
      <SportField
        v-model="form.confirmPassword"
        label="确认新密码"
        name="confirm-password"
        type="password"
        placeholder="再次输入新密码"
        autocomplete="new-password"
        required
        :disabled="loading"
        :error="errors.confirmPassword"
        @blur="validateField('confirmPassword')"
      />
      <SportButton type="submit" block size="lg" :busy="loading">重置密码</SportButton>
    </form>
    <div class="consumer-links">
      <router-link :to="{ path: '/portal/login', query: returnQuery }">返回登录</router-link><router-link to="/portal/home">返回首页</router-link>
    </div>
  </ConsumerAuthLayout>
</template>

<script setup lang="ts" name="PortalForgot">
import { computed, reactive, ref, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { to } from 'await-to-js';
import { ElMessageBox } from 'element-plus';
import SportField from '@/components/sport-ui/SportField.vue';
import SportButton from '@/components/sport-ui/SportButton.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import { useAuthFields } from '@/components/sport-ui/useAuthFields';
import ConsumerAuthLayout from '@/components/consumer/ConsumerAuthLayout.vue';
import { resetParticipantPassword } from '@/api/login';
import { useUserStore } from '@/store/modules/user';
import { getToken, removePlatformToken, removeToken } from '@/utils/auth';
import { firstQuery, sanitizeReturnTo } from '@/utils/returnTo';
import { useCleanReturnTo } from '@/utils/useCleanReturnTo';
import { useSmsChallenge } from '@/utils/useSmsChallenge';

const route = useRoute();
const router = useRouter();
const userStore = useUserStore();
const loading = ref(false);
const form = reactive({ phone: '', smsCode: '', password: '', confirmPassword: '' });
const sms = useSmsChallenge('reset');
const {
  elementId,
  buttonId,
  debugCode,
  smsHint,
  captchaError,
  smsWaiting,
  smsSending,
  smsSeconds,
  imageCaptcha,
  imageUrl,
  imageCode,
  refreshImage,
  send
} = sms;
const { errors, validateField, validate } = useAuthFields(form, { newPassword: true, sms: true });
useCleanReturnTo();
const returnQuery = computed(() => {
  const value = firstQuery(route.query.returnTo);
  return value ? { returnTo: sanitizeReturnTo(value) } : {};
});

const clearLocalSession = async () => {
  if (getToken()) {
    await to(userStore.logout());
  }
  userStore.token = '';
  userStore.roles = [];
  userStore.permissions = [];
  removeToken();
  removePlatformToken();
};

const submit = async () => {
  if (loading.value) return;
  if (!validate()) {
    await nextTick();
    document.querySelector<HTMLInputElement>('.sport-field.has-error input')?.focus();
    return;
  }
  loading.value = true;
  const [err] = await to(resetParticipantPassword({ phone: form.phone, password: form.password, smsCode: form.smsCode }));
  loading.value = false;
  if (err) {
    return;
  }
  form.password = '';
  form.confirmPassword = '';
  form.smsCode = '';
  await clearLocalSession();
  await ElMessageBox.alert('密码已重置。请重新登录。旧的平台会话和组织会话已按服务端规则撤销。', '系统提示', { type: 'success' });
  await router.replace({ path: '/portal/login', query: returnQuery.value });
};
</script>
