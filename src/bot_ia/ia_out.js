import { askGemini } from '../lib/gemini.js';

// memoria simple
const conversations = new Map();

const businessContext = `
Negocio: Florería Flores del Centro
Ubicación: Buenos Aires
Horarios: lunes a sábado de 9 a 18

Productos:
- simple: 2500 (económico y clásico)
- eucalipto: 3000 (vistoso y aromático)
- premium: 4500 (completo y elegante)

Envío:
- disponible
- costo: 1000

Pago:
- transferencia
- alias: flores.centro.mp

REGLAS:
- NO inventar productos
- NO inventar precios
- usar SOLO esta información
`;

function getConversation(userId) {
  if (!conversations.has(userId)) {
    conversations.set(userId, []);
  }
  return conversations.get(userId);
}

function updateConversation(userId, message, reply) {
  const history = getConversation(userId);

  history.push({ role: 'user', content: message });
  history.push({ role: 'assistant', content: reply });

  if (history.length > 10) {
    conversations.set(userId, history.slice(-10));
  }
}

function buildPrompt(message, history) {
  const historyText = history
    .map(m =>
      m.role === 'user'
        ? `Cliente: ${m.content}`
        : `Plipi: ${m.content}`
    )
    .join('\n');

  return `
Sos Plipi, vendedor experto por WhatsApp.

${businessContext}

OBJETIVO:
- vender
- avanzar la conversación SIEMPRE
- guiar al cliente hasta el pago

REGLAS:
- máximo 2 líneas
- tono argentino natural
- 1 sola pregunta
- no repetir lo mismo
- no volver al inicio
- no inventar nada

FLUJO DE VENTA:

1. si no sabe qué quiere → guiar (simple / eucalipto / premium)
2. si elige producto → dar precio
3. si falta cantidad → pedirla
4. si ya tiene todo → calcular total y confirmar
5. si confirma → dar alias
6. si paga → cerrar

COMPORTAMIENTO:

- si pide algo que no vendés → redirigir a flores
- si duda → simplificar opciones
- si ya eligió → no volver atrás

---

Conversación:
${historyText}

Cliente: ${message}

Plipi:
`;
}

export async function askPlipi(message, userId = 'demo') {
  const history = getConversation(userId);

  try {
    const prompt = buildPrompt(message, history);

    const reply = await askGemini(prompt);

    const finalReply =
      reply && reply.length > 3
        ? reply
        : '¿buscás algo simple o premium? 🌸';

    updateConversation(userId, message, finalReply);

    return {
      ok: true,
      reply: finalReply
    };

  } catch (err) {
    console.error('GEMINI ERROR:', err?.message || err);

    return {
      ok: false,
      reply: 'Estoy viendo las mejores opciones 👍 ¿es para regalo o para vos?'
    };
  }
}