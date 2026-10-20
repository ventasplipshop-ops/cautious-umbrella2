import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();


/*
GET
/api/reciclaje/caja/movimientos
*/
router.get("/movimientos", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_movimientos_caja($1)`,

            [companyId]

        );

        res.json(rows);

    } catch (err) {

        console.error(err);

        res.status(500).json({

            error: err.message

        });

    }

});


/*
============================================================
DEVOLUCIÓN DE DINERO DEL TRANSPORTISTA
============================================================

POST
/api/reciclaje/gastos/devolucion-transporte

Registra el dinero que el transportista devuelve a Caja
después de rendir compras y gastos.

A diferencia de un gasto, esto SÍ representa un movimiento
físico de dinero hacia Caja.

Ejemplo:

Entregado al transportista:   $100
Compras justificadas:          $55
Gastos justificados:            $4
-----------------------------------
Devolución a Caja:             $41

Genera:

tipo     = 'entrada'
concepto = 'devolucion_transporte'
*/
router.post("/devolucion-transporte", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {

            monto,

            moneda = "ARS",

            tipo_cambio = 1,

            transportista_id,

            transportista_nombre = null,

            origen_tipo = "grupo_operaciones",

            origen_id = null,

            referencia = null,

            observaciones = null

        } = req.body;


        const montoNumero = Number(monto);

        if (
            !Number.isFinite(montoNumero)
            || montoNumero <= 0
        ) {

            return res.status(400).json({
                error: "El monto devuelto debe ser mayor a cero."
            });

        }


        if (!transportista_id) {

            return res.status(400).json({
                error: "Debe indicar el transportista."
            });

        }


        const monedaNormalizada =
            String(moneda || "ARS")
                .trim()
                .toUpperCase();


        let tipoCambioNumero;


        // ------------------------------------------------------------
        // // ARS SIEMPRE TIENE TIPO DE CAMBIO 1
        // ------------------------------------------------------------

        if (monedaNormalizada === "ARS") {

            tipoCambioNumero = 1;

        } else {

            tipoCambioNumero =
                Number(tipo_cambio);


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
                montoNumero
                * tipoCambioNumero
                * 100
            ) / 100;


        // ------------------------------------------------------------
        // // REGISTRAR ENTRADA REAL A CAJA
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

                referencia,

                concepto,

                descripcion,

                origen_tipo,

                origen_id,

                responsable_tipo,

                responsable_id,

                responsable_nombre,

                observaciones

            )

            VALUES (

                $1,

                'entrada',

                $2,

                $3,

                $4,

                $5,

                $6,

                'devolucion_transporte',

                'Devolución de dinero por rendición del transportista',

                $7,

                $8,

                'transportista',

                $9,

                $10,

                $11

            )

            RETURNING *
            `,

            [
                companyId,

                montoNumero,

                monedaNormalizada,

                tipoCambioNumero,

                montoArs,

                referencia,

                origen_tipo,

                origen_id,

                transportista_id,

                transportista_nombre,

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

});

/*
============================================================
REGISTRAR VENTA
============================================================

POST
/api/reciclaje/caja/ventas
*/

router.post("/ventas", async (req, res) => {

    try {

        const companyId = COMPANY_ID;


        const {
            deposito_id,
            materiales,
            monto
        } = req.body;


        if (!deposito_id) {

            return res.status(400).json({
                error: "deposito_id es obligatorio."
            });

        }


        if (
            !Array.isArray(materiales) ||
            materiales.length === 0
        ) {

            return res.status(400).json({
                error: "Debe indicar al menos un material."
            });

        }


        if (
            monto === undefined ||
            monto === null ||
            Number(monto) <= 0
        ) {

            return res.status(400).json({
                error: "El monto debe ser mayor que cero."
            });

        }


        const { rows } = await pool.query(

            `
            SELECT reciclaje.registrar_venta(
                $1,
                $2::jsonb
            ) AS resultado
            `,

            [
                companyId,
                req.body
            ]

        );


        res.status(201).json(
            rows[0]?.resultado
        );

    } catch (err) {

        console.error(
            "ERROR REGISTRAR VENTA:",
            err
        );


        res.status(400).json({
            error: err.message
        });

    }

});

export default router;