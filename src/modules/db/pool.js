import pg from "pg";
import "dotenv/config";

export const pool = new pg.Pool({

    connectionString: process.env.DATABASE_URL,

    ssl: process.env.DB_SSL === "true"
        ? { rejectUnauthorized: false }
        : false

});