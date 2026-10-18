# Arquitectura frontend

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
