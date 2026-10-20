
const OLLAMA_URL = "http://localhost:11434";
const MODELO = "secretaria";

const pruebas = [
    // ==========================================
    // PRUEBAS ORIGINALES ACTUALIZADAS (1-15)
    // ==========================================

    {
        mensaje: "Buenas noches, ¿todo bien por ahí?",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "¿Cuántas reuniones tengo esta semana?",
        esperado: ["CONSULTA"]
    },
    {
        mensaje: "Poneme una visita a la obra para el lunes.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "Estoy pensando en visitar la obra el lunes.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "Ni se te ocurra borrar la visita.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "En lugar del martes, dejalo para el jueves.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "Anotá que debo comprar materiales y mostrame mis pendientes.",
        esperado: ["ORDEN", "CONSULTA"]
    },
    {
        mensaje: "¿Podés decirme cuándo viene el electricista?",
        esperado: ["CONSULTA"]
    },
    {
        mensaje: "Quiero que me recuerdes pagarle a Juan mañana.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "Quizás sería bueno cancelar la inspección.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "No programes ninguna visita para el viernes.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "Perdón, dije a las tres, pero era a las cuatro.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "Che, ¿qué tengo pendiente? Y agregame llamar al arquitecto.",
        esperado: ["CONSULTA", "ORDEN"]
    },
    {
        mensaje: "Me parece que mañana va a llover.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "Si tengo tiempo, capaz paso por la obra.",
        esperado: ["CONVERSACION"]
    },

    // ==========================================
    // 20 PRUEBAS NUEVAS (16-35)
    // ==========================================

    {
        mensaje: "Hoy estoy agotado, fue un día larguísimo.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "Me gustaría saber cuánto falta para terminar la obra.",
        esperado: ["CONSULTA"]
    },
    {
        mensaje: "Necesito que me anotes una reunión con el proveedor.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "¿Podrías recordarme que llame al contador el martes?",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "¿Es posible cambiar la fecha de una visita?",
        esperado: ["CONSULTA"]
    },
    {
        mensaje: "Estoy evaluando si contrato otro electricista.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "No quiero que elimines ningún registro.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "La verdad, creo que deberíamos organizar mejor los trabajos.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "Mostrame las tareas vencidas y anotá una inspección para mañana.",
        esperado: ["CONSULTA", "ORDEN"]
    },
    {
        mensaje: "Agendame una visita y después decime a qué hora quedó.",
        esperado: ["ORDEN", "CONSULTA"]
    },
    {
        mensaje: "¿Te parece buena idea visitar la obra el sábado?",
        esperado: ["CONSULTA"]
    },
    {
        mensaje: "Capaz conviene llamar primero al arquitecto.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "Dejá la reunión como está, no cambies nada.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "Necesito saber si Juan terminó la instalación eléctrica.",
        esperado: ["CONSULTA"]
    },
    {
        mensaje: "Che, anotame que tengo que comprar cemento.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "Me confundí, la inspección era el miércoles.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "¿Cuándo vence el pago del proveedor? Y recordámelo un día antes.",
        esperado: ["CONSULTA", "ORDEN"]
    },
    {
        mensaje: "Por ahora no hagas nada con esa reunión.",
        esperado: ["ORDEN"]
    },
    {
        mensaje: "Ojalá terminemos la obra antes de diciembre.",
        esperado: ["CONVERSACION"]
    },
    {
        mensaje: "Contame cómo funciona la agenda y después agendame una visita.",
        esperado: ["CONSULTA", "ORDEN"]
    }
];

// ==========================================
// CONSULTAR MODELO
// ==========================================

async function clasificar(mensaje) {
    const respuesta = await fetch(`${OLLAMA_URL}/api/generate`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            model: MODELO,
            prompt: mensaje,
            stream: false,
            format: "json",
            options: {
                temperature: 0.1
            }
        })
    });

    if (!respuesta.ok) {
        throw new Error(await respuesta.text());
    }

    const datos = await respuesta.json();
    const json = JSON.parse(datos.response);

    if (!Array.isArray(json.intenciones)) {
        throw new Error(
            `Respuesta sin array de intenciones: ${datos.response}`
        );
    }

    const permitidas = [
        "CONVERSACION",
        "CONSULTA",
        "ORDEN",
        "NO_ENTENDIDO"
    ];

    if (
        json.intenciones.length === 0 ||
        json.intenciones.some(
            intencion => !permitidas.includes(intencion)
        )
    ) {
        throw new Error(
            `Intenciones inválidas: ${JSON.stringify(json.intenciones)}`
        );
    }

    return json.intenciones;
}

// Comparar sin importar el orden
function iguales(a, b) {
    return JSON.stringify([...a].sort()) ===
           JSON.stringify([...b].sort());
}

// ==========================================
// EJECUTAR PRUEBAS
// ==========================================

async function main() {
    let correctas = 0;
    const errores = [];

    const resultados = {
        CONVERSACION: { correctas: 0, total: 0 },
        CONSULTA: { correctas: 0, total: 0 },
        ORDEN: { correctas: 0, total: 0 },
        MULTIPLE: { correctas: 0, total: 0 }
    };

    console.log("\nPRUEBA DE INTENCIONES - SECRETARÍA\n");

    for (let i = 0; i < pruebas.length; i++) {
        const prueba = pruebas[i];

        const categoria = prueba.esperado.length > 1
            ? "MULTIPLE"
            : prueba.esperado[0];

        resultados[categoria].total++;

        try {
            const obtenido = await clasificar(prueba.mensaje);
            const correcto = iguales(obtenido, prueba.esperado);

            if (correcto) {
                correctas++;
                resultados[categoria].correctas++;
            } else {
                errores.push({
                    prueba: i + 1,
                    mensaje: prueba.mensaje,
                    esperado: prueba.esperado,
                    obtenido
                });
            }

            console.log(
                `${correcto ? "✅" : "❌"} PRUEBA ${i + 1}`
            );
            console.log("Mensaje:", prueba.mensaje);
            console.log("Esperado:", prueba.esperado);
            console.log("Obtenido:", obtenido);
            console.log("");

        } catch (error) {
            errores.push({
                prueba: i + 1,
                mensaje: prueba.mensaje,
                error: error.message
            });

            console.log(
                `❌ PRUEBA ${i + 1}: ${error.message}\n`
            );
        }
    }

    console.log("================================");
    console.log("RESULTADO FINAL");
    console.log("================================");

    const porcentaje = (
        correctas / pruebas.length * 100
    ).toFixed(1);

    console.log(
        `TOTAL: ${correctas}/${pruebas.length} (${porcentaje}%)`
    );

    console.log("\nRESULTADOS POR CATEGORÍA:");

    for (const [categoria, datos] of Object.entries(resultados)) {
        console.log(
            `${categoria}: ${datos.correctas}/${datos.total}`
        );
    }

    console.log("\nERRORES:");

    if (errores.length === 0) {
        console.log("Ninguno");
    } else {
        console.log(JSON.stringify(errores, null, 2));
    }

    console.log("================================");
}

main().catch(console.error);
