# Demo Web: publicación y preparación del paquete

## Publicación vigente del pulido y alertas — 04/11/2026

La [Web pública](https://crowdradar-demo-web.vercel.app) sirve `8ce8510123bba400b5ed628ba96c67f18a47b57c`, despliegue `dpl_4BcTtyyXUAfXxztGv2dDgLsS2sy9` en estado `READY`. La [API](https://crowdradar-demo-api.vercel.app) conserva `7780db488892a0dc3c45edfc7a9622b846e71847`. El paquete nuevo incorpora el pulido visual, control de alertas por dispositivo y transición histórica al abrir una alerta. Análisis limpio, 737 pruebas aprobadas/2 opt-in omitidas y build Web de 46,4 s. [Registro público saneado](evidence/demo-improvements-20261104/release-verification.json).

El control sin autenticación de las 23:45:18 UTC aprobó **37/37**: raíz más 28 archivos estáticos con tamaño/SHA256 coincidentes, siete rutas ausentes o privadas con 404 y HTTP→HTTPS 308. La fuente compilada produjo 29.982.782 bytes estáticos. Se conservan los workers, PWA `none`, no-cache/nosniff y ausencia de fallback HTML para recursos desconocidos.

La publicación reutilizó **9 blobs CanvasKit inmutables** del despliegue anterior, contrastados mediante un listado remoto nuevo de Vercel y coincidencia de SHA1/SHA256/tamaño con ambos manifests. Se confirmaron **4 cargas nuevas** y se incluyeron **16 archivos pequeños inline**, incluida la configuración. No se atribuyen trece cargas nuevas ni una recompilación remota a esta versión. El manifest local conserva `deployed: false` como registro de compilación; la publicación se acredita por separado.

**Alias y reversión:** `createDeployment` llegó a `READY` sin cambiar `crowdradar-demo-web.vercel.app`. El control previo a la asignación dio 35/37: `main.dart.js` y `MaterialIcons-Regular.otf` aún coincidían con la versión anterior. La operación explícita `assign_alias` del nuevo despliegue al alias habitual reemplazó `dpl_cWMnw46YkbA893DRGNmkwokhTZv2`; la repetición posterior pasó 37/37. Ambos resultados se conservan. Para revertir esta publicación, asignar el mismo alias a `dpl_cWMnw46YkbA893DRGNmkwokhTZv2` y verificar después los hashes del paquete anterior y el acceso público; no cambiar SQL ni la API para esta reversión del frontend.

La baja/reactivación real y la recepción/apertura con transición quedaron confirmadas en Chrome: cero envíos con el dispositivo eliminado, un evento `MODERADO→SATURADO` después de reactivarlo y cero envíos en el ciclo siguiente sin cambio. Rael confirmó recepción, apertura de Kennedy y el banner. [Evidencia de ese ciclo](evidence/demo-improvements-20261104/push-toggle-human-acceptance.json). La ficha muestra el cambio histórico y no añade una consulta del nivel actual. El recorrido visual ampliado y las capturas nuevas siguen pendientes tras detenerse el control del navegador con Esc. Los registros anteriores de GUI, correo y FCM conservan el par `a4919f0`/`7780db4` y no se reatribuyen a este paquete.

## Primera publicación verificada (antecedente) — 04/11/2026

La demo pública está disponible en [crowdradar-demo-web.vercel.app](https://crowdradar-demo-web.vercel.app), con API en [crowdradar-demo-api.vercel.app](https://crowdradar-demo-api.vercel.app). El despliegue Web `dpl_cWMnw46YkbA893DRGNmkwokhTZv2` está `READY` y sirve el paquete compilado desde el SHA frontend `a4919f021157632a4e6500855c6d32acff2f0ab9`. La API publicada corresponde al SHA backend `7780db488892a0dc3c45edfc7a9622b846e71847`; sus rutas `/` y `/health/ready` respondieron HTTP 200 sin autenticación.

La verificación HTTP pública aprobó **37/37 comprobaciones**, sin cookies ni credenciales: raíz y 28 archivos estáticos HTTP 200, siete rutas ausentes o privadas HTTP 404 y redirección HTTP→HTTPS 308. Los tamaños y SHA256 de los 28 archivos coinciden con el paquete local, incluidos `main.dart.js`, worker push, logo, fuentes y WASM. Se validaron certificado y nombre TLS, tipos de contenido y cabeceras `no-cache, no-store, must-revalidate`, `nosniff`, Referrer-Policy y HSTS. Esa política de respuesta no implica ausencia de caché interna del CDN.

El recorrido real en el navegador integrado aprobó siete comprobaciones: login mediante el formulario público; mapa con cinco lugares y teselas OpenStreetMap; agregar Museo Amano desde el mapa y verlo en Favoritos; abrir detalle e historial; retirar el favorito y volver a la lista vacía; enviar un reporte MODERADO desde la interfaz; y consultar los reportes propios, incluidos el previo por API y el nuevo por interfaz. El saldo mostrado al final fue 20. El repositorio incluye el [registro del recorrido](evidence/demo-20261104/public-ui-acceptance.json) y capturas de [mapa](evidence/demo-20261104/web-public-map.png), [favoritos](evidence/demo-20261104/web-public-favorite.png) e [historial](evidence/demo-20261104/web-public-history.png), revisadas sin credenciales ni datos personales. Las otras capturas referenciadas y los controles `frontend-public-http-smoke.json`, `frontend-deployment-verification.json` y `api-public-readiness-http.json` permanecen fuera de Git en `tmp/cierre-demo-web-20261104/qa`.

**FCM recibido y abierto en el dominio publicado:** en Chrome normal de Rael, tres reportes reales HTTP 201 del Parque John F. Kennedy produjeron `SATURADO→MODERADO`. El cron de Supabase invocó la API Vercel; outbox 2 quedó `SENT` a las 22:46:00 UTC, con un intento y sin error. Rael confirmó: «Sí, llegó y abrió Parque Kennedy». El resultado acredita recepción y apertura del lugar, además de la aceptación del proveedor. Diez ejecuciones automáticas anteriores sin cambio de nivel enviaron cero alertas. El [registro de aceptación humana](evidence/demo-20261104/public-push-human-acceptance.json) está incluido en el repositorio; sus logs de diagnóstico permanecen en la carpeta QA local. El primer intento de las 17:35 Lima conserva solo aceptación del proveedor; el usuario no estuvo seguro de haberlo visto y pidió esta repetición.

**Recuperación por correo confirmada:** después de la solicitud HTTP 202 de las 22:47:57 UTC (17:47:57 Lima), Rael confirmó «Sí, llegaron ambos y pude entrar»: recibió el correo de recuperación, cambió personalmente la contraseña mediante el enlace, recibió el aviso del cambio y volvió a iniciar sesión. La comprobación SQL de solo lectura observó `sessionVersion` 0→1, token de recuperación consumido, dispositivos elegibles de la sesión anterior 1→0 y favorito Kennedy conservado. El [registro de aceptación de recuperación](evidence/demo-20261104/public-recovery-human-acceptance.json) identifica el par publicado y la evidencia sin contraseñas, hashes, valores de token ni enlaces privados. El envío SMTP sigue siendo diferido, sin cola durable ni garantía de reintentos automáticos.

La prueba FCM mantuvo una pestaña autenticada abierta; no acredita entrega con la aplicación cerrada, Android o iOS. El recorrido GUI documentado no representa una repetición exhaustiva de todas las historias ni una prueba de lector de pantalla.

La publicación conservó los bytes estáticos de `.vercel/output/static`, enviados como archivos `public/` y un `vercel.json` con las mismas rutas y cabeceras, `framework: null`, comandos de instalación/build vacíos y `outputDirectory: public`. Se aceptaron 13 archivos grandes por huella y se incluyeron 16 archivos pequeños en la petición, incluida esa configuración. No se recompiló Flutter en Vercel ni se utilizó un parámetro `prebuilt` inexistente en el conector.

## Preparación local

La herramienta local genera Vercel Build Output API v3 en `.vercel/output`. No inicia un despliegue, no crea proyectos ni cambia Firebase. El destino de la API debe existir y quedar verificado por separado. Este procedimiento usa la misma aplicación Flutter; no cambia su interfaz, rutas, dependencias ni lógica de favoritos.

## Entradas admitidas

- Un SHA completo revisado, igual al HEAD de este repositorio y con árbol Git limpio, incluidos archivos no rastreados. La herramienta comprueba de nuevo ese estado después de compilar.
- Flutter **3.41.9**, revisión `00b0c91f06209d9e4a41f71b7a512d6eb3b9c694`, y Dart **3.11.5** instalados.
- Origen API **HTTPS**, sin credenciales, ruta, puerto alternativo, parámetros ni fragmento. No se admiten direcciones IP, localhost o dominios locales.
- Solo las seis claves públicas de `tool/demo_firebase_public.json`: API key de navegador, dominio Auth, sender ID, project ID, Web app ID y VAPID pública. Pertenecen a `crowdradar-hu8-web`; se verifica la huella del conjunto exacto. No son una cuenta de servicio ni una clave privada. Toda clave extra o valor distinto se rechaza.

Una rotación autorizada de configuración pública requiere actualizar el archivo y la huella en `demo_web_output.mjs` con nueva evidencia. Nunca añadir JWT, contraseña, URL de base de datos, token de recuperación o JSON de cuenta de servicio al archivo de defines.

## Ejecución local

Primero registrar y revisar el pequeño cambio de tooling. El empaquetador rechaza un árbol con cambios pendientes; no crea commits automáticamente. Desde este repositorio, sustituir los valores entre ángulos:

```powershell
.\tool\build_demo_web.ps1 `
  -ExpectedSha '<SHA completo del commit revisado>' `
  -ApiOrigin '<origen HTTPS de la API verificada>' `
  -FirebaseDefinesPath '.\tool\demo_firebase_public.json' `
  -FlutterSdkPath '<directorio del SDK Flutter 3.41.9>'
```

El proceso ejecuta `pub get --offline --enforce-lockfile`, análisis, pruebas Flutter y build release. Utiliza únicamente dependencias del lock ya disponibles en la caché local; no actualiza versiones. Si falta un paquete, detenerse y resolver la caché de manera explícita. Las salidas y logs quedan ignorados bajo `.vercel/`; el build Flutter queda en `build/web/`.

La compilación usa `--pwa-strategy=none --no-source-maps --no-web-resources-cdn`. El worker de caché de Flutter queda vacío y no se registra desde el bootstrap; `crowdradar-push.js` y `push/firebase-messaging-sw.js` se conservan byte por byte. Firebase JS y el mapa siguen usando sus proveedores externos.

## Verificación y entrega

```powershell
node --test tool/demo_web_output.test.mjs
git diff --check
```

Los seis controles cubren configuración pública válida, claves/archivos prohibidos, orígenes inseguros, identidad Firebase ajena, SHA/árbol modificado y salida previa. Sus fixtures quedan en la carpeta QA hermana; no forman parte del paquete ni del repositorio.

El manifest `.vercel/demo-manifest.json` identifica SHA/tree de origen, SDK, API, huella de configuración pública, lock y hashes/tamaños de cada archivo servido. Se mantiene fuera de `static/`. El paquete contiene solo recursos compilados y `config.json`; omite `.last_build_id` y símbolos de depuración. No copia fuentes, env, SDK, pruebas ni node_modules. Los archivos inesperados, enlaces simbólicos y patrones de claves privadas detienen el empaquetado.

Todas las respuestas llevan no-cache/no-store y nosniff. Solo `/` apunta a `index.html`: no existe un fallback SPA general. Flutter conserva navegación con fragmento `#`, por lo que un worker o recurso inexistente conserva el 404 y nunca recibe HTML como sustituto. La configuración expresa el tipo JavaScript del worker push.

**No se sobrescribe ni elimina una salida anterior.** Si ya existe `build/web`, `.vercel/output` o evidencia de una ejecución anterior, se detiene antes de compilar. Conservar esos resultados y preparar una nueva copia limpia para otro intento; nunca borrar evidencia automáticamente. Un fallo parcial queda disponible para inspección.

El manifest de compilación conserva `deployed: false`: describe el empaquetado y no se reescribe después de publicar. El despliegue y las comprobaciones públicas se registran por separado en el corte superior. Generar o servir el paquete no acredita el recorrido autenticado, persistencia entre sesiones ni recepción de correo/alertas en hosting. Push Web sigue requiriendo permiso y una pestaña autenticada viva. Android/iOS y lectores de pantalla no se acreditan con este build.

Referencias oficiales: [configuración Build Output API](https://vercel.com/docs/build-output-api/configuration) y [recursos estáticos](https://vercel.com/docs/build-output-api/primitives). La semántica concreta de PWA none se contrastó con el SDK Flutter 3.41.9 instalado.
