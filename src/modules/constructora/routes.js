import express from "express";

import {
    listarProyectos,
    listarProyectosPublicos,
    upsertProyecto,
    eliminarProyecto,
    upsertCronograma,
    eliminarCronograma,
    subirImagen,
    subirImagenEditada,
    aprobarImagen,
    upsertAvance,
    retrocederAvance,
    ejecutarAgenda,
    gestionarItemAgenda,
    listarAgenda,
    guardarTranscripcionAgenda,
    guardarContextoVozAgenda,
    listarContextoVozAgenda,
    transcribirAudioAgenda,
    registrarConversacionSecretaria,
    obtenerContextoSecretaria,
    conversarSecretaria,
    importarWhatsApp,
    listarAnalisisWhatsApp,
    upsertItemWhatsApp,

    probarSecretariaIA,



} from "./controller.js";
import {secretariaEntrenamientoRouter} from "./secretariaEntrenamieto.js";
import { uploadImagen, uploadImagenEditada, uploadAudioAgenda, uploadWhatsApp } from "./upload.js";


const router = express.Router();


// ============================================================
// PROYECTOS
// ============================================================

router.get("/proyectos", listarProyectos);

router.post("/proyectos", upsertProyecto);

router.delete("/proyectos/:id", eliminarProyecto);


// ============================================================
// CRONOGRAMA
// ============================================================

router.post("/cronograma", upsertCronograma);

router.delete("/cronograma/:id", eliminarCronograma);

// ============================================================
// IMÁGENES
// ============================================================

router.post(
    "/imagenes",
    uploadImagen.single("imagen"),
    subirImagen
);

router.post(
    "/imagenes/:id/editar",
    uploadImagenEditada.single("imagen"),
    subirImagenEditada
);

router.post(
    "/imagenes/:id/aprobar",
    aprobarImagen
);

// ============================================================
// AVANCES
// ============================================================

router.post(
    "/avances",
    upsertAvance
);

router.post(
    "/avances/:id/retroceder",
    retrocederAvance
);

// ============================================================
// PÚBLICO
// ============================================================

router.get(
    "/public/proyectos",
    listarProyectosPublicos
);

// ============================================================
// AGENDA
// ============================================================

router.post(
    "/agenda/ejecutar",
    ejecutarAgenda
);

router.post(
    "/agenda/items/:id/gestionar",
    gestionarItemAgenda
);

router.get(
    "/agenda", 
    listarAgenda
);

router.post(
    "/agenda/transcripciones",
    guardarTranscripcionAgenda
);

router.post(
    "/agenda/contexto-voz",
    guardarContextoVozAgenda
);

router.get(
    "/agenda/contexto-voz",
    listarContextoVozAgenda
);

router.post(
    "/agenda/speech",
    uploadAudioAgenda.single("audio"),
    transcribirAudioAgenda
);

// ============================================================
// SECRETARÍA — CONVERSACIÓN Y MEMORIA
// ============================================================

router.post(
    "/agenda/conversacion",
    registrarConversacionSecretaria
);

router.get(
    "/agenda/contexto",
    obtenerContextoSecretaria
);

router.post(
    "/agenda/secretaria",
    conversarSecretaria
);

// ============================================================
// SECRETARÍA — IMPORTAR WHATSAPP
// ============================================================

router.post(
    "/agenda/whatsapp/importar",
    uploadWhatsApp.single("archivo"),
    importarWhatsApp
);

router.get(
    "/agenda/whatsapp/analisis",
    listarAnalisisWhatsApp
);

router.post(
  '/agenda/whatsapp/item/upsert',
  upsertItemWhatsApp
);

router.get(
    "/agenda/ia/test",
    probarSecretariaIA
);


router.use('/agenda/ia', secretariaEntrenamientoRouter);

export default router;