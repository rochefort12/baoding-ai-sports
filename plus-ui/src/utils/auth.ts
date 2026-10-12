const TokenKey = 'Admin-Token';
const PlatformTokenKey = 'Platform-Token';

const tokenStorage = useStorage<null | string>(TokenKey, null);
const platformTokenStorage = useStorage<null | string>(PlatformTokenKey, null);

export const getToken = () => tokenStorage.value;

export const setToken = (access_token: string) => (tokenStorage.value = access_token);

export const removeToken = () => (tokenStorage.value = null);

export const getPlatformToken = () => platformTokenStorage.value;

export const setPlatformToken = (access_token: string) => (platformTokenStorage.value = access_token);

export const removePlatformToken = () => (platformTokenStorage.value = null);
