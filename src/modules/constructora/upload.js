import multer from "multer";
import path from "path";
import crypto from "crypto";

const STORAGE_PATH = "/home/edwin/storage/constructora/originales";

const storage = multer.diskStorage({

    destination: (req, file, cb) => {
        cb(null, STORAGE_PATH);
    },

    filename: (req, file, cb) => {

        const extension = path.extname(file.originalname).toLowerCase();

        const nombre = `${Date.now()}-${crypto.randomUUID()}${extension}`;

        cb(null, nombre);
    }

});


const fileFilter = (req, file, cb) => {

    const permitidos = [
        "image/jpeg",
        "image/png",
        "image/webp"
    ];

    if (!permitidos.includes(file.mimetype)) {
        return cb(
            new Error("Solo se permiten imágenes JPG, PNG o WEBP")
        );
    }

    cb(null, true);
};


export const uploadImagen = multer({

    storage,

    limits: {
        fileSize: 15 * 1024 * 1024
    },

    fileFilter

});


const EDITADAS_PATH = "/home/edwin/storage/constructora/editadas";

const storageEditadas = multer.diskStorage({

    destination: (req, file, cb) => {
        cb(null, EDITADAS_PATH);
    },

    filename: (req, file, cb) => {

        const extension = path.extname(file.originalname).toLowerCase();

        const nombre =
            `${Date.now()}-${crypto.randomUUID()}${extension}`;

        cb(null, nombre);
    }

});


export const uploadImagenEditada = multer({

    storage: storageEditadas,

    limits: {
        fileSize: 15 * 1024 * 1024
    },

    fileFilter

});

const AUDIOS_PATH = "/home/edwin/storage/constructora/audios";

const storageAudios = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, AUDIOS_PATH);
    },

    filename: (req, file, cb) => {
        const extension = path.extname(file.originalname).toLowerCase();

        const nombre =
            `${Date.now()}-${crypto.randomUUID()}${extension}`;

        cb(null, nombre);
    }
});

const audioFileFilter = (req, file, cb) => {
    const tiposPermitidos = [
        "audio/mpeg",
        "audio/mp3",
        "audio/mp4",
        "audio/m4a",
        "audio/aac",
        "audio/wav",
        "audio/x-wav",
        "audio/ogg",
        "audio/webm",
        "audio/flac"
    ];

    const extensionesPermitidas = [
        ".mp3",
        ".mp4",
        ".m4a",
        ".aac",
        ".wav",
        ".ogg",
        ".webm",
        ".flac"
    ];

    const extension =
        path.extname(file.originalname).toLowerCase();

    const mimeValido =
        tiposPermitidos.includes(file.mimetype);

    const octetStreamValido =
        file.mimetype === "application/octet-stream" &&
        extensionesPermitidas.includes(extension);

    if (!mimeValido && !octetStreamValido) {
        return cb(
            new Error(
                `Formato de audio no permitido: ${file.mimetype} ${extension}`
            )
        );
    }

    cb(null, true);
};

export const uploadAudioAgenda = multer({
    storage: storageAudios,

    limits: {
        fileSize: 100 * 1024 * 1024
    },

    fileFilter: audioFileFilter
});

const WHATSAPP_PATH =
    "/home/edwin/storage/constructora/whatsapp";

const storageWhatsApp = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, WHATSAPP_PATH);
    },

    filename: (req, file, cb) => {
        const nombre =
            `${Date.now()}-${crypto.randomUUID()}.zip`;

        cb(null, nombre);
    }
});

const whatsappFileFilter = (req, file, cb) => {
    const extension =
        path.extname(file.originalname).toLowerCase();

    const tiposPermitidos = [
        "application/zip",
        "application/x-zip-compressed",
        "application/octet-stream"
    ];

    if (
        extension !== ".zip" ||
        !tiposPermitidos.includes(file.mimetype)
    ) {
        return cb(
            new Error("Solo se permiten archivos ZIP de WhatsApp")
        );
    }

    cb(null, true);
};

export const uploadWhatsApp = multer({
    storage: storageWhatsApp,
    limits: {
        fileSize: 100 * 1024 * 1024
    },
    fileFilter: whatsappFileFilter
});