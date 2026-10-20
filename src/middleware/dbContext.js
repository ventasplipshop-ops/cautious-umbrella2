import { pool } from '../db/pool.js';

export async function dbContextMiddleware(req, res, next) {
  if (!req.user?.company_id) {
    return next();
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    await client.query(
      `select set_config('app.company_id', $1, true)`,
      [req.user.company_id]
    );

    await client.query(
      `select set_config('app.current_role', $1, true)`,
      [req.user.role || 'admin']
    );

    await client.query(
      `select set_config('app.user_id', $1, true)`,
      [req.user.user_id]
    );

    // Guardar el cliente en la request
    req.db = client;

    // Liberar la conexión al finalizar la respuesta
    res.on('finish', async () => {
      try {
        await client.query('COMMIT');
      } catch {
        await client.query('ROLLBACK');
      }
      client.release();
    });

    next();
  } catch (err) {
    await client.query('ROLLBACK');
    client.release();
    console.error('DB CONTEXT ERROR:', err);
    res.status(500).json({ error: 'db context error' });
  }
}