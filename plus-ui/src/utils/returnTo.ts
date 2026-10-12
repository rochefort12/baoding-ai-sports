/**
 * 登录回跳只接受站内业务地址。外链、编码绕过和管理后台地址回到公开首页。
 * 查询参数只保留赛事和项目编号，避免把验证码、手机号或其他参数带进地址。
 */

export const PLATFORM_HOME = '/portal/home';
export const ADMIN_HOME = '/index';

const AUTH_PATHS = new Set(['/login', '/register', '/forgot', '/portal/login', '/portal/register', '/portal/forgot', '/social-callback']);

export const firstQuery = (value: unknown): string => {
  if (Array.isArray(value)) {
    return firstQuery(value[0]);
  }
  return typeof value === 'string' ? value : '';
};

const decodeRepeated = (input: string): string | null => {
  let value = input.trim();
  if (!value || value.length > 500) {
    return null;
  }
  for (let i = 0; i < 3; i += 1) {
    if (value.includes('\\') || /[\u0000-\u001f\s]/.test(value)) {
      return null;
    }
    try {
      const next = decodeURIComponent(value);
      if (next === value) {
        break;
      }
      value = next;
    } catch {
      return null;
    }
  }
  if (value.includes('%') || value.includes('\\') || /[\u0000-\u001f\s]/.test(value)) {
    return null;
  }
  if (value.startsWith('//') || /^[a-z][a-z0-9+.-]*:/i.test(value)) {
    return null;
  }
  if (!value.startsWith('/')) {
    return null;
  }
  return value;
};

const parsed = (value: string): URL | null => {
  try {
    const url = new URL(value, 'http://local.invalid');
    if (url.origin !== 'http://local.invalid' || url.username || url.password) {
      return null;
    }
    return url;
  } catch {
    return null;
  }
};

export const isPlatformBusinessPath = (pathname: string): boolean => {
  if (
    pathname === '/portal/home' ||
    pathname === '/portal/identity' ||
    pathname === '/portal/profile' ||
    pathname === '/portal/organization' ||
    pathname === '/portal/registration' ||
    pathname === '/portal/registration/apply' ||
    pathname === '/portal/feedback' ||
    pathname === '/portal/notices' ||
    pathname === '/portal/proofs' ||
    pathname === '/portal/results' ||
    pathname === '/portal/teams' ||
    pathname === '/portal/rooms' ||
    pathname === '/portal/growth' ||
    pathname === '/portal/issues' ||
    pathname === '/public/events' ||
    pathname === '/portal/future/venues' ||
    pathname === '/portal/future/life'
  ) {
    return true;
  }
  return (
    /^\/public\/events\/\d+$/.test(pathname) ||
    /^\/portal\/teams\/\d+$/.test(pathname) ||
    /^\/portal\/rooms\/\d+$/.test(pathname) ||
    /^\/portal\/issues\/\d+$/.test(pathname) ||
    /^\/portal\/teams\/invitations\/\d+$/.test(pathname) ||
    /^\/portal\/teams\/join\/[a-f0-9]{64}$/.test(pathname) ||
    /^\/portal\/registration\/invite\/[A-Za-z0-9_-]+$/.test(pathname) ||
    /^\/portal\/registration\/detail\/\d+$/.test(pathname)
  );
};

const platformQuery = (url: URL): string => {
  const kept = new URLSearchParams();
  for (const key of ['eventId', 'unitId', 'teamId', 'sportId']) {
    const value = url.searchParams.get(key);
    if (value && /^\d{1,20}$/.test(value)) {
      kept.set(key, value);
    }
  }
  const query = kept.toString();
  return query ? `${url.pathname}?${query}` : url.pathname;
};

export const sanitizeReturnTo = (value: unknown): string => {
  const decoded = decodeRepeated(firstQuery(value));
  const url = decoded ? parsed(decoded) : null;
  if (!url || !isPlatformBusinessPath(url.pathname) || AUTH_PATHS.has(url.pathname)) {
    return PLATFORM_HOME;
  }
  return platformQuery(url);
};

const safeAdminQuery = (url: URL): string => {
  const kept = new URLSearchParams();
  for (const [key, value] of url.searchParams) {
    if (!/^[A-Za-z0-9_-]{1,40}$/.test(key) || value.length > 200) {
      continue;
    }
    if (value.includes('\\') || value.includes('%') || value.includes('//') || value.includes('://')) {
      continue;
    }
    kept.append(key, value);
  }
  const query = kept.toString();
  return query ? `${url.pathname}?${query}` : url.pathname;
};

export const prefersPlatformLogin = (value: unknown): boolean => {
  const decoded = decodeRepeated(firstQuery(value));
  const url = decoded ? parsed(decoded) : null;
  return Boolean(url && (isPlatformBusinessPath(url.pathname) || url.pathname.startsWith('/public/')));
};

export const splitTarget = (target: string) => {
  const url = new URL(target, 'http://local.invalid');
  const query: Record<string, string> = {};
  url.searchParams.forEach((item, key) => {
    query[key] = item;
  });
  return { path: url.pathname, query, replace: true as const };
};

export const sanitizeAdminTarget = (value: unknown): string => {
  const decoded = decodeRepeated(firstQuery(value));
  const url = decoded ? parsed(decoded) : null;
  if (!url || AUTH_PATHS.has(url.pathname) || url.pathname === '/') {
    return ADMIN_HOME;
  }
  return safeAdminQuery(url);
};

export const reauthLocation = (fullPath: string): { path: string; query: Record<string, string> } => {
  if (fullPath.startsWith('/org-desk/')) {
    sessionStorage.setItem('organizerReturnTo', sanitizeOrganizerTarget(fullPath));
    return { path: '/portal/login', query: { returnTo: '/portal/organization' } };
  }
  const decoded = decodeRepeated(firstQuery(fullPath));
  const url = decoded ? parsed(decoded) : null;
  if (url && (isPlatformBusinessPath(url.pathname) || url.pathname.startsWith('/public/'))) {
    return { path: '/portal/login', query: { returnTo: sanitizeReturnTo(fullPath) } };
  }
  const admin = sanitizeAdminTarget(fullPath);
  return admin === ADMIN_HOME ? { path: '/login', query: {} } : { path: '/login', query: { redirect: admin } };
};

/** 组织任务仅在服务端兑换组织会话后恢复，不能借此进入平台管理或外链。 */
export const sanitizeOrganizerTarget = (value: unknown): string => {
  const decoded = decodeRepeated(firstQuery(value));
  const url = decoded ? parsed(decoded) : null;
  if (!url || !(/^\/org-desk\/(home|events|catalog|registrations|competition|issues)$/.test(url.pathname) || /^\/org-desk\/workspace\/\d{1,20}$/.test(url.pathname) || /^\/org-desk\/events\/from-document(?:\/\d{1,20})?$/.test(url.pathname)))
    return '/org-desk/home';
  const kept = new URLSearchParams();
  const task = url.searchParams.get('task');
  if (task && ['overview', 'projects', 'registrations', 'fields', 'checkin', 'matches', 'awards', 'closure', 'publication', 'notifications'].includes(task))
    kept.set('task', task);
  const filter = url.searchParams.get('filter');
  if (filter && ['submitted', 'declared', 'refund'].includes(filter)) kept.set('filter', filter);
  const unit = url.searchParams.get('unitId');
  if (unit && /^\d{1,20}$/.test(unit)) kept.set('unitId', unit);
  return url.pathname + (kept.size ? '?' + kept.toString() : '');
};
