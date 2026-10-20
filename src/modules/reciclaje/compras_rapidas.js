import { Router } from "express";
import { pool } from "../db/pool.js";
import {
    COMPANY_ID,
    FAKE_USERS
} from "./config.js";

const router = Router();


/*
POST
/api/reciclaje/compras-rapidas
*/
router.post("/", async (req, res) => {

    const client = await pool.connect();

    try {

        /*
        ====================================================
        1. USUARIO AUTENTICADO
        ====================================================
        */

        const authorization = req.headers.authorization;

        if (!authorization?.startsWith("Bearer ")) {

            return res.status(401).json({
                error: "Sesión no válida."
            });

        }


        const token = authorization.substring(7);

        let payload;

        try {

            payload = JSON.parse(
                Buffer.from(
                    token,
                    "base64url"
                ).toString("utf8")
            );

        } catch {

            return res.status(401).json({
                error: "Token no válido."
            });

        }


        const comprador = FAKE_USERS.find(
            (u) => u.id === payload.user_id
        );


        if (!comprador) {

            return res.status(401).json({
                error: "Usuario no válido."
            });

        }


        if (comprador.role !== "comprador") {

            return res.status(403).json({
                error: "Esta operación es exclusiva para compradores."
            });

        }


        /*
        ====================================================
        2. DATOS
        ====================================================
        */

        const {

            socio_id,

            deposito_id,

            transportista_id,

            materiales,

            pagos,

            tipo_cambio = 1,

            observaciones

        } = req.body;


        /*
        ====================================================
        3. VALIDACIONES
        ====================================================
        */

        if (!socio_id) {

            return res.status(400).json({
                error: "Debe seleccionar un socio."
            });

        }


        if (!deposito_id) {

            return res.status(400).json({
                error: "Debe seleccionar el depósito."
            });

        }


        if (!transportista_id) {

            return res.status(400).json({
                error: "Debe seleccionar un transportista."
            });

        }


        if (
            !Array.isArray(materiales) ||
            materiales.length === 0
        ) {

            return res.status(400).json({
                error: "Debe cargar al menos un material."
            });

        }


        if (
            !Array.isArray(pagos) ||
            pagos.length === 0
        ) {

            return res.status(400).json({
                error: "Debe indicar al menos una forma de pago."
            });

        }


        /*
        ====================================================
        4. MARCA DE COMPRA EXTERNA
        ====================================================
        */

        const marcaCompra =
            `COMPRA EXTERNA | Comprador: ${comprador.nombre}`;


        const observacionesFinales = [

            marcaCompra,

            observaciones?.trim()

        ]
        .filter(Boolean)
        .join(" | ");


        /*
        ====================================================
        5. TRANSACCIÓN
        ====================================================
        */

        await client.query("BEGIN");


        /*
        ====================================================
        6. CREAR ORDEN
        ====================================================
        */

        const ordenPayload = {

            socio_id,

            transportista_id,

            observaciones: observacionesFinales,

            materiales: materiales.map((m) => ({

                material_id: m.material_id,

                cantidad: Number(m.cantidad),

                precio_unitario:
                    Number(m.precio_unitario)

            })),

            pagos: pagos.map((p) => ({

                forma_pago_id:
                    p.forma_pago_id,

                moneda_id:
                    p.moneda_id,

                monto:
                    Number(p.monto),

                referencia:
                    p.referencia ?? null,

                observaciones:
                    p.observaciones ?? null

            }))

        };


        const ordenResult = await client.query(

            `SELECT *
             FROM reciclaje.crear_orden_compra(
                $1,
                $2::jsonb
             )`,

            [
                COMPANY_ID,
                ordenPayload
            ]

        );


        const orden = ordenResult.rows[0];


        /*
        ====================================================
        7. CREAR RECEPCIÓN AUTOMÁTICA
        ====================================================
        */

        const recepcionResult = await client.query(

            `SELECT *
             FROM reciclaje.crear_recepcion(
                $1,
                $2,
                $3,
                $4
             )`,

            [

                COMPANY_ID,

                orden.id,

                comprador.nombre,

                observacionesFinales

            ]

        );


        let recepcion = recepcionResult.rows[0];


        /*
        ====================================================
        8. COMPLETAR RECEPCIÓN
        ====================================================
        */

        const recepcionPayload = {

            deposito_id,

            recibido_por:
                comprador.nombre,

            observaciones:
                observacionesFinales,

            materiales: materiales.map((m) => ({

                material_id:
                    m.material_id,

                cantidad:
                    Number(m.cantidad),

                precio_unitario:
                    Number(m.precio_unitario),

                observaciones:
                    m.observaciones ?? null

            }))

        };


        const actualizarRecepcion =
            await client.query(

                `SELECT *
                 FROM reciclaje.actualizar_recepcion(
                    $1,
                    $2,
                    $3::jsonb
                 )`,

                [

                    COMPANY_ID,

                    recepcion.id,

                    recepcionPayload

                ]

            );


        recepcion =
            actualizarRecepcion.rows[0];


        /*
        ====================================================
        9. CONFIRMAR RECEPCIÓN
        ====================================================
        */

        const confirmarResult =
            await client.query(

                `SELECT *
                 FROM reciclaje.confirmar_recepcion(
                    $1,
                    $2
                 )`,

                [

                    COMPANY_ID,

                    recepcion.id

                ]

            );


        recepcion =
            confirmarResult.rows[0];


        /*
        ====================================================
        10. GUARDAR PRECIOS PREFERENCIALES
        ====================================================
        */

        for (const material of materiales) {

            if (
                material.guardar_precio_socio === true
            ) {

                await client.query(

                    `SELECT *
                     FROM reciclaje.guardar_precio_socio(
                        $1,
                        $2,
                        $3,
                        $4,
                        $5
                     )`,

                    [

                        COMPANY_ID,

                        socio_id,

                        material.material_id,

                        Number(
                            material.precio_unitario
                        ),

                        `Precio fijado por ${comprador.nombre}`

                    ]

                );

            }

        }


        /*
        ====================================================
        11. CALCULAR DINERO ENTREGADO
        ====================================================
        */

        const montoPagado =
            pagos.reduce(

                (total, pago) =>
                    total + Number(pago.monto || 0),

                0

            );


        const totalCompra =
            Number(orden.total);


        const excedente =
            montoPagado - totalCompra;


        /*
        ====================================================
        12. FINANZA POR EXCEDENTE
        ====================================================
        */

        let finanzaId = null;


        if (excedente > 0) {

            const finanzaResult =
                await client.query(

                    `SELECT reciclaje.crear_finanza(
                        $1,
                        $2,
                        $3,
                        $4,
                        $5,
                        $6,
                        $7,
                        $8,
                        $9,
                        $10,
                        $11
                     ) AS id`,

                    [

                        COMPANY_ID,

                        "cxc",

                        Number(tipo_cambio),

                        excedente,

                        "orden_compra",

                        orden.id,

                        null,

                        `Excedente de compra externa | ${marcaCompra}`,

                        comprador.nombre,

                        null,

                        "comprador"

                    ]

                );


            finanzaId =
                finanzaResult.rows[0].id;

        }


        /*
        ====================================================
        13. COMMIT
        ====================================================
        */

        await client.query("COMMIT");


        /*
        ====================================================
        14. RESPUESTA
        ====================================================
        */

        return res.status(201).json({

            ok: true,

            comprador: {
                id: comprador.id,
                nombre: comprador.nombre
            },

            orden: {
                id: orden.id,
                total: totalCompra
            },

            recepcion: {
                id: recepcion.id,
                estado: recepcion.estado,
                deposito_id: recepcion.deposito_id
            },

            pago: {
                total_compra: totalCompra,
                monto_pagado: montoPagado,
                excedente:
                    excedente > 0
                        ? excedente
                        : 0
            },

            finanza: finanzaId
                ? {
                    creada: true,
                    id: finanzaId,
                    tipo: "cxc",
                    importe: excedente,
                    responsable:
                        comprador.nombre
                }
                : {
                    creada: false
                }

        });


    } catch (err) {

        /*
        ====================================================
        ROLLBACK
        ====================================================
        */

        try {

            await client.query("ROLLBACK");

        } catch (rollbackError) {

            console.error(
                "ERROR ROLLBACK:",
                rollbackError
            );

        }


        console.error(
            "ERROR COMPRA RAPIDA:",
            err
        );


        return res.status(500).json({
            error: err.message
        });


    } finally {

        client.release();

    }

});


export default router;
