# Arquitectura frontend

## Integración HU8 — 30/10/2026

Favoritos conserva pages → cubits → PlaceService → API. FavoritesCubit centraliza lista propia, carga/error/vacío, borrado por ID, envío único y descarte por generación. PlaceDetailCubit consulta el ID de la ruta y alterna el favorito sin confiar en `extra`. PlaceModel conserva dirección/referencia y añade esFavorito opcional para mantener compatibles los contratos y fixtures anteriores. Los mensajes de mutación son públicos y fijos.

SessionService.changes notifica cada generación, incluso al pasar de cuenta A a B sin logout intermedio. Los servicios de favoritos llaman rejectIfCurrent con token/generación antes de interpretar un401. Red, timeout y503 conservan sesión. El mapa actualiza por ID; las mutaciones conservan selección/cámara mediante selectionKey y una consulta nueva las retira como antes. Volver del detalle refresca ese lugar sin reiniciar los filtros.

PushNotificationService reutiliza Firebase/FCM y PushDeviceService originales. Web se activa desde una acción explícita, obtiene un registro FCM mediante getToken y envía targetType=fcm-token; al salir usa deleteToken. Nativo mantiene register/onRegistered con FID y targetType=fid. El backend entrega el binding registrationId en ambos casos; el tipo de destino se declara y no se deduce de la longitud ni se intercambia FID por token/JWT.

La adaptación Web usa la API de compatibilidad deprecada del SDK tras comprobar recepción primero en un control aislado y después en el recorrido real de la aplicación, que abrió el lugar correcto desde la alerta. Antes del primer getToken comprueba únicamente la presencia de metadata FID del appId vigente mediante count en una transacción IndexedDB readonly, acotada al esquema Firebase JS13.1.0 del lock. Si existe, unregister revoca el registro anterior; si no, conserva la caché legacy. No crea BD ausentes, no devuelve identificadores ni usa un marcador de sesión persistente. Después de esa transición Web solo administra getToken/deleteToken. Cada activación revalida el token a demanda; onTokenRefresh es un stream vacío en el plugin Web actual.

El plazo de20s abarca también el permiso del navegador; al vencer invalida el intento. Una cola SDK serializa obtención, migración y revocación, para que un token A tardío se descarte y su limpieza termine antes de obtener el de B. Otra cola serializa registros HTTP para evitar bindings cliente/servidor distintos. Una baja incluye token de dispositivo y registrationId capturado: una baja antigua no elimina el alta de una sesión posterior. El binding activo exige la generación vigente y el mismo usuario antes de mostrar/abrir alertas.

El worker Web recibe mensajes data-only, consulta el binding efímero a pestañas vivas y muestra texto genérico. Un click vuelve a validar binding y entrega placeId a Dart, que valida usuario/binding y navega a `/places/:id`; el detalle siempre consulta la API autorizada. No hay JWT, sesiones ni binding en almacenamiento del navegador o worker. Sin pestaña autenticada viva se descarta la alerta; no se garantiza entrega con la aplicación cerrada. [Configuración](../README.md) y [pruebas/límites](ESTADO_ACTUAL.md).

## Moderación HU7 — 28/10/2026

Páginas/diálogos administrativos → cubits derivados de RequestCubit → AdminUserService o AdminReportService → ApiJsonClient. Modelos validan DTO, agrupaciones, revisiones, orden y cursores. El router restringe ADMIN; la autorización efectiva pertenece al backend. No hay HTTP en widgets ni datos simulados para reemplazar endpoints.

Los listados conservan filtros al volver del detalle y descartan respuestas antiguas. Confirmación se cierra al cambiar sesión; envío pendiente impide doble acción y salida. Una respuesta incierta o conflicto exige actualizar. Historial se renueva tras cada decisión, con fechas Lima e IDs BIGINT como texto. Pendiente puede coexistir con decisiones anteriores porque una denuncia nueva reabre revisión.

Historial propio añade visibilidad y CitizenReport permite la señal de retiro solo en consulta propia. El login reconoce403 ACCOUNT_SUSPENDED con texto público fijo; no almacena sesión y mantiene el formulario.401 conserva error genérico; otros403 no exponen detalles internos. Se reutilizan tema, sesión y componentes; sin dependencias o locks nuevos. Backend HU7 con008/009 es prerrequisito.

[Recorrido/evidencia](CIERRE_HU7.md) y [estado](ESTADO_ACTUAL.md). Android y lectores de pantalla siguen pendientes.

## Antecedentes anteriores a HU7

Los cortes inferiores conservan su fecha y alcance originales. El estado vigente de HU7 es el resumen superior; sus iteraciones previas se conservan en Git.

