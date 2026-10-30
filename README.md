# CrowdRadar Frontend

## Candidato HU7 para revisión — 28/10/2026

Esta rama incorpora Perfil ADMIN → Administrar usuarios y Revisar reportes denunciados, con búsqueda, acciones confirmadas e historiales persistidos. Necesita el backend HU7 y sus migraciones explícitas008/009. [Recorridos y evidencia](docs/CIERRE_HU7.md); contrato canónico en el backend compañero. Publicación, revisión e integración son pasos separados; el par exacto se acredita en Git/PR. Los cortes inferiores son históricos y no describen el alcance HU7 de esta rama.

Corte20/10/2026:verificación de aceptación Web en PR#21 y backend#39,pendiente de revisión ajena/merge. Las2integracionesopt-in ya ejecutadas contra PostgreSQLaislado;procedimiento en CONFIGURACION_LOCALbackend,perfilcierre/API3053/Web5553. Demo3043/5543conservada. [Resultados actuales](docs/CIERRE_WEB_R01_S03.md). HU7/8siguen pendientes.

## Revisión Web R01/S3 y demo local — 19/10/2026

Rama `integration/cierre-web-r01-s03-20261019`, desde `18cec26` más pendientes F3/C2/F11. La publicación se acredita por el PR y su par exacto; **no implica integración en develop, aceptación ni despliegue**. Flutter Android/Web; Web es la plataforma comprobada en este cierre. [Resultados y procedencia](docs/CIERRE_WEB_R01_S03.md).

Con backend demo3043 iniciado según el [procedimiento canónico](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/integration/cierre-web-r01-s03-20261019/docs/CATALOGO_DEMO_LOCAL.md), ejecutar desde la raíz de tu clon frontend:

```powershell
flutter pub get --enforce-lockfile
$demoBuild = Join-Path (Get-Location).Path ("build/demo-web-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
flutter build web --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:3043 --output="$demoBuild"
node tool/serve_demo_web.mjs "$demoBuild"
```

Abrir http://127.0.0.1:5543/#/login. Cinco lugares reales/observaciones demostrativas, **sin monitoreo en tiempo real**. Crear cuenta sintética propia; sin usuarios/contraseñas predeterminados. SMTP demo deshabilitado. JWT en memoria: recargar exige login. Salida absoluta nueva para evitar fallo de shaders con ruta relativa y no reemplazar evidencias. build/ ignorado; servidor solo loopback, no producción. No iniciar dos servidores en5543 ni detener uno ajeno. No se instalaron paquetes en el cierre; pub get con lock es un paso para otra PC.

Incluye I1(sesión vigente/antigua),I2(reporte confirmado/cooldown/incertidumbre),I3/C2(catálogo plegable,selección ID,filtros AND,perfil/puntos) y F11(Historial→Perfil). Conserva aportes/autoría de Nick/Manu/Diego, tema y OSM; no usa el experimento visual rechazado.

Lugares/filtros, reportes/karma/historial propio y, ahora, Validar con votos/confiabilidad/denuncias; detalle con historial horario/comparación/horarios suficientes. HU7/8 siguen fuera del alcance; Favoritos aún es placeholder. Tema publicado conservado; experimento visual rechazado excluido.

Lee [CONTRIBUTING](CONTRIBUTING.md), [arquitectura](docs/ARQUITECTURA.md), [guía visual](docs/GUIA_VISUAL.md) y [pruebas](docs/ESTADO_ACTUAL.md). Clonar la rama de integración publicada descarga el candidato, no los datos/secretos/SDK. Clonar develop obtiene solo lo integrado allí. SMTP real requiere otro entorno y autorización, no instalar “Brevo” ni compartir contraseñas.

## Requisitos

- Flutter 3.41.9 estable (Dart 3.11.5), coincidente con `.metadata` y compatible con `pubspec.lock`.
- Para Web: navegador compatible y backend CrowdRadar en ejecución; no se necesita Android SDK.
- Solo para Android: Android SDK y emulador/dispositivo; Java 21, Platform 36 / Build-Tools 36 según la compilación histórica comprobada. No es requisito para ejecutar Web.

