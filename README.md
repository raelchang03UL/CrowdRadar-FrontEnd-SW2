# CrowdRadar Frontend - Sprint 1

Aplicación móvil Flutter para las historias del Sprint 1: registro de ciudadano, inicio de sesión, visualización del perfil y actualización del perfil.

## Requisitos

- Flutter con una versión de Dart compatible con `^3.11.5`.
- Android Studio o Android SDK y un emulador Android configurado.
- Backend CrowdRadar en ejecución.

Comprueba el entorno antes de ejecutar:

```powershell
flutter doctor
flutter devices
```

## Instalación y ejecución

```powershell
flutter pub get
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` permite que el emulador Android acceda al `localhost` de la PC. Para un dispositivo físico, reemplaza la URL por la IP de la PC en la misma red, por ejemplo:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
```

El valor predeterminado sigue siendo `http://10.0.2.2:3000` cuando no se envía `API_BASE_URL`.

## Flujo del Sprint 1

1. La app abre `/login`.
2. Desde login se accede a `/register`.
3. Un registro exitoso vuelve al login.
4. Un login exitoso guarda el JWT en memoria y abre `/map`.
5. La sección `/profile` consulta `GET /api/users/profile`.
6. `/profile/edit` envía los cambios con `PUT /api/users/profile`.

Archivos principales:

- `lib/pages/login/login_page.dart`
- `lib/pages/register/register_page.dart`
- `lib/pages/profile/profile_page.dart`
- `lib/pages/profile/edit_profile_page.dart`
- `lib/services/auth_service.dart`
- `lib/services/user_service.dart`
- `lib/configs/api_config.dart`

## Pruebas

El proyecto incluye `test/widget_test.dart`, que comprueba que la app muestra la pantalla de inicio de sesión. En la revisión local del 20/09/2026 no se ejecutó porque Flutter y Dart no estaban instalados en la PC. La presencia del código no se considera evidencia de compilación.

## Alcance

Esta entrega conserva el diseño móvil y se limita al Sprint 1. Las pantallas de mapa, validación y favoritos no se amplían como parte de esta revisión.
