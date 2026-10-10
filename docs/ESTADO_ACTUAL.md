# Estado actual

## Hito A — pulido aplicado, 08/10/2026

Rama `feature/ui-flujos-ciudadano`, padre `feature/hu-3-1-mapa-lugares` en `f2437a2991293fa275626e4d5e8819a22b1aed2a`. HU 3.1/PR #9 sigue sin integrar; esta rama no modifica ese PR ni `develop`/`main`.

Tema neutro, tarjetas claras, formularios contenidos, logo compacto y espaciado compartido. Perfil/edición 680/560 dp, carga inicial/reintento, errores públicos y timeout 15 s; guardar no elimina formulario y bloquea doble envío. Navegación inferior crece con texto ampliado. Mapa conserva datos demostrativos y atribución, sin funciones nuevas. Contratos, dependencias y sesión no cambiaron.

Validación: `flutter analyze --no-pub` sin problemas; `flutter test --no-pub` 110/110 (69 anteriores +37 perfil/edición +4 layouts); build Web correcto. Widgets 360/390/1440 dp, texto 2× y teclado simulado, no recorrido manual. La primera ejecución focalizada detectó overflow de 2 px en navegación 2× y un fixture lazy; ambos corregidos, suite global aprobada sin ocultar excepciones.

[Capturas antes/después y límites](evidencias/ui_flujos_2026_10_08/README.md). No se repitió Chrome normal, IAB ni Android: revisión manual pendiente. No se eludió la detención de seguridad de Chrome. Sin afirmar certificación de accesibilidad ni cierre de Sprint.

## Registro histórico — cierre local HU 3.1 / Web, 07/10/2026

Fotografía de la validación local del 07/10/2026, anterior a su publicación: rama `feature/hu-3-1-mapa-lugares`, HEAD/base `f214886d7a40aabfc3b10b0af1a266128cc421fe`, entonces sin staging, commit ni publicación. HU 2.4 integrada se conserva, con JWT sin revocación backend. Para conocer la publicación/integración posterior, comprobar Git y los PR relacionados; los resultados siguientes conservan su fecha y alcance.

## Validación final Web y formularios

- `dart format` únicamente sobre los 17 Dart candidatos; el formateo incidental de otros archivos se revirtió y no queda en el diff.
- `flutter analyze --no-pub`: `No issues found!`, código 0.
- `flutter test --no-pub`: **69: All tests passed!**, código 0. Incluye los 25 casos anteriores HU 2.4, 23 de lugares/mapa, 7 de layout/navegación Web y 14 de usabilidad/servicio de autenticación. Cubre 1440×900, 390×844 y 360×360, sin ocultar overflows/excepciones.
- `flutter build web --no-pub --dart-define=API_BASE_URL=http://localhost:3000`: **Built build/web**, `58,7 s`, código 0; dry-run Wasm correcto, avisos informativos de tree-shaking. No se probó un despliegue de ese build release; el recorrido fue sobre el servidor de desarrollo de la misma app.
- `git diff --check`: código 0. Sin cambios de pubspec, lockfile, Gradle ni dependencias. `web/index.html` solo bootstrap de Flutter.

Los intentos intermedios detectaron getters incorrectos en el test de visibilidad y avisos de estilo; después, 68 pruebas pasaron y 1 falló por una respuesta simulada con texto español sin charset UTF-8. Se corrigió el doble HTTP (el backend real usa JSON UTF-8), sin ocultar el resultado. La ejecución final anterior aprobó los 69 casos.

## Recorrido manual Web verificado

URL **http://localhost:5500/#/login**, API **http://localhost:3000**, PostgreSQL 18 local `crowdradar_dev`. Chrome fue iniciado con `flutter run -d chrome --web-hostname=localhost --web-port=5500 --no-pub --dart-define=API_BASE_URL=http://localhost:3000`; no usa `--disable-web-security`. Oracle sigue en IPv4 `127.0.0.1:5500`; Flutter en IPv6 `::1:5500`. No se cambió a 5000 ni se detuvo Oracle.

**Alcance de la evidencia:** el recorrido interactivo siguiente se ejecutó en el navegador integrado (IAB), sobre esa app Flutter y URL local. El control del Chrome normal no estuvo disponible de forma fiable; queda pendiente repetirlo allí con Rael. No se presenta IAB como Chrome normal. Contraseña aleatoria local de 40 caracteres ASCII, solo en memoria, oculta en capturas; sin credencial predeterminada ni autoalmacenamiento.

