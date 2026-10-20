import fs from "fs";

const INPUT = "dumpbdre.sql";
const OUTPUT = "dump_ordenado.sql";

const order = [
  "SCHEMA",
  "TYPE",
  "TABLE",
  "SEQUENCE",
  "FUNCTION",
  "VIEW",
  "INDEX",
  "CONSTRAINT",
  "TRIGGER",
  "ACL",
  "OTHER",
];

const sections = {};

for (const key of order) {
  sections[key] = [];
}

const sql = fs.readFileSync(INPUT, "utf8");

// Cabecera (todo antes del primer objeto)
const firstObject = sql.indexOf("--\n-- Name:");
const header = sql.substring(0, firstObject);

// Separar objetos
const objects = sql
  .substring(firstObject)
  .split(/(?=--\n-- Name:)/g);

for (const obj of objects) {
  const match = obj.match(/Type:\s*([^;]+);/);

  if (!match) {
    sections.OTHER.push(obj);
    continue;
  }

  const type = match[1].trim().toUpperCase();

  if (sections[type]) {
    sections[type].push(obj);
  } else {
    sections.OTHER.push(obj);
  }
}

// Ordenar alfabéticamente cada sección
for (const key of Object.keys(sections)) {
  sections[key].sort((a, b) => {
    const na = a.match(/Name:\s*([^;]+)/)?.[1] ?? "";
    const nb = b.match(/Name:\s*([^;]+)/)?.[1] ?? "";
    return na.localeCompare(nb);
  });
}

let out = header;

for (const key of order) {
  if (!sections[key].length) continue;

  out += `\n\n-- ======================================================\n`;
  out += `-- ${key}\n`;
  out += `-- ======================================================\n\n`;

  out += sections[key].join("\n");
}

fs.writeFileSync(OUTPUT, out);

console.log(`✔ Archivo generado: ${OUTPUT}`);