## Cierre de revisión — 19/10/2026

Rama integration/cierre-web-r01-s03-20261019; publicación acreditada por PR, no integración/aceptación/despliegue. F11 consulta GoRouterState.uri.path antes de ignorar el índice activo: sección y subruta no son equivalentes. No cambia router ni Favoritos;7regresiones y suite final en CIERRE_WEB_R01_S03. I1/I2/C2 conservados. Snapshots tmp inferiores son procedencia histórica opcional; evidencia esencial ahora versionada y enlazada desde el cierre.

## Extensión de presentación sobre F3 — 19/10/2026

Visibilidad de catálogo en estado local de PlacesMap; ValueKey estable del Expanded conserva FlutterMapState al retirar la columna. PlacesCubit sigue siendo único dueño de consultas/filtros; la selección por ID permanece en PlacesMap, sincronizada con lista/marcadores/ficha. No HTTP/SQL en widgets. SaturationPanel recibe ubicación opcional del PlaceModel API y reutiliza el desplegable. CitizenPointsCard extrae solo presentación de saldo/política para probar0/1/saldo real y texto ampliado sin cargar toda la página; no calcula premios ni modifica UserModel/roles. Alternativa: mantener un ListTile con trailing largo, descartada por legibilidad a2×. Coste pequeño: un widget reutilizable y parámetros explícitos, sin capas/patrones GoF ni carpetas reorganizadas. Tests y límites actuales en ESTADO_ACTUAL. I1/I2,servicios,router,SMTP y reglas de negocio intactos.

## Incrementos locales I1–I3 — 19/10/2026

Se conserva el par candidato B`eeff38b`/F`18cec26`, más los estados de trabajo inventariados. No implica publicación, integración ni aceptación. Diffs por incremento y huellas completas en `../../../../tmp/cierre-ux-20261019/F0` a `F3`; ESTADO_ACTUAL controla las pruebas vigentes. El corte del 18/10 inferior es antecedente.

- I1: `SessionService.rejectIfCurrent` comprueba token/generación antes de invalidar una sesión rechazada. Los servicios protegidos llaman esa única comprobación; GoRouter observa la sesión y decide la navegación con aviso. No hay BuildContext en servicios, otro gestor de sesión, persistencia ni revocación backend. 503/desconexión no equivalen a 401. El login conserva su tratamiento de credenciales incorrectas.
- I2: se reutiliza `GenericResponse<SaturationReportReward>` con códigos de resultado, sin cambiar API. `409 + REPORT_COOLDOWN` confirma el rechazo; transporte/respuestas no verificables producen `REPORT_UNCERTAIN`. Un 201 requiere mensaje e ID positivos válidos y correspondencia de lugar/nivel si se incluyen; una recompensa inválida/ausente no genera puntos en UI. El formulario conserva envío único y guardas, bloquea reenvío desde incertidumbre y permite revisar `/profile/reports`. HTTP no es garantía de entrega exactamente una vez: no se añade idempotencia de servidor ni reintentos automáticos.
- I3: `PlaceMapControls` extrae solo el controlador del campo y composición adaptable. `PlacesCubit` sigue siendo dueño de nombre/categoría/nivel AND, última petición y limpieza por sesión; no se crea un segundo buscador. La ruta de búsqueda original se conserva. Catálogo/selector/marcadores usan ID y coordenadas reales. La consulta nueva retira la selección anterior; escribir sin consultar no recentra. `SaturationPanel.compact` reutiliza el mismo DTO y oculta solo explicación/conteos/fechas en Más información; detalle mantiene la presentación completa. Acciones de reportar, detalle e historiales quedan fuera del desplegable.

Son composición de widgets, coordinación Observer del framework y límites de transporte/presentación existentes, no nuevos patrones GoF. Alternativas descartadas: navegar desde cada servicio, migrar toda la capa HTTP, otro buscador local incompatible o un tema nuevo. Reducirían poco estas brechas y ampliarían el riesgo. Costes conservados: estado estático de sesión, scroll en pantallas bajas/texto ampliado y verificación de respuestas. Pruebas de sesión, transporte, navegación, ID y disposición mantienen esos límites verificables; no se reorganizan carpetas.

Corte local del 18/10/2026. Flutter Android/Web; Web responsive es plataforma principal. Rama `feature/local-s03-validacion-analitica-20261017`, no publicada ni aceptada formalmente. Conserva Cubit, GoRouter, flutter_map, Material 3 y tema publicado; excluye el experimento visual de la carpeta original.

## Responsabilidades e imports

