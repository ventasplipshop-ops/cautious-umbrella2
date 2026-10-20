import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { pool } from '../db/pool.js';

const router = express.Router();

/**
 * POST /api/bootstrap/company
 *
 * Crea:
 *  - una empresa
 *  - un usuario admin
 * Devuelve:
 *  - token JWT admin
 *
 * Seguridad:
 *  - SECURITY DEFINER en DB
 *  - clave bootstrap en ENV
 */
router.post('/company', async (req, res) => {
  const { company, admin } = req.body;

  // ===============================
  // VALIDACIÓN BÁSICA
  // ===============================
  if (
    !company?.name ||
    !company?.slug ||
    !admin?.email ||
    !admin?.password
  ) {
    return res.status(400).json({
      error: 'invalid payload',
      detail: 'company.name, company.slug, admin.email y admin.password son obligatorios'
    });
  }

  if (!process.env.BOOTSTRAP_KEY) {
    return res.status(500).json({
      error: 'bootstrap misconfigured',
      detail: 'BOOTSTRAP_KEY no está definida en el entorno'
    });
  }

  const client = await pool.connect();
  console.log('BOOTSTRAP PAYLOAD:', {
    company,
    admin,
    envKey: !!process.env.BOOTSTRAP_KEY
  });
  try {
    await client.query('BEGIN');

    // ===============================
    // SETEAR CLAVE DE BOOTSTRAP (GUC)
    // ===============================
    await client.query(
      'select set_config($1, $2, true)',
      ['app.bootstrap_key', process.env.BOOTSTRAP_KEY]
    );

    // ===============================
    // HASH PASSWORD ADMIN
    // ===============================
    const passwordHash = await bcrypt.hash(admin.password, 10);

    // ===============================
    // EJECUTAR FUNCIÓN SEGURA
    // ===============================
    const { rows } = await client.query(
      `
      select * from tenant.bootstrap_company(
        $1, $2, $3, $4, $5, $6
      )
      `,
      [
        process.env.BOOTSTRAP_KEY,
        company.name,
        company.slug,
        admin.email,
        passwordHash,
        admin.nombre || 'Admin'
      ]
    );

    if (!rows.length) {
      throw new Error('bootstrap function returned no rows');
    }

    const { company_id, user_id } = rows[0];

    // ===============================
    // GENERAR TOKEN ADMIN
    // ===============================
    const token = jwt.sign(
      {
        user_id,
        company_id,
        role: 'admin'
      },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    await client.query('COMMIT');

    // ===============================
    // RESPUESTA FINAL
    // ===============================
    return res.status(201).json({
      token,
      company: {
        id: company_id,
        name: company.name,
        slug: company.slug
      },
      user: {
        id: user_id,
        email: admin.email,
        nombre: admin.nombre || 'Admin',
        role: 'admin'
      }
    });

  } catch (err) {
    await client.query('ROLLBACK');

    console.error('❌ BOOTSTRAP ERROR');
    console.error(err);

    // ===============================
    // ERRORES CONTROLADOS
    // ===============================
    if (err.message === 'invalid bootstrap key') {
      return res.status(403).json({
        error: 'forbidden',
        detail: 'bootstrap key inválida'
      });
    }

    if (err.code === '23505') {
      return res.status(409).json({
        error: 'conflict',
        detail: 'empresa o usuario ya existe'
      });
    }

    return res.status(500).json({
      error: 'internal error',
      code: err.code,
      message: err.message
    });

  } finally {
    client.release();
  }
});



// =====================================================
// LISTAR EMPRESAS
// GET /api/bootstrap/companies
// =====================================================
router.get('/companies', async (req, res) => {
  try {

    const { rows } = await pool.query(`
      select *
      from tenant.list_companies()
    `);

    return res.json(rows);

  } catch (err) {

    console.error(err);

    return res.status(500).json({
      error: 'internal_error',
      message: err.message
    });

  }
});


// =====================================================
// DETALLE EMPRESA
// GET /api/bootstrap/company/:id
// =====================================================
router.get('/company/:id', async (req, res) => {
  try {

    const { id } = req.params;

    const { rows } = await pool.query(
      `
      select tenant.get_company($1) as company
      `,
      [id]
    );

    return res.json(
      rows[0]?.company || null
    );

  } catch (err) {

    console.error(err);

    return res.status(500).json({
      error: 'internal_error',
      message: err.message
    });

  }
});


// =====================================================
// DESACTIVAR EMPRESA
// POST /api/bootstrap/company/:id/disable
// =====================================================
router.post('/company/:id/disable', async (req, res) => {
  try {

    const { id } = req.params;

    await pool.query(
      `
      select tenant.disable_company($1)
      `,
      [id]
    );

    return res.json({
      success: true
    });

  } catch (err) {

    console.error(err);

    return res.status(500).json({
      error: 'internal_error',
      message: err.message
    });

  }
});




export default router;
