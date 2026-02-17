import { pool } from '../db/pool.js';

export async function dbContextMiddleware(req, res, next) {
  if (!req.user?.company_id) {
    return next();
  }

  try {
    await pool.query(
      `select set_config('app.company_id', $1, true)`,
      [req.user.company_id]
    );
    next();
  } catch (err) {
    console.error('DB CONTEXT ERROR:', err);
    res.status(500).json({ error: 'db context error' });
  }
}
