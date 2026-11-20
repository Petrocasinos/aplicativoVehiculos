#!/usr/bin/env bash
# Respaldo diario: volcado de la BD y copia de los archivos de Storage. Conserva 14 días.
# Uso (cron, desde la carpeta del entorno): ./deploy/backup.sh /srv/backups/vehiculos
set -euo pipefail
umask 077 # los respaldos incluyen hashes de contraseñas: solo legibles por el dueño
cd "$(dirname "$0")/.."
dest="${1:?Indica la carpeta destino}"
project=$(grep '^COMPOSE_PROJECT_NAME=' .env | cut -d= -f2)
stamp=$(date +%Y%m%d-%H%M)
mkdir -p "$dest"
docker compose exec -T db pg_dump -U postgres -d postgres -Fc > "$dest/$project-db-$stamp.dump"
docker compose exec -T storage tar -C /var/lib/storage -czf - . > "$dest/$project-storage-$stamp.tar.gz"
find "$dest" -name "$project-*" -mtime +14 -delete
echo "Respaldo $project $stamp listo en $dest"
