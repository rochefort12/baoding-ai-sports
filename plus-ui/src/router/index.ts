import { createWebHistory, createRouter, RouteRecordRaw } from 'vue-router';
import { sanitizeReturnTo } from '@/utils/returnTo';
/* Layout */
import Layout from '@/layout/index.vue';

/**
 * Note: 路由配置项
 *
 * hidden: true                     // 当设置 true 的时候该路由不会再侧边栏出现 如401，login等页面，或者如一些编辑页面/edit/1
 * alwaysShow: true                 // 当你一个路由下面的 children 声明的路由大于1个时，自动会变成嵌套的模式--如组件页面
 *                                  // 只有一个时，会将那个子路由当做根路由显示在侧边栏--如引导页面
 *                                  // 若你想不管路由下面的 children 声明的个数都显示你的根路由
 *                                  // 你可以设置 alwaysShow: true，这样它就会忽略之前定义的规则，一直显示根路由
 * redirect: noRedirect             // 当设置 noRedirect 的时候该路由在面包屑导航中不可被点击
 * name:'router-name'               // 设定路由的名字，一定要填写不然使用<keep-alive>时会出现各种问题
 * query: '{"id": 1, "name": "ry"}' // 访问路由的默认传递参数
 * roles: ['admin', 'common']       // 访问路由的角色权限
 * permissions: ['a:a:a', 'b:b:b']  // 访问路由的菜单权限
 * meta : {
    noCache: true                   // 如果设置为true，则不会被 <keep-alive> 缓存(默认 false)
    title: 'title'                  // 设置该路由在侧边栏和面包屑中展示的名字
    icon: 'svg-name'                // 设置该路由的图标，对应路径src/assets/icons/svg
    breadcrumb: false               // 如果设置为false，则不会在breadcrumb面包屑中显示
    activeMenu: '/system/user'      // 当路由设置了该属性，则会高亮相对应的侧边栏。
  }
 */

