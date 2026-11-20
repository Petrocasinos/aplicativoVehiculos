#!/usr/bin/env bash
# Aplica las migraciones pendientes de supabase/migrations y lleva registro en deploy.migrations.
# Uso (desde la carpeta del entorno): ./deploy/migrate.sh        -> sin datos demo
#                                     SEED=1 ./deploy/migrate.sh -> además carga supabase/seed.sql (solo QA)
set -euo pipefail
cd "$(dirname "$0")/.."
psql() { docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -qAt "$@"; }

echo "Esperando a que Auth y Storage creen sus tablas…"
for _ in $(seq 1 60); do
  ready=$(psql -c "select to_regclass('auth.users') is not null and to_regclass('storage.buckets') is not null")
  [ "$ready" = "t" ] && break
  sleep 2
done
[ "$ready" = "t" ] || { echo "Auth/Storage no inicializaron. Revisa: docker compose logs auth storage"; exit 1; }

psql <<'SQL'
create schema if not exists deploy;
revoke all on schema deploy from public;
create table if not exists deploy.migrations(name text primary key, applied_at timestamptz not null default now());
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claims',true)::jsonb->>'sub','')::uuid $$;
create or replace function auth.role() returns text language sql stable as $$ select current_setting('request.jwt.claims',true)::jsonb->>'role' $$;
SQL

for file in $(ls supabase/migrations/*.sql | sort); do
  name=$(basename "$file")
  [ "$(psql -c "select count(*) from deploy.migrations where name='$name'")" = "1" ] && continue
  { echo "begin;"; cat "$file"; echo; echo "insert into deploy.migrations(name) values('$name');"; echo "commit;"; } | psql
  echo "Aplicada $name"
done

if [ "${SEED:-0}" = "1" ]; then psql < supabase/seed.sql && echo "Seed demo cargado."; fi

psql <<'SQL'
grant select,insert,update,delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
notify pgrst, 'reload schema';
SQL
echo "Migraciones al día."
