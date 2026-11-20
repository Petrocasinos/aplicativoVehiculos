#!/bin/sh
# Primera inicialización de la BD: roles y esquemas de scripts/local/init.sql,
# luego reemplaza las contraseñas de prueba por las del .env del entorno.
set -eu
psql -v ON_ERROR_STOP=1 -U postgres -d postgres -f /init/init.sql
psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -v rest_pw="$AUTHENTICATOR_PASSWORD" \
  -v auth_pw="$AUTH_ADMIN_PASSWORD" \
  -v storage_pw="$STORAGE_ADMIN_PASSWORD" <<'SQL'
alter role authenticator password :'rest_pw';
alter role supabase_auth_admin password :'auth_pw';
alter role supabase_storage_admin password :'storage_pw';
SQL
