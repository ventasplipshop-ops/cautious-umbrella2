import { Router } from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import crypto from "crypto";

const router = Router();

const MATERIALS_DIR =
    "/home/edwin/storage/reciclaje/materiales";

fs.mkdirSync(MATERIALS_DIR, {
    recursive: true
});

const storage = multer.diskStorage({

    destination: (req, file, cb) => {
        cb(null, MATERIALS_DIR);
    },

    filename: (req, file, cb) => {

        const extension =
            path.extname(file.originalname).toLowerCase();

        const filename =
            `${crypto.randomUUID()}${extension}`;

        cb(null, filename);
    }

});

const upload = multer({

    storage,

    limits: {
        fileSize: 5 * 1024 * 1024
    },

    fileFilter: (req, file, cb) => {

        const allowed = [
            "image/jpeg",
            "image/png",
            "image/webp"
        ];

        if (!allowed.includes(file.mimetype)) {

            return cb(
                new Error(
                    "Solo se permiten imágenes JPG, PNG o WEBP."
                )
            );

        }

        cb(null, true);
    }

});


/*
POST
/api/reciclaje/storage/materiales
*/

router.post(
    "/materiales",
    upload.single("imagen"),
    (req, res) => {

        if (!req.file) {

            return res.status(400).json({
                error: "Debe enviar una imagen."
            });

        }

        const imagenUrl =
            `/storage/reciclaje/materiales/${req.file.filename}`;

        res.status(201).json({

            filename: req.file.filename,

            imagen_url: imagenUrl

        });
    }
);

export default router;
