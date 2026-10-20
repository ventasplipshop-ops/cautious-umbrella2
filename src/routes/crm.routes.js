import express from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { pool } from '../db/pool.js';
import XLSX from 'xlsx';

const router = express.Router();
router.use(authMiddleware);

/* =========================================================
   Helper: contexto seguro + transacción
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
   📊 BOARD (KPI + estructura base)
========================================================= */
router.get('/board', async (req, res) => {
  try {
    const data = await withContext(req, async (client) => {

      const { rows } = await client.query(
        `select tenant.crm_list_board($1,$2,$3,$4) as data`,
        [
          req.user.company_id,
          req.query.assigned_to || null,
          req.user.role,
          req.user.user_id
        ]
      );

      return rows[0].data;
    });

    res.json(data);

  } catch (err) {
    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('CRM BOARD ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

/* =========================================================
   ➕ CREATE LEAD (usa función DB)
========================================================= */
router.post('/leads', async (req, res) => {
  const { title, stage_id, assigned_to, contacts } = req.body;

  if (!title || !stage_id) {
    return res.status(400).json({
      error: 'invalid_payload',
      detail: 'title and stage_id are required'
    });
  }

  try {

    const lead = await withContext(req, async (client) => {

      // 🔍 pipeline
      const { rows: stageRows } = await client.query(
        `
        select pipeline_id
        from tenant.crm_stages
        where id = $1
          and company_id = $2
        `,
        [stage_id, req.user.company_id]
      );

      if (!stageRows.length) {
        throw new Error('stage_not_found');
      }

      const pipeline_id = stageRows[0].pipeline_id;

      // 🔥 crear lead
      const { rows } = await client.query(
        `select * from tenant.crm_create_lead($1,$2,$3,$4,$5)`,
        [
          req.user.company_id,
          pipeline_id,
          stage_id,
          title,
          assigned_to || null
        ]
      );

      const lead = rows[0];

      // 🔥 crear contactos (DENTRO de la transacción)
      if (contacts && Array.isArray(contacts)) {
        for (const c of contacts) {
          await client.query(
            `select tenant.crm_add_contact($1,$2,$3,$4,$5,$6)`,
            [
              req.user.company_id,
              lead.id,
              c.type,
              c.value,
              c.label || null,
              c.is_primary || false
            ]
          );
        }
      }

      return lead;
    });

    res.status(201).json(lead);

  } catch (err) {

    if (err.message === 'stage_not_found') {
      return res.status(404).json({ error: 'stage_not_found' });
    }

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('CREATE LEAD ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

/* =========================================================
   🔄 MOVE LEAD (usa función DB)
========================================================= */
router.patch('/leads/:id/move', async (req, res) => {
  const { stage_id } = req.body;

  if (!stage_id) {
    return res.status(400).json({ error: 'stage_id required' });
  }

  try {
    const lead = await withContext(req, async (client) => {

      const { rows } = await client.query(
        `select * from tenant.crm_move_lead($1,$2,$3)`,
        [
          req.user.company_id,
          req.params.id,
          stage_id
        ]
      );

      return rows[0];
    });

    res.json(lead);

  } catch (err) {

    if (err.message === 'lead not found') {
      return res.status(404).json({ error: 'lead_not_found' });
    }

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('MOVE LEAD ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

/* =========================================================
   📝 ADD ACTIVITY (usa función DB)
========================================================= */
router.post('/leads/:id/activities', async (req, res) => {
  const { note } = req.body;

  if (!note) {
    return res.status(400).json({ error: 'note required' });
  }

  try {
    const activity = await withContext(req, async (client) => {

      const { rows } = await client.query(
        `select * from tenant.crm_add_activity($1,$2,$3)`,
        [
          req.user.company_id,
          req.params.id,
          note
        ]
      );

      return rows[0];
    });

    res.status(201).json(activity);

  } catch (err) {
    console.error('CREATE ACTIVITY ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});


// contactos
router.get('/leads/:id/contacts', async (req, res) => {
  try {

    const contacts = await withContext(req, async (client) => {

      const { rows } = await client.query(
        `select tenant.crm_list_contacts($1,$2) as data`,
        [
          req.user.company_id,
          req.params.id
        ]
      );

      return rows[0].data;
    });

    res.json(contacts);

  } catch (err) {
    console.error('LIST CONTACTS ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

router.post('/leads/:id/contacts', async (req, res) => {
  const { type, value, label, is_primary } = req.body;

  if (!type || !value) {
    return res.status(400).json({
      error: 'invalid_payload',
      detail: 'type and value are required'
    });
  }

  try {

    const contact = await withContext(req, async (client) => {

      const { rows } = await client.query(
        `select * from tenant.crm_add_contact($1,$2,$3,$4,$5,$6)`,
        [
          req.user.company_id,
          req.params.id,
          type,
          value,
          label || null,
          is_primary || false
        ]
      );

      return rows[0];
    });

    res.status(201).json(contact);

  } catch (err) {
    console.error('ADD CONTACT ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

router.patch('/contacts/:id/primary', async (req, res) => {
  try {

    await withContext(req, async (client) => {

      await client.query(
        `select tenant.crm_set_primary_contact($1,$2)`,
        [
          req.user.company_id,
          req.params.id
        ]
      );
    });

    res.json({ ok: true });

  } catch (err) {
    console.error('SET PRIMARY ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});


router.post('/import', async (req, res) => {
  try {

    const { fileBase64 } = req.body;

    if (!fileBase64) {
      return res.status(400).json({ error: 'file required' });
    }

    const buffer = Buffer.from(fileBase64, 'base64');
    const workbook = XLSX.read(buffer, { type: 'buffer' });

    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(sheet);

    const result = await withContext(req, async (client) => {

      const created = [];

      // 🔥 obtener stage default UNA sola vez
      const { rows: stageRows } = await client.query(`
        select id, pipeline_id
        from tenant.crm_stages
        where company_id = $1
        order by position asc
        limit 1
      `, [req.user.company_id]);

      if (!stageRows.length) {
        throw new Error('no_stages');
      }

      const stage = stageRows[0];

      for (const row of rows) {

        const title = row.nombre || row.name || 'Sin nombre';

        // 🔍 detectar contactos dinámicamente
        const contacts = [];

        for (const key in row) {
          const value = row[key];
          if (!value) continue;

          const k = key.toLowerCase();

          if (k.includes('tel') || k.includes('phone') || k.includes('cel')) {
            contacts.push({ type: 'phone', value: String(value) });
          }

          if (k.includes('mail') || k.includes('email')) {
            contacts.push({ type: 'email', value: String(value) });
          }

          if (k.includes('insta')) {
            contacts.push({ type: 'instagram', value: String(value) });
          }
        }

        // 🔥 crear lead
        const { rows: leadRows } = await client.query(
          `select * from tenant.crm_create_lead($1,$2,$3,$4,$5)`,
          [
            req.user.company_id,
            stage.pipeline_id,
            stage.id,
            title,
            req.user.user_id
          ]
        );

        const lead = leadRows[0];

        // 🔥 insertar contactos
        let hasPrimary = {};

        for (const c of contacts) {

          const isPrimary = !hasPrimary[c.type];

          await client.query(
            `select tenant.crm_add_contact($1,$2,$3,$4,$5,$6)`,
            [
              req.user.company_id,
              lead.id,
              c.type,
              c.value,
              null,
              isPrimary
            ]
          );

          hasPrimary[c.type] = true;
        }

        created.push(lead.id);
      }

      return created;
    });

    res.json({
      success: true,
      created: result.length
    });

  } catch (err) {

    if (err.message === 'no_stages') {
      return res.status(400).json({ error: 'no_stages_configured' });
    }

    console.error('IMPORT ERROR:', err);
    res.status(500).json({ error: 'import_failed' });
  }
});


router.get('/leads/:id/activities', async (req, res) => {
  try {

    const data = await withContext(req, async (client) => {

      const { rows } = await client.query(
        `select tenant.crm_list_activities($1,$2,$3,$4) as data`,
        [
          req.user.company_id,
          req.params.id,
          req.user.role,
          req.user.user_id
        ]
      );

      return rows[0].data;
    });

    res.json(data);

  } catch (err) {

    if (err.message?.includes('forbidden')) {
      return res.status(403).json({ error: 'forbidden' });
    }

    console.error('LIST ACTIVITIES ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

router.patch('/stages/:id', async (req, res) => {
  const { name, position, is_closed } = req.body;

  try {

    const stage = await withContext(req, async (client) => {

      const { rows } = await client.query(
        `select * from tenant.crm_update_stage($1,$2,$3,$4,$5,$6)`,
        [
          req.user.company_id,
          req.params.id,
          name || null,
          position || null,
          is_closed ?? null,
          req.user.role
        ]
      );

      return rows[0];
    });

    res.json(stage);

  } catch (err) {

    if (err.message === 'forbidden') {
      return res.status(403).json({ error: 'forbidden' });
    }

    if (err.message === 'stage_not_found') {
      return res.status(404).json({ error: 'stage_not_found' });
    }

    console.error('UPDATE STAGE ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});


router.delete('/stages/:id', async (req, res) => {
  try {

    await withContext(req, async (client) => {

      await client.query(
        `select tenant.crm_delete_stage($1,$2,$3)`,
        [
          req.user.company_id,
          req.params.id,
          req.user.role
        ]
      );
    });

    res.json({ ok: true });

  } catch (err) {

    if (err.message === 'forbidden') {
      return res.status(403).json({ error: 'forbidden' });
    }

    if (err.message === 'stage_has_leads') {
      return res.status(400).json({ error: 'stage_has_leads' });
    }

    console.error('DELETE STAGE ERROR:', err);
    res.status(500).json({ error: 'internal_error' });
  }
});


export default router;