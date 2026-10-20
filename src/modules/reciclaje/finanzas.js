import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();

/*
GET
/api/reciclaje/finanzas
*/

router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const incluirAnuladas = req.query.incluir_anuladas === "true";

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_finanzas($1,$2)`,

            [

                companyId,

                incluirAnuladas

            ]

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
GET
/api/reciclaje/finanzas/:id
*/
router.get("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.obtener_finanza($1,$2)`,

            [

                companyId,

                id

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
POST
/api/reciclaje/finanzas
*/
router.post("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {

            tipo,

            origen_tipo,

            origen_id,

            fecha_vencimiento,

            tipo_cambio,

            importe_base,

            observaciones

        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.crear_finanza(
                $1,$2,$3,$4,$5,$6,$7,$8
             )`,

            [

                companyId,

                tipo,

                tipo_cambio,

                importe_base,

                origen_tipo,

                origen_id,

                fecha_vencimiento,

                observaciones

            ]

        );

        res.status(201).json(rows[0]);

    } catch (err) {

        console.error(err);

        res.status(500).json({

            error: err.message

        });

    }

});

/*
PUT
/api/reciclaje/finanzas/:id
*/
router.put("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const {

            tipo,

            origen_tipo,

            origen_id,

            fecha_vencimiento,

            tipo_cambio,

            importe_base,

            observaciones

        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.actualizar_finanza(
                $1,$2,$3,$4,$5,$6,$7,$8,$9
             )`,

            [

                companyId,

                id,

                tipo,

                tipo_cambio,

                importe_base,

                origen_tipo,

                origen_id,

                fecha_vencimiento,

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
PATCH
/api/reciclaje/finanzas/:id/anular
*/
router.patch("/:id/anular", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.anular_finanza($1,$2)`,

            [

                companyId,

                id

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
DELETE
/api/reciclaje/finanzas/:id
*/
router.delete("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        await pool.query(

            `SELECT reciclaje.eliminar_finanza($1,$2)`,

            [

                companyId,

                id

            ]

        );

        res.json({

            ok: true

        });

    } catch (err) {

        console.error(err);

        res.status(500).json({

            error: err.message

        });

    }

});

export default router;