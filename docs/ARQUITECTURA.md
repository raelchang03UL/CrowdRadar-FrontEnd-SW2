# Arquitectura frontend

Incluye HU 3.1, pulido A y HU 2.3 en ramas dependientes de revisión; todavía no integradas en `develop`. Confirmar Git y el estado de integración al reutilizarla.

## Responsabilidades

```text
main.dart / MaterialApp.router
  → router/app_router.dart (acceso y navegación)
  → pages / components (presentación y formularios)
  → cubits (estado y operaciones asíncronas)
  → services (HTTP / traducción de errores)
  → configs/api_config.dart → backend
```

`models` representa datos de la API. `theme/AppTheme` y `AppColors` definen el estilo común. `auth_fields` y `auth_form_layout` comparten validación/presentación de autenticación. No añadir HTTP en widgets ni duplicar clientes o temas por pantalla.

`AuthCubit` coordina registro/login/logout. `SessionService` guarda token/usuario en memoria y una generación de sesión para descartar respuestas antiguas. El router protege todas las rutas excepto login/registro; al añadir recuperación debe acordarse qué rutas son públicas sin abrir el resto. El cierre retira datos inmediatamente; una respuesta tardía no los repone.

`PlacesCubit` controla carga/vacío/error/datos y descarta solicitudes antiguas; `PlaceService` usa JWT y timeout; `MapPage` representa lugares mediante flutter_map/OpenStreetMap. Los datos actuales son ilustrativos y se identifican como demostrativos. Seleccionar un marcador no implementa detalle completo ni saturación.

`PasswordService` traduce el contrato de cambio a resultados públicos sin mutar sesión. `PasswordChangeCubit` controla envío único y generación/token; solo una respuesta perteneciente a la sesión vigente puede cerrarla. La página protegida conserva formulario/errores durante la solicitud; después de éxito exige nuevo login. La invalidación efectiva de todos los JWT anteriores la hace el backend con `users.sessionVersion`, no el widget. No se persisten contraseñas/JWT ni se interpreta un mensaje arbitrario de API como aviso de login.

## Configuración y plataformas

Una sola aplicación Flutter para Android/Web. `API_BASE_URL` se define al ejecutar/compilar; el valor por defecto `10.0.2.2:3000` es para Android emulado, no Web. Usar el README para la URL/puerto real. La configuración pública no contiene secretos.

Web usa rutas con fragmento `#/`. Recargar pierde la sesión porque no hay persistencia. Cambiar ese comportamiento o mover tokens a almacenamiento es una decisión de seguridad, no un arreglo visual. No desactivar CORS/seguridad del navegador para conectar.

## Fronteras compartidas

Coordinar antes de editar router, sesión, AuthCubit, API config, UserModel, PlaceModel o tema. El contrato canónico está en backend `docs/CONTRATO_API.md`; enlaces y lectura local en [CONTRIBUTING](../CONTRIBUTING.md). Registrar los dos SHA usados en integración.

## Pruebas y deuda

Flutter tests cubren servicios/modelos/cubits y navegación/widgets; dobles de HTTP/teselas no demuestran una API/base real. Un build aprobado tampoco acredita el recorrido de usuario. Las evidencias actuales distinguen IAB, Chrome normal y Android; comprobar la plataforma sobre el estado final.

Pendientes: recuperación/restablecimiento, recorrido manual final Chrome/Android, CI y catálogo real. El pulido homogeneiza perfil/edición; HU 2.3 incorpora la política explícita de invalidación backend. Mantener la [guía visual](GUIA_VISUAL.md) para las pantallas nuevas; no implementar pendientes por una refactorización de UI.
