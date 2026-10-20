import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();


/*
============================================================
GET INVENTARIO
============================================================

GET
/api/reciclaje/inventario

Opcional:
?deposito_id=UUID
*/

router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {
            deposito_id
        } = req.query;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_inventario(
                $1,
                $2
             )`,

            [
                companyId,
                deposito_id || null
            ]

        );

        res.json(rows);

    } catch (err) {

        console.error("ERROR LISTAR INVENTARIO:", err);

        res.status(500).json({
            error: err.message
        });

    }

});


/*
============================================================
GET MOVIMIENTOS
============================================================

GET
/api/reciclaje/inventario/movimientos

Filtros opcionales:

?deposito_id=UUID
?material_id=UUID
?tipo_movimiento=entrada
?limite=100
*/

router.get("/movimientos", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {
            deposito_id,
            material_id,
            tipo_movimiento,
            limite
        } = req.query;


        const limiteFinal = limite
            ? Number(limite)
            : 100;


        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_movimientos_stock(
                $1,
                $2,
                $3,
                $4,
                $5
             )`,

            [
                companyId,
                deposito_id || null,
                material_id || null,
                tipo_movimiento || null,
                limiteFinal
            ]

        );


        res.json(rows);

    } catch (err) {

        console.error("ERROR LISTAR MOVIMIENTOS:", err);

        res.status(500).json({
            error: err.message
        });

    }

});


/*
============================================================
REGISTRAR SALIDA
============================================================

POST
/api/reciclaje/inventario/salidas

BODY:

{
    "deposito_id": "uuid",
    "material_id": "uuid",
    "cantidad": 100,
    "observaciones": "Venta de material"
}
*/

router.post("/salidas", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {
            deposito_id,
            material_id,
            cantidad,
            observaciones
        } = req.body;


        if (!deposito_id) {

            return res.status(400).json({
                error: "deposito_id es obligatorio."
            });

        }


        if (!material_id) {

            return res.status(400).json({
                error: "material_id es obligatorio."
            });

        }


        if (
            cantidad === undefined ||
            cantidad === null ||
            Number(cantidad) <= 0
        ) {

            return res.status(400).json({
                error: "cantidad debe ser mayor que cero."
            });

        }


        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.registrar_salida(
                $1,
                $2,
                $3,
                $4,
                $5
             )`,

            [
                companyId,
                deposito_id,
                material_id,
                cantidad,
                observaciones || null
            ]

        );


        res.status(201).json(rows[0]);

    } catch (err) {

        console.error("ERROR REGISTRAR SALIDA:", err);

        res.status(400).json({
            error: err.message
        });

    }

});


/*
============================================================
REGISTRAR AJUSTE
============================================================

POST
/api/reciclaje/inventario/ajustes

BODY:

{
    "deposito_id": "uuid",
    "material_id": "uuid",
    "cantidad": -5,
    "observaciones": "Diferencia detectada en conteo físico"
}

cantidad:
+10 = sumar 10
-10 = restar 10
*/

router.post("/ajustes", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {
            deposito_id,
            material_id,
            cantidad,
            observaciones
        } = req.body;


        if (!deposito_id) {

            return res.status(400).json({
                error: "deposito_id es obligatorio."
            });

        }


        if (!material_id) {

            return res.status(400).json({
                error: "material_id es obligatorio."
            });

        }


        if (
            cantidad === undefined ||
            cantidad === null ||
            Number(cantidad) === 0
        ) {

            return res.status(400).json({
                error: "cantidad no puede ser cero."
            });

        }


        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.registrar_ajuste(
                $1,
                $2,
                $3,
                $4,
                $5
             )`,

            [
                companyId,
                deposito_id,
                material_id,
                cantidad,
                observaciones || null
            ]

        );


        res.status(201).json(rows[0]);

    } catch (err) {

        console.error("ERROR REGISTRAR AJUSTE:", err);

        res.status(400).json({
            error: err.message
        });

    }

});


/*
============================================================
REGISTRAR TRASLADO
============================================================

POST
/api/reciclaje/inventario/traslados

BODY:

{
    "deposito_origen_id": "uuid",
    "deposito_destino_id": "uuid",
    "material_id": "uuid",
    "cantidad": 100,
    "observaciones": "Traslado entre depósitos"
}
*/

