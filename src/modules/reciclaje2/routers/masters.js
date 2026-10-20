import { Router } from "express";
import sql from "../services/sql.js";
import { asyncHandler, boolean, httpError, integer, optional, requireObject, requireUuid } from "../http.js";
import { prepareMasterData } from "../internal-codes.js";
import { preparePrecioSocioUpsert } from "../price-command.js";
function master(entity,list){const x=Router();x.get("/",asyncHandler(async(q,r)=>r.json(await list(q))));x.post("/",asyncHandler(async(q,r)=>r.status(201).json(await sql.configuracion(q.companyId,entity,null,prepareMasterData(entity,null,requireObject(q.body))))));x.put("/:id",asyncHandler(async(q,r)=>{const id=requireUuid(q.params.id,"id");r.json(await sql.configuracion(q.companyId,entity,id,prepareMasterData(entity,id,requireObject(q.body))));}));x.delete("/:id",()=>{throw httpError(405,"V2 no permite borrado físico; envíe el registro completo con activo=false.");});return x;}
export const socios=master("socio",q=>sql.socios(q.companyId,optional(q.query.busqueda),boolean(q.query.activo,true),boolean(q.query.compra),boolean(q.query.venta),integer(q.query.limit,50),integer(q.query.offset,0)));
export const transportistas=master("transportista",q=>sql.transportistas(q.companyId,optional(q.query.busqueda),boolean(q.query.activo,true),integer(q.query.limit,50),integer(q.query.offset,0)));
export const materiales=master("material",q=>sql.materiales(q.companyId,optional(q.query.busqueda),optional(q.query.socio_id),boolean(q.query.activo,true),boolean(q.query.compuesto),integer(q.query.limit,50),integer(q.query.offset,0)));
export const depositos=master("deposito",q=>sql.depositos(q.companyId,optional(q.query.busqueda),boolean(q.query.activo,true)));
export const precios=Router();
precios.get("/socio/:socio_id",asyncHandler(async(q,r)=>r.json(await sql.precios(q.companyId,requireUuid(q.params.socio_id,"socio_id"),optional(q.query.material_id)))));
precios.get("/socio/:socio_id/material/:material_id",asyncHandler(async(q,r)=>r.json(await sql.precios(q.companyId,requireUuid(q.params.socio_id,"socio_id"),requireUuid(q.params.material_id,"material_id")))));
precios.put("/socio/:socio_id/material/:material_id",asyncHandler(async(q,r)=>{const datos=preparePrecioSocioUpsert(q.body,q.params.socio_id,q.params.material_id);r.json(await sql.configuracion(q.companyId,"precio_socio",null,datos));}));
