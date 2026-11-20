// Genera el .env de un entorno del VPS con secretos aleatorios. No sobrescribe uno existente.
// Uso: node deploy/gen-env.mjs --project vehiculos-prod \
//        --url https://vehiculos.portalpetrocasinos.com --front 20003 --back 21003
import { createHmac, randomBytes } from 'node:crypto';
import { existsSync, writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';

const { values: o } = parseArgs({
  options: {
    project: { type: 'string' },
    url: { type: 'string' },
    front: { type: 'string' },
    back: { type: 'string' },
    out: { type: 'string', default: '.env' },
  },
});
if (!o.project || !o.url || !o.front || !o.back)
  throw new Error('Faltan --project, --url, --front o --back.');
if (!/^https:\/\/[a-z0-9.-]+$/.test(o.url))
  throw new Error('--url debe ser https://dominio, sin barra final.');
if (existsSync(o.out)) throw new Error(`${o.out} ya existe; no se sobrescriben secretos.`);

const hex = (n) => randomBytes(n).toString('hex');
const jwtSecret = hex(40);
const now = Math.floor(Date.now() / 1000);
const jwt = (role) => {
  const enc = (x) => Buffer.from(JSON.stringify(x)).toString('base64url');
  // Claves de servicio de larga duración (10 años), como en Supabase. Rotar = regenerar el .env.
  const body =
    enc({ alg: 'HS256', typ: 'JWT' }) +
    '.' +
    enc({ role, iss: 'supabase', iat: now, exp: now + 10 * 365 * 86400 });
  return body + '.' + createHmac('sha256', jwtSecret).update(body).digest('base64url');
};

const env = {
  COMPOSE_PROJECT_NAME: o.project,
  PUBLIC_URL: o.url,
  FRONT_PORT: o.front,
  BACK_PORT: o.back,
  POSTGRES_PASSWORD: hex(24),
  AUTHENTICATOR_PASSWORD: hex(24),
  AUTH_ADMIN_PASSWORD: hex(24),
  STORAGE_ADMIN_PASSWORD: hex(24),
  JWT_SECRET: jwtSecret,
  ANON_KEY: jwt('anon'),
  SERVICE_KEY: jwt('service_role'),
  AUTH_RATE_LIMIT_SECRET: hex(32),
};
writeFileSync(
  o.out,
  Object.entries(env)
    .map(([k, v]) => `${k}=${v}`)
    .join('\n') + '\n',
  {
    mode: 0o600,
  },
);
console.log(`${o.out} creado para ${o.project} (secretos no impresos).`);
