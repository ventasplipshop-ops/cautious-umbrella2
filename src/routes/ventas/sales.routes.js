import express from 'express';
import { authMiddleware } from '../../middleware/auth.js';
import { pool } from '../../db/pool.js';

const router = express.Router();
router.use(authMiddleware);

/**
 * Crear venta
 */
router.post('/', async (req, res) => {
  const { items, payment_method } = req.body;

  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'items required' });
  }

  try {
    const { rows } = await pool.query(
      `select tenant.create_sale($1, $2, $3) as sale_id`,
      [
        req.user.company_id,
        JSON.stringify(items),
        payment_method || null
      ]
    );

    res.status(201).json({ sale_id: rows[0].sale_id });
  } catch (err) {
      console.error('CREATE SALE ERROR:', err);

      // errores de negocio desde SQL
      if (err.message?.includes('insufficient stock')) {
        return res.status(400).json({
          error: 'insufficient_stock',
          detail: err.message
        });
      }

      if (err.message?.includes('product not found')) {
        return res.status(404).json({
          error: 'product_not_found',
          detail: err.message
        });
      }

      res.status(500).json({
        error: 'internal_error',
        detail: err.message
      });
    }

});
//ver todas las ventas

/**
 * Listar todas las ventas con items
 */
router.get('/', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `select tenant.list_sales($1) as sales`,
      [req.user.company_id]
    );

    res.json(rows[0].sales || []);
  } catch (err) {
    console.error('LIST SALES ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});


// ver venta


router.get('/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `select tenant.get_sale($1, $2) as sale`,
      [req.user.company_id, req.params.id]
    );

    if (!rows[0]?.sale) {
      return res.status(404).json({ error: 'sale not found' });
    }

    res.json(rows[0].sale);
  } catch (err) {
    console.error('GET SALE ERROR:', err);
    res.status(500).json({ error: 'internal error' });
  }
});



// devolucion

router.post('/:id/return', async (req, res) => {
  const { reason } = req.body;

  try {
    const { rows } = await pool.query(
      `select tenant.return_sale($1, $2, $3) as return_id`,
      [req.user.company_id, req.params.id, reason || null]
    );

    res.json({ return_id: rows[0].return_id });
  } catch (err) {
    console.error('RETURN SALE ERROR:', err);
    res.status(500).json({ error: 'internal error' });
  }
});

export default router;
