import express from 'express'
import { pool } from '../db/pool.js'

const router = express.Router()

router.post('/', async (req, res) => {
  try {

    const { meta } = req.body

    if (!meta) {
      return res.status(400).json({
        error: 'meta is required'
      })
    }

    await pool.query(
      `select public.trial_feedback_submit($1::jsonb)`,
      [meta]
    )

    res.json({
      success: true
    })

  } catch (err) {
    console.error('TRIAL FEEDBACK ERROR:', err)

    res.status(500).json({
      error: 'internal error'
    })
  }
})

export default router