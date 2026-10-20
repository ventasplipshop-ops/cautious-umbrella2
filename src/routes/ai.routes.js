import express from 'express';
import { askPlipi } from '../bot_ia/ia_out.js';

const router = express.Router();

router.post('/chat', async (req, res) => {
  const { message, context } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'message required' });
  }

  try {
    const result = await askPlipi(message, context);

    res.json(result);

  } catch (err) {
    console.error('AI ROUTE ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

export default router;