import express from 'express';
import { authMiddleware } from '../../middleware/auth.js';
import { pool } from '../../db/pool.js';

const router = express.Router();
router.use(authMiddleware);
// -- tenant.list_inventory:
// --   - id               uuid        -> ID del producto
// --   - name             text        -> Nombre actual
// --   - price            numeric     -> Precio actual
// --   - stock            integer     -> Stock actual
// --   - image_url        text        -> URL pública en R2
// --   - is_active        boolean     -> Estado lógico del producto
// --   - updated_at       timestamptz -> Última modificación del producto
// --   - last_movement    timestamptz -> Fecha del último movimiento de stock
// --   - movements_count  integer     -> Cantidad total de movimientos registrados

router.get('/products', async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('begin');

    await client.query(
      `select set_config('app.current_role', $1, true)`,
      [req.user.role]
    );

    const { rows } = await client.query(
      `select tenant.list_inventory($1) as data`,
      [req.user.company_id]
    );

    await client.query('commit');

    res.json(rows[0].data);

  } catch (err) {
    await client.query('rollback');

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('INVENTORY LIST ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  } finally {
    client.release();
  }
});


router.get('/movements/:product_id', async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('begin');

    await client.query(
      `select set_config('app.current_role', $1, true)`,
      [req.user.role]
    );

    const { rows } = await client.query(
      `select tenant.list_stock_movements($1, $2) as data`,
      [req.user.company_id, req.params.product_id]
    );

    await client.query('commit');

    res.json(rows[0].data);

  } catch (err) {

    await client.query('rollback');

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('MOVEMENTS ERROR:', err);
    res.status(500).json({ error: 'internal_error' });

  } finally {
    client.release();
  }
});




export default router;
