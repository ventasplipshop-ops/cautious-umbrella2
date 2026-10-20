import express from 'express';
import cors from 'cors';
import 'dotenv/config';
import { pool } from './db/pool.js';
// import usersRouter from './routes/users.js';
import authRouter from './routes/auth.js';
import meRouter from './routes/me.js';
import bootstrapRouter from './routes/bootstrap.js';
import companyProfileRouter from './routes/companyProfile.js';
import productsRouter from './routes/products.js';

import inventoryRoutes from './routes/ventas/inventory.routes.js';
import salesRoutes from './routes/ventas/sales.routes.js';
import dashboardRoutes from './routes/ventas/dashboard.routes.js';
import trialRouter from './routes/trial.js';
import crmRoutes from './routes/crm.routes.js';
import trialRoutes from './routes/trial.routes.js'
import usersRouter from './routes/users.js';
import aiRoutes from './routes/ai.routes.js';
import { startAIWorker } from './services_POS/aiBackground.js';
import purchasesRoutes from './routes/compras/purchases.routes.js';
import ordersRoutes from './routes/orders/orders.routes.js';
import reciclajeRouter from "./modules/reciclaje/routes.js";
import reciclaje2Router from "./modules/reciclaje2/routes.js";
import constructoraRouter from "./modules/constructora/routes.js";





const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/health', async (req, res) => {
  try {
    const result = await pool.query('select 1 as ok');
    res.json({ status: 'ok', db: result.rows[0].ok });
  } catch (err) {
    console.error(err);
    res.status(500).json({ status: 'error', message: 'db unavailable' });
  }
});



app.use('/api/auth', authRouter);
app.use('/api/trial', trialRouter);
app.use('/api/me', meRouter);
app.use('/api/bootstrap', bootstrapRouter);
app.use('/api/company/profile', companyProfileRouter);
app.use('/api/products', productsRouter);
app.use('/api/trial-feedback', trialRoutes);
app.use('/api/users', usersRouter);



// ventas

    app.use('/api/inventory', inventoryRoutes);
    app.use('/api/sales', salesRoutes);
    app.use('/api/dashboard', dashboardRoutes);
    app.use('/api/crm', crmRoutes);
    app.use('/api/ai', aiRoutes);
    app.use('/api/purchases', purchasesRoutes);
    app.use('/api/orders', ordersRoutes);
    startAIWorker();

// ======================================================
// STORAGE LOCAL
// ======================================================

app.use(
    "/storage",
    express.static("/home/edwin/storage")
);


//locura reciclaje

    app.use("/api/reciclaje", reciclajeRouter);
    app.use("/api/reciclaje2", reciclaje2Router);

//locura de pagina constructora con imagenes

  app.use("/api/constructora", constructoraRouter);
    

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 API running on http://localhost:${PORT}`);
});

