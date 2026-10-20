import express from 'express';
import jwt from 'jsonwebtoken';
import { pool } from '../db/pool.js';

const router = express.Router();

/**
 * POST /api/trial
 * Crea empresa demo + usuario admin + seed data
 * Devuelve token 30 minutos
 */
router.post('/', async (req, res) => {

  const client = await pool.connect();

  try {
    await client.query('begin');

    // 1️⃣ Crear empresa demo
    const { rows } = await client.query(
      `select * from tenant.bootstrap_demo_company()`
    );

    if (!rows.length) {
      throw new Error('bootstrap_demo_company failed');
    }

    const { company_id, user_id } = rows[0];

    // 2️⃣ Ejecutar seed manual (por si no usás trigger)
    await client.query(
      `select tenant.seed_demo_company($1)`,
      [company_id]
    );

    // 3️⃣ Generar token trial
    const token = jwt.sign(
      {
        user_id,
        company_id,
        role: 'admin',
        trial: true
      },
      process.env.JWT_SECRET,
      { expiresIn: '30m' }
    );

    await client.query('commit');

    return res.status(201).json({
    token,
    user: {
        id: user_id,
        nombre: 'Demo',
        tipo_usuario: 'admin',
        trial: true
    },
    trial: {
        expires_in_seconds: 30 * 60
    }
    });

  } catch (err) {

    await client.query('rollback');

    if (err.message?.includes('demo_capacity_reached')) {
        return res.status(503).json({
        error: 'trial_unavailable',
        detail: 'En este momento no hay capacidad para nuevos trials'
        });
    }

    console.error('TRIAL ERROR:', err);

    return res.status(500).json({
        error: 'trial_creation_failed',
        detail: err.message
    });
    }
  finally {
    client.release();
  }
});

export default router;