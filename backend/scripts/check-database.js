import { readDatabaseConfig } from '../src/config.js';
import { createDatabase } from '../src/database.js';

const database = createDatabase(readDatabaseConfig());
try {
  await database.check();
  console.log('Koneksi database berhasil.');
} catch (error) {
  console.error(`Koneksi database gagal: ${error.code ?? 'DATABASE_UNAVAILABLE'}`);
  process.exitCode = 1;
} finally {
  await database.close();
}