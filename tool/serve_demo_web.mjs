// Servidor de comprobación local, no un despliegue ni servidor de producción.
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
const root=path.resolve(process.argv[2]??'build/web');
const port=Number(process.argv[3]??5543);
if(![5543,5553].includes(port)) throw new Error('Puerto local no autorizado; usar5543demo o5553QA.');
createServer(async(req,res)=>{
 try{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const file=path.resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
  if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  const bytes=await readFile(file);
  const types={'.html':'text/html; charset=utf-8','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.svg':'image/svg+xml','.ttf':'font/ttf'};
  res.writeHead(200,{'Content-Type':types[path.extname(file)]??'application/octet-stream','Cache-Control':'no-store'});res.end(bytes);
 }catch{res.writeHead(404).end();}
}).listen(port,'127.0.0.1',()=>console.log(`Flutter en http://127.0.0.1:${port}; solo local.`));
