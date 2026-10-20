import { enrichProductAI } from './aiProduct.js';
import { pool } from '../db/pool.js';

/* =========================================
   OPCIONAL (modo simple sin cola)
========================================= */
export async function enrichProductInBackground(product, company_id) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    await client.query(
      `select set_config('app.company_id', $1, true)`,
      [company_id]
    );

    const meta = await enrichProductAI({
      name: product.name,
      image_url: product.image_url
    });

    await client.query(
      `select * from tenant.update_product_metadata($1, $2, $3)`,
      [company_id, product.id, meta]
    );

    await client.query('COMMIT');

    console.log('✅ AI metadata updated:', product.id);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ AI BACKGROUND ERROR:', product.id, err.message);
  } finally {
    client.release();
  }
}

/* =========================================
   COLA (MODO PRODUCCIÓN)
========================================= */

export async function enqueueAIJob(product, company_id) {
  const client = await pool.connect();

  try {
    await client.query(`
      insert into tenant.ai_jobs (company_id, product_id)
      values ($1, $2)
    `, [company_id, product.id]);

    console.log('📥 AI job queued:', product.id);
  } catch (err) {
    console.error('❌ AI QUEUE ERROR:', err.message);
  } finally {
    client.release();
  }
}

/* =========================================
   WORKER
========================================= */

async function processAIJobs() {
  const client = await pool.connect();
  let job = null;

  try {
    await client.query('BEGIN');

    const { rows } = await client.query(`
      select *
      from tenant.ai_jobs
      where status = 'pending'
        and attempts < 3
      order by created_at asc
      limit 1
      for update skip locked
    `);

    if (!rows.length) {
      await client.query('COMMIT');
      return;
    }

    job = rows[0];

    await client.query(`
      update tenant.ai_jobs
      set status = 'processing',
          attempts = attempts + 1,
          updated_at = now()
      where id = $1
    `, [job.id]);

    await client.query('COMMIT');

    /* =========================================
       TODO el procesamiento usa EL MISMO CLIENT
    ========================================= */

    await client.query('BEGIN');

    await client.query(
      `select set_config('app.company_id', $1, true)`,
      [job.company_id]
    );

    const { rows: productRows } = await client.query(`
      select name, image_url
      from tenant.products
      where id = $1
    `, [job.product_id]);

    if (!productRows.length) {
      console.log('⚠️ PRODUCT NOT FOUND → deleting job');

      await client.query(`
        delete from tenant.ai_jobs
        where id = $1
      `, [job.id]);

      await client.query('COMMIT');
      return;
    }

    const product = productRows[0];

    await client.query('COMMIT');

    /* =========================================
       IA fuera de transacción
    ========================================= */
    const meta = await enrichProductAI({
      name: product.name,
      image_url: product.image_url
    });

    /* =========================================
       GUARDAR METADATA + LIMPIAR JOB
    ========================================= */
    await client.query('BEGIN');

    await client.query(
      `select set_config('app.company_id', $1, true)`,
      [job.company_id]
    );

    await client.query(
      `select * from tenant.update_product_metadata($1, $2, $3)`,
      [job.company_id, job.product_id, meta]
    );

    await client.query(`
      delete from tenant.ai_jobs
      where id = $1
    `, [job.id]);

    await client.query('COMMIT');

    console.log('✅ AI job done:', job.product_id);
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch {}

    console.error('❌ AI JOB ERROR:', err.message);

    if (job?.id) {
      try {
        await client.query('BEGIN');

        await client.query(`
          update tenant.ai_jobs
          set status = 'pending',
              error = $2,
              updated_at = now()
          where id = $1
        `, [job.id, err.message]);

        await client.query('COMMIT');
      } catch (updateErr) {
        try {
          await client.query('ROLLBACK');
        } catch {}
        console.error('❌ AI JOB STATUS UPDATE ERROR:', updateErr.message);
      }
    }
  } finally {
    client.release();
  }
}

/* =========================================
   START WORKER
========================================= */

export function startAIWorker() {
  console.log('🤖 AI Worker started...');
  setInterval(processAIJobs, 2000);
}