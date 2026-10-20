import express from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { pool } from '../db/pool.js';
import { PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { r2 } from "../lib/r2.js";
import crypto from "crypto";
import { enqueueAIJob } from '../services_POS/aiBackground.js';


const router = express.Router();
router.use(authMiddleware);


/**
 * POST /api/products
 * Crear producto (mínimo)
 */
router.post('/', async (req, res) => {
  const { name, price, stock } = req.body;

  try {
    const { name, price, stock, metadata } = req.body;

  const { rows } = await pool.query(
    `
    select * from tenant.create_product(
      $1::uuid,
      $2::text,
      $3::numeric,
      $4::integer,
      $5::jsonb
    )
    `,
    [
      req.user.company_id,
      name,
      price,
      stock ?? 0,
      metadata ?? {}
    ]
  );

    const product = rows[0];

    // 🔥 DISPARO EN SEGUNDO PLANO (NO BLOQUEA)
    enqueueAIJob(product, req.user.company_id);

    // 🔥 RESPUESTA INMEDIATA
    res.status(201).json(product);

  } catch (err) {
    console.error('CREATE PRODUCT ERROR:', err);
    res.status(500).json({ error: 'internal error' });
  }
});

/** 
 * GET /api/products
 * Listar productos
 */
router.get('/', async (req, res) => {
  const onlyActive = req.query.active === 'true';
  const client = await pool.connect();

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

    await client.query(
      `select set_config('app.user_id', $1, true)`,
      [req.user.user_id]
    );

    const { rows } = await client.query(
      `select * from tenant.list_products($1, $2)`,
      [
        req.user.company_id,
        onlyActive
      ]
    );

    await client.query('COMMIT');
    res.json(rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('LIST PRODUCTS ERROR:', err);
    res.status(500).json({
      error: 'internal_error',
      detail: err.message
    });
  } finally {
    client.release();
  }
});

/**
 * GET /api/products/:id
 * Obtener producto completo (incluye metadata)
 */
router.get('/:id',  async (req, res) => {
  try {
    const { rows } = await pool.query(
      `select * from tenant.get_product($1, $2)`,
      [
        req.user.company_id,
        req.params.id
      ]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'product not found' });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error('GET PRODUCT ERROR:', err);
    res.status(500).json({ error: 'internal error' });
  }
});

/**
 * PUT /api/products/:id/image
 * Setear imagen (URL ya subida a R2)
 */
router.put('/:id/image',  async (req, res) => {
  const { image_url } = req.body;

  if (!image_url) {
    return res.status(400).json({
      error: 'invalid payload',
      detail: 'image_url es obligatorio'
    });
  }

  try {
    const { rows } = await pool.query(
      `select * from tenant.set_product_image($1, $2, $3)`,
      [
        req.user.company_id,
        req.params.id,
        image_url
      ]
    );

    res.json(rows[0]);
  } catch (err) {
    console.error('SET PRODUCT IMAGE ERROR:', err);

    if (err.message === 'product not found') {
      return res.status(404).json({ error: 'product not found' });
    }

    res.status(500).json({ error: 'internal error' });
  }
});

/**
 * PUT /api/products/:id/metadata
 * Merge de metadata (JSONB)
 */
router.put('/:id/metadata',  async (req, res) => {
  try {
    const { rows } = await pool.query(
      `select * from tenant.update_product_metadata($1, $2, $3)`,
      [
        req.user.company_id,
        req.params.id,
        req.body
      ]
    );

    res.json(rows[0]);
  } catch (err) {
    console.error('UPDATE PRODUCT METADATA ERROR:', err);

    if (err.message === 'metadata not found') {
      return res.status(404).json({ error: 'metadata not found' });
    }

    res.status(500).json({ error: 'internal error' });
  }
});



router.put('/:id/adjust', async (req, res) => {
  const { quantity, reason } = req.body;

  if (quantity === undefined) {
    return res.status(400).json({
      error: 'quantity required'
    });
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
      [req.user.role]
    );

    await client.query(
      `select set_config('app.user_id', $1, true)`,
      [req.user.user_id]
    );

    await client.query(
      `select tenant.adjust_stock($1,$2,$3,$4)`,
      [
        req.user.company_id,
        req.params.id,
        Number(quantity),
        reason || 'purchase'
      ]
    );

    await client.query('COMMIT');

    res.json({ ok: true });

  } catch (err) {

    await client.query('ROLLBACK');

    console.error('ADJUST STOCK ERROR FULL:', err);

    res.status(500).json({
      error: err.message,
      code: err.code,
      detail: err.detail
    });

  } finally {
    client.release();
  }
});

router.patch('/:id', async (req, res) => {
  const { name, price, stock } = req.body;

  const client = await pool.connect();

  try {
    await client.query('begin');

    // 🔥 Setear contexto en la MISMA conexión
    await client.query(
      `select set_config('app.current_role', $1, true)`,
      [req.user.role]
    );

    const { rows } = await client.query(
      `select * from tenant.update_product_admin($1, $2, $3, $4, $5)`,
      [
        req.user.company_id,
        req.params.id,
        name ?? null,
        price ?? null,
        stock ?? null
      ]
    );

    await client.query('commit');
    res.json(rows[0]);

  } catch (err) {
    await client.query('rollback');

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    if (err.message?.includes('product not found')) {
      return res.status(404).json({ error: 'product_not_found' });
    }

    if (err.message?.includes('stock cannot be negative')) {
      return res.status(400).json({ error: 'invalid_stock' });
    }

    console.error('UPDATE PRODUCT ADMIN ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  } finally {
    client.release();
  }
});


router.post("/:id/upload-url", async (req, res) => {
  const { content_type } = req.body;

  if (!content_type) {
    return res.status(400).json({ error: "content_type required" });
  }

  try {
    const extension = content_type.split("/")[1] || "jpg";
    const imageId = crypto.randomUUID();

    const key = `companies/${req.user.company_id}/products/${req.params.id}/${imageId}.${extension}`;

    const command = new PutObjectCommand({
      Bucket: process.env.R2_BUCKET,
      Key: key,
      ContentType: content_type,
    });


    const uploadUrl = await getSignedUrl(r2, command, {
      expiresIn: 300, // 1 minuto
    });

    const publicUrl = `${process.env.R2_PUBLIC_URL}/${key}`;

    res.json({
      upload_url: uploadUrl,
      public_url: publicUrl,
      key
    });

  } catch (err) {
    console.error("SIGNED URL ERROR:", err);
    res.status(500).json({ error: "internal_error", message: err.message});
  }
});



export default router;
