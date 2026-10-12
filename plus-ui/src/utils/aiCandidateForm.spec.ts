import { describe, expect, it } from 'vitest';
import { applyUniformCandidateValues, candidateUnitIds, canRestoreCandidateUnits, readCandidateForm } from './aiCandidateForm';
import type { AiTaskCard } from '@/api/sports/aiTask';

describe('conversation candidate form',()=>{
  it('restores prices only to the same ordered actual project IDs',()=>{
    const ids=candidateUnitIds([{createdUnitId:'2109633684175859713'},{createdUnitId:'2109633684175859714'}]);
    expect(canRestoreCandidateUnits(ids,[...ids])).toBe(true);
    expect(canRestoreCandidateUnits(ids,[...ids].reverse())).toBe(false);
    expect(canRestoreCandidateUnits(ids,['2109633684175859713','2109633684175859715'])).toBe(false);
    expect(canRestoreCandidateUnits(['',''],['',''])).toBe(false);
    expect(canRestoreCandidateUnits([ids[0],ids[0]],[ids[0],ids[0]])).toBe(false);
  });
  it('preserves zero fees, public sport description and the chosen source cover',()=>{
    const task={proposal:JSON.stringify({event:{projectName:{value:'羽毛球分龄单打与双打'},registrationReview:{value:'manual'},declarationText:{value:'本人确认'}},units:[{feeAmount:{value:0},feeBasis:{value:'order'}}],cover:{fileId:'12',index:2}})} as AiTaskCard;
    const result=readCandidateForm(task);expect(result.event.projectName).toBe('羽毛球分龄单打与双打');expect(result.event.registrationReview).toBe('manual');expect(result.units[0].feeAmount).toBe('0');expect(result.cover).toEqual({fileId:'12',index:2});
  });
  it('sets all orders only after an explicit bulk application without changing members',()=>{
    const units=[{name:'单打',feeBasis:'unknown',minMembers:'1'},{name:'双打',feeBasis:'per_person',minMembers:'2'}];
    applyUniformCandidateValues(units,'100','32');expect(units.map(unit=>({...unit}))).toEqual([{name:'单打',feeBasis:'order',minMembers:'1',feeAmount:'100',limitCount:'32'},{name:'双打',feeBasis:'order',minMembers:'2',feeAmount:'100',limitCount:'32'}]);
  });
  it('rejects invalid bulk inputs before touching any existing price',()=>{
    const units=[{feeAmount:'70',feeBasis:'order'}];expect(()=>applyUniformCandidateValues(units,'100','0')).toThrow();expect(units[0].feeAmount).toBe('70');expect(()=>applyUniformCandidateValues(units,'-1','32')).toThrow();
  });
});
