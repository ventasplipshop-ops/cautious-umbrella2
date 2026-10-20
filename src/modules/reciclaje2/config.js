// Instalación deliberadamente monoempresa. No representa un catálogo SQL.
export const COMPANY_ID = "11111111-1111-1111-1111-111111111111";

// Los UUID deben conservarse estables en el entorno de cada instalación.
// Las contraseñas nunca se almacenan en este repositorio.
export const LOCAL_USERS = [
  {
    id: process.env.RECICLAJE2_ADMIN_ID,
    email: process.env.RECICLAJE2_ADMIN_EMAIL ?? "admin@reciclaje.com",
    password: process.env.RECICLAJE2_ADMIN_PASSWORD,
    nombre: process.env.RECICLAJE2_ADMIN_NAME ?? "Administrador",
    role: "admin",
  },
  {
    id: process.env.RECICLAJE2_ADMIN2_ID,
    email: process.env.RECICLAJE2_ADMIN2_EMAIL ?? "admin2@reciclaje.com",
    password: process.env.RECICLAJE2_ADMIN2_PASSWORD,
    nombre: process.env.RECICLAJE2_ADMIN2_NAME ?? "Administrador",
    role: "admin",
  },
  {
    id: process.env.RECICLAJE2_COMPRADOR_ID,
    email: process.env.RECICLAJE2_COMPRADOR_EMAIL ?? "comprador@reciclaje.com",
    password: process.env.RECICLAJE2_COMPRADOR_PASSWORD,
    nombre: process.env.RECICLAJE2_COMPRADOR_NAME ?? "Comprador",
    role: "comprador",
  },
    {
    id: process.env.RECICLAJE2_SUCURSAL_ID,
    email: process.env.RECICLAJE2_SUCURSAL_EMAIL ?? "sucursal@reciclaje.com",
    password: process.env.RECICLAJE2_SUCURSAL_PASSWORD,
    nombre: process.env.RECICLAJE2_SUCURSAL_NAME ?? "sucursal",
    role: "sucursal",
  },
];

export const AUTH_SECRET = process.env.RECICLAJE2_AUTH_SECRET;
export const AUTH_TTL_SECONDS = Number(process.env.RECICLAJE2_AUTH_TTL_SECONDS ?? 28800);