Comprueba el entorno antes de ejecutar:

```powershell
flutter doctor
flutter devices
```

## Instalación y ejecución

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` permite que el emulador Android acceda al `localhost` de la PC. Para un dispositivo físico, reemplaza la URL por la IP de la PC en la misma red, por ejemplo:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
```

El valor predeterminado sigue siendo `http://10.0.2.2:3000` cuando no se envía `API_BASE_URL`. Desde Android, `localhost` apunta al propio dispositivo, no a la PC.

## Flujo del Sprint 1

1. La app abre `/login`.
2. Desde login se accede a `/register`.
3. Un registro exitoso vuelve al login.
4. Un login exitoso guarda el JWT en memoria y abre `/map`.
5. La sección `/profile` consulta `GET /api/users/profile`.
6. `/profile/edit` envía los cambios con `PUT /api/users/profile`.

## HU 2.4 — cierre de sesión local

Desde Perfil, **Cerrar sesión** borra el token y el usuario en memoria. El router redirige a `/login` y bloquea `/map`, `/validar`, `/favoritos`, `/profile` y `/profile/edit` sin sesión, incluso después del cierre. Login y registro son públicos. No se añade persistencia ni revocación del JWT en el backend.

## HU 2.3 — cambiar contraseña

Perfil → Cambiar contraseña (`/profile/password`, protegida). Escribe la actual, la nueva y su confirmación. Mínimo 8 caracteres Unicode y máximo 72 bytes UTF-8; no se recorta ni se permite reutilizar la actual. Tras éxito, todas las sesiones anteriores quedan invalidadas **en PostgreSQL/backend** mediante versión persistente y la app vuelve al login. El cierre local HU 2.4, por separado, sigue sin revocar JWT.

Antes de arrancar esta versión backend, ejecuta allí `npm run db:migrate`: añade explícitamente la versión de sesión y reproduce `users` en bases nuevas. No hay DDL al arrancar. Los JWT previos a esta versión requieren iniciar sesión de nuevo. Consulta el [contrato de la rama compañera](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/feature/hu-2-3-cambio-password/docs/CONTRATO_API.md).

## HU 2.1–2.2 — avance de recuperación/restablecimiento

Login → Recuperar contraseña (`/forgot-password`, pública). El mensaje no distingue cuentas existentes/inexistentes. El enlace abre `/#/reset-password?token=…`; el token se valida antes de mostrar el formulario y se consume una sola vez al guardar. Después exige login nuevo, sin inicio automático, e invalida sesiones anteriores en backend.

**Correo:** adaptador SMTP/Brevo integrado; sin configuración privada la API responde503 uniforme. Transporte en memoria solo para pruebas. No publicar enlaces, tokens ni claves. Recepción real de esta PC no ejecutada.

Esta rama requiere la migración 003 y el [contrato C compañero](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/feature/hu-2-1-2-recuperacion/docs/CONTRATO_API.md). Chrome/Android del estado final siguen pendientes de recorrido manual. No hay deep links Android verificados: el enlace Web no acredita apertura automática de la app nativa.

Archivos principales:

- `lib/pages/login/login_page.dart`
- `lib/pages/register/register_page.dart`
- `lib/pages/profile/profile_page.dart`
- `lib/pages/profile/edit_profile_page.dart`
- `lib/services/auth_service.dart`
- `lib/services/user_service.dart`
- `lib/configs/api_config.dart`

## Antecedente HU3.1 — 07/10/2026 (no describe el alcance final)

La HU3.1 original mostraba nombre/categoría. El candidato actual añade detalle,búsqueda,filtros,consulta de saturación,reportes e historiales; no leer las limitaciones de ese incremento aislado como funciones ausentes hoy. Conserva flutter_map,OSM y guardas de sesión.

En el backend de esta misma rama, configura `.env` para `crowdradar_dev` y ejecuta:

```powershell
npm run db:migrate
# Opcional: datos DEMOSTRATIVOS, no lugares realmente monitoreados.
npm run db:seed:demo
npm start
```

