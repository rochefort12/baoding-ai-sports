"""Bind the known legacy business mutation methods; never generate actions for raw mappers."""
from generate_table_helpers import ROOT
import re
base=ROOT/'backend/aisports-domains'
domains={}
for p in base.rglob('*.java'):
 if '/src/main/' not in p.as_posix(): continue
 match=re.search(r'package org.dromara.sports.(identity|organization|event|registration|team|finance|competition)',p.read_text('utf-8'))
 if match: domains.setdefault(match[1],set()).update(re.findall(r'asp_[a-z][a-z0-9_]+',p.read_text('utf-8')))
closure={'identity':['identity','registration'], 'organization':['organization'], 'event':['event','registration','finance','competition'], 'registration':['registration','finance','event','competition'], 'team':['team','registration','finance','event'], 'finance':['finance','registration','event'], 'competition':['competition','registration']}
growth={'asp_growth_record','asp_growth_profile','asp_growth_policy','asp_title_equipment','asp_honor','asp_team','asp_team_member','asp_account','asp_person','asp_sport','asp_profile_display','asp_team_room','asp_team_room_member','asp_competition_type','asp_roster_member','asp_roster_version'}
methods={'confirmManual','confirmCallback','reverse','closeWithoutRefund','recordRefund','settleCancellation','placeInitialPolicy','saveEventPaymentConfig','saveMine','saveOrgField','saveEventField','changeReview','offline','retrySms','createFromDocument','saveToDraft','create','rename','apply','cancel','approve','reject','invite','accept','decline','revoke','leave','remove','transfer','disband','createUnit','createDraft','addTeammate','removeMember','confirmInvite','declineInvite','submit','declarePaid','withdraw','deleteDraft','updateUnit','adjustLimit','tryAutoApproveAfterPayment','acknowledgeDeclaration','checkIn','createMatch','saveResult','finalizeResult','importResults','grantAward','register','saveProfile','updateProfile','closeAccount','resetPassword','changePassword','createApplication','saveDraft','resubmit','publish','unpublish','end','cancelEvent','update','save','confirm','delete','upload','saveSettings','recordPayment','reversePayment','createRefund','completeRefund','confirmRefund','rejectRefund','requestRefund','resolve','created','read','respond','markRead','send','verify'}
changed=0
for p in base.rglob('*Service.java'):
 if '/src/main/' not in p.as_posix(): continue
 original=p.read_text('utf-8');text=original; match=re.search(r'package org.dromara.sports.(identity|organization|event|registration|team|finance|competition)',text)
 if not match: continue
 domain=match[1]; tables=set().union(*(domains.get(d,set()) for d in closure[domain]))|growth
 # SQL source regex may include prose suffixes: constrain to the trusted catalog.
 from generate_table_helpers import load_catalog
 names={t.name for t in load_catalog().TABLES}; tables&=names
 text=re.sub(r'(reads|writes)=\{[^}]*\}',lambda m:m[1]+'={'+','.join('\"'+t+'\"' for t in sorted(tables))+'}',text)
 values=','.join('"'+t+'"' for t in sorted(tables))
 def bind(m):
  prefix=m[1]; name=m[2]
  if name not in methods or '@SportsAction(' in prefix or '@org.dromara.sports.platform.core.SportsAction(' in prefix:return m[0]
  code='legacy.'+domain+'.'+p.stem.lower()+'.'+name.lower()
  return prefix+'    @org.dromara.sports.platform.core.SportsAction(value="'+code+'",title="兼容业务办理",reads={'+values+'},writes={'+values+'})\n'+m[0][len(prefix):]
 # Group preceding annotations, so an already registered method is left unchanged.
 result=re.sub(r'((?:    @[^\n]+\n)*)    public [^\n{;=]+?\b(\w+)\([^\n]*',bind,text)
 if result!=original:p.write_text(result,'utf-8');changed+=1
print(f'Registered legacy mutation boundaries in {changed} service files')
