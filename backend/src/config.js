export function readConfig(env = process.env) {
  const rawPort = env.PORT ?? '3000';
  const port = Number(rawPort);
  if (!/^\d+$/.test(rawPort) || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT harus berupa integer antara 1 dan 65535.');
  }
  return { host: env.HOST?.trim() || '127.0.0.1', port };
}