Pages/components → cubits → servicios HTTP → API. Models son DTO y configs contiene API_BASE_URL pública y formateo horario. No hay SQL, SMTP ni claves privilegiadas en Flutter. AppTheme/AppColors conservan identidad; no hay reorganización masiva de carpetas.

AuthCubit, SessionService y router conservan JWT/usuario en memoria, generación de sesión y guardas. Recargar pierde sesión; logout no revoca por sí mismo el JWT del backend. Un cambio/reset sí invalida versiones. El servidor sigue autorizando cada operación.

PlacesCubit mantiene nombre/categoría/nivel, última solicitud y limpieza por sesión. PlaceService construye queries combinadas, timeout y mensajes seguros. Detalle conserva su clave por ID de Nick; las rutas nuevas de revisión/historial también llevan ValueKey por recurso. No se reutiliza estado de otro ID.

ReportPlaceSheet usa SaturationReportService de Manu. Bloquea doble envío y cierre durante la petición, limpia estado al cambiar sesión y descarta respuestas tardías. Solo muestra premio real enviado por API. Perfil e historial personal se reutilizan; IDs BIGINT viajan como texto y fechas se presentan explícitamente en Lima.

## Incremento HU5–6

- ApiJsonClient centraliza transporte de los recorridos nuevos: Bearer, 15 segundos de timeout, generación y errores de vocabulario público. No decide permisos de negocio ni muestra cuerpos arbitrarios.
- ReportReviewService decodifica CitizenReport; PlaceHistoryService verifica estructura antes de construir widgets. Sus servicios no conocen BuildContext.
- RequestCubit comparte únicamente requisitos comprobados de carga/escritura: última solicitud, envío único, limpieza/logout y descarte tras dispose. Un 401 vigente borra sesión; uno antiguo no cierra una sesión posterior. No es GenericRepository.
- ReportHubPage/ReportReviewPage muestran últimos 50 reportes, conteos, confiabilidad, elección definitiva y denuncia confirmada. El autor no tiene botones de participación. El servidor impone lo mismo.
- PlaceHistoryPage muestra bloques, conteos de dos períodos y horarios basados en datos suficientes; fechas editables, máximo 31 días, Lima y advertencias explícitas. Sin aforos inventados ni medias de categorías.
- Historial personal permite abrir el estado propio desde su detalle. PlaceDetailPage enlaza al historial del lugar. Formularios, scroll y navegación usan componentes existentes.

## Patrones y alternativas

| Estado / clasificación | Problema y participantes | Alternativa, beneficio/coste y pruebas |
| --- | --- | --- |
| Existente: presentación reactiva Cubit, no GoF State | Pages → Cubits → Services | FutureBuilder/estado local simplifica casos aislados, pero repetiría carreras. Se comparte RequestCubit solo donde los requisitos coinciden. Coste: estados/generaciones/suscripciones; tests de concurrencia, 401 y logout. |
| Existente: Observer del framework | SessionService Listenable/ValueNotifier → router/cubits/listeners con dispose | Evita callbacks dispersos; coste de estado global estático y limpieza. No se afirma Singleton GoF ni se añade event bus. |
| Local: adaptador de transporte/DTO, no Repository de DB | ApiJsonClient + servicios + modelos; HU5–6 | HTTP en widgets mezclaría presentación/errores. Centraliza timeout y traducción pública; cuesta validar contratos. Tests JSON incompleto/errores/BIGINT. No llamar Factory Method a fromJson/create por nombre. |
| Local: componente de interacción | ReportPlaceSheet; HU4.1 | StatefulBuilder podía perder una petición al cerrar. Componente controlado conserva montaje/sesión; cuesta manejar teclado/scroll. Ocho pruebas de R01 y recorrido real. |

DRY no sustituye permisos del servidor por guardas UI. SOLID se aplica con límites comprobables, no nuevas capas por apariencia. No se migraron framework, gestor, dependencias, Gradle ni locks.

## Evidencia y límites

Flutter 3.41.9 / Dart 3.11.5: análisis limpio, 448 aprobadas y 2 opt-in omitidas; build Web final 58,7 s. 17 tests nuevos S3 incluyen 360/390/1440 y texto 2x, lista/revisión/análisis, carreras y errores. Recorridos IAB + API/PostgreSQL QA y capturas en ESTADO_ACTUAL.

IAB no equivale a Chrome normal ni Android; Android final y SMTP real no se repitieron. No certificación WCAG. Referrer strict-origin-when-cross-origin conserva OSM sin enviar query/fragmento de recuperación entre orígenes. No persistir JWT ni desactivar seguridad del navegador.

Contrato y UML editables canónicos en backend docs/CONTRATO_API.md y docs/modelos/consolidacion.puml. Preparación de nube no equivale a despliegue.
