import { pool } from "../../db/pool.js";
import { createSqlService } from "./factory.js";
export default createSqlService(pool);
