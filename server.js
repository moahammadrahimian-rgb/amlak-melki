const express = require("express");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const multer = require("multer");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "CHANGE_THIS_SECRET_IN_PRODUCTION";
const DATA = path.join(__dirname, "../data");
const USERS = path.join(DATA, "users.json");
const PROPS = path.join(DATA, "properties.json");
const UPLOADS = path.join(__dirname, "../uploads");
fs.mkdirSync(DATA,{recursive:true}); fs.mkdirSync(UPLOADS,{recursive:true});
if(!fs.existsSync(USERS)) fs.writeFileSync(USERS,"[]");
if(!fs.existsSync(PROPS)) fs.writeFileSync(PROPS,"[]");

app.use(cors());
app.use(express.json({limit:"2mb"}));
app.use("/uploads", express.static(UPLOADS));

const read = f => JSON.parse(fs.readFileSync(f,"utf8"));
const write = (f,d) => fs.writeFileSync(f, JSON.stringify(d,null,2));

function auth(req,res,next){
  const h=req.headers.authorization||"";
  if(!h.startsWith("Bearer ")) return res.status(401).json({error:"نیاز به ورود"});
  try{ req.user=jwt.verify(h.slice(7),JWT_SECRET); next(); }
  catch(e){ return res.status(401).json({error:"توکن نامعتبر"}); }
}

app.get("/api/health",(req,res)=>res.json({ok:true,service:"amlak-melki",version:"v3"}));

app.post("/api/auth/register", async (req,res)=>{
  const {name,email,password,phone}=req.body||{};
  if(!email||!password) return res.status(400).json({error:"ایمیل و رمز عبور الزامی است"});
  const users=read(USERS);
  if(users.some(u=>u.email.toLowerCase()===email.toLowerCase()))
    return res.status(409).json({error:"این ایمیل قبلا ثبت شده است"});
  const user={id:Date.now().toString(),name:name||"",email,phone:phone||"",password:await bcrypt.hash(password,10),role:"user",createdAt:new Date().toISOString()};
  users.push(user); write(USERS,users);
  const token=jwt.sign({id:user.id,email:user.email,role:user.role},JWT_SECRET,{expiresIn:"7d"});
  res.json({token,user:{id:user.id,name:user.name,email:user.email,phone:user.phone,role:user.role}});
});

app.post("/api/auth/login", async (req,res)=>{
  const {email,password}=req.body||{}; const user=read(USERS).find(u=>u.email===email);
  if(!user||!(await bcrypt.compare(password,user.password))) return res.status(401).json({error:"ایمیل یا رمز عبور اشتباه است"});
  const token=jwt.sign({id:user.id,email:user.email,role:user.role},JWT_SECRET,{expiresIn:"7d"});
  res.json({token,user:{id:user.id,name:user.name,email:user.email,phone:user.phone,role:user.role}});
});

app.get("/api/me",auth,(req,res)=>{
  const u=read(USERS).find(x=>x.id===req.user.id); if(!u) return res.status(404).json({error:"کاربر پیدا نشد"});
  delete u.password; res.json({user:u});
});

app.get("/api/properties",(req,res)=>{
  let p=read(PROPS).filter(x=>x.status!=="rejected");
  const q=(req.query.q||"").toLowerCase().trim();
  if(q) p=p.filter(x=>[x.title,x.city,x.neighborhood,x.type,x.description].join(" ").toLowerCase().includes(q));
  res.json({properties:p.sort((a,b)=>new Date(b.createdAt)-new Date(a.createdAt))});
});

app.post("/api/properties",auth,(req,res)=>{
  const body=req.body||{};
  if(!body.title||!body.city) return res.status(400).json({error:"عنوان و شهر الزامی است"});
  const p={id:Date.now().toString(),ownerId:req.user.id,title:body.title,city:body.city,neighborhood:body.neighborhood||"",type:body.type||"فروش",price:body.price||"",area:body.area||"",phone:body.phone||"",description:body.description||"",images:[],status:"pending",createdAt:new Date().toISOString()};
  const all=read(PROPS); all.push(p); write(PROPS,all); res.status(201).json({property:p});
});

app.post("/api/properties/:id/images",auth,(req,res)=>{
  const p=read(PROPS); const item=p.find(x=>x.id===req.params.id);
  if(!item) return res.status(404).json({error:"آگهی پیدا نشد"});
  if(item.ownerId!==req.user.id && req.user.role!=="admin") return res.status(403).json({error:"دسترسی ندارید"});
  res.json({message:"آپلود تصویر در API آماده است؛ برای multipart از endpoint آپلود استفاده شود.",images:item.images||[]});
});

const upload=multer({storage:multer.diskStorage({
  destination:(req,file,cb)=>cb(null,UPLOADS),
  filename:(req,file,cb)=>cb(null,Date.now()+"-"+Math.random().toString(36).slice(2)+path.extname(file.originalname))
}),limits:{fileSize:8*1024*1024}});

app.post("/api/upload",auth,upload.array("images",10),(req,res)=>{
  const urls=(req.files||[]).map(f=>"/uploads/"+f.filename);
  res.json({images:urls});
});

app.post("/api/properties/:id/approve",auth,(req,res)=>{
  if(req.user.role!=="admin") return res.status(403).json({error:"فقط مدیر"});
  const all=read(PROPS); const item=all.find(x=>x.id===req.params.id);
  if(!item) return res.status(404).json({error:"آگهی پیدا نشد"});
  item.status="approved"; write(PROPS,all); res.json({property:item});
});

app.delete("/api/properties/:id",auth,(req,res)=>{
  const all=read(PROPS); const i=all.findIndex(x=>x.id===req.params.id);
  if(i<0) return res.status(404).json({error:"آگهی پیدا نشد"});
  if(all[i].ownerId!==req.user.id && req.user.role!=="admin") return res.status(403).json({error:"دسترسی ندارید"});
  const x=all.splice(i,1)[0]; write(PROPS,all); res.json({deleted:x.id});
});

app.listen(PORT,()=>console.log(`Amlak Melki API running on ${PORT}`));
