# Arquitectura frontend

## Revisión administrativa HU7.1 — 28/10/2026

AdminReportsPage/AdminReportDetailPage → cubits derivados de RequestCubit → AdminReportService → ApiJsonClient. Modelos separados validan resumen, detalle, agrupaciones, cursor e historial. Las pantallas presentan información y confirmaciones; no calculan permisos efectivos ni hacen HTTP. El router conserva el guard ADMIN y el backend revalida al actor para cada operación.

La decisión envía revisión y total leídos. Guardado pendiente impide doble envío y salida; un409 o una respuesta incierta ocultan acciones obsoletas y piden actualizar. Al decidir se reinicia el cursor del historial. Cambiar sesión invalida respuestas y cierra la confirmación. Estado Pendiente puede coexistir con decisiones anteriores porque una denuncia nueva reabre la revisión; no representa pérdida del historial.

El historial propio reutiliza su modelo y tarjeta con isPublic, y CitizenReport permite removedFromPublic solo para una consulta propia. Etiquetas y explicación aclaran el retiro conservando evidencia y puntos. Cambios aditivos en las rutas existentes, sin reemplazar ApiJsonClient, RequestCubit, tema, dependencias ni locks. Migraciones008/009 del backend son prerrequisito. La visualización de Sites permanece independiente del código local real.

## Confirmación e historial administrativo — 28/10/2026

AdminUserDetailPage conserva RequestCubit para leer/guardar; AdminAccountPanel y AdminAccountDialog contienen presentación y confirmación. AdminHistoryCubit reutiliza RequestCubit y guarda solo el cursor de la página actual. AdminUserService valida la revisión/estado/ID del resultado y el orden/cursor del historial, sin lógica de permisos visual que sustituya al servidor. AdminAccountAction mantiene ID BIGINT textual; fechas mediante limaDate existente.

La revisión forma parte de la clave del panel para renovar el historial tras cada transición; regresar a la lista recarga sus datos y conserva filtros. La acción pendiente bloquea envío y vuelta; una respuesta no verificable exige leer antes de decidir de nuevo. La confirmación se cierra al cambiar sesión. No se modifican ApiJsonClient ni RequestCubit compartidos, tema, dependencias o rutas ciudadanas. El backend exige migración008 y conserva la autorización real. Ver ESTADO_ACTUAL para pruebas de widgets, PostgreSQL y recorrido Web independientes.

## Consulta de usuarios HU7.2 — 27/10/2026

Incremento local: AdminUsersPage → AdminUsersCubit/RequestCubit → AdminUserService → ApiJsonClient → rutas administrativas reales. AdminUserDetailPage reutiliza RequestCubit para la lectura por ID. AdminUser valida el DTO; el servicio exige que ID/paginación correspondan a lo solicitado y descarta respuestas incoherentes. No hay datos administrativos simulados en producción ni dependencias nuevas.

Perfil muestra Administrar usuarios únicamente al cargar una cuenta ADMIN. El router restringe ambas páginas; la autorización efectiva sigue en el backend. La búsqueda se ejecuta con Buscar/Enter, combina estado y texto, reinicia página y presenta solo el último resultado vigente. Lista y detalle son rutas separadas; volver conserva filtros y listado. Los estados cargando/vacío/error y la limpieza al cambiar sesión reutilizan las guardas del proyecto. Material 3, AppTheme y AppColors se conservan, con disposición adaptable y scroll. Suspensión, reactivación y auditoría aún no se habilitan en este incremento.

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
