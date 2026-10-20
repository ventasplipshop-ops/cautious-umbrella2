import { Router } from "express";

import authRouter from "./auth.js";
import bootstrapRouter from "./bootstrap.js";
import sociosRouter from "./socios.js";
import materialesRouter from "./materiales.js";
import depositosRouter from "./depositos.js";
import transportistasRouter from "./transportistas.js";
import ordenesCompraRouter from "./ordenes_compra.js";
import recepcionesRouter from "./recepciones.js";
import finanzasRouter from "./finanzas.js";
import preciosRouter from "./precios.routes.js";
import storageRouter from "./storage.js";
import inventarioRouter from "./inventario.js";
import comprasRapidasRouter from "./compras_rapidas.js";
import operacionesRouter from "./operaciones.js";
import cajaRouter from "./caja.js";
import gastosRouter from "./gastos.js";
import dashboardRouter from "./dashboard.js";

const router = Router();

router.use("/auth", authRouter);

router.use("/bootstrap", bootstrapRouter);

router.use("/socios", sociosRouter);

router.use("/materiales", materialesRouter);

router.use("/depositos", depositosRouter);

router.use("/transportistas", transportistasRouter);

router.use("/ordenes-compra", ordenesCompraRouter);

router.use("/recepciones", recepcionesRouter);

router.use("/finanzas", finanzasRouter);

router.use("/precios", preciosRouter);

router.use("/storage", storageRouter);

router.use("/inventario", inventarioRouter);

router.use("/operaciones", operacionesRouter);

router.use("/compras-rapidas", comprasRapidasRouter);

router.use("/caja", cajaRouter);

router.use("/gastos", gastosRouter);

router.use("/dashboard", dashboardRouter);

export default router;