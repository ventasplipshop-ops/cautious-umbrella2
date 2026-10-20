import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();

/*
GET
/api/reciclaje/recepciones
*/
router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_recepciones($1)`,

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
GET
/api/reciclaje/recepciones/:id
*/
router.get("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.obtener_recepcion($1,$2)`,

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
/api/reciclaje/recepciones
*/
router.post("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {

            orden_compra_id,

            recibido_por,

            observaciones

        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.crear_recepcion(
                $1,
                $2,
                $3,
                $4
             )`,

            [

                companyId,

                orden_compra_id,

                recibido_por,

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
/api/reciclaje/recepciones/:id
*/
router.put("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.actualizar_recepcion(
                $1,
                $2,
                $3::jsonb
             )`,

            [

                companyId,

                id,

                req.body

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
/api/reciclaje/recepciones/:id/confirmar
*/
router.post("/:id/confirmar", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.confirmar_recepcion(
                $1,
                $2
             )`,

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
/api/reciclaje/recepciones/:id/cancelar
*/
router.post("/:id/cancelar", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.cancelar_recepcion(
                $1,
                $2
             )`,

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

export default router;