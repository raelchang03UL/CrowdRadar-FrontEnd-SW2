# Frontend — HU 2.4, cierre de sesión

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
