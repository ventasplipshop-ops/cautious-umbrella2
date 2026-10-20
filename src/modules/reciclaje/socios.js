import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();

/*
GET
/api/reciclaje/socios
*/
router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_socios($1)`,

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
/api/reciclaje/socios/:id
*/
router.get("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.obtener_socio($1,$2)`,

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
/api/reciclaje/socios
*/
router.post("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {
            nombre,
            documento,
            telefono,
            direccion,
            observaciones,
            latitud,
            longitud
        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.crear_socio(
                $1,$2,$3,$4,$5,$6,$7,$8
             )`,

            [
                companyId,
                nombre,
                documento,
                telefono,
                direccion,
                observaciones,
                latitud,
                longitud
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
/api/reciclaje/socios/:id
*/
router.put("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const {
            nombre,
            documento,
            telefono,
            direccion,
            observaciones,
            latitud,
            longitud
        } = req.body;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.actualizar_socio(
                $1,$2,$3,$4,$5,$6,$7,$8,$9
             )`,

            [
                companyId,
                id,
                nombre,
                documento,
                telefono,
                direccion,
                observaciones,
                latitud,
                longitud
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
/api/reciclaje/socios/:id
*/
router.delete("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        await pool.query(

            `SELECT reciclaje.eliminar_socio($1,$2)`,

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