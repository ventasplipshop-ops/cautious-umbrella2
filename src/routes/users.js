// import express from 'express';
// import bcrypt from 'bcryptjs';
// import { authMiddleware } from '../middleware/auth.js';
// import { withCompanyContext } from '../db/withCompanyContext.js';

// const router = express.Router();

// router.post(
//   '/',
//   authMiddleware,
//   async (req, res) => {
//     const { email, password, nombre, apellido, tipo_usuario } = req.body;

//     if (!email || !password) {
//       return res.status(400).json({ error: 'email and password required' });
//     }

//     try {
//       const SALT_ROUNDS = 10;
//       const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

//       const result = await withCompanyContext(req, async (client) => {
//         const r = await client.query(
//           `
//           insert into tenant.users
//             (company_id, email, password, nombre, apellido, tipo_usuario)
//           values
//             (current_setting('app.current_company_id')::uuid, $1, $2, $3, $4, $5)
//           returning id
//           `,
//           [email, passwordHash, nombre, apellido, tipo_usuario]
//         );

//         return r.rows[0];
//       });

//       res.status(201).json({ user_id: result.id });
//     } catch (err) {
//       console.error('❌ ERROR creating user');
//       console.error(err.message);

//       if (err.code === '23505') {
//         return res.status(409).json({ error: 'user already exists in company' });
//       }

//       res.status(500).json({ error: 'internal error', detail: err.message });
//     }
//   }
// );

// export default router;
