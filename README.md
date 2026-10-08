# CrowdRadar Frontend

Aplicación Flutter Android y Web para registro, inicio de sesión, perfil y mapa de lugares. El soporte Web ejecuta la misma aplicación y servicios; no hay un frontend HTML paralelo.

**Origen funcional de esta instantánea:** HU 2.1–2.2 publicada en `feature/hu-2-1-2-recuperacion`, desde HU 2.3 frontend `1e62c754682f3abe2b166b178d44b7e6e7d1fad0`; backend compañero misma rama desde `97e607ed22b48561bed30a4e821099f76360210d`. HU 2.3 parte del pulido `0361ae1`, y ambos dependen de HU 3.1 pendiente de merge. Clonar `develop` no incorpora estos incrementos; publicación no equivale a integración.

Para colaborar con el equipo y usar IA sobre el código, empieza por [AGENTS.md](AGENTS.md) y [CONTRIBUTING.md](CONTRIBUTING.md). Después, lee `docs/INICIO_EQUIPO.md` en el clon backend hermano: explica el arranque sin historial de chats e incluye un prompt sin tarea asignada. Consulta [arquitectura](docs/ARQUITECTURA.md) y [guía visual](docs/GUIA_VISUAL.md); CONTRIBUTING enlaza coordinación y contrato canónico backend. `develop` reúne los aportes integrados de los siete; una rama publicada con PR abierto sigue pendiente de incorporación a esa base.

**Descarga actual del equipo:** usar `integration/base-equipo` en ambos repositorios para leer, ejecutar y revisar los avances con las guías nuevas. Es una instantánea pendiente de integración, no la base aprobada para iniciar funcionalidades. La guía de inicio backend contiene ambos comandos de clonación; tras aprobar/integrar el par, las tareas nuevas parten de `develop` actualizado.

## Requisitos

- Flutter 3.41.9 estable (Dart 3.11.5), coincidente con `.metadata` y compatible con `pubspec.lock`.
- Android Studio o Android SDK y un emulador Android configurado.
- Java 21 y Android SDK Platform 36 / Build-Tools 36 para la compilación comprobada.
- Backend CrowdRadar en ejecución.

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

**Envío real pendiente:** el equipo todavía no eligió proveedor/remitente. El backend normal devuelve indisponibilidad uniforme, no afirma haber enviado un correo. No hay cuenta ni clave predeterminada, consola con enlaces ni modo de correo falso habilitable por entorno. El transporte capturado pertenece exclusivamente a pruebas; no demuestra entrega real y no completa HU 2.1/Sprint 2. No publiques un enlace/token real, historial de navegación o captura que lo contenga.

Esta rama requiere la migración 003 y el [contrato C compañero](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/feature/hu-2-1-2-recuperacion/docs/CONTRATO_API.md). Chrome/Android del estado final siguen pendientes de recorrido manual. No hay deep links Android verificados: el enlace Web no acredita apertura automática de la app nativa.

Archivos principales:

- `lib/pages/login/login_page.dart`
- `lib/pages/register/register_page.dart`
- `lib/pages/profile/profile_page.dart`
- `lib/pages/profile/edit_profile_page.dart`
- `lib/services/auth_service.dart`
- `lib/services/user_service.dart`
- `lib/configs/api_config.dart`

## HU 3.1 — mapa de lugares (incremento de revisión)

El mapa consulta `GET /api/places` con JWT y muestra un marcador por coordenada recibida, sin marcador fijo. Ofrece carga, vacío, error comprensible y reintento; seleccionar un marcador identifica nombre/categoría, no abre detalles completos. Conserva `flutter_map`, OpenStreetMap y las guardas HU 2.4.

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

## Web local en Chrome

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

`build/web` está ignorado. La sesión solo vive en memoria: recargar una ruta protegida vuelve a login. Entradas públicas: `/#/login`, `/#/register`, `/#/forgot-password` y `/#/reset-password` (esta última exige enlace vigente). HU 3.1 y los incrementos posteriores están en ramas de revisión; una clonación de `develop` todavía no los contiene.

## Pruebas anteriores

El proyecto incluye `test/widget_test.dart`, que comprueba que la app muestra el inicio de sesión. El 22/09/2026 pasaron `flutter analyze`, `flutter test` (1 prueba) y `flutter build apk --debug`. El APK se instaló en un emulador Android 16 y se comprobó el flujo con `crowdradar_dev`. El estado y las capturas están en [docs/ESTADO_ACTUAL.md del backend](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/develop/docs/ESTADO_ACTUAL.md).

La validación local del 05/10/2026 añade `test/session_service_test.dart` y `test/auth_navigation_test.dart`: 20 pruebas aprobadas en total y análisis sin problemas. Los resultados y el recorrido Android de la HU 2.4 están en [docs/ESTADO_ACTUAL.md](docs/ESTADO_ACTUAL.md).

La revisión del 06/10/2026 conserva ese trabajo y añade `test/session_async_test.dart`: 25 pruebas aprobadas. Se corrigieron respuestas pendientes tras el cierre y se repitió el recorrido Android; no se actualizaron dependencias.

## Alcance

La base entregada corresponde al Sprint 1 y `develop` incluye HU 2.4. Ramas dependientes incorporan HU 3.1, pulido, HU 2.3 y partes verificables de HU 2.1–2.2, con envío real pendiente. No incluyen saturación, búsqueda, filtros, reportes, favoritos, geolocalización ni detalles completos. HU 3.2 y HU 3.3 no están terminadas. Publicación no equivale a integración ni aprobación manual de plataformas; ver [estado técnico](docs/ESTADO_ACTUAL.md).
