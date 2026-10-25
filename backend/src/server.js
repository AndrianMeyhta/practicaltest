import { createApp } from './app.js';
import { readConfig, readDatabaseConfig } from './config.js';
import { createDatabase } from './database.js';

const { host, port } = readConfig();
const database = createDatabase(readDatabaseConfig());
const server = createApp({ database }).listen(port, host, () => {
  console.log(`API berjalan di http://${host}:${port}`);
});
server.on('error', async (error) => {
  console.error(`Server gagal dijalankan: ${error.code}`);
  await database.close();
  process.exitCode = 1;
});
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, () => {
    server.close(async () => {
      try { await database.close(); process.exit(0); }
      catch { process.exit(1); }
    });
    setTimeout(() => process.exit(1), 5000).unref();
  });
}