router.post("/traslados", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {
            deposito_origen_id,
            deposito_destino_id,
            material_id,
            cantidad,
            observaciones
        } = req.body;


        if (!deposito_origen_id) {

            return res.status(400).json({
                error: "deposito_origen_id es obligatorio."
            });

        }


        if (!deposito_destino_id) {

            return res.status(400).json({
                error: "deposito_destino_id es obligatorio."
            });

        }


        if (deposito_origen_id === deposito_destino_id) {

            return res.status(400).json({
                error: "El depósito de origen y destino no pueden ser iguales."
            });

        }


        if (!material_id) {

            return res.status(400).json({
                error: "material_id es obligatorio."
            });

        }


        if (
            cantidad === undefined ||
            cantidad === null ||
            Number(cantidad) <= 0
        ) {

            return res.status(400).json({
                error: "cantidad debe ser mayor que cero."
            });

        }


        const { rows } = await pool.query(

            `SELECT reciclaje.registrar_traslado(
                $1,
                $2,
                $3,
                $4,
                $5,
                $6
             ) AS movimiento_grupo_id`,

            [
                companyId,
                deposito_origen_id,
                deposito_destino_id,
                material_id,
                cantidad,
                observaciones || null
            ]

        );


        res.status(201).json({
            ok: true,
            movimiento_grupo_id:
                rows[0].movimiento_grupo_id
        });

    } catch (err) {

        console.error("ERROR REGISTRAR TRASLADO:", err);

        res.status(400).json({
            error: err.message
        });

    }

});


/*
============================================================
TRANSFORMAR MATERIAL
============================================================

POST
/api/reciclaje/inventario/transformaciones

Transforma una cantidad de un material compuesto
en uno o varios materiales resultantes.

El backend registra toda la transformación de forma atómica.

BODY:

{
    "deposito_id": "uuid",
    "material_origen_id": "uuid",
    "cantidad_origen": 20,
    "resultados": [
        {
            "material_id": "uuid-cobre",
            "cantidad": 12
        },
        {
            "material_id": "uuid-tapas",
            "cantidad": 7
        }
    ],
    "observaciones": "Procesamiento de radiadores"
}

Ejemplo:

Radiador   -20
Cobre      +12
Tapas       +7

Merma calculada automáticamente: 1
*/

router.post("/transformaciones", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const {

            deposito_id,

            material_origen_id,

            cantidad_origen,

            resultados,

            observaciones

        } = req.body;


        // ------------------------------------------------------------
        // VALIDACIONES BÁSICAS DEL REQUEST
        // ------------------------------------------------------------

        if (!deposito_id) {

            return res.status(400).json({
                error: "deposito_id es obligatorio."
            });

        }


        if (!material_origen_id) {

            return res.status(400).json({
                error: "material_origen_id es obligatorio."
            });

        }


        if (
            cantidad_origen === undefined ||
            cantidad_origen === null ||
            Number(cantidad_origen) <= 0
        ) {

            return res.status(400).json({
                error: "cantidad_origen debe ser mayor que cero."
            });

        }


        if (
            !Array.isArray(resultados) ||
            resultados.length === 0
        ) {

            return res.status(400).json({
                error: "Debe indicar al menos un material resultante."
            });

        }


        // ------------------------------------------------------------
        // VALIDACIÓN ESTRUCTURAL DE RESULTADOS
        //
        // Las validaciones reales de materiales, stock y balance
        // continúan siendo responsabilidad de PostgreSQL.
        // ------------------------------------------------------------

        for (const resultado of resultados) {

            if (!resultado?.material_id) {

                return res.status(400).json({
                    error: "Todos los resultados deben indicar material_id."
                });

            }


            if (
                resultado.cantidad === undefined ||
                resultado.cantidad === null ||
                Number(resultado.cantidad) <= 0
            ) {

                return res.status(400).json({
                    error: "Todas las cantidades resultantes deben ser mayores que cero."
                });

            }

        }


        // ------------------------------------------------------------
        // TRANSFORMACIÓN ATÓMICA
        // ------------------------------------------------------------

        const { rows } = await pool.query(

            `
            SELECT reciclaje.transformar_material(
                $1,
                $2,
                $3,
                $4,
                $5::jsonb,
                $6
            ) AS resultado
            `,

            [
                companyId,

                deposito_id,

                material_origen_id,

                Number(cantidad_origen),

                JSON.stringify(resultados),

                observaciones || null
            ]

        );


        res.status(201).json(
            rows[0]?.resultado
        );

    } catch (err) {

        console.error(
            "ERROR TRANSFORMAR MATERIAL:",
            err
        );


        /*
        Las validaciones importantes ocurren también
        dentro de transformar_material():

        - material origen existente;
        - material origen compuesto;
        - depósito válido;
        - stock suficiente;
        - materiales resultantes válidos;
        - cantidades válidas;
        - resultado no superior al origen;
        - transformación atómica.
        */

        res.status(400).json({
            error: err.message
        });

    }

});

export default router;