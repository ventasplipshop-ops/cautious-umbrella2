import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();

/*
GET
/api/reciclaje/precios/socio/:socio_id/material/:material_id

Devuelve:
- precio_base
- precio_mayorista
- precio_socio
- ultimo_precio
- ultimo_precio_fecha
*/
router.get(
    "/socio/:socio_id/material/:material_id",
    async (req, res) => {

        try {

            const companyId = COMPANY_ID;

            const {
                socio_id,
                material_id
            } = req.params;

            const { rows } = await pool.query(

                `SELECT *
                 FROM reciclaje.obtener_precios_material_socio(
                    $1,
                    $2,
                    $3
                 )`,

                [
                    companyId,
                    socio_id,
                    material_id
                ]

            );

            if (rows.length === 0) {

                return res.status(404).json({
                    error: "Material no encontrado."
                });

            }

            res.json(rows[0]);

        } catch (err) {

            console.error(err);

            res.status(500).json({
                error: err.message
            });

        }

    }
);

/*
PUT
/api/reciclaje/precios/socio/:socio_id/material/:material_id

Guarda o actualiza el precio preferencial del socio.

Body:
{
    "precio": 470,
    "observaciones": "Precio negociado"
}
*/
router.put(
    "/socio/:socio_id/material/:material_id",
    async (req, res) => {

        try {

            const companyId = COMPANY_ID;

            const {
                socio_id,
                material_id
            } = req.params;

            const {
                precio,
                observaciones
            } = req.body;

            // -----------------------------
            // Validación básica
            // -----------------------------

            if (
                precio === undefined ||
                precio === null ||
                precio === ""
            ) {
                return res.status(400).json({
                    error: "El precio es obligatorio."
                });
            }

            const precioNumero = Number(precio);

            if (
                !Number.isFinite(precioNumero) ||
                precioNumero < 0
            ) {
                return res.status(400).json({
                    error: "El precio debe ser un número válido."
                });
            }

            // -----------------------------
            // Guardar precio socio
            // -----------------------------

            const { rows } = await pool.query(

                `SELECT *
                 FROM reciclaje.guardar_precio_socio(
                    $1,
                    $2,
                    $3,
                    $4,
                    $5
                 )`,

                [
                    companyId,
                    socio_id,
                    material_id,
                    precioNumero,
                    observaciones ?? null
                ]

            );

            res.json({
                ok: true,
                precio_socio: rows[0]
            });

        } catch (err) {

            console.error("ERROR guardar precio socio:", err);

            res.status(500).json({
                error: err.message
            });

        }

    }
);

export default router;