import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();

/*
GET
/api/reciclaje/transportistas
*/
router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_transportistas($1)`,

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
/api/reciclaje/transportistas/:id
*/
router.get("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.obtener_transportista($1,$2)`,

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
/api/reciclaje/transportistas
*/
router.post("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {

            nombre,

            telefono,

            placa

        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.crear_transportista(
                $1,$2,$3,$4
             )`,

            [

                companyId,

                nombre,

                telefono,

                placa

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
/api/reciclaje/transportistas/:id
*/
router.put("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const {

            nombre,

            telefono,

            placa

        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.actualizar_transportista(
                $1,$2,$3,$4,$5
             )`,

            [

                companyId,

                id,

                nombre,

                telefono,

                placa

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
/api/reciclaje/transportistas/:id
*/
router.delete("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        await pool.query(

            `SELECT reciclaje.eliminar_transportista($1,$2)`,

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
