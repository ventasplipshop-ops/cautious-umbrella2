import express from 'express';
import { authMiddleware } from '../../middleware/auth.js';
import { pool } from '../../db/pool.js';
import XLSX from 'xlsx';

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

/**
 * GET /api/inventory/products/operator
 * Listar productos para operadores
 */
router.get('/products/operator', async (req, res) => {
  const onlyActive = req.query.active === 'true';

  try {
    const { rows } = await pool.query(
      `SELECT * FROM tenant.list_products_operator_full($1, $2)`,
      [
        req.user.company_id,
        onlyActive
      ]
    );

    res.json(rows);
  } catch (err) {
    console.error('LIST PRODUCTS OPERATOR ERROR:', err);
    res.status(500).json({
      error: 'internal_error',
      detail: err.message
    });
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


import { enqueueAIJob } from '../../services_POS/aiBackground.js';

router.post('/products/import', async (req, res) => {
  try {
    const { fileBase64 } = req.body;

    if (!fileBase64) {
      return res.status(400).json({ error: 'file required' });
    }

    const buffer = Buffer.from(fileBase64, 'base64');
    const workbook = XLSX.read(buffer, { type: 'buffer' });
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(sheet);

    const client = await pool.connect();

    let created = 0;
    const productsCreated = [];

    try {
      await client.query('BEGIN');

      await client.query(
        `select set_config('app.company_id', $1, true)`,
        [req.user.company_id]
      );

      await client.query(
        `select set_config('app.current_role', $1, true)`,
        [req.user.role]
      );

      for (const row of rows) {
        const { rows: result } = await client.query(
          `select * from tenant.create_product($1, $2, $3, $4)`,
          [
            req.user.company_id,
            row.name,
            Number(row.price || 0),
            Number(row.stock || 0),
          ]
        );

        const product = result[0];

        productsCreated.push(product); // 🔥 guardamos
        created++;
      }

      await client.query('COMMIT');

    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    /* =========================================
       🔥 ENCOLAR FUERA DE LA TRANSACCIÓN
    ========================================= */
    for (const product of productsCreated) {
      enqueueAIJob(product, req.user.company_id);
    }

    res.json({
      success: true,
      created,
      queued: productsCreated.length
    });

  } catch (err) {
    console.error('IMPORT PRODUCTS ERROR:', err);

    res.status(500).json({
      error: 'internal_error',
      detail: err.message
    });
  }
});


router.get('/products/export', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `
      SELECT
        name,
        price,
        stock
      FROM tenant.list_products($1, false)
      `,
      [req.user.company_id]
    );

    const worksheet = XLSX.utils.json_to_sheet(rows);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Inventario');

    const buffer = XLSX.write(workbook, {
      type: 'buffer',
      bookType: 'xlsx',
    });

    res.setHeader(
      'Content-Disposition',
      'attachment; filename=inventario.xlsx'
    );
    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    );

    res.send(buffer);
  } catch (err) {
    console.error('EXPORT PRODUCTS ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

export default router;
