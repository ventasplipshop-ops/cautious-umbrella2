import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";


const router = Router();

/*
GET
/api/reciclaje/depositos
*/
router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_depositos($1)`,

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
/api/reciclaje/depositos/:id
*/
router.get("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.obtener_deposito($1,$2)`,

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
/api/reciclaje/depositos
*/
router.post("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {

            nombre,

            direccion

        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.crear_deposito(
                $1,$2,$3
             )`,

            [

                companyId,

                nombre,

                direccion

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
/api/reciclaje/depositos/:id
*/
router.put("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const {

            nombre,

            direccion

        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.actualizar_deposito(
                $1,$2,$3,$4
             )`,

            [

                companyId,

                id,

                nombre,

                direccion

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
/api/reciclaje/depositos/:id
*/
router.delete("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        await pool.query(

            `SELECT reciclaje.eliminar_deposito($1,$2)`,

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
