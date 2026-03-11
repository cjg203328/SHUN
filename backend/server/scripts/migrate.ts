import { readFileSync } from 'fs';
import { resolve } from 'path';
import { Pool } from 'pg';

function getSchemaPath(): string {
  return resolve(__dirname, '../../db/schema_v1.sql');
}

async function run(): Promise<void> {
  const checkOnly = process.argv.includes('--check');
  const schemaPath = getSchemaPath();
  const sql = readFileSync(schemaPath, 'utf-8');

  const pool = new Pool({
    host: process.env.DB_HOST ?? '127.0.0.1',
    port: Number(process.env.DB_PORT ?? 5432),
    database: process.env.DB_NAME ?? 'sunliao',
    user: process.env.DB_USER ?? 'sunliao',
    password: process.env.DB_PASSWORD ?? 'sunliao_dev',
  });

  try {
    if (checkOnly) {
      const result = await pool.query('SELECT 1 as ok');
      if (result.rowCount === 1) {
        // eslint-disable-next-line no-console
        console.log(
          `[db:migrate:check] database connection ok, schema file loaded: ${schemaPath}`,
        );
      }
      return;
    }

    await pool.query('BEGIN');
    await pool.query(sql);
    await pool.query('COMMIT');
    // eslint-disable-next-line no-console
    console.log(`[db:migrate] success: ${schemaPath}`);
  } catch (error) {
    await pool.query('ROLLBACK');
    // eslint-disable-next-line no-console
    console.error('[db:migrate] failed', error);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

void run();

