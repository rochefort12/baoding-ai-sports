#requires -Version 7.0
# 在本机 aisports-dev 库写入 13100000001–13100000010 共 10 个平台登录。
# 不发短信，不建参赛档案。已有同一手机号绑定的账号保持原样，不改密码。
# 清空测试数据仍用 Reset-TestData.ps1；清空后可再运行本脚本补回这 10 个号。
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
Set-Location -LiteralPath $WorkspaceRoot
$dockerCli = Get-DockerCommand

function Assert-ProjectContainer([string]$Name) {
    $actual = (& $dockerCli inspect -f '{{.Name}}' $Name).Trim()
    Assert-NativeExit "Inspect $Name"
    if ($actual -ne "/$Name") { throw "Refusing to touch a container other than $Name." }
}

function Sql-Literal([string]$Value) {
    return "'" + $Value.Replace("'", "''") + "'"
}

function Get-PhoneSubjectHash([string]$Pepper, [string]$Phone) {
    $bytes = [Text.Encoding]::UTF8.GetBytes("${Pepper}`n${Phone}")
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return ([Convert]::ToHexString($hash)).ToLowerInvariant()
}

Assert-ProjectContainer 'aisports-dev-postgres'

$ymlPath = Join-Path $WorkspaceRoot 'backend/ruoyi-admin/src/main/resources/application-local.yml'
$pepperLine = Select-String -LiteralPath $ymlPath -Pattern '^\s*phone-pepper:\s*(\S+)\s*$' | Select-Object -First 1
if (-not $pepperLine) { throw 'phone-pepper is missing from application-local.yml.' }
$pepper = $pepperLine.Matches[0].Groups[1].Value
if ($pepper.StartsWith('${')) { throw 'phone-pepper must be a local literal so the hash matches the running backend.' }

# 与《环境运行》本地试用口令相同。只写入散列，脚本输出不打印口令。
$trialPassword = '123456'
$rows = New-Object System.Collections.Generic.List[string]
foreach ($n in 1..10) {
    $phone = '131000000{0:00}' -f $n
    if ($phone -notmatch '^131000000(0[1-9]|10)$') { throw "Unexpected trial phone $phone." }
    $userId = [long]::Parse(('2106113100000000{0:000}' -f $n))
    $accountId = [long]::Parse(('2106213100000000{0:000}' -f $n))
    $identityId = [long]::Parse(('2106313100000000{0:000}' -f $n))
    $displayName = $phone.Substring(0, 3) + '****' + $phone.Substring(7)
    $subjectHash = Get-PhoneSubjectHash $pepper $phone
    $rows.Add(("({0}, {1}, {2}, {3}, {4}, {5})" -f (Sql-Literal $phone), $userId, $accountId, $identityId, (Sql-Literal $displayName), (Sql-Literal $subjectHash)))
}

