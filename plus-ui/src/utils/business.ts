/** 日期控件回填上海当地时间，避免丢弃 API 的 UTC 偏移后保存时把时间平移八小时。 */
export const businessPickerTime = (value?: string | null): string => {
  if (!value) return '';
  const input = /[Zz]|[+-]\d{2}:\d{2}$/.test(value) ? value : value.replace(' ', 'T') + '+08:00';
  const date = new Date(input);
  if (Number.isNaN(date.getTime())) return '';
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23'
  }).formatToParts(date);
  const part = (name: string) => parts.find((p) => p.type === name)?.value || '';
  return `${part('year')}-${part('month')}-${part('day')} ${part('hour')}:${part('minute')}:${part('second')}`;
};

/** 业务时间按北京时间展示；无偏移的既有响应也按上海时区解释。 */
export const businessTime = (value?: string | null): string => {
  if (!value) return '未填写';
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  const input = /[Zz]|[+-]\d{2}:\d{2}$/.test(value) ? value : value.replace(' ', 'T') + '+08:00';
  const date = new Date(input);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  }).format(date);
};
