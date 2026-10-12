import { to as tos } from 'await-to-js';
import router from './router';
import { returnToPlatform } from '@/api/sports/organization';
import NProgress from 'nprogress';
import 'nprogress/nprogress.css';
import { getToken, getPlatformToken } from '@/utils/auth';
import { isHttp, isPathMatch } from '@/utils/validate';
import { isRelogin } from '@/utils/request';
import { useUserStore } from '@/store/modules/user';
import { useSettingsStore } from '@/store/modules/settings';
import { usePermissionStore } from '@/store/modules/permission';
import { ElMessage } from 'element-plus/es';
import type { RouteLocationNormalized, RouteLocationRaw } from 'vue-router';
import {
  PLATFORM_HOME,
  prefersPlatformLogin,
  reauthLocation,
  sanitizeAdminTarget,
  sanitizeReturnTo,
  splitTarget,
  sanitizeOrganizerTarget
} from '@/utils/returnTo';

NProgress.configure({ showSpinner: false });

const whiteList = [
  '/login',
  '/register',
  '/forgot',
  '/social-callback',
  '/register*',
  '/register/*',
  '/public/events',
  '/public/events/*',
  '/public/athletes/*',
  '/portal/home',
  '/portal/login',
  '/portal/register',
  '/portal/forgot',
  '/portal/teams/join/*',
  '/portal/future/venues',
  '/portal/future/life'
];

const isWhiteList = (path: string) => whiteList.some((pattern) => isPathMatch(pattern, path));

const participantOnly = () => {
  const roles = useUserStore().roles;
  return roles.includes('participant') && !roles.includes('superadmin');
};

const samePlace = (to: RouteLocationNormalized, path: string) => to.path === path;

const loggedInEntry = (to: RouteLocationNormalized) => {
  if (to.path === '/portal/forgot' || to.path === '/forgot') {
    return null;
  }
  if (to.path === '/login') {
    const raw = to.query.redirect || to.query.returnTo;
    return participantOnly() ? sanitizeReturnTo(raw) : sanitizeAdminTarget(raw);
  }
  if (to.path === '/portal/login' || to.path === '/portal/register' || to.path === '/register') {
    const raw = to.query.returnTo || to.query.redirect;
    return participantOnly() ? sanitizeReturnTo(raw) : sanitizeAdminTarget(raw);
  }
  return null;
};

const goOn = (to: RouteLocationNormalized) => {
  if (participantOnly() && (to.path === '/' || to.path === '/index')) {
    return { path: PLATFORM_HOME, replace: true };
  }
  return { path: to.path, replace: true, params: to.params, query: to.query, hash: to.hash, name: to.name as string };
};

router.beforeEach(async (to, _from, next) => {
  NProgress.start();
  if (to.path === '/') {
    next({ path: PLATFORM_HOME, replace: true });
    NProgress.done();
    return;
  }
  if (getPlatformToken() && getToken() !== getPlatformToken() && (to.path.startsWith('/portal/') || to.path.startsWith('/public/events'))) {
    returnToPlatform(sanitizeReturnTo(to.fullPath)); next(false); NProgress.done(); return;
  }
  if (getToken()) {
    to.meta.title && useSettingsStore().setTitle(to.meta.title as string);
    let routesAdded = false;
    // Public pages still need the actual identity of an authenticated visitor.
    // Otherwise a restored work token is mistaken for a participant token, or
    // a restored participant loses its own profile until a protected route.
    if (useUserStore().roles.length === 0) {
      isRelogin.show = true;
      const [err] = await tos(useUserStore().getInfo());
      if (err) {
        await useUserStore().logout();
        ElMessage.error(err);
        next({ path: PLATFORM_HOME });
        return;
      }
      isRelogin.show = false;
      const accessRoutes = await usePermissionStore().generateRoutes();
      accessRoutes.forEach((route) => {
        if (!isHttp(route.path)) {
          router.addRoute(route);
        }
      });
      routesAdded = true;
    }
    if (participantOnly() && to.path.startsWith('/org-desk/')) {
      sessionStorage.setItem('organizerReturnTo', sanitizeOrganizerTarget(to.fullPath));
      next({ path: '/portal/organization' });
      NProgress.done();
      return;
    }
    const entry = loggedInEntry(to);
    if (entry && !samePlace(to, splitTarget(entry).path)) {
      next(splitTarget(entry));
      NProgress.done();
      return;
    }
    const settled = goOn(to);
    if (settled.path !== to.path) {
      next(settled);
      return;
    }
    if (routesAdded) {
      // Retain the requested alias path (for example /portal/profile). Providing
      // name together with path would make Vue Router select its canonical path.
      next({ path: to.path, replace: true, query: to.query, hash: to.hash } as RouteLocationRaw);
      return;
    }
    next();
    return;
  }
  if (to.path === '/login' && prefersPlatformLogin(to.query.redirect || to.query.returnTo)) {
    next({ path: '/portal/login', query: { returnTo: sanitizeReturnTo(to.query.redirect || to.query.returnTo) }, replace: true });
    NProgress.done();
    return;
  }
  if (isWhiteList(to.path)) {
    next();
    return;
  }
  next(reauthLocation(to.fullPath));
  NProgress.done();
});

router.afterEach(() => {
  NProgress.done();
});
