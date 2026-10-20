import { Router } from "express";
import sql from "./services/sql.js";
import { asyncHandler, integer, optional, requireObject, requireUuid } from "./http.js";
const router=Router();
router.get("/",asyncHandler(async(q,r)=>r.json(await sql.listarGastos(q.companyId,optional(q.query.fecha_desde),optional(q.query.fecha_hasta),optional(q.query.tipo_gasto_id),optional(q.query.estado),optional(q.query.origen),optional(q.query.moneda_id),integer(q.query.limit,100),integer(q.query.offset,0)))));
router.get("/presupuestos",asyncHandler(async(q,r)=>r.json(await sql.listarPresupuestosGastos(q.companyId,optional(q.query.periodo)))));
router.put("/presupuestos",asyncHandler(async(q,r)=>{const body=requireObject(q.body,"body");requireUuid(body.moneda_id,"moneda_id");r.json(await sql.upsertPresupuestoGasto(q.companyId,body.periodo,body.moneda_id,body.limite));}));
for(const alias of ["combustible","peaje","comida","estacionamiento","reparacion","carga-descarga","otros"]){router.post(`/${alias}`,asyncHandler(async(q,r)=>{const body=requireObject(q.body,"body");const evento=requireUuid(body.evento_id,"evento_id");const datos=requireObject(body.datos);requireUuid(datos.tipo_gasto_id,"datos.tipo_gasto_id");r.json(await sql.dinero(q.companyId,evento,"gasto",datos));}));}
export default router;
