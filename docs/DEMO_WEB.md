# Preparar el paquete Web de la demo

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

El manifest dice `deployed: false`: generar el paquete no demuestra una URL pública, autenticación contra la API publicada ni entrega de correo/alertas en hosting. La aceptación pública necesita el par realmente servido, CORS exacto, migraciones, persistencia entre sesiones y proveedores configurados. Push Web sigue requiriendo permiso y una pestaña autenticada viva. Android/iOS y lectores de pantalla no se acreditan con este build.

Referencias oficiales: [configuración Build Output API](https://vercel.com/docs/build-output-api/configuration) y [recursos estáticos](https://vercel.com/docs/build-output-api/primitives). La semántica concreta de PWA none se contrastó con el SDK Flutter 3.41.9 instalado.
