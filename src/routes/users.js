import express from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { pool } from '../db/pool.js';
import bcrypt from 'bcryptjs';

const router = express.Router();

router.use(authMiddleware);

/* =========================================================
   Helper: contexto + transacción
========================================================= */
async function withContext(req, callback) {
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

    const result = await callback(client);

    await client.query('COMMIT');
    return result;

  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/* =========================================================
   📋 LIST USERS (DB controla seguridad)
========================================================= */
router.get('/', async (req, res) => {
  try {
    const users = await withContext(req, async (client) => {

      const { rows } = await client.query(
        `select * from tenant.users_list()`
      );

      return rows;
    });

    res.json(users);

  } catch (err) {
    console.error('LIST USERS ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

/* =========================================================
   ➕ CREATE USER (vendedor simple)
========================================================= */
router.post('/', async (req, res) => {
  const { nombre, password, tipo_usuario } = req.body;

  if (!nombre) {
    return res.status(400).json({
      error: 'invalid_payload',
      detail: 'nombre required'
    });
  }

  if (!['operador', 'supervisor'].includes(tipo_usuario)) {
    return res.status(400).json({
      error: 'invalid_role'
    });
  }

  try {
    const user = await withContext(req, async (client) => {

      
      if (!password) {
        return res.status(400).json({ error: 'password_required' });
      }

      const passwordHash = await bcrypt.hash(password, 10);

      const { rows } = await client.query(
        `select * from tenant.create_user($1,$2,$3,$4)`,
        [
          req.user.company_id,
          nombre,
          tipo_usuario,
          passwordHash
        ]
      );

      return rows[0];
    });

    res.status(201).json(user);

  } catch (err) {

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('CREATE USER ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

/* =========================================================
   ✏️ UPDATE USER
========================================================= */
router.patch('/:id', async (req, res) => {
  const { nombre, password, tipo_usuario } = req.body;

  try {
    const user = await withContext(req, async (client) => {

      const passwordHash = password
        ? await bcrypt.hash(password, 10)
        : null;

      const { rows } = await client.query(
        `select * from tenant.users_update($1,$2,$3,$4)`,
        [
          req.params.id,
          nombre || null,
          passwordHash,
          tipo_usuario || null
        ]
      );

      return rows[0];
    });

    res.json(user);

  } catch (err) {

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    if (err.message?.includes('user_not_found')) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    console.error('UPDATE USER ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

export default router;