En el frontend, con paquetes ya resueltos:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter run -d emulator-5554 --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

En una clonación nueva ejecuta antes `flutter pub get` con el lockfile existente. No se añadieron ni actualizaron dependencias. Validación Web del 07/10/2026: análisis correcto y **69/69 pruebas**. El recorrido Android anterior del mismo día comprobó mapa/selección/error/reintento; no se reejecutó Android tras las últimas mejoras de formularios. Detalle en [ESTADO_ACTUAL.md](docs/ESTADO_ACTUAL.md).

## Configuración histórica Web3000/5500 (alternativa, no demo3043/5543)

Con PostgreSQL y backend en `http://localhost:3000`, abre una segunda terminal:

```powershell
flutter run -d chrome --web-hostname=localhost --web-port=5500 --no-pub --dart-define=API_BASE_URL=http://localhost:3000
```

Abre **http://localhost:5500/#/login**. El `#/` corresponde al router Flutter. En esta PC Oracle conserva IPv4 `127.0.0.1:5500` y Flutter sirve por IPv6 `::1:5500` al usar localhost; no detener Oracle ni desactivar la seguridad de Chrome. Si se cierran los procesos, repite `npm start` en Backend y el comando anterior en Frontend.

Para registrarte usa nombre/apellido/distrito de 2 caracteres o más, correo válido único, contraseña propia de mínimo 8 caracteres y máximo 72 bytes UTF-8, teléfono de exactamente 9 dígitos. Todos son obligatorios en el formulario. No hay contraseña ni cuenta predeterminada. Después del aviso de éxito, inicia sesión con lo que elegiste. Mostrar/ocultar contraseña es temporal; no se almacena automáticamente. Las solicitudes deshabilitan envíos dobles sin retirar el formulario. Errores de conexión/credenciales se muestran en español sin detalles técnicos.

Para compilar Web:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub --dart-define=API_BASE_URL=http://localhost:3000
```

`build/web` está ignorado. La sesión solo vive en memoria: recargar una ruta protegida vuelve a login. Entradas públicas: `/#/login`, `/#/register`, `/#/forgot-password` y `/#/reset-password` (esta última exige enlace vigente). Esos resultados corresponden a la base histórica indicada; usar la entrada demo superior para revisar el candidato actual sin conflictos de puertos.

## Pruebas anteriores

El proyecto incluye `test/widget_test.dart`, que comprueba que la app muestra el inicio de sesión. El 22/09/2026 pasaron `flutter analyze`, `flutter test` (1 prueba) y `flutter build apk --debug`. El APK se instaló en un emulador Android 16 y se comprobó el flujo con `crowdradar_dev`. El estado y las capturas están en [docs/ESTADO_ACTUAL.md del backend](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/develop/docs/ESTADO_ACTUAL.md).

La validación local del 05/10/2026 añade `test/session_service_test.dart` y `test/auth_navigation_test.dart`: 20 pruebas aprobadas en total y análisis sin problemas. Los resultados y el recorrido Android de la HU 2.4 están en [docs/ESTADO_ACTUAL.md](docs/ESTADO_ACTUAL.md).

La revisión del 06/10/2026 conserva ese trabajo y añade `test/session_async_test.dart`: 25 pruebas aprobadas. Se corrigieron respuestas pendientes tras el cierre y se repitió el recorrido Android; no se actualizaron dependencias.

## Alcance

El candidato reúne autenticación/perfil,recuperación/cambio,detalle/búsqueda/filtros AND de lugares,saturación,reportes/karma/historial propio,HU5(validación/confiabilidad/estado/denuncia) y HU6(historial/comparación/horarios suficientes). Favoritos sigue placeholder; HU7/8,geolocalización,nuevas reglas y nube fuera. SMTP real/Android/2opt-in/QA integral desde cero y aceptación humana pendientes. Rama publicada y PR no son merge ni aceptación. Ver [estado técnico](docs/ESTADO_ACTUAL.md).
