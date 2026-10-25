export function readConfig(env = process.env) {
  const rawPort = env.PORT ?? '3000';
  const port = Number(rawPort);
  if (!/^\d+$/.test(rawPort) || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT harus berupa integer antara 1 dan 65535.');
  }
  return { host: env.HOST?.trim() || '127.0.0.1', port };
}

export function readDatabaseConfig(env = process.env) {
  for (const key of ['DB_HOST', 'DB_USER', 'DB_NAME']) {
    if (!env[key]?.trim()) throw new Error(`${key} wajib diisi.`);
  }
  const { port } = readConfig({ PORT: env.DB_PORT ?? '3306' });
  return {
    host: env.DB_HOST.trim(), port,
    user: env.DB_USER.trim(), password: env.DB_PASSWORD ?? '',
    database: env.DB_NAME.trim(),
    timezone: 'Z', charset: 'utf8mb4',
    connectionLimit: 5, waitForConnections: false, connectTimeout: 3000,
  };
}