import crypto from "crypto";

const PREFIX = {
  socio: "SOC",
  transportista: "TRA",
  deposito: "DEP",
  material: "MAT",
};

// Identificador técnico opaco. La unicidad definitiva continúa protegida por SQL.
export function generateInternalCode(entity, now = new Date(), randomBytes = crypto.randomBytes) {
  const prefix = PREFIX[entity];
  if (!prefix) throw new Error(`Entidad sin código interno: ${entity}`);
  const date = now.toISOString().slice(0, 10).replaceAll("-", "");
  const entropy = randomBytes(6).toString("hex").toUpperCase();
  return `${prefix}-${date}-${entropy}`;
}

export function prepareMasterData(entity, id, input) {
  const data = { ...input };
  if (id == null) data.codigo = generateInternalCode(entity);
  return data;
}
