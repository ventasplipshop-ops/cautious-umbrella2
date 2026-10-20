
const OLLAMA_URL = "http://localhost:11434";
const MODELO_BASE = "llama3.2:3b";
const MODELO_NUEVO = "secretaria";

// =====================================================
// INSTRUCCIONES DEL MODELO SECRETARÍA
// PASO 1: COMPRENSIÓN DE INTENCIONES HUMANAS
// =====================================================


const INSTRUCCIONES = `
Sos Secretaría ELECCON, una asistente encargada de analizar
conversaciones de WhatsApp y preparar informes útiles.

Tu objetivo es que el usuario comprenda rápidamente:
- Qué tiene que hacer.
- Qué fechas importantes se aproximan.
- Qué noticias o cambios debe conocer.
- Qué asuntos siguen sin resolverse.

ESTILO DE REDACCIÓN

Escribí de forma natural, clara, breve y profesional.
Utilizá títulos descriptivos y organizá la información
por importancia y cercanía de las fechas.

Explicá qué ocurrió, qué significa y qué requiere atención.
Evitá repetir información, conversaciones informales,
bromas y detalles que no aporten valor.

No inventes información.
Cuando algo no esté confirmado, indicalo con naturalidad.
No presentes propuestas como decisiones tomadas.

Priorizá la información vigente respecto de la fecha
de referencia proporcionada.

No describas tu proceso de análisis.
No expliques las reglas que utilizaste.
Entregá directamente el informe.
`;

// =====================================================
// COMUNICACIÓN CON OLLAMA
// =====================================================

async function solicitar(endpoint, body) {
    const response = await fetch(
        `${OLLAMA_URL}${endpoint}`,
        {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(body)
        }
    );

    if (!response.ok) {
        throw new Error(
            `Ollama ${response.status}: ${await response.text()}`
        );
    }

    return response.json();
}

// =====================================================
// CREACIÓN DEL MODELO
// =====================================================

async function main() {
    console.log("Creando modelo secretaria...");

    const creado = await solicitar("/api/create", {
        model: MODELO_NUEVO,
        from: MODELO_BASE,
        system: INSTRUCCIONES,
        parameters: {
            temperature: 0.1,
            num_ctx: 8192
        },
        stream: false
    });

    console.log("Estado:", creado.status);

    // Prueba inicial
// =====================================================
// PRUEBA INICIAL — EXTRACCIÓN DE COMPROMISOS
// =====================================================

const mensaje = `
[12/10/2026, 10:00] Juan:
El viernes tenemos que entregar el informe.

[12/10/2026, 10:05] María:
Confirmado, lo entregamos el 16 de octubre.

[12/10/2026, 10:10] Juan:
Yo me encargo de prepararlo.

[12/10/2026, 11:00] Pedro:
La reunión de ayer ya terminó.
`;

const resultado = await solicitar("/api/generate", {
    model: MODELO_NUEVO,

    prompt: `
Analizá esta conversación de WhatsApp.

Extraé todos los compromisos identificables.

Fecha de referencia: 2026-10-12.

Respondé con un objeto JSON que contenga
un array llamado "compromisos".

CONVERSACIÓN:
${mensaje}
`,

    stream: false,

    format: {
        type: "object",
        properties: {
            compromisos: {
                type: "array",
                items: {
                    type: "object",
                    properties: {
                        tipo: {
                            type: "string",
                            enum: [
                                "tarea",
                                "evento",
                                "evaluacion",
                                "reunion",
                                "proyecto",
                                "vencimiento"
                            ]
                        },
                        titulo: {
                            type: "string"
                        },
                        estado: {
                            type: "string",
                            enum: [
                                "pendiente",
                                "en_proceso",
                                "finalizado",
                                "cancelado"
                            ]
                        },
                        fecha_inicio: {
                            type: ["string", "null"]
                        },
                        responsable: {
                            type: ["string", "null"]
                        },
                        confirmacion: {
                            type: "string",
                            enum: [
                                "confirmado",
                                "tentativo",
                                "desconocido"
                            ]
                        }
                    },
                    required: [
                        "tipo",
                        "titulo",
                        "estado",
                        "fecha_inicio",
                        "responsable",
                        "confirmacion"
                    ],
                    additionalProperties: false
                }
            }
        },
        required: ["compromisos"],
        additionalProperties: false
    },

    options: {
        temperature: 0.1,
        num_ctx: 8192
    }
});

console.log("\nRESPUESTA DEL MODELO:");
console.log(
    JSON.stringify(
        JSON.parse(resultado.response),
        null,
        2
    )
);

console.log("\nTIEMPO:");
console.log(
    (resultado.total_duration / 1e9).toFixed(2),
    "segundos"
);

console.log("\nTOKENS DE ENTRADA:");
console.log(resultado.prompt_eval_count);

console.log("\nTOKENS GENERADOS:");
console.log(resultado.eval_count);
}

main().catch(error => {
    console.error("ERROR:", error.message);
    process.exitCode = 1;
});
