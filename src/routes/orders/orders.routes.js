import express from 'express';
import jwt from 'jsonwebtoken';

import { pool } from '../../db/pool.js';
import { authMiddleware } from '../../middleware/auth.js';
import { orderAuth } from '../../middleware/orderAuth.js';

const router = express.Router();

/* =========================================================
   PUBLIC
========================================================= */

/**
 * POST /api/orders/public/create-link
 *
 * ADMIN genera link público
 */
router.post(
  '/public/create-link',
  authMiddleware,
  async (req, res) => {

    const { lead_id } = req.body;

    if (!lead_id) {
      return res.status(400).json({
        error: 'lead_id_required'
      });
    }

    const client = await pool.connect();

    try {

      const { rows } = await client.query(
        `
        select *
        from tenant.create_reserved_order(
          $1,
          $2,
          $3
        )
        `,
        [
          req.user.company_id,
          lead_id,
          req.user.user_id
        ]
      );

      const order = rows[0];

      const token = jwt.sign(
        {
          type: 'order_public',
          company_id: req.user.company_id,
          lead_id,
          created_by: req.user.user_id
        },
        process.env.ORDER_PUBLIC_SECRET,
        {
          expiresIn: '24h'
        }
      );

      res.json({
        order_id: order.id,
        token,
        url: `${process.env.FRONTEND_URL}/pedido/${token}`
      });

    } catch (err) {

      console.error('CREATE LINK ERROR:', err);

      res.status(500).json({
        error: 'internal_error',
        detail: err.message
      });

    } finally {
      client.release();
    }
  }
);

/**
 * POST /api/orders/public/:token/init
 */
router.post(
  '/public/:token/init',
  orderAuth,
  async (req, res) => {

    const client = await pool.connect();

    try {

      await client.query('BEGIN');

      const ctx = req.orderContext;

      const { rows } = await client.query(
        `
        select *
        from tenant.create_order_from_lead(
          $1,
          $2,
          $3
        )
        `,
        [
          ctx.company_id,
          ctx.lead_id,
          ctx.created_by
        ]
      );

      await client.query('COMMIT');

      res.json(rows[0]);

    } catch (err) {

      await client.query('ROLLBACK');

      console.error('INIT ORDER ERROR:', err);

      if (err.message === 'lead_not_found') {
        return res.status(404).json({
          error: 'lead_not_found'
        });
      }

      if (err.message === 'order_already_confirmed') {
        return res.status(409).json({
          error: 'order_already_confirmed'
        });
      }

      if (err.message === 'order_already_paid') {
        return res.status(409).json({
          error: 'order_already_paid'
        });
      }

      return res.status(500).json({
        error: 'internal_error',
        detail: err.message
      });

    } finally {
      client.release();
    }
  }
);

/**
 * POST /api/orders/public/:token/items
 */
router.post(
  '/public/:token/items',
  orderAuth,
  async (req, res) => {

    const {
      order_id,
      product_id,
      quantity
    } = req.body;

    if (!order_id || !product_id) {
      return res.status(400).json({
        error: 'invalid_payload'
      });
    }

    const client = await pool.connect();

    try {

      await client.query('BEGIN');

      const ctx = req.orderContext;

      const { rows } = await client.query(
        `
        select tenant.order_set_item(
          $1,
          $2,
          $3,
          $4
        ) as result
        `,
        [
          ctx.company_id,
          order_id,
          product_id,
          quantity
        ]
      );

      await client.query('COMMIT');

      res.json(rows[0].result);

    } catch (err) {

      await client.query('ROLLBACK');

      console.error('SET ITEM ERROR:', err);

      if (err.message.includes('insufficient_stock')) {
        return res.status(400).json({
          error: 'insufficient_stock'
        });
      }

      if (err.message.includes('order_not_available')) {
        return res.status(400).json({
          error: 'order_not_available'
        });
      }

      res.status(500).json({
        error: 'internal_error',
        detail: err.message
      });

    } finally {
      client.release();
    }
  }
);

/**
 * GET /api/orders/public/:token/products
 */
