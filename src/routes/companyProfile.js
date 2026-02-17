import express from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { pool } from '../db/pool.js';

const router = express.Router();

/**
 * GET /api/company/profile
 */
router.get(
  '/',
  authMiddleware,
  async (req, res) => {
    try {
      const { rows } = await pool.query(
        'select * from tenant.get_company_profile($1)',
        [req.user.company_id]
      );

      if (!rows[0]) {
        return res.status(404).json({ error: 'profile not found' });
      }

      res.json(rows[0]);
    } catch (err) {
      console.error('GET company_profile error:', err);
      res.status(500).json({ error: 'internal error' });
    }
  }
);

/**
 * POST /api/company/profile
 */
router.post(
  '/',
  authMiddleware,
  async (req, res) => {
    try {
      const { rows } = await pool.query(
        'select * from tenant.create_company_profile($1, $2)',
        [req.user.company_id, req.body]
      );

      res.status(201).json(rows[0]);
    } catch (err) {
      console.error('CREATE company_profile error:', err);

      if (err.code === '23505') {
        return res.status(409).json({ error: 'profile already exists' });
      }

      res.status(500).json({ error: 'internal error' });
    }
  }
);

/**
 * PUT /api/company/profile
 */
router.put(
  '/',
  authMiddleware,
  async (req, res) => {
    try {
      const stage =
        req.query.stage !== undefined
          ? Number(req.query.stage)
          : null;

      const completed =
        req.query.completed !== undefined
          ? req.query.completed === 'true'
          : null;

      const { rows } = await pool.query(
        `
        select *
        from tenant.update_company_profile(
          $1,
          $2,
          $3,
          $4
        )
        `,
        [
          req.user.company_id,
          req.body,       // p_profile_data (jsonb)
          stage,          // p_profile_stage
          completed       // p_profile_completed
        ]
      );

      res.json(rows[0]);
    } catch (err) {
      console.error('UPDATE company_profile error:', err);

      if (err.code === 'P0002') {
        return res.status(404).json({ error: 'profile not found' });
      }

      res.status(500).json({ error: 'internal error' });
    }
  }
);




export default router;
