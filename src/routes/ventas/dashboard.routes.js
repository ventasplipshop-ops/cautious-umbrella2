import express from 'express';
import { authMiddleware } from '../../middleware/auth.js';
import { pool } from '../../db/pool.js';

const router = express.Router();
router.use(authMiddleware);


//RESULTDO DE dashboard_admin {
//   "today": {
//     "total_sales": 60000,
//     "transactions": 2,
//     "total_items": 4
//   },
//   "top_products": [
//     {
//       "product_id": "...",
//       "name": "Producto test",
//       "quantity": 4
//     }
//   ],
//   "low_stock": [
//     {
//       "product_id": "...",
//       "name": "Producto X",
//       "stock": 2
//     }
//   ]
// }



router.get('/', async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('begin');

    await client.query(
      `select set_config('app.current_role', $1, true)`,
      [req.user.role]
    );

    const { rows } = await client.query(
      `select tenant.dashboard_admin($1) as data`,
      [req.user.company_id]
    );

    await client.query('commit');

    res.json(rows[0].data);

  } catch (err) {
    await client.query('rollback');

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('DASHBOARD ERROR:', err);
    res.status(500).json({ error: 'internal_error' });

  } finally {
    client.release();
  }
});

router.get('/cash-closing', async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Establecer el contexto de seguridad
    await client.query(
      `SELECT set_config('app.company_id', $1, true)`,
      [req.user.company_id]
    );

    await client.query(
      `SELECT set_config('app.current_role', $1, true)`,
      [req.user.role]
    );

    await client.query(
      `SELECT set_config('app.user_id', $1, true)`,
      [req.user.user_id]
    );

    const { rows } = await client.query(
      `SELECT tenant.cash_closing_report($1) AS report`,
      [req.user.company_id]
    );

    await client.query('COMMIT');

    res.json(rows[0].report || []);
  } catch (error) {
    await client.query('ROLLBACK');

    if (error.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('CASH CLOSING ERROR:', error);
    res.status(500).json({
      error: 'internal_error',
      detail: error.message,
    });
  } finally {
    client.release();
  }
});



export default router;
