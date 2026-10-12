-- 只用于 Test-CriticalDatabase.ps1 创建的无业务数据临时库。
INSERT INTO asp_account(id,display_name,status) VALUES(201,'Synthetic participant','active');
INSERT INTO asp_organization(id,tenant_id,name,status) VALUES(601,'critical','Synthetic organizer','certified');
INSERT INTO asp_sport(id,code,name,rule_family,capability_status,status) VALUES(101,'critical','Synthetic sport','badminton','registration','active');
INSERT INTO asp_event(id,tenant_id,organization_id,name,status,registration_status,payment_status,visibility,published_revision,contact_snapshot)
VALUES(901,'critical',601,'Synthetic event','draft','closed','disabled','private',0,'{}');
INSERT INTO asp_competition_unit(id,tenant_id,event_id,sport_id,name,entry_type,min_members,max_members,status)
VALUES(501,'critical',901,101,'Critical pair','pair',2,2,'open');
INSERT INTO asp_capacity_pool(id,tenant_id,event_id,capacity_unit,dedupe_scope,limit_count,used_count,status)
VALUES(401,'critical',901,'entry','unit',1,0,'active');
INSERT INTO asp_notification(id,tenant_id,recipient_account_id,business_type,business_id,business_revision,purpose,content,dedupe_key)
VALUES(801,'critical',201,'invitation',701,1,'invite','{}','invite-701');
INSERT INTO asp_notification_delivery(id,tenant_id,notification_id,channel,attempt,status)
VALUES(811,'critical',801,'inbox',0,'sent');
DO $$ BEGIN
 BEGIN
  INSERT INTO asp_competition_unit(id,tenant_id,event_id,sport_id,name,entry_type,min_members,max_members,status)
  VALUES(502,'critical',901,101,'  CRITICAL PAIR  ','pair',2,2,'open');
  RAISE EXCEPTION 'Expected normalized unit uniqueness';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 RAISE NOTICE 'PASS normalized-unit-name';
 BEGIN
  INSERT INTO asp_competition_unit(id,tenant_id,event_id,sport_id,name,entry_type,min_members,max_members,status)
  VALUES(503,'another',901,101,'Cross tenant','pair',2,2,'open');
  RAISE EXCEPTION 'Expected tenant foreign key';
 EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 RAISE NOTICE 'PASS cross-tenant-unit-rejected';
 BEGIN
  INSERT INTO asp_notification_delivery(id,tenant_id,notification_id,channel,attempt,status)
  VALUES(812,'another',801,'inbox',0,'sent');
  RAISE EXCEPTION 'Expected tenant foreign key';
 EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 RAISE NOTICE 'PASS cross-tenant-delivery-rejected';
 BEGIN
  INSERT INTO asp_notification_delivery(id,tenant_id,notification_id,channel,attempt,status)
  VALUES(813,'critical',801,'inbox',0,'sent');
  RAISE EXCEPTION 'Expected delivery uniqueness';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 RAISE NOTICE 'PASS duplicate-delivery-rejected';
 BEGIN
  INSERT INTO asp_notification(id,tenant_id,recipient_account_id,business_type,business_id,business_revision,purpose,content,dedupe_key)
  VALUES(802,'critical',201,'invitation',702,1,'invite','{}','invite-702');
  INSERT INTO asp_notification_delivery(id,tenant_id,notification_id,channel,attempt,status)
  VALUES(814,'another',802,'inbox',0,'sent');
  RAISE EXCEPTION 'Expected transaction failure';
 EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 IF EXISTS(SELECT FROM asp_notification WHERE id=802) THEN RAISE EXCEPTION 'Partial notice survived rollback'; END IF;
 RAISE NOTICE 'PASS notice-and-delivery-rollback';
 BEGIN
  UPDATE asp_capacity_pool SET used_count=2 WHERE id=401;
  RAISE EXCEPTION 'Expected capacity constraint';
 EXCEPTION WHEN check_violation THEN NULL; END;
 IF (SELECT used_count FROM asp_capacity_pool WHERE id=401) <> 0 THEN RAISE EXCEPTION 'Invalid capacity persisted'; END IF;
 RAISE NOTICE 'PASS capacity-overflow-rejected';
 BEGIN
  UPDATE asp_capacity_pool SET used_count=1 WHERE id=401;
  RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Synthetic downstream failure';
 EXCEPTION WHEN no_data_found THEN NULL; END;
 IF (SELECT used_count FROM asp_capacity_pool WHERE id=401) <> 0 THEN RAISE EXCEPTION 'Reservation survived rollback'; END IF;
 RAISE NOTICE 'PASS reservation-rollback';
END $$;
