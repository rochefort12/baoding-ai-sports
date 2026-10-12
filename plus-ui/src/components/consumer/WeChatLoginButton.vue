<template>
  <section class="wechat-login" aria-label="微信登录">
    <div class="wechat-login-divider" aria-hidden="true"><span />微信登录<span /></div>
    <button
      class="wechat-login-button"
      type="button"
      :disabled="disabled || loading"
      :aria-busy="loading || undefined"
      :aria-describedby="message ? messageId : undefined"
      @click="startAuthorization"
    >
      <span class="wechat-login-icon" aria-hidden="true"><img src="/images/sports/wechat-login.svg" alt="" draggable="false" /></span>
      <span>{{ loading ? '正在连接微信' : '使用微信登录' }}</span>
      <span v-if="loading" class="wechat-login-spinner" aria-hidden="true" />
      <svg v-else class="wechat-login-arrow" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M5 12h14m-5-5 5 5-5 5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>
    <p v-if="message" :id="messageId" class="wechat-login-feedback" role="status">{{ message }}</p>
  </section>
</template>

<script setup lang="ts">
import { ref, useId } from 'vue';
import type { WeChatAuthorization } from '@/api/wechatLogin';

const props = defineProps<{ disabled?: boolean; authorize: () => Promise<WeChatAuthorization> }>();
const loading = ref(false);
const message = ref('');
const messageId = `wechat-login-${useId()}`;

const startAuthorization = async () => {
  if (props.disabled || loading.value) return;
  loading.value = true;
  message.value = '';
  try {
    const result = await props.authorize();
    if (!result.available || !result.authorizationUrl) {
      message.value = result.message || '微信登录暂不可用，请使用工作账号登录。';
      return;
    }
    // 授权只跳往微信官方HTTPS页面；拒绝异常返回，保留正在填写的表单。
    const target = new URL(result.authorizationUrl);
    if (target.protocol !== 'https:' || target.hostname !== 'open.weixin.qq.com' || target.username || target.password || target.port) {
      message.value = '微信登录暂时无法连接，请使用工作账号登录。';
      return;
    }
    window.location.assign(target.href);
  } catch {
    message.value = '暂时无法连接微信，请稍后重试，或使用工作账号登录。';
  } finally {
    loading.value = false;
  }
};
</script>

<style scoped lang="scss">
.wechat-login {
  margin-top: 28px;
}
.wechat-login-divider {
  display: flex;
  align-items: center;
  gap: 15px;
  font-size: 11px;
  color: var(--s-muted);
}
.wechat-login-divider span {
  height: 1px;
  flex: 1;
  background: var(--s-line);
}
.wechat-login-button {
  display: flex;
  width: 100%;
  min-height: 52px;
  align-items: center;
  justify-content: center;
  gap: 11px;
  margin-top: 15px;
  padding: 10px 16px;
  border: 1px solid var(--s-line);
  border-radius: 15px;
  background: var(--s-surface);
  color: var(--s-ink);
  font: inherit;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition:
    border-color 0.2s ease,
    background 0.2s ease,
    transform 0.2s ease,
    box-shadow 0.2s ease;
}
.wechat-login-button:hover:not(:disabled) {
  border-color: rgba(7, 156, 80, 0.28);
  background: #f7faf7;
  box-shadow: 0 3px 14px rgba(29, 49, 32, 0.04);
}
.wechat-login-button:active:not(:disabled) {
  transform: translateY(1px);
}
.wechat-login-button:focus-visible {
  outline: none;
  border-color: #568d67;
  box-shadow: inset 0 0 0 1px #568d67;
}
.wechat-login-button:disabled {
  cursor: default;
  opacity: 0.6;
}
.wechat-login-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
}
.wechat-login-icon img {
  display: block;
  width: 25px;
  height: 22px;
  pointer-events: none;
  user-select: none;
  -webkit-user-drag: none;
}
.wechat-login-arrow {
  width: 17px;
  height: 17px;
  color: var(--s-muted);
  margin-left: 7px;
}
.wechat-login-spinner {
  width: 14px;
  height: 14px;
  margin-left: 7px;
  border: 1.5px solid var(--s-line);
  border-top-color: #079c50;
  border-radius: 50%;
  animation: wechat-rotate 0.7s linear infinite;
}
.wechat-login-feedback {
  margin: 11px 2px 0;
  font-size: 12px;
  line-height: 1.7;
  color: var(--s-muted);
}
@keyframes wechat-rotate {
  to {
    transform: rotate(360deg);
  }
}
@media (prefers-reduced-motion: reduce) {
  .wechat-login-button {
    transition: none;
  }
  .wechat-login-spinner {
    animation-duration: 2s;
  }
}
@media (max-width: 640px) {
  .wechat-login {
    margin-top: 24px;
  }
}
</style>
