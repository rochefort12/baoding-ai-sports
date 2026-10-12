import { useUserStore } from '@/store/modules/user';

/** Explicit account switching must clear the participant session before /login:
 * the router intentionally redirects authenticated users away from login pages.
 * Work-account authentication and permissions still come from the server.
 */
export const openWorkAccountLogin = async () => {
  const store = useUserStore();
  if (store.token) await store.logout();
  window.location.assign('/login');
};
