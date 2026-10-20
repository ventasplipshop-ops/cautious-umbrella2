import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();

/*
GET
/api/reciclaje/materiales
*/
router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_materiales($1)`,

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
/api/reciclaje/materiales/:id
*/
router.get("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.obtener_material($1,$2)`,

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
/api/reciclaje/materiales
*/
router.post("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {
            nombre,
            unidad,
            metadata,
            precio_base,
            precio_mayorista,
            imagen_url
        } = req.body;

        console.log("===== post MATERIAL =====");
        console.log("BODY:", req.body);
        console.log("imagen_url:", imagen_url);

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.crear_material(
                $1,$2,$3,$4,$5,$6,$7
             )`,

            [
                companyId,
                nombre,
                unidad,
                metadata,
                precio_base,
                precio_mayorista,
                imagen_url
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
/api/reciclaje/materiales/:id
*/
router.put("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const {
            nombre,
            unidad,
            metadata,
            precio_base,
            precio_mayorista,
            imagen_url
        } = req.body;

        console.log("===== PUT MATERIAL =====");
        console.log("BODY:", req.body);
        console.log("imagen_url:", imagen_url);

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.actualizar_material(
                $1,$2,$3,$4,$5,$6,$7,$8
             )`,

            [
                companyId,
                id,
                nombre,
                unidad,
                metadata,
                precio_base,
                precio_mayorista,
                imagen_url
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
/api/reciclaje/materiales/:id
*/
router.delete("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        await pool.query(

            `SELECT reciclaje.eliminar_material($1,$2)`,

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