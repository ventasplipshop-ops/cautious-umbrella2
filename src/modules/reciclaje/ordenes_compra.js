import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();

/*
GET
/api/reciclaje/ordenes-compra
*/
router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_ordenes_compra($1)`,

            [companyId]

        );

        console.log(JSON.stringify(rows, null, 2));

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
/api/reciclaje/ordenes-compra/ultimo-pedido/:socioId
*/
router.get("/ultimo-pedido/:socioId", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { socioId } = req.params;

        const { rows } = await pool.query(

            `SELECT reciclaje.obtener_ultimo_pedido_socio(
                $1,
                $2
             ) AS pedido`,

            [
                companyId,
                socioId
            ]

        );

        const pedido = rows[0]?.pedido;

        if (!pedido) {

            return res.status(404).json({
                error: "Este socio todavía no tiene pedidos anteriores."
            });

        }

        res.json(pedido);

    } catch (err) {

        console.error(err);

        res.status(500).json({
            error: err.message
        });

    }

});

/*
GET
/api/reciclaje/ordenes-compra/:id
*/
router.get("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.obtener_orden_compra($1,$2)`,

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
/api/reciclaje/ordenes-compra
*/
router.post("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.crear_orden_compra(
                $1,
                $2::jsonb
             )`,

            [

                companyId,

                req.body

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
/api/reciclaje/ordenes-compra/:id
*/
router.put("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.actualizar_orden_compra(
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
DELETE
/api/reciclaje/ordenes-compra/:id
*/
router.delete("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.eliminar_orden_compra(
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