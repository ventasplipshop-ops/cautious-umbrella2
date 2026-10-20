import { Router } from "express";
import sql from "../services/sql.js";
import { asyncHandler, command } from "../http.js";
import { prepareOperationCommand } from "../operation-command.js";
function actions(service,allowed){const x=Router();x.post("/",asyncHandler(async(q,r)=>{const c=command(q.body,allowed);r.json(await service(q.companyId,c.eventoId,c.accion,c.datos));}));return x;}
export const operaciones=Router();
operaciones.post("/",asyncHandler(async(q,r)=>{
  const c=prepareOperationCommand(q.body,q.get?.("idempotency-key"));
  r.set?.("X-Idempotency-Key",c.idempotencyKey);
  r.set?.("X-Evento-Id",c.eventoId);
  r.json(await sql.operacion(q.companyId,c.eventoId,c.accion,c.datos));
}));
export const dinero=actions(sql.dinero,["entrega","devolucion","justificacion_operacion","gasto","gasto_pendiente","cobro","pago","diferencia","ajuste","liquidacion_operacion","pago_fisico_operacion","vuelto_recibido"]);
export const inventario=actions(sql.inventarioAccion,["ajuste","transferencia","transformacion"]);
export const finanzas=actions(sql.finanzasAccion,["crear_obligacion","definir_plan_pago","modificar_plan_pago","anular_obligacion"]);
