import type { ComputedRef, InjectionKey } from 'vue';
import type { CertifiedHonor } from '@/api/sports/honorCertification';

export type WorldHonorArtwork = 'champion' | 'runner-up' | 'third-place';
export interface CertifiedFrameDisplay {
  readonly honorId: string;
  readonly sportId: string;
  readonly eventYear: number;
  readonly artwork: WorldHonorArtwork;
  readonly source: string;
}

/** A scoped, read-only display projection. Providing this never grants or changes an honor. */
export const certifiedFrameContext: InjectionKey<ComputedRef<CertifiedFrameDisplay | undefined>>=Symbol('sports-certified-frame');

/** Only canonical podium numbers are supported; unknown labels never become a gold badge. */
export const worldHonorArtwork=(place:unknown):WorldHonorArtwork|undefined=>{
  if(place===1||place==='1')return 'champion';
  if(place===2||place==='2')return 'runner-up';
  if(place===3||place==='3')return 'third-place';
  return undefined;
};
export const worldHonorBadgePath=(place:unknown)=>{const artwork=worldHonorArtwork(place);return artwork?`/images/sports/honors/world-${artwork}-badge.webp`:'';};
export const worldHonorFramePath=(place:unknown)=>{const artwork=worldHonorArtwork(place);return artwork?`/images/sports/honors/world-${artwork}-frame.webp`:'';};
export const validHonorYear=(year:unknown,currentYear=new Date().getFullYear())=>typeof year==='number'&&Number.isInteger(year)&&year>=1900&&year<=currentYear;

/** Input must be the honor service's approved owner/public projection, not an application claim. */
export const validWornCertifiedHonors=(honors:readonly CertifiedHonor[]|undefined,sportId:string|undefined,currentYear=new Date().getFullYear()):CertifiedHonor[]=>{
  if(!sportId)return [];
  return honors?.filter(honor=>honor.worn===true&&String(honor.sportId)===String(sportId)&&typeof honor.honorId==='string'&&!!honor.honorId.trim()&&typeof honor.title==='string'&&!!honor.title.trim()&&validHonorYear(honor.eventYear,currentYear)&&[1,2,3].includes(honor.place))||[];
};
export const certifiedFrameDisplay=(honors:readonly CertifiedHonor[]|undefined,sportId:string|undefined,currentYear=new Date().getFullYear()):CertifiedFrameDisplay|undefined=>{
  const worn=validWornCertifiedHonors(honors,sportId,currentYear);
  // Conflicting worn facts are not a reason to choose the most prestigious frame.
  if(worn.length!==1)return undefined;
  const honor=worn[0],artwork=worldHonorArtwork(honor.place);
  if(!artwork)return undefined;
  return Object.freeze({honorId:honor.honorId,sportId:honor.sportId,eventYear:honor.eventYear,artwork,source:worldHonorFramePath(honor.place)});
};