| Paso | Resultado observado en IAB |
| --- | --- |
| Registro nuevo | Rael / Chang, correo QA único, teléfono 9 dígitos y Miraflores. Volvió a login con «Cuenta creada. Ya puedes iniciar sesión…». SQL confirmó usuario y bcrypt en crowdradar_dev. |
| Correo repetido | «El correo ya está registrado. Inicia sesión o usa otro correo.», sin perder los campos. |
| Validación de seis campos | Formulario vacío mostró errores por nombre/apellido/distrito, correo, contraseña y teléfono; requisitos visibles. Malformados/límite UTF-8 cubiertos además por tests. |
| Login recién registrado | Abrió `/#/map`; consulta autenticada y 3 lugares recibidos. |
| Contraseña incorrecta | «Correo o contraseña incorrectos.», sin abrir sesión. |
| Backend apagado | Se detuvo solo nuestro servidor, puerto 3000 sin listener; login mostró mensaje comprensible y formulario conservado. Se reinició backend y GET / respondió 200. |
| Mapa y marcadores | Teselas OpenStreetMap y 3 marcadores; aviso demostrativo/sin tiempo real. |
| Selección | Demo · Parque Central / Parque · Demostrativo; no detalles completos. |
| Cierre | Perfil mostró Rael Chang; Cerrar sesión volvió a login con campos vacíos. |
| Reingreso protegido | Entradas a `/#/map`, `/#/validar`, `/#/favoritos`, `/#/profile`, `/#/profile/edit` redirigieron a `/#/login`. |
| Recargas | Recarga completa en `/#/login`: formulario vacío; en `/#/register`: registro público; en `/#/map` sin sesión: URL final `/#/login`. Una espera automatizada de accesibilidad expiró mientras cargaba Flutter; después se inspeccionó y activó la accesibilidad, sin cambiar la app ni desactivar seguridad. La prueba automatizada también cubre éxito de registro sin historial previo. |
| Diseño y teclado | 390×844 y 1440×900 inspeccionados; Tab desde Distrito alcanzó Registrarme; mostrar/ocultar probado sin revelar la credencial. No es una auditoría completa WCAG/lector de pantalla. |

Capturas nuevas (no reemplazan las Android): [mapa/identificación](evidencias/hu_3_1/web_2026_10_07/01_mapa_identificacion.jpg), [backend apagado](evidencias/hu_3_1/web_2026_10_07/02_login_backend_apagado.jpg), [login móvil](evidencias/hu_3_1/web_2026_10_07/03_login_movil.jpg), [registro móvil](evidencias/hu_3_1/web_2026_10_07/04_registro_movil.jpg), [validaciones escritorio](evidencias/hu_3_1/web_2026_10_07/05_validaciones_escritorio.jpg).

### Problema observado y corrección contenida

Antes no se explicaban todos los requisitos; el formulario desaparecía durante la solicitud y errores de red podían mostrar `ClientException`. Registro directo podía intentar volver sin historial. Se añadieron ayudas, validación coherente 8 caracteres/72 bytes, mostrar/ocultar, estados inline públicos con región accesible, campos/botones deshabilitados durante la solicitud y descarte de respuestas antiguas. Un error de registro no se muestra como error de login. Ancho máximo 480, centrado/scroll; no se rediseñó el resto. No hay prueba que permita atribuir todo el fallo original de Rael a una única causa de infraestructura; las deficiencias de interfaz/código sí están identificadas.

Pendientes reales: Chrome normal, clonación limpia de este incremento aún no publicado, revisión de equipo y fuente canónica; sesión solo en memoria, JWT no revocado, User.sync histórico, OSM requiere Internet. No se repitió Android tras las últimas correcciones de formulario. No se implementaron recuperación/restablecimiento/cambio, saturación ni detalle completo.

## Inventario final para revisión (sin staging)

29 archivos: 9 modificados y 20 nuevos. `M`/`??` reproducen `git status --porcelain=v1 --untracked-files=all` desde la raíz del repositorio frontend. Incluyen el incremento previo conservado, no solo los ajustes de este cierre.

