import { createApp } from './app.js';
import { readConfig } from './config.js';

const { host, port } = readConfig();
const server = createApp().listen(port, host, () => {
  console.log(`API berjalan di http://${host}:${port}`);
});
server.on('error', (error) => {
  console.error(`Server gagal dijalankan: ${error.code}`);
  process.exitCode = 1;
});
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 5000).unref();
  });
}