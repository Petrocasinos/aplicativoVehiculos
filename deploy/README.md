# Despliegue en el VPS de Sistemas

Un entorno = una carpeta con su clon del repo y su `.env` (nunca en GitHub).

| Entorno    | Carpeta                  | Rama       | Dominio                                    | Front | Back (gateway) |
| ---------- | ------------------------ | ---------- | ------------------------------------------ | ----- | -------------- |
| Producción | /opt/apps/vehiculos/prod | production | https://vehiculos.portalpetrocasinos.com   | 20003 | 21003          |
| QA         | /opt/apps/vehiculos/qa   | QA         | https://vehiculosqa.portalpetrocasinos.com | 23003 | 24003          |

La BD (Postgres 17) no se publica. Auth, PostgREST y Storage salen por el gateway en el
puerto "back"; Caddy del host enruta `/auth/v1`, `/rest/v1` y `/storage/v1` del dominio a ese
puerto y el resto a la app.

## Primera instalación

```bash
docker run --rm -v "$PWD":/w -w /w node:24.22.1-alpine node deploy/gen-env.mjs \
  --project vehiculos-prod --url https://vehiculos.portalpetrocasinos.com --front 20003 --back 21003
sudo docker compose up -d --build
./deploy/migrate.sh                     # QA con datos demo: SEED=1 ./deploy/migrate.sh
sudo docker compose run --rm -e BOOTSTRAP_EMAIL=... -e BOOTSTRAP_ALIAS=nombre.apellido \
  -e BOOTSTRAP_PASSWORD='...' tools node scripts/bootstrap.mjs
```

## Actualizar

```bash
git pull && sudo docker compose up -d --build && ./deploy/migrate.sh
```

## Caddy del host

```
vehiculos.portalpetrocasinos.com {
	@supabase path /auth/v1/* /rest/v1/* /storage/v1/*
	handle @supabase {
		reverse_proxy 127.0.0.1:21003
	}
	handle {
		reverse_proxy 127.0.0.1:20003
	}
}
```

## Respaldo

`./deploy/backup.sh /srv/backups/vehiculos` (cron diario). Restaurar BD:
`docker compose exec -T db pg_restore -U postgres -d postgres --clean < archivo.dump`.

## Flujo de ramas

Rama corta (`feat/…`, `fix/…`, `chore/…`) desde `develop` → PR a `develop` (CI verde) →
PR `develop` → `QA` → actualizar QA en el VPS → PR `QA` → `production` → actualizar producción.
Nunca push directo a `develop`, `QA` ni `production`.