```text
 M README.md
 M docs/ESTADO_ACTUAL.md
 M lib/components/cr_bottom_nav.dart
 M lib/configs/api_config.dart
 M lib/cubits/login_cubit.dart
 M lib/pages/login/login_page.dart
 M lib/pages/map/map_page.dart
 M lib/pages/register/register_page.dart
 M lib/services/auth_service.dart
?? docs/evidencias/hu_3_1/2026_10_07/01_mapa_lugares.png
?? docs/evidencias/hu_3_1/2026_10_07/02_identificacion.png
?? docs/evidencias/hu_3_1/2026_10_07/03_error_backend_apagado.png
?? docs/evidencias/hu_3_1/2026_10_07/04_reintento_correcto.png
?? docs/evidencias/hu_3_1/web_2026_10_07/01_mapa_identificacion.jpg
?? docs/evidencias/hu_3_1/web_2026_10_07/02_login_backend_apagado.jpg
?? docs/evidencias/hu_3_1/web_2026_10_07/03_login_movil.jpg
?? docs/evidencias/hu_3_1/web_2026_10_07/04_registro_movil.jpg
?? docs/evidencias/hu_3_1/web_2026_10_07/05_validaciones_escritorio.jpg
?? lib/components/auth_fields.dart
?? lib/components/auth_form_layout.dart
?? lib/cubits/places/places_cubit.dart
?? lib/cubits/places/places_state.dart
?? lib/models/place_model.dart
?? lib/services/place_service.dart
?? test/auth_usability_test.dart
?? test/map_page_test.dart
?? test/places_test.dart
?? test/web_layout_navigation_test.dart
?? web/index.html
```

Revisión de candidatos: sin archivos mayores de 5 MB, generados ni asignaciones de credenciales locales detectadas; JWT real ausente en los textos revisados, `.env` no rastreado. `.dart_tool`, `build/web`, `local.properties`, SDK/AVD y APK siguen fuera de Git. `HEAD = develop = origin/develop` (referencias locales verificadas), diferencia `0 0`; el trabajo está en archivos, no en commits. `origin/main` conserva `6286e0a9c17b41e1e4c3303e32ca102316bc095d`; no existe rama local main en este checkout y no se creó. Evidencias HU 2.4 sin cambios.

## Registro inicial HU 3.1 — 07/10/2026

