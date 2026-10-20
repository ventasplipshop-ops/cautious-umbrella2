const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
export const optional = (v) => v === undefined || v === "" ? null : v;
export function integer(v, fallback = null) { if (v === undefined || v === "") return fallback; const n = Number(v); if (!Number.isInteger(n)) throw httpError(400, "Parámetro entero inválido."); return n; }
export function boolean(v, fallback = null) { if (v === undefined || v === "") return fallback; if (v === true || v === "true") return true; if (v === false || v === "false") return false; throw httpError(400, "Parámetro booleano inválido."); }
export function requireUuid(v, field) { if (!UUID_RE.test(String(v ?? ""))) throw httpError(400, `${field} debe ser un UUID válido.`); return v; }
export function requireObject(v, field = "datos") { if (!v || typeof v !== "object" || Array.isArray(v)) throw httpError(400, `${field} debe ser un objeto.`); return v; }
export function command(body, actions) { requireObject(body, "body"); const eventoId = requireUuid(body.evento_id, "evento_id"); if (!actions.includes(body.accion)) throw httpError(400, "acción no admitida."); return { eventoId, accion: body.accion, datos: requireObject(body.datos) }; }
export function httpError(status, message) { const error = new Error(message); error.status = status; return error; }
