import { Router } from "express";
import { AUTH_TTL_SECONDS, LOCAL_USERS } from "./config.js";
import { assertLocalConfig, authenticateLocal, issueToken, safePasswordEqual } from "./middleware/auth.js";
import { asyncHandler } from "./http.js";
const router=Router();
router.post("/login",asyncHandler(async(req,res)=>{assertLocalConfig();const email=String(req.body?.email??"").trim().toLowerCase();const user=LOCAL_USERS.find(x=>x.email.toLowerCase()===email);if(!user||!safePasswordEqual(req.body?.password,user.password)){const e=new Error("Email o contraseña incorrectos.");e.status=401;throw e;}const token=issueToken(user,undefined,undefined,AUTH_TTL_SECONDS);res.json({token,user:{id:user.id,email:user.email,nombre:user.nombre,role:user.role}});}));
router.get("/me",authenticateLocal,(req,res)=>res.json({user:{id:req.auth.id,email:req.auth.email,nombre:req.auth.nombre,role:req.auth.role},company_id:req.auth.company_id}));
export default router;

