# CrowdRadar Frontend

Aplicación móvil Flutter para las historias del Sprint 1: registro de ciudadano, inicio de sesión, visualización del perfil y actualización del perfil.

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

## Pruebas

El proyecto incluye `test/widget_test.dart`, que comprueba que la app muestra el inicio de sesión. El 22/09/2026 pasaron `flutter analyze`, `flutter test` (1 prueba) y `flutter build apk --debug`. El APK se instaló en un emulador Android 16 y se comprobó el flujo con `crowdradar_dev`. El estado y las capturas están en [docs/ESTADO_ACTUAL.md del backend](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/develop/docs/ESTADO_ACTUAL.md).

La validación local del 05/10/2026 añade `test/session_service_test.dart` y `test/auth_navigation_test.dart`: 20 pruebas aprobadas en total y análisis sin problemas. Los resultados y el recorrido Android de la HU 2.4 están en [docs/ESTADO_ACTUAL.md](docs/ESTADO_ACTUAL.md).

La revisión del 06/10/2026 conserva ese trabajo y añade `test/session_async_test.dart`: 25 pruebas aprobadas. Se corrigieron respuestas pendientes tras el cierre y se repitió el recorrido Android; no se actualizaron dependencias.

## Alcance

La base entregada corresponde al Sprint 1. La revisión actual añade únicamente la HU 2.4 en el frontend, conservando el diseño móvil. Las pantallas de mapa, validación y favoritos no se amplían.
