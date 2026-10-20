import { Router } from "express";
import { pool } from "../db/pool.js";
import { COMPANY_ID } from "./config.js";

const router = Router();


/*
GET
/api/reciclaje/operaciones

Listado resumido para las cards del pipeline.
Las operaciones abiertas permanecen visibles.
Las finalizadas solo aparecen durante las últimas 24 horas.
*/
router.get("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.listar_operaciones($1)`,

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
POST
/api/reciclaje/operaciones/iniciar-multicarga

Inicia una salida con una o varias operaciones.

La función SQL:

- valida todas las operaciones;
- exige que estén en precarga;
- genera un grupo_salida_id común;
- asigna el mismo transportista;
- pasa todas a en_proceso;
- crea un único movimiento de caja si se entregó dinero.

BODY:

{
    "operacion_ids": [
        "uuid-operacion-1",
        "uuid-operacion-2"
    ],
    "transportista_id": "uuid-transportista",
    "caja": {
        "monto": 30000,
        "moneda": "ARS",
        "tipo_cambio": 1,
        "forma_pago": "efectivo",
        "referencia": null,
        "observaciones": null
    }
}
*/
router.post("/iniciar-multicarga", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT reciclaje.iniciar_operaciones_multicarga(
                $1,
                $2::jsonb
             ) AS resultado`,

            [
                companyId,
                req.body
            ]

        );

        res.json(rows[0]?.resultado);

    } catch (err) {

        console.error(err);

        res.status(500).json({
            error: err.message
        });

    }

});


/*
GET
/api/reciclaje/operaciones/:id

Obtiene la operación completa para abrirla,
continuarla o revisarla.
*/
router.get("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT reciclaje.obtener_operacion(
                $1,
                $2
             ) AS operacion`,

            [
                companyId,
                id
            ]

        );

        const operacion = rows[0]?.operacion;

        if (!operacion) {

            return res.status(404).json({
                error: "Operación no encontrada."
            });

        }

        res.json(operacion);

    } catch (err) {

        console.error(err);

        res.status(500).json({
            error: err.message
        });

    }

});


/*
POST
/api/reciclaje/operaciones

Crea o actualiza una operación del pipeline.

Sin id:
    crea operación.

Con id:
    actualiza la operación existente.
*/
router.post("/", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { rows } = await pool.query(

            `SELECT reciclaje.upsert_operacion(
                $1,
                $2::jsonb
             ) AS operacion`,

            [
                companyId,
                req.body
            ]

        );

        res.json(rows[0]?.operacion);

    } catch (err) {

        console.error(err);

        res.status(500).json({
            error: err.message
        });

    }

});


/*
POST
/api/reciclaje/operaciones/transportista/:transportistaId/confirmar

Confirma conjuntamente todas las operaciones en proceso
de un mismo transportista.

El frontend envía únicamente:
- deposito_id
- inventario físico real consolidado

Cada operación genera individualmente:
- su orden de compra
- su recepción

El inventario se registra una sola vez usando
las cantidades físicas consolidadas enviadas por el frontend.
*/
router.post("/transportista/:transportistaId/confirmar", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { transportistaId } = req.params;

        const { rows } = await pool.query(

            `SELECT reciclaje.confirmar_operaciones_transportista(
                $1,
                $2,
                $3::jsonb
             ) AS resultado`,

            [
                companyId,
                transportistaId,
                req.body
            ]

        );

        res.json(rows[0]?.resultado);

    } catch (err) {

        console.error(err);

        res.status(500).json({
            error: err.message
        });

    }

});

/*
POST
/api/reciclaje/operaciones/:id/confirmar

Cierra definitivamente la operación.

Genera:
- orden de compra
- detalle
- pagos
- recepción
- movimientos de stock
- actualización de inventario
- cierre de la operación
*/
router.post("/:id/confirmar", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT reciclaje.confirmar_operacion(
                $1,
                $2
             ) AS resultado`,

            [
                companyId,
                id
            ]

        );

        res.json(rows[0]?.resultado);

    } catch (err) {

        console.error(err);

        res.status(500).json({
            error: err.message
        });

    }

});


/*
DELETE
/api/reciclaje/operaciones/:id/multicarga

Elimina UNA operación perteneciente a una salida.

La función SQL se encarga de:

- eliminar únicamente la operación indicada;
- mantener intacto el movimiento de caja mientras existan
  otras operaciones del mismo grupo;
- si era la última operación del grupo, generar la entrada
  compensatoria por el total del dinero entregado;
- si la operación no pertenece a un grupo, eliminarla normalmente.

NO elimina automáticamente las demás operaciones del grupo.
*/
router.delete("/:id/multicarga", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT reciclaje.eliminar_operacion_multicarga(
                $1,
                $2
             ) AS resultado`,

            [
                companyId,
                id
            ]

        );

        res.json(rows[0]?.resultado);

    } catch (err) {

        console.error(err);

        res.status(500).json({
            error: err.message
        });

    }

});


/*
DELETE
/api/reciclaje/operaciones/:id

Eliminación individual legacy.

Se conserva por compatibilidad con el flujo actual.
*/
router.delete("/:id", async (req, res) => {

    try {

        const companyId = COMPANY_ID;

        const { id } = req.params;

        const { rows } = await pool.query(

            `SELECT *
             FROM reciclaje.eliminar_operacion(
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