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

export default router;