// 公共路由
export const constantRoutes: RouteRecordRaw[] = [
  {path:'/org-desk/issues',component:Layout,hidden:true,children:[{path:':id?',component:()=>import('@/views/portal/issues.vue'),meta:{title:'赛事问题处理'}}]},
  {path:'/government/issues',component:Layout,hidden:true,children:[{path:':id?',component:()=>import('@/views/portal/issues.vue'),meta:{title:'投诉协调'}}]},
  { path:'/portal/rooms/:id?', component:()=>import('@/views/portal/rooms.vue'), hidden:true, meta:{title:'参赛集结'} },
  { path:'/portal/growth', component:()=>import('@/views/portal/growth.vue'), hidden:true, meta:{title:'运动成长'} },
  { path:'/portal/issues/:id?', component:()=>import('@/views/portal/issues.vue'), hidden:true, meta:{title:'赛事问题处理'} },
  { path:'/public/athletes/:id', component:()=>import('@/views/portal/athlete.vue'), hidden:true, meta:{title:'运动名片'} },
  {
    path: '/org-desk/events/from-document',
    component: Layout,
    hidden: true,
    children: [
      {
        path: ':taskId?',
        component: () => import('@/views/sports/event/from-document.vue'),
        name: 'SportsEventFromDocument',
        meta: { title: 'AI办赛', noCache: true }
      }
    ]
  },
  {
    path: '/org-desk/workspace',
    component: Layout,
    hidden: true,
    children: [
      {
        path: ':eventId',
        component: () => import('@/views/sports/workspace/index.vue'),
        name: 'SportsWorkspace',
        meta: { title: '赛事工作区', noCache: true }
      }
    ]
  },
  {
    path: '/org-desk/catalog',
    component: Layout,
    hidden: true,
    children: [
      {
        path: '',
        component: () => import('@/views/sports/field/index.vue'),
        name: 'SportsFieldCatalog',
        meta: { title: '组织字段目录', noCache: true }
      }
    ]
  },
  {
    path: '/redirect',
    component: Layout,
    hidden: true,
    children: [
      {
        path: '/redirect/:path(.*)',
        component: () => import('@/views/redirect/index.vue')
      }
    ]
  },
  {
    path: '/social-callback',
    hidden: true,
    component: () => import('@/layout/components/SocialCallback/index.vue')
  },
  {
    path: '/login',
    component: () => import('@/views/login.vue'),
    hidden: true
  },
  {
    path: '/public/events',
    component: () => import('@/views/public/events/index.vue'),
    hidden: true,
    meta: { title: '公开赛事' }
  },
  {
    path: '/public/events/:id',
    component: () => import('@/views/public/events/detail.vue'),
    hidden: true,
    meta: { title: '赛事详情' }
  },
  {
    path: '/register',
    redirect: (to) => ({
      path: '/portal/register',
      query: to.query.returnTo || to.query.redirect ? { returnTo: sanitizeReturnTo(to.query.returnTo || to.query.redirect) } : {}
    }),
    hidden: true
  },
  {
    path: '/forgot',
    redirect: (to) => ({
      path: '/portal/forgot',
      query: to.query.returnTo || to.query.redirect ? { returnTo: sanitizeReturnTo(to.query.returnTo || to.query.redirect) } : {}
    }),
    hidden: true
  },
  {
    path: '/portal/home',
    component: () => import('@/views/portal/home.vue'),
    hidden: true,
    meta: { title: '首页' }
  },
  {
    path: '/portal/login',
    component: () => import('@/views/portal/login.vue'),
    hidden: true,
    meta: { title: '登录' }
  },
  {
    path: '/portal/register',
    component: () => import('@/views/portal/register.vue'),
    hidden: true,
    meta: { title: '注册' }
  },
  {
    path: '/portal/forgot',
    component: () => import('@/views/portal/forgot.vue'),
    hidden: true,
    meta: { title: '重置密码' }
  },
  {
    path: '/portal/future/:kind',
    component: () => import('@/views/portal/future.vue'),
    hidden: true,
    meta: { title: '暂未开放' }
  },
  {
    path: '/:pathMatch(.*)*',
    component: () => import('@/views/error/404.vue'),
    hidden: true
  },
  {
    path: '/401',
    component: () => import('@/views/error/401.vue'),
    hidden: true
  },
  {
    path: '',
    component: Layout,
    redirect: '/portal/home',
    children: [
      {
        path: '/index',
        component: () => import('@/views/index.vue'),
        name: 'Index',
        meta: { title: '首页', icon: 'dashboard', affix: true }
      }
    ]
  },
  {
    path: '/platform/tools',
    component: Layout,
    hidden: true,
    children: [
      {
        path: '',
        component: () => import('@/views/platform/tools.vue'),
        name: 'PlatformTools',
        meta: { title: '平台办理', icon: 'form' }
      }
    ]
  },
  {
    path: '/portal',
    component: () => import('@/layout/consumer/PortalFrame.vue'),
    hidden: true,
    children: [
      {
        path: 'identity',
        alias: 'profile',
        component: () => import('@/views/portal/identity.vue'),
        name: 'PortalIdentity',
        meta: { title: '身份档案', icon: 'user' }
      },
      {
        path: 'organization',
        component: () => import('@/views/portal/organization.vue'),
        name: 'PortalOrganization',
        meta: { title: '我要办赛', icon: 'form' }
      },
      {
        path: 'registration',
        component: () => import('@/views/sports/registration/enter.vue'),
        name: 'PortalRegistration',
        meta: { title: '我的报名', icon: 'form' }
      },
      {
        path: 'registration/apply',
        component: () => import('@/views/sports/registration/enter.vue'),
        name: 'PortalRegistrationApply',
        meta: { title: '报名办理' }
      },
      {
        path: 'registration/detail/:id',
        component: () => import('@/views/sports/registration/enter.vue'),
        name: 'PortalRegistrationDetail',
        meta: { title: '报名详情' }
      },
      {
        path: 'feedback',
        component: () => import('@/views/portal/feedback.vue'),
        name: 'PortalFeedback',
        meta: { title: '问题反馈', icon: 'message' }
      },
      {
        path: 'notices',
        component: () => import('@/views/portal/notices.vue'),
        name: 'PortalNotices',
        meta: { title: '我的消息', icon: 'message' }
      },
      {
        path: 'proofs',
        component: () => import('@/views/portal/proof.vue'),
        name: 'PortalProofs',
        meta: { title: '我的证明', icon: 'form' }
      },
      {
        path: 'results',
        component: () => import('@/views/portal/results.vue'),
        name: 'PortalResults',
        meta: { title: '我的赛果' }
      },
      {
        path: 'teams',
        component: () => import('@/views/portal/team.vue'),
        name: 'PortalTeams',
        meta: { title: '长期队伍', icon: 'peoples' }
      },
      {
        path: 'teams/invitations/:invitationId',
        component: () => import('@/views/portal/team-invitation.vue'),
        name: 'PortalTeamInvitation',
        meta: { title: '入队邀请' }
      },
      {
        path: 'teams/join/:token',
        component: () => import('@/views/portal/team-share.vue'),
        name: 'PortalTeamShare',
        meta: { title: '加入队伍' }
      },
      {
        path: 'teams/:id',
        component: () => import('@/views/portal/team.vue'),
        name: 'PortalTeamDetail',
        meta: { title: '队伍', icon: 'peoples' }
      },
      {
        path: 'registration/invite/:token',
        component: () => import('@/views/sports/registration/invite.vue'),
        name: 'RegistrationInvite',
        meta: { title: '确认参赛' }
      }
    ]
  },
  {
    path: '/user',
    component: Layout,
    hidden: true,
    redirect: 'noredirect',
    children: [
      {
        path: 'profile',
        component: () => import('@/views/system/user/profile/index.vue'),
        name: 'Profile',
        meta: { title: '个人中心', icon: 'user' }
      }
    ]
  }
];

// 动态路由，基于用户权限动态去加载
export const dynamicRoutes: RouteRecordRaw[] = [];

/**
 * 创建路由
 */
const router = createRouter({
  history: createWebHistory(import.meta.env.VITE_APP_CONTEXT_PATH),
  routes: constantRoutes,
  // 刷新时，滚动条位置还原
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition;
    }
    return { top: 0 };
  }
});

export default router;
