import mysql from 'mysql2/promise';
import { readDatabaseConfig } from '../src/config.js';
import { seedDemo } from '../src/seed.js';

const connection = await mysql.createConnection(readDatabaseConfig());
try {
  console.log(await seedDemo(connection) ? 'Seed UPVC berhasil.' : 'Seed sudah pernah dijalankan; data tidak diubah.');
} finally { await connection.end(); }