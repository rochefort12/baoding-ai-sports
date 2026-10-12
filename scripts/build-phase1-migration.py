"""Create the new V030 once from the approved model. Applied migrations are never regenerated."""
from pathlib import Path
import importlib.util,sys,re
from generate_table_helpers import ROOT,load_catalog
spec=importlib.util.spec_from_file_location('aisports_ddl',ROOT/'scripts/generate-model.py')
ddl=importlib.util.module_from_spec(spec);sys.modules[spec.name]=ddl;spec.loader.exec_module(ddl)
model=load_catalog();new={t.name for t in model.TABLES if t.name in {
 'asp_competition_type','asp_profile_display','asp_team_room','asp_team_room_member','asp_recruitment','asp_matching_request','asp_matching_offer','asp_matching_offer_member','asp_room_interaction',
 'asp_governance_grant','asp_growth_policy','asp_growth_profile','asp_title_equipment','asp_capability_version','asp_capability_activation','asp_action_execution','asp_agent','asp_agent_version','asp_agent_grant','asp_agent_run','asp_agent_step','asp_agent_message','asp_action_confirmation','asp_complaint_message'}}
sql=['-- V030: additive phase-one objects. Existing identities, receipts and snapshots remain unchanged.','SET LOCAL TIME ZONE \'Asia/Shanghai\';']
fks=[]
for table in model.TABLES:
 if table.name not in new:continue
 lines=[]
 for col in ddl.common(table):
  value=f'    {ddl.ident(col.name)} {col.type}'
  if not col.nullable:value+=' NOT NULL'
  if col.default:value+=' DEFAULT '+col.default
  if col.name=='id':value+=' PRIMARY KEY'
  if col.check:value+=' CHECK ('+col.check+')'
  lines.append(value)
  if col.reference:fks.append(f'ALTER TABLE {table.name} ADD CONSTRAINT {ddl.short("fk",table.name,col.name)} FOREIGN KEY ({col.name}) REFERENCES {col.reference}(id);')
 lines += ['    CHECK ('+check+')' for check in table.checks]
 sql.append('CREATE TABLE '+table.name+' (\n'+',\n'.join(lines)+'\n);')
 for fields,where in table.unique:
  sql.append('CREATE UNIQUE INDEX '+ddl.short('uq',table.name,fields)+' ON '+table.name+' ('+fields+')'+(' WHERE '+where if where else '')+';')
 sql.append('COMMENT ON TABLE '+table.name+' IS '+ddl.quote(table.description)+';')
 for col in ddl.common(table):sql.append('COMMENT ON COLUMN '+table.name+'.'+col.name+' IS '+ddl.quote(col.description)+';')
sql+=fks
sql += [
 "ALTER TABLE asp_competition_unit ADD COLUMN competition_type_id bigint REFERENCES asp_competition_type(id);",
 "ALTER TABLE asp_registration ADD COLUMN manager_account_id bigint REFERENCES asp_account(id);",
 "UPDATE asp_registration SET manager_account_id=submitter_account_id;",
 "ALTER TABLE asp_match ADD COLUMN court_name varchar(80);",
 "ALTER TABLE asp_event ADD COLUMN closure_status varchar(32) NOT NULL DEFAULT 'open' CHECK (closure_status IN ('open','wrap_up','closed'));",
 "ALTER TABLE asp_growth_record ADD COLUMN sport_id bigint REFERENCES asp_sport(id), ADD COLUMN event_id bigint REFERENCES asp_event(id), ADD COLUMN milestone varchar(64), ADD COLUMN points_delta integer NOT NULL DEFAULT 0, ADD COLUMN source_key varchar(160);",
 "CREATE UNIQUE INDEX uq_growth_source_key ON asp_growth_record(source_key) WHERE source_key IS NOT NULL;",
 "ALTER TABLE asp_honor ADD COLUMN sport_id bigint REFERENCES asp_sport(id), ADD COLUMN title_code varchar(64);",
 "ALTER TABLE asp_ai_task ADD COLUMN provider_consent boolean NOT NULL DEFAULT false, ADD COLUMN provider_name varchar(64) NOT NULL DEFAULT 'legacy-bailian', ADD COLUMN consent_version varchar(64) NOT NULL DEFAULT 'legacy';",
 "DO $consent$ DECLARE item record; BEGIN FOR item IN SELECT conname FROM pg_constraint WHERE conrelid='asp_ai_task'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%bailian_consent%' LOOP EXECUTE format('ALTER TABLE asp_ai_task DROP CONSTRAINT %I',item.conname); END LOOP; END $consent$;",
 "ALTER TABLE asp_ai_task ADD CONSTRAINT ck_ai_actual_provider_consent CHECK (bailian_consent=true OR (provider_consent=true AND provider_name='deepseek'));",
 "INSERT INTO asp_sport(id,code,name,rule_family,capability_status,status) VALUES (930000000000000001,'basketball','篮球','对抗','catalog','active'),(930000000000000002,'football','足球','对抗','catalog','active'),(930000000000000003,'table_tennis','乒乓球','对抗','catalog','active') ON CONFLICT (code) DO NOTHING;",
 "INSERT INTO asp_competition_type(id,sport_id,code,name,entry_type,min_members,max_members,capability_status,status) SELECT 930000000000000011,id,'singles','羽毛球单打','individual',1,1,'manual','active' FROM asp_sport WHERE code='badminton' ON CONFLICT (sport_id,code) DO NOTHING;",
 "INSERT INTO asp_competition_type(id,sport_id,code,name,entry_type,min_members,max_members,capability_status,status) SELECT 930000000000000012,id,'doubles','羽毛球双打','pair',2,2,'manual','active' FROM asp_sport WHERE code='badminton' ON CONFLICT (sport_id,code) DO NOTHING;",
 "UPDATE asp_competition_unit u SET competition_type_id=t.id FROM asp_competition_type t WHERE t.sport_id=u.sport_id AND t.entry_type=u.entry_type AND t.min_members=u.min_members AND t.max_members=u.max_members;",
 "CREATE INDEX ix_room_unit_status ON asp_team_room(unit_id,status);",
 "CREATE INDEX ix_matching_unit_status ON asp_matching_request(unit_id,status,create_time);",
 "CREATE INDEX ix_growth_owner ON asp_growth_record(person_id,team_id,sport_id,event_id);",
 "CREATE INDEX ix_run_owner ON asp_agent_run(actor_type,actor_id,create_time);",
 "CREATE INDEX ix_complaint_object ON asp_complaint(object_type,object_id,status);",
 "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO aisports_app;"
]
path=ROOT/'database/migrations/V030__phase1_object_kernel.sql'
text='\n\n'.join(sql)+'\n'
if path.exists() and path.read_text('utf-8')!=text:raise SystemExit('V030 already exists with different bytes; create a later migration')
path.write_text(text,'utf-8');print(f'V030: {len(new)} additive tables')
