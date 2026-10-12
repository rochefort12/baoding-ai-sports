import request from '@/utils/request';
import type { CertifiedHonor } from './honorCertification';

/** Anonymous projection requires both honor and profile consent; never returns evidence or review notes. */
export const publicCertifiedHonors=(accountId:string,sportId?:string)=>request<CertifiedHonor[]>({url:`/sports/honors/certifications/public/${encodeURIComponent(accountId)}`,params:{sportId},headers:{isToken:false}});
