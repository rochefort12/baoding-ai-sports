#!/usr/bin/env bash
# Runs once on a fresh dedicated volume, after the unchanged framework SQL.
set -euo pipefail
for name in OWNER_PASSWORD APP_PASSWORD PLATFORM_PASSWORD; do
  value=${!name}
  [[ "$value" =~ ^[a-f0-9]{64}$ ]] || { echo 'Invalid generated database credential format' >&2; exit 1; }
done
# Secrets enter psql only via stdin, without tracing or credential command arguments.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
BEGIN;
CREATE ROLE aisports_owner LOGIN PASSWORD '$OWNER_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE aisports_app LOGIN PASSWORD '$APP_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER DATABASE aisports OWNER TO aisports_owner;
ALTER SCHEMA public OWNER TO aisports_owner;
DO \$ownership\$
DECLARE r record;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
    EXECUTE format('ALTER TABLE public.%I OWNER TO aisports_owner', r.tablename);
  END LOOP;
  FOR r IN SELECT sequencename FROM pg_sequences WHERE schemaname='public' LOOP
    EXECUTE format('ALTER SEQUENCE public.%I OWNER TO aisports_owner', r.sequencename);
  END LOOP;
END
\$ownership\$;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE aisports TO aisports_app;
GRANT USAGE ON SCHEMA public TO aisports_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO aisports_app;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO aisports_app;
ALTER DEFAULT PRIVILEGES FOR ROLE aisports_owner IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO aisports_app;
ALTER DEFAULT PRIVILEGES FOR ROLE aisports_owner IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO aisports_app;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
UPDATE sys_user SET password=crypt('$PLATFORM_PASSWORD',gen_salt('bf',12)) WHERE user_id=1;
UPDATE sys_user SET status='1' WHERE user_id=2;
COMMIT;
SQL
