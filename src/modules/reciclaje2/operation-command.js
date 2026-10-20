import crypto from "crypto";
import { httpError, requireObject, requireUuid } from "./http.js";

export const OPERATION_ACTIONS = [
  "registrar_operacion", "actualizar_operacion", "preparar_salida",
  "agregar_a_salida", "cancelar_operacion", "eliminar_operacion",
  "cancelar_salida", "finalizar_salida", "finalizar_compra_directa",
];

function uuidFromKey(key, scope) {
  const bytes = crypto.createHash("sha256").update(`${scope}:${key}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
}

function mainEventId(clientKey) {
  if (!clientKey) return crypto.randomUUID();
  try { return requireUuid(clientKey, "Idempotency-Key"); }
  catch { return uuidFromKey(clientKey, "reciclaje2:operacion"); }
}

function validateCancellation(data, eventId) {
  requireUuid(data.operacion_id, "datos.operacion_id");
  if (typeof data.motivo !== "string" || data.motivo.trim() === "") throw httpError(400, "datos.motivo es obligatorio.");
  if (!("devolucion" in data)) return data;
  const refund = requireObject(data.devolucion, "datos.devolucion");
  if (refund.monto === undefined || refund.moneda_id === undefined || refund.tipo_cambio === undefined) {
    throw httpError(400, "La devolución requiere monto, moneda_id y tipo_cambio.");
  }
  requireUuid(refund.moneda_id, "datos.devolucion.moneda_id");
  return { ...data, devolucion: { ...refund, evento_id: uuidFromKey(eventId, "reciclaje2:cancelar_operacion:devolucion") } };
}

function validateSalidaCancellation(data, eventId) {
  requireUuid(data.salida_id, "datos.salida_id");
  if (typeof data.motivo !== "string" || data.motivo.trim() === "") throw httpError(400, "datos.motivo es obligatorio.");
  if (!("devolucion" in data)) return data;
  const refund = requireObject(data.devolucion, "datos.devolucion");
  if (refund.monto === undefined || refund.moneda_id === undefined || refund.tipo_cambio === undefined) {
    throw httpError(400, "La devolución requiere monto, moneda_id y tipo_cambio.");
  }
  requireUuid(refund.moneda_id, "datos.devolucion.moneda_id");
  return { ...data, devolucion: { ...refund, evento_id: uuidFromKey(eventId, "reciclaje2:cancelar_salida:devolucion") } };
}

function validateLogicalDeletion(data, eventId) {
  requireUuid(data.operacion_id, "datos.operacion_id");
  if (!("devolucion" in data)) return data;
  const refund = requireObject(data.devolucion, "datos.devolucion");
  if (refund.monto === undefined || refund.moneda_id === undefined || refund.tipo_cambio === undefined) {
    throw httpError(400, "La devolución requiere monto, moneda_id y tipo_cambio.");
  }
  requireUuid(refund.moneda_id, "datos.devolucion.moneda_id");
  return { ...data, devolucion: { ...refund, evento_id: uuidFromKey(eventId, "reciclaje2:eliminar_operacion:devolucion") } };
}

function withTechnicalEvent(value, eventId, scope, { requireRate = true } = {}) {
  const item = requireObject(value, scope);
  if (item.monto === undefined || item.moneda_id === undefined || (requireRate && item.tipo_cambio === undefined)) {
    throw httpError(400, `${scope} requiere monto, moneda_id${requireRate ? " y tipo_cambio" : ""}.`);
  }
  requireUuid(item.moneda_id, `${scope}.moneda_id`);
  return { ...item, evento_id: uuidFromKey(eventId, `reciclaje2:finalizar_salida:${scope}`) };
}

function prepareFinalization(data, eventId) {
  requireUuid(data.salida_id, "datos.salida_id");
  const physical = Array.isArray(data.fisico) ? data.fisico.map((raw, index) => {
    const item = requireObject(raw, `datos.fisico[${index}]`);
    if (item.operacion_id !== undefined && item.operacion_id !== null) {
      requireUuid(item.operacion_id, `datos.fisico[${index}].operacion_id`);
    }
    if (item.operacion_material_id !== undefined && item.operacion_material_id !== null) {
      requireUuid(item.operacion_material_id, `datos.fisico[${index}].operacion_material_id`);
      if (!item.operacion_id) throw httpError(400, `datos.fisico[${index}].operacion_id es obligatorio cuando se informa operacion_material_id.`);
    }
    return item;
  }) : [];
  const liquidations = Array.isArray(data.liquidaciones) ? data.liquidaciones : [];
  const prepared = {
    ...data,
    fisico: physical,
    liquidaciones: liquidations.map((raw, index) => {
      const item = requireObject(raw, `datos.liquidaciones[${index}]`);
      requireUuid(item.operacion_id, `datos.liquidaciones[${index}].operacion_id`);
      if (item.modelo_version !== undefined && Number(item.modelo_version) !== 2) {
        throw httpError(400, `datos.liquidaciones[${index}].modelo_version debe ser 2.`);
      }
      const stable = `${item.operacion_id}:${index}`;
      return {
        ...item,
        evento_id: uuidFromKey(eventId, `reciclaje2:finalizar_salida:liquidacion:${stable}`),
        pagos_fisicos: (Array.isArray(item.pagos_fisicos) ? item.pagos_fisicos : []).map((x, i) =>
          withTechnicalEvent(x, eventId, `pago:${stable}:${i}`)),
        vueltos: (Array.isArray(item.vueltos) ? item.vueltos : []).map((x, i) =>
          withTechnicalEvent(x, eventId, `vuelto:${stable}:${i}`)),
      };
    }),
    gastos: (Array.isArray(data.gastos) ? data.gastos : []).map((x, i) => withTechnicalEvent(x, eventId, `gasto:${i}`)),
  };
  if (Array.isArray(data.devoluciones)) prepared.devoluciones = data.devoluciones.map((x, i) => withTechnicalEvent(x, eventId, `devolucion:${i}`, { requireRate: false }));
  else if (data.devolucion) prepared.devolucion = withTechnicalEvent(data.devolucion, eventId, "devolucion:legacy", { requireRate: false });
  if (Array.isArray(data.diferencias)) prepared.diferencias = data.diferencias.map((x, i) => withTechnicalEvent(x, eventId, `diferencia:${i}`, { requireRate: false }));
  else if (data.diferencia) prepared.diferencia = withTechnicalEvent(data.diferencia, eventId, "diferencia:legacy", { requireRate: false });
  return prepared;
}

function prepareDirectPurchase(data, eventId) {
  requireUuid(data.operacion_id, "datos.operacion_id");
  if (!Array.isArray(data.fisico) || data.fisico.length === 0) {
    throw httpError(400, "datos.fisico requiere al menos una recepción.");
  }
  const physical = data.fisico.map((raw, index) => {
    const item = requireObject(raw, `datos.fisico[${index}]`);
    requireUuid(item.operacion_material_id, `datos.fisico[${index}].operacion_material_id`);
    requireUuid(item.material_id, `datos.fisico[${index}].material_id`);
    requireUuid(item.deposito_id, `datos.fisico[${index}].deposito_id`);
    if (item.tipo !== undefined && item.tipo !== "entrada") throw httpError(400, "La compra directa sólo admite entradas.");
    if (!Number.isFinite(Number(item.cantidad)) || Number(item.cantidad) <= 0) throw httpError(400, "La cantidad recibida debe ser positiva.");
    return { ...item, tipo: "entrada" };
  });
  let payment;
  if (data.pago !== undefined && data.pago !== null) {
    const item = requireObject(data.pago, "datos.pago");
    if (!Number.isFinite(Number(item.monto)) || Number(item.monto) <= 0) throw httpError(400, "datos.pago.monto debe ser positivo.");
    requireUuid(item.moneda_id, "datos.pago.moneda_id");
    if (!Number.isFinite(Number(item.tipo_cambio)) || Number(item.tipo_cambio) <= 0) throw httpError(400, "datos.pago.tipo_cambio debe ser positivo.");
    const humanPayment = { ...item };
    delete humanPayment.evento_id;
    delete humanPayment.origen_fondos;
    delete humanPayment.grupo_dinero_id;
    delete humanPayment.grupo_transporte_id;
    payment = {
      ...humanPayment,
      origen_fondos: "caja",
      evento_id: uuidFromKey(eventId, "reciclaje2:finalizar_compra_directa:pago"),
    };
  }
  const contract = { ...data };
  delete contract.liquidacion_evento_id;
  delete contract.movimiento_grupo_id;
  return {
    ...contract,
    fisico: physical,
    ...(payment ? { pago: payment } : {}),
    liquidacion_evento_id: uuidFromKey(eventId, "reciclaje2:finalizar_compra_directa:liquidacion"),
  };
}

export function prepareOperationCommand(body, headerKey) {
  requireObject(body, "body");
  if (!OPERATION_ACTIONS.includes(body.accion)) throw httpError(400, "acción no admitida.");
  let data = requireObject(body.datos);
  const eventId = mainEventId(headerKey || body.evento_id);
  if (body.accion === "cancelar_operacion") data = validateCancellation(data, eventId);
  if (body.accion === "cancelar_salida") data = validateSalidaCancellation(data, eventId);
  if (body.accion === "eliminar_operacion") data = validateLogicalDeletion(data, eventId);
  if (body.accion === "finalizar_salida") data = prepareFinalization(data, eventId);
  if (body.accion === "finalizar_compra_directa") data = prepareDirectPurchase(data, eventId);
  return { eventoId: eventId, accion: body.accion, datos: data, idempotencyKey: eventId };
}
