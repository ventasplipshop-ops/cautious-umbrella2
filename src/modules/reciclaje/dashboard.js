import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();


/*
============================================================
DASHBOARD MENSUAL
============================================================

GET
/api/reciclaje/dashboard/mensual

Opcional:
?anio=2026
?mes=8

Si no se indican:
- anio = año actual
- mes = mes actual
*/

router.get("/mensual", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const ahora = new Date();

        const anio =
            req.query.anio !== undefined
                ? Number(req.query.anio)
                : ahora.getFullYear();

        const mes =
            req.query.mes !== undefined
                ? Number(req.query.mes)
                : ahora.getMonth() + 1;


        // ------------------------------------------------------------
        // VALIDACIONES
        // ------------------------------------------------------------

        if (
            !Number.isInteger(anio) ||
            anio < 2000 ||
            anio > 2100
        ) {

            return res.status(400).json({
                error: "El año indicado no es válido."
            });

        }


        if (
            !Number.isInteger(mes) ||
            mes < 1 ||
            mes > 12
        ) {

            return res.status(400).json({
                error: "El mes debe estar entre 1 y 12."
            });

        }


        // ------------------------------------------------------------
        // DASHBOARD
        // ------------------------------------------------------------

        const { rows } = await pool.query(

            `
            SELECT reciclaje.dashboard_mensual(
                $1,
                $2,
                $3
            ) AS dashboard
            `,

            [
                companyId,
                anio,
                mes
            ]

        );


        res.json(
            rows[0]?.dashboard ?? {}
        );


    } catch (err) {

        console.error(
            "ERROR DASHBOARD MENSUAL:",
            err
        );


        res.status(500).json({
            error: err.message
        });

    }

});


export default router;