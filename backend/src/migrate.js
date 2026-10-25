import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';

export async function migrate(connection) {
  const lockName = `migration:${connection.config.database}`;
  const [[lock]] = await connection.query('SELECT GET_LOCK(?, 10) AS acquired', [lockName]);
  if (lock.acquired !== 1) throw new Error('Migration sedang berjalan.');
  try {
    await connection.query("SET time_zone = '+00:00'");
    await connection.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      name VARCHAR(150) PRIMARY KEY, checksum CHAR(64) NOT NULL,
      status VARCHAR(10) NOT NULL, applied_at DATETIME(6) NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
    const directory = new URL('../migrations/', import.meta.url);
    for (const name of (await readdir(directory)).filter((file) => file.endsWith('.sql')).sort()) {
      const sql = await readFile(new URL(name, directory), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      const [[previous]] = await connection.execute('SELECT * FROM schema_migrations WHERE name=?', [name]);
      if (previous) {
        if (previous.status !== 'applied' || previous.checksum !== checksum) {
          throw new Error(`Migration ${name} berubah atau sebelumnya terhenti. Periksa schema sebelum melanjutkan.`);
        }
        continue;
      }
      await connection.execute('INSERT INTO schema_migrations(name,checksum,status) VALUES (?,?,?)', [name, checksum, 'running']);
      // DDL MySQL melakukan implicit commit. Status running sengaja dipertahankan jika gagal.
      for (const statement of sql.split(';').map((part) => part.trim()).filter(Boolean)) {
        await connection.query(statement);
      }
      await connection.execute("UPDATE schema_migrations SET status='applied',applied_at=UTC_TIMESTAMP(6) WHERE name=?", [name]);
    }
  } finally {
    await connection.query('SELECT RELEASE_LOCK(?)', [lockName]);
  }
}