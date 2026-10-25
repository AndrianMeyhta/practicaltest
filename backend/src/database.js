import mysql from 'mysql2/promise';

export function createDatabase(config) {
  const pool = mysql.createPool(config);
  return {
    async check() {
      const connection = await pool.getConnection();
      try {
        await connection.query({ sql: 'SELECT 1 AS healthy', timeout: 3000 });
      } finally {
        connection.release();
      }
    },
    close: () => pool.end(),
  };
}