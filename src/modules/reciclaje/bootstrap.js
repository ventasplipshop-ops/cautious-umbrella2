import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();

/*
GET
/api/reciclaje/bootstrap
*/
router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT reciclaje.bootstrap($1) AS bootstrap`,

            [

                companyId

            ]

        );

        res.json(

            rows[0].bootstrap

        );

    }

    catch (err) {

        console.error(err);

        res.status(500).json({

            error: err.message

        });

    }

});

export default router;
