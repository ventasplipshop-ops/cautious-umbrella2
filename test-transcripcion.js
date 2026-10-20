import "dotenv/config";
import { GoogleGenAI } from "@google/genai";
import util from "node:util";

const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
});

async function main() {

    console.log("Subiendo Pruebavoz.m4a...");

    const archivo = await ai.files.upload({
        file: "Pruebavoz.m4a",
        config: {
            mimeType: "audio/m4a"
        }
    });

    console.log("\n--- ARCHIVO SUBIDO ---\n");

    console.log(
        util.inspect(archivo, {
            depth: null,
            colors: true
        })
    );

    console.log("\nTranscribiendo con generateContent + diarización...");

    const response = await ai.models.generateContent({
        model: "gemini-3.5-transcribe",

        contents: [
            {
                role: "user",
                parts: [
                    {
                        fileData: {
                            fileUri: archivo.uri,
                            mimeType: archivo.mimeType
                        }
                    }
                ]
            }
        ],

        config: {
            audioTranscriptionConfig: {
                languageCodes: ["es-AR"],
                diarization: true,
                mode: "VERBATIM"
            }
        }
    });


    console.log("\n\n========================================");
    console.log("RESPONSE.TEXT");
    console.log("========================================\n");

    console.log(response.text);


    console.log("\n\n========================================");
    console.log("RESPUESTA COMPLETA");
    console.log("========================================\n");

    console.log(
        util.inspect(response, {
            depth: null,
            colors: true,
            maxArrayLength: null,
            maxStringLength: null,
            compact: false
        })
    );


    console.log("\n\n========================================");
    console.log("PARTS");
    console.log("========================================\n");

    const parts =
        response.candidates?.[0]?.content?.parts ?? [];

    console.log(
        util.inspect(parts, {
            depth: null,
            colors: true,
            maxArrayLength: null,
            maxStringLength: null,
            compact: false
        })
    );


    console.log("\n\n========================================");
    console.log("TRANSCRIPCIONES DE AUDIO");
    console.log("========================================\n");

    let cantidad = 0;

    for (const part of parts) {

        if (part.audioTranscription) {

            cantidad++;

            console.log(
                `\n--- SEGMENTO ${cantidad} ---`
            );

            console.log(
                util.inspect(
                    part.audioTranscription,
                    {
                        depth: null,
                        colors: true,
                        maxArrayLength: null,
                        maxStringLength: null,
                        compact: false
                    }
                )
            );
        }
    }

    console.log(
        `\nTotal segmentos encontrados: ${cantidad}`
    );
}


main().catch((error) => {

    console.error("\n\n========================================");
    console.error("ERROR");
    console.error("========================================\n");

    console.error(
        util.inspect(error, {
            depth: null,
            colors: true
        })
    );

    process.exit(1);
});