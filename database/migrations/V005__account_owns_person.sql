-- 本人档案改挂在平台账号上。一名账号最多一份档案，一份档案最多一个账号。
-- 不再通过账号-档案关联、监护和代报授权为别人建档。

ALTER TABLE asp_account ADD COLUMN person_id bigint;

UPDATE asp_account AS account
SET person_id = link.person_id
FROM (
    SELECT DISTINCT ON (account_id) account_id, person_id
    FROM asp_account_person
    WHERE valid_until IS NULL
    ORDER BY account_id, id
) AS link
WHERE account.id = link.account_id
  AND account.person_id IS NULL;

CREATE UNIQUE INDEX uq_asp_account_person_id ON asp_account (person_id) WHERE person_id IS NOT NULL;
ALTER TABLE asp_account
    ADD CONSTRAINT fk_asp_account_person_id FOREIGN KEY (person_id) REFERENCES asp_person (id);
COMMENT ON COLUMN asp_account.person_id IS '本人参赛档案；空表示尚未建档。一名账号最多一份。';

DROP TABLE asp_delegation;
DROP TABLE asp_guardianship;
DROP TABLE asp_account_person;
