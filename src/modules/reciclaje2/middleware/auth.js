import crypto from "crypto";
import { AUTH_SECRET, COMPANY_ID, LOCAL_USERS } from "../config.js";
// PostgreSQL acepta el formato UUID sin exigir versión/variante RFC.
const UUID_RE=/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const encode=(value)=>Buffer.from(JSON.stringify(value)).toString("base64url");
const signature=(data,secret)=>crypto.createHmac("sha256",secret).update(data).digest("base64url");
export function issueToken(user,secret=AUTH_SECRET,now=Math.floor(Date.now()/1000),ttl=28800){if(!secret)throw authConfigError();const data=`${encode({alg:"HS256",typ:"JWT"})}.${encode({sub:user.id,role:user.role,company_id:COMPANY_ID,iat:now,exp:now+ttl})}`;return `${data}.${signature(data,secret)}`;}
export function verifyToken(token,secret=AUTH_SECRET,now=Math.floor(Date.now()/1000)){if(!secret)throw authConfigError();const parts=String(token??"").split(".");if(parts.length!==3)throw unauthorized();const data=`${parts[0]}.${parts[1]}`;const expected=Buffer.from(signature(data,secret));const actual=Buffer.from(parts[2]);if(expected.length!==actual.length||!crypto.timingSafeEqual(expected,actual))throw unauthorized();let payload;try{payload=JSON.parse(Buffer.from(parts[1],"base64url").toString("utf8"));}catch{throw unauthorized();}if(payload.exp<=now||payload.company_id!==COMPANY_ID||!UUID_RE.test(String(payload.sub??"")))throw unauthorized();const user=LOCAL_USERS.find(x=>x.id===payload.sub&&x.role===payload.role);if(!user)throw unauthorized();return {id:user.id,user_id:user.id,email:user.email,nombre:user.nombre,role:user.role,company_id:COMPANY_ID};}
export function authenticateLocal(req,res,next){try{const header=req.get?.("authorization")??req.headers?.authorization??"";if(!header.startsWith("Bearer "))throw unauthorized();req.auth=verifyToken(header.slice(7));req.companyId=COMPANY_ID;req.userId=req.auth.user_id;next();}catch(error){next(error);}}
export function safePasswordEqual(received,expected){if(!expected)return false;const a=Buffer.from(String(received??""));const b=Buffer.from(String(expected));return a.length===b.length&&crypto.timingSafeEqual(a,b);}
export function assertLocalConfig(){if(!AUTH_SECRET||!Number.isFinite(Number(process.env.RECICLAJE2_AUTH_TTL_SECONDS??28800))||LOCAL_USERS.some(x=>!UUID_RE.test(String(x.id??""))||!x.password))throw authConfigError();}
function unauthorized(){const e=new Error("Credenciales inválidas o sesión expirada.");e.status=401;return e;}
function authConfigError(){const e=new Error("Autenticación local de Reciclaje2 no configurada.");e.status=503;return e;}
