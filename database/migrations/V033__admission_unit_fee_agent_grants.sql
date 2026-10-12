-- Capability descriptions and grants are not channel activation. Real-model activation remains separately gated.
INSERT INTO asp_agent_grant(id,agent_id,capability_code,scope,status)
SELECT a.id*100+c.n,a.id,c.code,'{"inheritActorScope":true}'::jsonb,'active'
FROM asp_agent a CROSS JOIN (VALUES
(41,'type.catalog'),(42,'unit.create'),(43,'fee.units'),(44,'fee.configure'),
(45,'organization.mine'),(46,'organization.save'),(47,'organization.submit'))c(n,code)
WHERE a.id BETWEEN 831000000010 AND 831000000017
AND (a.code='platform' OR (a.code IN('organizer','event') AND c.n BETWEEN 41 AND 44)
 OR (a.code IN('participant','registration') AND c.n IN(41,45,46,47))
 OR (a.code='teammates' AND c.n=41))
ON CONFLICT(agent_id,capability_code) WHERE status='active' DO NOTHING;
