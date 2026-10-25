import mysql from 'mysql2/promise';
import { readDatabaseConfig } from '../src/config.js';
import { migrate } from '../src/migrate.js';

const connection = await mysql.createConnection(readDatabaseConfig());
try {
  await migrate(connection);
  console.log('Migration selesai.');
} finally { await connection.end(); }