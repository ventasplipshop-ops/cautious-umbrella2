import { requireObject, requireUuid } from "./http.js";

export function preparePrecioSocioUpsert(body,socioId,materialId){
  const input=requireObject(body);
  return {
    socio_id:requireUuid(socioId,"socio_id"),
    material_id:requireUuid(materialId,"material_id"),
    precio:input.precio,
    moneda_id:requireUuid(input.moneda_id,"moneda_id"),
    ...(input.observaciones===undefined?{}:{observaciones:input.observaciones}),
  };
}