router.get(
  '/public/:token/products',
  orderAuth,
  async (req, res) => {

    try {

      const { company_id } = req.orderContext;

      const result = await pool.query(
        `
        select *
        from tenant.list_products_full($1, true)
        `,
        [company_id]
      );

      return res.json({
        products: result.rows
      });

    } catch (err) {

      console.error(err);

      return res.status(500).json({
        error: 'internal_error'
      });

    }

  }
);

/**
 * GET /api/orders/public/:token/order
 */
router.get(
  '/public/:token/order',
  orderAuth,
  async (req, res) => {

    try {

      const ctx = req.orderContext;

      const { rows } = await pool.query(
        `
        select tenant.get_public_order(
          $1,
          $2
        ) as data
        `,
        [
          ctx.company_id,
          ctx.lead_id
        ]
      );

      res.json(rows[0].data);

    } catch (err) {

      console.error('GET PUBLIC ORDER ERROR:', err);

      res.status(500).json({
        error: 'internal_error',
        detail: err.message
      });

    }

  }
);

/**
 * GET /api/orders/public/:token/:order_id
 */
router.get(
  '/public/:token/:order_id',
  orderAuth,
  async (req, res) => {

    try {

      const ctx = req.orderContext;

      const { rows } = await pool.query(
        `
        select tenant.get_order(
          $1,
          $2
        ) as data
        `,
        [
          ctx.company_id,
          req.params.order_id
        ]
      );

      res.json(rows[0].data);

    } catch (err) {

      console.error('GET ORDER ERROR:', err);

      res.status(500).json({
        error: 'internal_error'
      });
    }
  }
);

/* =========================================================
   ADMIN
========================================================= */

/**
 * GET /api/orders/admin
 */
router.get(
  '/admin',
  authMiddleware,
  async (req, res) => {

    try {

      const { rows } = await pool.query(
        `
        select tenant.list_orders($1) as data
        `,
        [req.user.company_id]
      );

      res.json(rows[0].data || []);

    } catch (err) {

      console.error('LIST ORDERS ERROR:', err);

      res.status(500).json({
        error: 'internal_error'
      });
    }
  }
);

/**
 * GET /api/orders/admin/:id
 */
router.get(
  '/admin/:id',
  authMiddleware,
  async (req, res) => {

    try {

      const { rows } = await pool.query(
        `
        select tenant.get_order(
          $1,
          $2
        ) as data
        `,
        [
          req.user.company_id,
          req.params.id
        ]
      );

      res.json(rows[0].data);

    } catch (err) {

      console.error('GET ADMIN ORDER ERROR:', err);

      res.status(500).json({
        error: 'internal_error'
      });
    }
  }
);

/**
 * POST /api/orders/admin/:id/confirm
 */
router.post(
  '/admin/:id/confirm',
  authMiddleware,
  async (req, res) => {

    const client = await pool.connect();

    try {

        await client.query('BEGIN');

        await client.query(
          `
          select
            set_config('app.company_id', $1::text, true),
            set_config('app.current_role', $2::text, true),
            set_config('app.user_id', $3::text, true)
          `,
          [
            req.user.company_id,
            req.user.role,
            req.user.user_id
          ]
        );

        await client.query(
          `
          select tenant.confirm_order(
            $1,
            $2,
            $3
          )
          `,
          [
            req.user.company_id,
            req.params.id,
            'transfer'
          ]
        );

      await client.query('COMMIT');

      res.json({
        success: true
      });

    } catch (err) {

      await client.query('ROLLBACK');

      console.error('CONFIRM ORDER ERROR:', err);

      res.status(500).json({
        error: 'internal_error',
        detail: err.message
      });

    } finally {
      client.release();
    }
  }
);

/**
 * POST /api/orders/admin/:id/cancel
 */
router.post(
  '/admin/:id/cancel',
  authMiddleware,
  async (req, res) => {

    const client = await pool.connect();

    try {

      await client.query('BEGIN');

      await client.query(
        `
        select tenant.cancel_order(
          $1,
          $2
        )
        `,
        [
          req.user.company_id,
          req.params.id
        ]
      );

      await client.query('COMMIT');

      res.json({
        success: true
      });

    } catch (err) {

      await client.query('ROLLBACK');

      console.error('CANCEL ORDER ERROR:', err);

      res.status(500).json({
        error: 'internal_error',
        detail: err.message
      });

    } finally {
      client.release();
    }
  }
);

export default router;