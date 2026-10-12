import { onMounted, onUnmounted, ref } from 'vue';
import { to } from 'await-to-js';
import { ElMessage } from 'element-plus';
import { getCodeImg, getParticipantCaptchaConfig, sendParticipantSms, sendResetSms } from '@/api/login';

type SmsPurpose = 'register' | 'reset';

/**
 * 注册和重置共用现有验证码通道。出现 debugCode 时只说明本地模拟，不把接口文案里的“已发送”当成真实短信。
 */
export const useSmsChallenge = (purpose: SmsPurpose) => {
  const debugCode = ref('');
  const smsHint = ref('');
  const captchaError = ref('');
  const smsWaiting = ref(false);
  const smsSending = ref(false);
  const smsSeconds = ref(0);
  const imageCaptcha = ref(false);
  const imageUrl = ref('');
  const imageCode = ref('');
  const imageUuid = ref('');
  let captchaVerifyParam = '';
  let smsTimer = 0;
  let aliyun = false;
  let captchaInstance: { destroyCaptcha?: () => void; hide?: () => void } | undefined;
  let disposed = false;
  const disposeCaptcha = () => {
    disposed = true;
    window.clearInterval(smsTimer);
    captchaInstance?.hide?.();
    captchaInstance?.destroyCaptcha?.();
    captchaInstance = undefined;
    captchaVerifyParam = '';
    document.getElementById(elementId)?.replaceChildren();
  };
  onUnmounted(disposeCaptcha);

  const elementId = `portal-captcha-${purpose}`;
  const buttonId = `portal-captcha-button-${purpose}`;

  const refreshImage = async () => {
    const [err, res] = await to(getCodeImg());
    if (err || !res) {
      imageCaptcha.value = false;
      captchaError.value = '安全验证暂时无法加载，请刷新页面重试。';
      return;
    }
    captchaError.value = '';
    imageCaptcha.value = res.data.captchaEnabled !== false;
    if (imageCaptcha.value) {
      imageCode.value = '';
      imageUrl.value = 'data:image/gif;base64,' + res.data.img;
      imageUuid.value = res.data.uuid || '';
    }
  };

  const loadAliyun = (region: string, prefix: string, sceneId: string) => {
    const win = window as Window & {
      AliyunCaptchaConfig?: { region: string; prefix: string };
      initAliyunCaptcha?: (options: Record<string, unknown>) => void;
    };
    win.AliyunCaptchaConfig = { region, prefix };
    const start = () => {
      if (disposed) return;
      win.initAliyunCaptcha?.({
        SceneId: sceneId,
        mode: 'embed',
        element: '#' + elementId,
        button: '#' + buttonId,
        success: (param: string) => {
          captchaVerifyParam = param;
        },
        fail: () => {
          captchaVerifyParam = '';
          ElMessage.error('验证未通过，请重试');
        },
        getInstance: (instance: typeof captchaInstance) => {
          captchaInstance = instance;
        },
        slideStyle: { width: 260, height: 40 },
        language: 'cn',
        onError: () => {
          captchaError.value = '安全验证暂时无法加载，请刷新页面重试。';
        }
      });
    };
    if (win.initAliyunCaptcha) {
      start();
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js';
    script.onload = () => start();
    script.onerror = () => {
      captchaError.value = '安全验证暂时无法加载，请刷新页面重试。';
    };
    document.head.appendChild(script);
  };

  const startWait = () => {
    smsWaiting.value = true;
    smsSeconds.value = 60;
    window.clearInterval(smsTimer);
    smsTimer = window.setInterval(() => {
      smsSeconds.value -= 1;
      if (smsSeconds.value <= 0) {
        smsWaiting.value = false;
        window.clearInterval(smsTimer);
      }
    }, 1000);
  };

  const send = async (phone: string) => {
    if (!/^1[3-9]\d{9}$/.test(phone)) {
      ElMessage.error('请先填写中国大陆11位手机号');
      return;
    }
    if (aliyun && !captchaVerifyParam) {
      ElMessage.error('请先完成验证码');
      return;
    }
    if (imageCaptcha.value && !imageCode.value.trim()) {
      ElMessage.error('请先填写图形验证码');
      return;
    }
    smsSending.value = true;
    debugCode.value = '';
    const passed = captchaVerifyParam;
    captchaVerifyParam = '';
    const payload = {
      phone,
      captchaVerifyParam: passed || undefined,
      code: imageCaptcha.value ? imageCode.value.trim() : undefined,
      uuid: imageCaptcha.value ? imageUuid.value : undefined
    };
    const request = purpose === 'register' ? sendParticipantSms(payload) : sendResetSms(payload);
    const [err, res] = await to(request);
    smsSending.value = false;
    if (imageCaptcha.value) {
      await refreshImage();
    }
    if (err || !res) {
      smsHint.value = '验证码请求未成功，请按提示等待后重试。';
      return;
    }
    debugCode.value = res.data?.debugCode || '';
    if (debugCode.value) {
      smsHint.value = '当前为短信演练，验证码仅在页面显示。';
    } else {
      smsHint.value = purpose === 'reset' ? '如果这个手机号已注册，验证码会按当前通道处理。' : '验证码请求已交给当前发送通道。';
    }
    startWait();
  };

  onMounted(async () => {
    const [err, res] = await to(getParticipantCaptchaConfig());
    const config = err ? undefined : res.data;
    if (config?.aliyun && config.prefix && config.sceneId) {
      aliyun = true;
      loadAliyun(config.region || 'cn', config.prefix, config.sceneId);
      return;
    }
    await refreshImage();
  });

  return {
    disposeCaptcha,
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
  };
};
