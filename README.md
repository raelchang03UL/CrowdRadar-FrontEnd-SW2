# CrowdRadar Frontend

Aplicación Flutter Android y Web para registro, inicio de sesión, perfil y mapa de lugares. El soporte Web ejecuta la misma aplicación y servicios; no hay un frontend HTML paralelo.

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

Archivos principales:

- `lib/pages/login/login_page.dart`
- `lib/pages/register/register_page.dart`
- `lib/pages/profile/profile_page.dart`
- `lib/pages/profile/edit_profile_page.dart`
- `lib/services/auth_service.dart`
- `lib/services/user_service.dart`
- `lib/configs/api_config.dart`

## HU 3.1 — mapa de lugares (incremento local)

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

`build/web` está ignorado. La sesión solo vive en memoria: recargar una ruta protegida vuelve a login. Las entradas públicas directas son `/#/login` y `/#/register`. HU 3.1 y estas correcciones siguen sin commit/publicación: una clonación actual de `develop` todavía no contiene el incremento.

## Pruebas anteriores

El proyecto incluye `test/widget_test.dart`, que comprueba que la app muestra el inicio de sesión. El 22/09/2026 pasaron `flutter analyze`, `flutter test` (1 prueba) y `flutter build apk --debug`. El APK se instaló en un emulador Android 16 y se comprobó el flujo con `crowdradar_dev`. El estado y las capturas están en [docs/ESTADO_ACTUAL.md del backend](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/develop/docs/ESTADO_ACTUAL.md).

La validación local del 05/10/2026 añade `test/session_service_test.dart` y `test/auth_navigation_test.dart`: 20 pruebas aprobadas en total y análisis sin problemas. Los resultados y el recorrido Android de la HU 2.4 están en [docs/ESTADO_ACTUAL.md](docs/ESTADO_ACTUAL.md).

La revisión del 06/10/2026 conserva ese trabajo y añade `test/session_async_test.dart`: 25 pruebas aprobadas. Se corrigieron respuestas pendientes tras el cierre y se repitió el recorrido Android; no se actualizaron dependencias.

## Alcance

La base entregada corresponde al Sprint 1 y `develop` incluye HU 2.4. El incremento local actual se limita a HU 3.1: lugares en mapa, sin saturación, búsqueda, filtros, reportes, favoritos, geolocalización ni detalles completos. HU 3.2 y HU 3.3 no están terminadas. No hay commits ni publicación de este incremento todavía.
