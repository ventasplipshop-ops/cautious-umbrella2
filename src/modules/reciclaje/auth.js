import { Router } from "express";
import { FAKE_USERS } from "./config.js";

const router = Router();


/*
POST
/api/reciclaje/auth/login
*/
router.post("/login", async (req, res) => {

    try {

        const {
            email,
            password
        } = req.body;

        if (!email || !password) {

            return res.status(400).json({
                error: "Debe indicar correo y contraseña."
            });

        }

        const emailNormalizado = String(email)
            .trim()
            .toLowerCase();


        /*
        Buscar usuario
        */
        const user = FAKE_USERS.find((u) =>

            u.email.toLowerCase() === emailNormalizado
            &&
            u.password === String(password)

        );


        if (!user) {

            return res.status(401).json({
                error: "Correo o contraseña incorrectos."
            });

        }


        /*
        Token falso para el MVP.
        No debe utilizarse como seguridad real.
        */
        const token = Buffer.from(
            JSON.stringify({
                user_id: user.id,
                company_id: user.company_id,
                role: user.role,
                issued_at: Date.now()
            })
        ).toString("base64url");


        return res.json({

            token,

            user: {
                id: user.id,
                company_id: user.company_id,
                nombre: user.nombre,
                email: user.email,
                role: user.role
            }

        });


    } catch (err) {

        console.error(err);

        return res.status(500).json({
            error: "No se pudo iniciar sesión."
        });

    }

});


/*
GET
/api/reciclaje/auth/me
*/
router.get("/me", async (req, res) => {

    try {

        const authorization = req.headers.authorization;

        if (!authorization?.startsWith("Bearer ")) {

            return res.status(401).json({
                error: "Sesión no válida."
            });

        }


        const token = authorization.substring(7);

        let payload;


        /*
        Decodificar token
        */
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


        /*
        Buscar usuario del token
        */
        const user = FAKE_USERS.find(
            (u) => u.id === payload.user_id
        );


        if (!user) {

            return res.status(401).json({
                error: "Usuario no válido."
            });

        }


        /*
        Verificación mínima adicional
        */
        if (
            payload.company_id !== user.company_id ||
            payload.role !== user.role
        ) {

            return res.status(401).json({
                error: "Token no válido."
            });

        }


        return res.json({

            id: user.id,
            company_id: user.company_id,
            nombre: user.nombre,
            email: user.email,
            role: user.role

        });


    } catch (err) {

        console.error(err);

        return res.status(500).json({
            error: "No se pudo consultar la sesión."
        });

    }

});


export default router;