Rama local `feature/hu-3-1-mapa-lugares`, desde `develop` / merge HU 2.4 `f214886d7a40aabfc3b10b0af1a266128cc421fe`. Se verificó limpio y sincronizado con `origin/develop` antes de crear la rama. Cambios sin staging, commit ni publicación. Issue [#4](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/issues/4) leído, sin modificaciones.

## Flujo implementado y comprobado

- `PlaceModel` valida datos y coordenadas finitas/rangos. `PlaceService` consulta `/api/places` con JWT, tiempo máximo de 15 segundos y mensajes públicos; no muestra excepciones técnicas.
- `PlacesCubit` aplica generación de sesión, última solicitud y guarda de vista cerrada. Logout borra inmediatamente la lista; respuestas antiguas no repueblan el estado. Las guardas globales HU 2.4 permanecen intactas.
- `MapPage` reutiliza AppTheme/AppColors y navegación inferior. Muestra carga, vacío, error/reintento y marcadores dinámicos; encuadra los puntos y permite desplazar el mapa. Selección breve con nombre/categoría y cierre, sin HU 3.3 completa. No hay búsqueda o controles decorativos.
- No existía catálogo canónico en el código/Issue revisados. Los tres puntos del fixture backend son ilustrativos, con nombres `Demo · ...`, bandera `demostrativo` y aviso visible **Sin monitoreo en tiempo real**. No se atribuyen a lugares realmente monitoreados.

## Validación real

- `flutter analyze --no-pub`: **No issues found!**, código 0.
- `flutter test --no-pub`: **48: All tests passed!**, código 0: 25 anteriores, 18 de servicio/modelo/cubit y 5 widget del mapa.
- Los widgets usan 360 × 800 dp, tema real, FlutterMap/MarkerLayer reales y teselas en memoria solo para evitar red externa en tests. Prueban carga, vacío, marcadores/coordenadas, selección, desplazamiento, error/reintento y retiro de marcadores al cerrar sesión.
- Primera suite nueva: 43 aprobadas y 5 fallidas por `A RenderFlex overflowed by 1.00 pixels on the bottom.` Se corrigió exclusivamente el ajuste del texto de CrBottomNav a una línea con elipsis; sin ampliar el fixture ni ocultar excepciones. Se corrigieron tres avisos de estilo observados durante el desarrollo; análisis final limpio.
- `git diff --check`: sin errores. Sin cambios en pubspec, lockfile, Gradle, SDK ni dependencias.

## Android 16 / API 36

Se reutilizó `CrowdRadar_API36`, `emulator-5554`, arranque completo `sys.boot_completed=1`. `flutter run -d emulator-5554 --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000` compiló el APK debug (assembleDebug 31,9 s), lo instaló y abrió la app. Se usó una cuenta local existente, sin registrar otro usuario.

1. Login desde interfaz contra backend local/PostgreSQL 18 en `crowdradar_dev`.
2. [Mapa OpenStreetMap cargado y tres marcadores](evidencias/hu_3_1/2026_10_07/01_mapa_lugares.png).
3. [Selección: Demo · Parque Central / Parque · Demostrativo](evidencias/hu_3_1/2026_10_07/02_identificacion.png).
4. Se detuvo únicamente nuestro backend; Actualizar mostró [error público y Reintentar](evidencias/hu_3_1/2026_10_07/03_error_backend_apagado.png), sin ClientException visible.
5. Backend reiniciado; pulsar Reintentar recuperó [los tres marcadores y el mapa](evidencias/hu_3_1/2026_10_07/04_reintento_correcto.png).

La carga y el vacío se probaron automáticamente, no se capturó una base real vacía en Android. El error manual corresponde al backend apagado, no a una caída de OpenStreetMap. Persistió la advertencia no bloqueante `This version only understands SDK XML versions up to 3 but an SDK XML file of version 4 was encountered.`

## Criterios y límites

Los tres criterios técnicos del Issue #4 están demostrados localmente: consulta autenticada con marcadores, coordenadas recibidas exactas y error informativo con recuperación. Pendientes de revisión del equipo, commit/publicación autorizada y fuente canónica de lugares para un uso real. No se marcó el Issue como completado.

La identificación no incluye descripción completa, aforo ni saturación. No hay HU 3.2, HU 3.3 completa, favoritos, geolocalización, reportes, búsqueda ni filtros. JWT sigue sin revocación backend. La migración de `places` no resuelve todavía `User.sync()` histórico. OpenStreetMap necesita Internet; no se añadió modo offline ni tratamiento específico de errores de teselas.

## Registro histórico — HU 2.4

Última revisión: **06/10/2026**, 25 pruebas aprobadas y recorrido Android completado. El registro del 05/10 se conserva debajo; los hallazgos y correcciones adicionales están al final.

Verificado localmente el 05/10/2026. Rama `feature/hu-2-4-cierre-sesion`, creada desde `develop` (`f41229ed6eca69b9e3ff08d8bce3986962f35636`). Cambios sin commit, pendientes de revisión; no se publicaron ni se tocó `main`.

## Comportamiento comprobado

- `AuthCubit.logout()` borra token y usuario antes de notificar el cambio de sesión.
- El router escucha la sesión: al cerrarla desde una pantalla protegida, redirige a login y retira la pila protegida.
- Sin sesión, `/map`, `/validar`, `/favoritos`, `/profile` y `/profile/edit` redirigen a `/login`. Se probaron entrada inicial, `go`, `push` y rutas con parámetros de consulta.
- `/login` y `/register` siguen públicas. Una nueva sesión permite navegar nuevamente.
- Una respuesta de actualización de perfil de una sesión anterior no repuebla el usuario local después del cierre.

## Pruebas ejecutadas

Entorno existente: Flutter 3.41.9 / Dart 3.11.5, emulador `CrowdRadar_API36`, dispositivo `emulator-5554`, Android 16 API 36. No se actualizaron SDK ni dependencias.

```powershell
flutter analyze --no-pub
flutter test --no-pub
git diff --check
flutter run -d emulator-5554 --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

- Análisis: `No issues found!`.
- Pruebas: `20: All tests passed!` (5 de sesión, 14 de navegación y la prueba de humo existente).
- Revisión de espacios: sin errores.
- `flutter run`: compiló `app-debug.apk`, lo instaló y abrió la app. El APK permanece ignorado y no se incluye en Git.

Las dos primeras ejecuciones de pruebas terminaron con 13 aprobadas y 7 fallidas por `A RenderFlex overflowed by 1.00 pixels on the bottom.` La fuente Ahem del entorno de pruebas envolvía una etiqueta del menú. Se ajustó el fixture a 440 × 800 dp y al tema de la app; no se cambió la interfaz ni se ocultaron excepciones. Las dos ejecuciones posteriores aprobaron las 20 pruebas.

## Recorrido manual Android

Backend local iniciado con `npm start`, PostgreSQL 18 activo y `.env` ignorado configurado para `crowdradar_dev`. `GET /` devolvió `{"message":"CrowdRadar API"}`. No se usaron `crowdradar_sprint1` ni Supabase.

1. Se inició sesión desde la interfaz con una cuenta local de prueba existente.
2. Se abrió Perfil; la información del usuario se cargó desde el backend.
3. Se pulsó **Cerrar sesión** y apareció login con campos vacíos.
4. Se pulsó Atrás para intentar recuperar la pantalla protegida: Android salió a su pantalla principal, sin mostrar el perfil.
5. Al reabrir CrowdRadar apareció login, no el perfil anterior.

La tentativa manual de reingreso fue mediante Atrás; las entradas explícitas a las cinco rutas están comprobadas por las pruebas automatizadas. Las capturas de perfil, cierre y reapertura están en `docs/evidencias/hu_2_4/`.

## Límites

- El cierre es local: un JWT copiado previamente sigue válido en el backend hasta expirar. No se añadió revocación, persistencia de sesión ni funciones de contraseña.
- La compilación mostró una advertencia no bloqueante: `This version only understands SDK XML versions up to 3 but an SDK XML file of version 4 was encountered.` No se cambiaron herramientas para resolverla en esta HU.
- No se revalidaron todos los casos del Sprint 1 ni las funciones futuras de mapa, validación o favoritos.

## Revisión y finalización local — 06/10/2026

Issue relacionado: [Frontend #3, HU 2.4](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/issues/3). No se modificó el Issue ni su estado. Rama y HEAD siguen en `feature/hu-2-4-cierre-sesion` y `f41229ed6eca69b9e3ff08d8bce3986962f35636`; `develop` y `main` no se alteraron.

### Estado inicial y referencias remotas

Se revisó el diff completo y se preservaron los 13 archivos de la tarea anterior: README, seis archivos fuente, dos pruebas, este documento y tres capturas. Había siete archivos rastreados modificados y seis sin rastrear; nada staged. Backend limpio en `develop`, `a6da9a72e736bcb18568533a4ec7bf7aa4daa3f3`.

`git fetch --no-tags origin` terminó con código 0 en ambos repositorios. Ninguna referencia de `origin` cambió. `git rev-list --left-right --count HEAD...origin/develop` devolvió `0 0` en ambos: no aparecieron commits nuevos del equipo. No se hizo pull, checkout, merge, rebase, limpieza, commit ni push.

### Defectos reproducidos y cambios mínimos

Las 20 pruebas existentes pasaron antes de modificar código. Se añadieron cinco casos HTTP simulados: antes de corregir hubo **2 aprobados y 3 fallidos** en `flutter test --no-pub test/session_async_test.dart` (código 1):

1. Un login pendiente restauraba la sesión tras logout: `Expected: null; Actual: 'test-session'`.
2. Una actualización antigua sobrescribía el usuario al abrir otra sesión con el mismo token: `Expected: same instance as <Instance of 'UserModel'>; Actual: <Instance of 'UserModel'>`.
3. La consulta de perfil terminaba después de cerrar su cubit: `Bad state: Cannot emit new states after calling close`.

Se añadió una generación de sesión **solo en memoria** para descartar respuestas de sesiones anteriores, incluso con token repetido. El cubit de autenticación ignora el login invalidado por logout; el cubit de perfil no emite sobre una vista cerrada. No hay revocación JWT, almacenamiento persistente ni cambios backend.

Las 14 pruebas de navegación ahora usan **360 × 800 dp**, sin ampliar la pantalla para resolver el desbordamiento de Ahem. La edición de perfil es la pantalla protegida de referencia para probar la pila; todas las cinco rutas siguen cubiertas en entrada inicial y después del cierre con `go`/`push`. No se ocultaron excepciones ni se alteró el diseño real.

### Validación final

| Criterio | Evidencia ejecutada |
| --- | --- |
| Borrado de token y usuario, antes de notificar | Prueba de `AuthCubit.logout` y prueba HTTP de login pendiente |
| `clear()` repetido es seguro | Prueba de sesión ya cerrada |
| Redirección reactiva y pila protegida eliminada | Prueba con dos pantallas protegidas apiladas, sin `go('/login')` duplicado |
| Cinco rutas protegidas, incluso tras logout | 5 pruebas de entrada inicial y 5 de reingreso `go`/`push` |
| Login y registro públicos | 2 pruebas de rutas públicas |
| Nueva sesión permite acceso | Prueba de reentrada a `/profile/edit` |
| Respuestas antiguas no restauran usuario | HTTP pendiente tras logout y tras nueva sesión con token repetido |
| Token vacío rechazado | Prueba de token en blanco en `SessionService.start` |

Comandos obligatorios, todos con código 0 después de las correcciones:

- `flutter analyze --no-pub`: `No issues found!`.
- `flutter test --no-pub`: `25: All tests passed!` (5 de sesión, 5 HTTP/asíncronas, 14 de navegación, 1 de humo).
- `git diff --check`: sin errores; Git únicamente avisa de la normalización futura LF/CRLF del README.

Se comprobaron secretos locales contra los archivos de texto candidatos: **0 coincidencias**. No hay SDK, AVD, builds, APK ni archivos mayores de 5 MB entre los candidatos. `.env`, `.dart_tool`, el APK y `local.properties` están ignorados. `pubspec.yaml`, `pubspec.lock` y configuración Gradle siguen sin cambios.

### Android repetido realmente

Se reutilizó `CrowdRadar_API36`; `adb devices -l` mostró `emulator-5554` y `sys.boot_completed` fue `1`. Backend iniciado con `npm start`, sin cambios, sobre `crowdradar_dev`; `GET /` respondió `{"message":"CrowdRadar API"}`.

`flutter run -d emulator-5554 --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000` compiló, instaló y abrió el APK. Se completó: login desde la interfaz, apertura de Perfil, cierre, intento de volver con Atrás y reapertura. Atrás salió a Android sin recuperar el perfil; al reabrir apareció Login con campos vacíos.

Capturas nuevas, sin reemplazar las del 05/10:

- [Perfil cargado](evidencias/hu_2_4/revision_2026_10_06/01_perfil.png).
- [Login después de cerrar](evidencias/hu_2_4/revision_2026_10_06/02_cierre_login.png).
- [Atrás sale a Android](evidencias/hu_2_4/revision_2026_10_06/03_atras_android.png).
- [Reapertura en Login](evidencias/hu_2_4/revision_2026_10_06/04_reapertura_login.png).

Persistió la advertencia XML del SDK ya registrada; no impidió compilar ni ejecutar. Las entradas directas a rutas se probaron automáticamente, no con enlaces Android. No se reejecutó `npm test` ni todo el Sprint 1 en esta revisión.

### Archivos para la revisión y futuro commit

Conservar los 13 archivos iniciales. Los ajustes adicionales afectan `session_service.dart`, `auth_service.dart`, `user_service.dart`, `login_cubit.dart`, ambas pruebas anteriores, README y este documento. Añadir `lib/cubits/profile/profile_cubit.dart`, `test/session_async_test.dart` y las cuatro capturas nuevas: **19 archivos frontend candidatos** (8 rastreados modificados y 11 sin rastrear), sin staging.

El contexto maestro se actualiza aparte, fuera del repositorio frontend. Backend continúa limpio. No se publica ningún artefacto generado ni credencial.

Propuesta de commit, todavía no ejecutada: `feat(auth): finalize HU 2.4 secure local logout`, con `Refs #3` en el cuerpo. Después de autorización: revisar y añadir explícitamente esos archivos, crear el commit, comprobar nuevamente `origin/develop`, publicar únicamente `feature/hu-2-4-cierre-sesion` en `origin` y abrir un PR hacia `develop`. No cerrar automáticamente el Issue ni fusionar a `main`.