$sql = @'
BEGIN;
SELECT pg_advisory_xact_lock(621045014);
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TEMP TABLE trial_phone (
    phone text PRIMARY KEY,
    user_id bigint NOT NULL,
    account_id bigint NOT NULL,
    identity_id bigint NOT NULL,
    display_name text NOT NULL,
    subject_hash text NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE trial_result (
    phone text PRIMARY KEY,
    action text NOT NULL
) ON COMMIT DROP;

INSERT INTO trial_phone (phone, user_id, account_id, identity_id, display_name, subject_hash) VALUES
__VALUES__;

DO $body$
DECLARE
    trial_password text := __PASSWORD__;
    rec record;
    uid bigint;
    aid bigint;
    pwd text;
    fresh boolean;
    created_count integer := 0;
    kept_count integer := 0;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM sys_role
        WHERE role_id = 2106100000000000001 AND tenant_id = '100001' AND del_flag = '0'
    ) THEN
        RAISE EXCEPTION 'participant role is missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM sys_dept
        WHERE dept_id = 2106100000000000004 AND tenant_id = '100001' AND del_flag = '0'
    ) THEN
        RAISE EXCEPTION 'participant department is missing';
    END IF;

    FOR rec IN SELECT * FROM trial_phone ORDER BY phone LOOP
        uid := NULL;
        aid := NULL;
        fresh := false;

        IF EXISTS (
            SELECT 1 FROM asp_login_identity i
            WHERE i.channel = 'phone'
              AND i.subject_hash = rec.subject_hash
              AND i.valid_until IS NULL
        ) THEN
            INSERT INTO trial_result (phone, action) VALUES (rec.phone, 'kept');
            kept_count := kept_count + 1;
            CONTINUE;
        END IF;

        SELECT u.user_id INTO uid
        FROM sys_user u
        WHERE u.tenant_id = '100001'
          AND u.user_name = rec.phone
          AND u.del_flag = '0'
        ORDER BY u.user_id
        LIMIT 1;

        pwd := crypt(trial_password, gen_salt('bf', 10));
        IF crypt(trial_password, pwd) IS DISTINCT FROM pwd THEN
            RAISE EXCEPTION 'bcrypt hash does not verify';
        END IF;

        IF uid IS NULL THEN
            IF EXISTS (SELECT 1 FROM sys_user WHERE user_id = rec.user_id) THEN
                RAISE EXCEPTION 'reserved user id % already exists', rec.user_id;
            END IF;
            uid := rec.user_id;
            INSERT INTO sys_user (
                user_id, tenant_id, dept_id, user_name, nick_name, user_type, phonenumber,
                sex, password, status, del_flag, create_time, remark
            ) VALUES (
                uid, '100001', 2106100000000000004, rec.phone, rec.display_name, 'app_user', rec.phone,
                '0', pwd, '0', '0', CURRENT_TIMESTAMP,
                '本地试用账号。由脚本写入，没有经过短信注册，也没有参赛档案。'
            );
        END IF;

        INSERT INTO sys_user_role (user_id, role_id)
        SELECT uid, 2106100000000000001
        WHERE NOT EXISTS (
            SELECT 1 FROM sys_user_role
            WHERE user_id = uid AND role_id = 2106100000000000001
        );

        SELECT a.id INTO aid
        FROM asp_account a
        WHERE a.backend_user_id = uid
        ORDER BY a.id
        LIMIT 1;

        IF aid IS NULL THEN
            IF EXISTS (SELECT 1 FROM asp_account WHERE id = rec.account_id) THEN
                RAISE EXCEPTION 'reserved account id % already exists', rec.account_id;
            END IF;
            aid := rec.account_id;
            fresh := true;
            INSERT INTO asp_account (id, display_name, password_hash, backend_user_id, status, version)
            VALUES (aid, rec.display_name, pwd, uid, 'active', 0);
        ELSIF NOT EXISTS (
            SELECT 1 FROM asp_account
            WHERE id = aid AND password_hash IS NOT NULL AND btrim(password_hash) <> ''
        ) THEN
            UPDATE asp_account
            SET password_hash = pwd,
                status = 'active'
            WHERE id = aid;
            fresh := true;
        END IF;

        IF EXISTS (SELECT 1 FROM asp_login_identity WHERE id = rec.identity_id) THEN
            RAISE EXCEPTION 'reserved identity id % already exists', rec.identity_id;
        END IF;

        INSERT INTO asp_login_identity (
            id, account_id, channel, subject_hash, valid_from, verification_source, version
        ) VALUES (
            rec.identity_id, aid, 'phone', rec.subject_hash, CURRENT_TIMESTAMP, 'local-trial', 0
        );

        IF fresh AND crypt(trial_password, (SELECT password_hash FROM asp_account WHERE id = aid))
            IS DISTINCT FROM (SELECT password_hash FROM asp_account WHERE id = aid) THEN
            RAISE EXCEPTION 'stored password hash does not match the local trial password';
        END IF;

        INSERT INTO trial_result (phone, action) VALUES (rec.phone, 'created');
        created_count := created_count + 1;
    END LOOP;

    IF created_count + kept_count <> (SELECT count(*) FROM trial_phone) THEN
        RAISE EXCEPTION 'trial account count mismatch';
    END IF;
    IF (
        SELECT count(*)
        FROM trial_phone t
        JOIN asp_login_identity i
          ON i.channel = 'phone'
         AND i.subject_hash = t.subject_hash
         AND i.valid_until IS NULL
        JOIN asp_account a ON a.id = i.account_id AND a.status = 'active'
    ) <> (SELECT count(*) FROM trial_phone) THEN
        RAISE EXCEPTION 'not all trial logins are active';
    END IF;
END
$body$;

SELECT r.phone, r.action
FROM trial_result r
ORDER BY r.phone;
COMMIT;
'@
$sql = $sql.Replace('__VALUES__', ($rows -join ",`n")).Replace('__PASSWORD__', (Sql-Literal $trialPassword))
if ($sql.Contains('__VALUES__') -or $sql.Contains('__PASSWORD__')) { throw 'Trial SQL placeholders were not filled.' }

$sql | & $dockerCli exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
Assert-NativeExit 'Add local trial accounts'
Write-Host 'Local trial accounts 13100000001-13100000010 are ready. No profile was created.'
