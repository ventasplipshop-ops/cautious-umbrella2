const STATUS = { "22023": 400, "22004": 400, "22P02": 400, "23503": 409, "23505": 409, "23514": 422, P0002: 404 };
export function notFound(req, res) { res.status(404).json({ error: "Recurso no encontrado." }); }
export function errorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);
  const status = err.status ?? STATUS[err.code] ?? 500;
  if (status === 500) console.error("reciclaje2:", err);
  res.status(status).json({ error: status === 500 ? "Error interno del servidor." : err.message, ...(err.code ? { code: err.code } : {}) });
}
