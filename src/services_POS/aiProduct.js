import { askGemini, safeJSONParse } from '../lib/gemini.js';
import { pool } from '../db/pool.js';

function cleanText(value) {
  if (!value) return '';
  return String(value).trim();
}

function normalizeKey(value) {
  return cleanText(value).toLowerCase();
}

function normalizeTags(tags) {
  if (!Array.isArray(tags)) return [];

  const seen = new Set();

  return tags
    .map((tag) => normalizeKey(tag))
    .filter(Boolean)
    .filter((tag) => {
      if (seen.has(tag)) return false;
      seen.add(tag);
      return true;
    })
    .slice(0, 8);
}

async function getCategories() {
  const { rows } = await pool.query(`
    select name
    from tenant.categories
    order by name asc
  `);

  return rows
    .map((row) => cleanText(row.name))
    .filter(Boolean);
}

function validateCategory(rawCategory, categories) {
  const normalizedInput = normalizeKey(rawCategory);

  if (!normalizedInput) return 'otros';

  const match = categories.find(
    (category) => normalizeKey(category) === normalizedInput
  );

  return match || 'otros';
}

export async function enrichProductAI({ name }) {
  const safeName = cleanText(name) || 'Producto';

  try {
    let categories = [];

    try {
      categories = await getCategories();
    } catch (dbErr) {
      console.error('GET CATEGORIES ERROR:', dbErr.message);
    }

    if (!categories.length) {
      categories = ['otros'];
    } else if (!categories.some((c) => normalizeKey(c) === 'otros')) {
      categories.push('otros');
    }

    const prompt = `
Clasifica este producto para un sistema POS.

Nombre: ${safeName}

Categorias disponibles:
${categories.map((c) => `- ${c}`).join('\n')}

Debes responder SOLO un JSON válido con esta forma:
{
  "categoria": "...",
  "subcategoria": "...",
  "descripcion_corta": "...",
  "descripcion_larga": "...",
  "tags": ["...", "..."]
}

Reglas obligatorias:
- "categoria" debe ser EXACTAMENTE una de las categorias disponibles
- si no estás seguro, usa "otros"
- "subcategoria" puede ser libre y breve
- "descripcion_corta" debe ser una frase corta comercial
- "descripcion_larga" debe ser una descripción comercial breve
- "tags" debe ser un array de palabras o frases cortas
- no agregues texto fuera del JSON
`;

    let raw = await askGemini(prompt);

    // 🔍 detectar respuesta truncada
    if (!raw || !raw.includes('}')) {
      console.log('⚠️ AI TRUNCATED → retry...');
      raw = await askGemini(prompt);
    }

    // 🔍 parse
    let parsed = safeJSONParse(raw);

    // 🔍 retry si parse falla
    if (!parsed) {
      console.log('⚠️ AI PARSE FAIL → retry...');
      raw = await askGemini(prompt);
      parsed = safeJSONParse(raw);
    }

    // 🔴 si sigue fallando → fallback
    if (!parsed || typeof parsed !== 'object') {
      return {
        ai_status: 'fallback',
        categoria: 'otros',
        subcategoria: 'general',
        descripcion_corta: safeName,
        descripcion_larga: safeName,
        tags: [],
      };
    }

    const categoria = validateCategory(parsed.categoria, categories);
    const subcategoria = cleanText(parsed.subcategoria) || 'general';
    const descripcion_corta =
      cleanText(parsed.descripcion_corta) || safeName;
    const descripcion_larga =
      cleanText(parsed.descripcion_larga) || safeName;
    const tags = normalizeTags(parsed.tags);

    // 🔍 detectar calidad (esto es lo clave)
    let ai_status = 'ok';

    if (categoria === 'otros') {
      ai_status = 'low_confidence';
    }

    if (!parsed.categoria || !parsed.subcategoria) {
      ai_status = 'fallback';
    }

    return {
      ai_status,
      categoria,
      subcategoria,
      descripcion_corta,
      descripcion_larga,
      tags,
    };
  } catch (err) {
    console.error('AI PRODUCT ERROR:', err.message);

    return {
      ai_status: 'fallback',
      categoria: 'otros',
      subcategoria: 'general',
      descripcion_corta: safeName,
      descripcion_larga: safeName,
      tags: [],
    };
  }
}