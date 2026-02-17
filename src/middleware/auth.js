import jwt from 'jsonwebtoken';
import { pool } from '../db/pool.js';

export async function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'missing token' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const payload = jwt.verify(
      token,
      process.env.JWT_SECRET || 'dev-secret'
    );

    req.user = {
      user_id: payload.user_id,
      company_id: payload.company_id,
      role: payload.role
    };

    // 🔥 IMPORTANTE: Pasar contexto a PostgreSQL
    await pool.query(
      `select set_config('app.current_role', $1, true)`,
      [payload.role]
    );

    next();
  } catch (err) {
    return res.status(401).json({ error: 'invalid token' });
  }
}
