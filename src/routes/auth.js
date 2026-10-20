import express from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { pool } from '../db/pool.js';

const router = express.Router();

router.post('/login', async (req, res) => {
  const { company_slug, email, password } = req.body;

  if (!company_slug || !email || !password) {
    return res.status(400).json({ error: 'missing credentials' });
  }

  try {
    // 🔐 LOGIN VIA FUNCIÓN SEGURA
    const result = await pool.query(
      `select * from tenant.login_user($1, $2)`,
      [company_slug, email]
    );

    if (result.rowCount === 0) {
      return res.status(401).json({ error: 'invalid credentials' });
    }

    const user = result.rows[0];

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'invalid credentials' });
    }

    const token = jwt.sign(
      {
        user_id: user.user_id,
        company_id: user.company_id,
        role: user.tipo_usuario
      },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    res.json({
      token,
      user: {
        id: user.user_id,
        nombre: user.nombre,
        tipo_usuario: user.tipo_usuario
      }
    });
  } catch (err) {
    console.error('LOGIN ERROR FULL:', err);
    res.status(500).json({
      error: 'internal error',
      message: err.message
    });
  }
});

router.post('/login-universal', async (req, res) => {
  const { email, password, company_slug } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'email required' });
  }

  try {
    // 1️⃣ buscar empresas del usuario
    const { rows } = await pool.query(
      `select * from tenant.find_user_slugs($1)`,
      [email]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    // 2️⃣ UNA sola empresa → usarla directo
    if (rows.length === 1) {
      const slug = rows[0].slug;
      return await doLogin(slug, email, password, res);
    }

    // 3️⃣ múltiples → si no mandó slug → devolver lista
    if (!company_slug) {
      return res.json({
        requires_company: true,
        companies: rows.map(r => ({
          slug: r.slug,
          company_id: r.company_id
        }))
      });
    }

    // 4️⃣ validar slug
    const exists = rows.find(r => r.slug === company_slug);

    if (!exists) {
      return res.status(403).json({ error: 'invalid_company' });
    }

    // 5️⃣ login normal
    return await doLogin(company_slug, email, password, res);

  } catch (err) {
    console.error('LOGIN UNIVERSAL ERROR:', err);
    res.status(500).json({ error: 'internal error' });
  }
});

async function doLogin(company_slug, email, password, res) {
  if (!password) {
    return res.status(400).json({ error: 'password required' });
  }

  const result = await pool.query(
    `select * from tenant.login_user($1, $2)`,
    [company_slug, email]
  );

  if (result.rowCount === 0) {
    return res.status(401).json({ error: 'invalid credentials' });
  }

  const user = result.rows[0];

  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) {
    return res.status(401).json({ error: 'invalid credentials' });
  }

  const token = jwt.sign(
    {
      user_id: user.user_id,
      company_id: user.company_id,
      role: user.tipo_usuario
    },
    process.env.JWT_SECRET,
    { expiresIn: '8h' }
  );

  return res.json({
    token,
    user: {
      id: user.user_id,
      nombre: user.nombre,
      tipo_usuario: user.tipo_usuario
    }
  });
}

export default router;

