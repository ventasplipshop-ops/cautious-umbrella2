import express from 'express';
import { authMiddleware } from '../middleware/auth.js';

const router = express.Router();

router.get('/', authMiddleware, (req, res) => {
  res.json({
    user_id: req.user.user_id,
    company_id: req.user.company_id,
    role: req.user.role
  });
});

export default router;
