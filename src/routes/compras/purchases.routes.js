import express from 'express';
import { authMiddleware } from '../../middleware/auth.js';
import { pool } from '../../db/pool.js';

const router = express.Router();
router.use(authMiddleware);

/**
 * POST /api/purchases
 */
router.post('/', async (req, res) => {
  const { items, supplier, notes } = req.body;

  if (!items || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({
      error: 'invalid_payload',
      detail: 'items required'
    });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // 🔥 contexto (igual que en otros módulos tuyos)
    await client.query(
      `select set_config('app.company_id', $1, true)`,
      [req.user.company_id]
    );

    await client.query(
      `select set_config('app.current_role', $1, true)`,
      [req.user.role]
    );

    await client.query(
      `select set_config('app.user_id', $1, true)`,
      [req.user.user_id]
    );

    // 🔥 llamada a la función
    const { rows } = await client.query(
      `select tenant.register_purchase($1, $2, $3, $4) as id`,
      [
        req.user.company_id,
        JSON.stringify(items),
        supplier || null,
        notes || null
      ]
    );

    await client.query('COMMIT');

    res.status(201).json({
      id: rows[0].id
    });

  } catch (err) {
    await client.query('ROLLBACK');

    console.error('REGISTER PURCHASE ERROR:', err);

    res.status(500).json({
      error: 'internal_error',
      detail: err.message
    });
  } finally {
    client.release();
  }
});

export default router;