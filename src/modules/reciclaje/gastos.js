import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();


/*
============================================================
FUNCIÓN INTERNA
============================================================

Todos los endpoints de gastos terminan usando exactamente
la misma lógica.

IMPORTANTE:

tipo = 'gasto'

Un gasto NO representa una nueva salida física de Caja.

Ejemplo:

Se entregaron $100 al transportista.
Gastó $4 en combustible.

Caja ya registró la salida de $100.

Este movimiento "gasto" solamente documenta que $4
de esos $100 fueron utilizados en combustible.
*/
async function registrarGasto(req, res, concepto) {

    try {

        const companyId = COMPANY_ID;

        const {

            monto,

            moneda = "ARS",

            tipo_cambio = 1,

            descripcion = null,

            origen_tipo = null,

            origen_id = null,

            transportista_id = null,

            transportista_nombre = null,

            comprobante_url = null,

            observaciones = null

        } = req.body;


        // ------------------------------------------------------------
        // // VALIDACIONES
        // ------------------------------------------------------------

        const montoNumero = Number(monto);

        if (!Number.isFinite(montoNumero) || montoNumero <= 0) {

            return res.status(400).json({
                error: "El monto del gasto debe ser mayor a cero."
            });

        }


        const monedaNormalizada =
            String(moneda || "ARS")
                .trim()
                .toUpperCase();


        let tipoCambioNumero;

        if (monedaNormalizada === "ARS") {

            tipoCambioNumero = 1;

        } else {

            tipoCambioNumero = Number(tipo_cambio);

            if (
                !Number.isFinite(tipoCambioNumero)
                || tipoCambioNumero <= 0
            ) {

                return res.status(400).json({
                    error: "Debe indicar un tipo de cambio mayor a cero."
                });

            }

        }


        const montoArs =
            Math.round(
                montoNumero * tipoCambioNumero * 100
            ) / 100;


        // ------------------------------------------------------------
        // // INSERT
        // ------------------------------------------------------------

        const { rows } = await pool.query(

            `
            INSERT INTO reciclaje.movimientos_caja (

                company_id,

                tipo,

                monto,

                moneda,

                tipo_cambio,

                monto_ars,

                concepto,

                descripcion,

                origen_tipo,

                origen_id,

                responsable_tipo,

                responsable_id,

                responsable_nombre,

                comprobante_url,

                observaciones

            )

            VALUES (

                $1,

                'gasto',

                $2,

                $3,

                $4,

                $5,

                $6,

                $7,

                $8,

                $9,

                CASE
                    WHEN $10::uuid IS NOT NULL
                    THEN 'transportista'
                    ELSE NULL
                END,

                $10,

                $11,

                $12,

                $13

            )

            RETURNING *
            `,

            [
                companyId,

                montoNumero,

                monedaNormalizada,

                tipoCambioNumero,

                montoArs,

                concepto,

                descripcion,

                origen_tipo,

                origen_id,

                transportista_id,

                transportista_nombre,

                comprobante_url,

                observaciones
            ]

        );


        res.json(rows[0]);

    } catch (err) {

        console.error(err);

        res.status(500).json({
            error: err.message
        });

    }

}


/*
============================================================
COMBUSTIBLE
============================================================

POST
/api/reciclaje/gastos/combustible
*/
router.post("/combustible", (req, res) => {

    return registrarGasto(
        req,
        res,
        "combustible"
    );

});


/*
============================================================
PEAJE
============================================================

POST
/api/reciclaje/gastos/peaje
*/
router.post("/peaje", (req, res) => {

    return registrarGasto(
        req,
        res,
        "peaje"
    );

});


/*
============================================================
COMIDA
============================================================

POST
/api/reciclaje/gastos/comida
*/
router.post("/comida", (req, res) => {

    return registrarGasto(
        req,
        res,
        "comida"
    );

});


/*
============================================================
ESTACIONAMIENTO
============================================================

POST
/api/reciclaje/gastos/estacionamiento
*/
router.post("/estacionamiento", (req, res) => {

    return registrarGasto(
        req,
        res,
        "estacionamiento"
    );

});


/*
============================================================
REPARACIÓN
============================================================

POST
/api/reciclaje/gastos/reparacion
*/
router.post("/reparacion", (req, res) => {

    return registrarGasto(
        req,
        res,
        "reparacion"
    );

});


/*
============================================================
CARGA / DESCARGA
============================================================

POST
/api/reciclaje/gastos/carga-descarga
*/
router.post("/carga-descarga", (req, res) => {

    return registrarGasto(
        req,
        res,
        "carga_descarga"
    );

});


/*
============================================================
OTROS
============================================================

POST
/api/reciclaje/gastos/otros

En este caso el frontend puede enviar:

{
    "concepto": "Lavado del camión",
    ...
}

Si no manda concepto, queda simplemente "otros".
*/
router.post("/otros", (req, res) => {

    const concepto =
        typeof req.body.concepto === "string"
        && req.body.concepto.trim()
            ? req.body.concepto.trim()
            : "otros";

    return registrarGasto(
        req,
        res,
        concepto
    );

});


export default router;