# Estado actual

## Corte local de consolidación Release 01 — 17/10/2026

Rama `feature/local-r01-consolidacion-20261017`, no publicada; base Bffe9b19/Fdfdb753. Se reutilizaron los diez PR de Nick y las tres ramas independientes de Manu, preservando commits/autores. No se tocaron los árboles originales con borradores/experimento. No implica aceptación humana de17 HU.

- Sin premio ficticio: el formulario solo muestra recompensa enviada por API; bloqueo de doble envío/cierre durante petición, errores públicos y descarte/limpieza tras cambio de sesión. Perfil/historial reutilizados, sin arrastrar Gradle/locks/exclusiones del analizador.
- Flutter3.41.9/Dart3.11.5: análisis sin problemas;431 aprobadas/2 opt-in omitidas. Incluye8 nuevas de reporte/filtros/errores/sesión y360/390/1440 a texto2x. Build Web correcto66,8s antes del último ajuste puramente de llaves; se repetirá sobre el candidato final.
- Navegador IAB real + API3033 + PostgreSQL QA: registro/login, selección/saturación, reporte→+10 real, detalle con dirección ausente honesta,perfil con10,historial propio,filtros combinados/categoría/vacío. Móvil390×844 y escritorio1440×900. La primera revisión encontró y corrigió BIGINT textual del perfil.
- Capturas en docs/evidencias/consolidacion_2026_10_17: referencia origin/develop dfdb753 y después con el mismo catálogo QA,viewport yselección; no son capturas del experimento rechazado.
- Pendientes: Android/build manual final, SMTP real y las2 opt-in omitidas. IAB no se presenta como Chrome normal ni una auditoría WCAG.

Políticas aprobadas por Rael:10 puntos por reporte válido una sola vez;cooldown3 minutos;3 personas/30min para saturación yempate insuficiente. Código local probado no equivale a integración compartida/aceptación. Las secciones siguientes conservan fechas/resultados históricos; no usarlas como instrucciones vigentes.


## HU 3.4 — búsqueda de lugares, 10/10/2026

Rama `feature/hu-3-4-busqueda-lugares`, posterior a HU 3.3, para frontend #5. Lupa del mapa → buscador protegido, nombre completo/parcial, todas las coincidencias, sin resultados, limpiar y reintento con la consulta conservada. Resultado → detalle; regreso mantiene consulta/resultados. Solicitudes antiguas y cambios de sesión no restauran datos.

No modifica tema, sesiones ni dependencias. El PR se compara inicialmente contra la rama de detalles; integrar HU 3.3 antes de cambiar su base a develop. Backend compañero en la rama homónima; resultados reales y par de SHA en los PR. Android, revisión humana y catálogo real pendientes.

## HU 3.3 — información del lugar, 10/10/2026

Rama `feature/hu-3-3-detalles-lugar`, desde develop `dfdb753`, compañera de backend #7. Marcador → Ver detalles abre `/places/:id` con nombre, dirección, categoría y referencia, estados de carga/error/reintento y aviso demostrativo. El cubit y el servicio descartan respuestas de generaciones de sesión anteriores; logout elimina los datos y el router vuelve a login.

Se conserva la navegación y el tema existentes. No incluye búsqueda ni modifica dependencias. Una dirección no registrada no se sustituye por referencia. Requiere backend HU 3.3 y migración 004; par probado y pruebas reales en los PR. Android, aceptación humana y catálogo real pendientes.

Las secciones siguientes conservan la evidencia histórica de otras tareas.

## HU 3.5 — filtro por categoría local, 11/10/2026

Rama `feature/hu-3-5-filtro-categoria`, desde `origin/develop` `dfdb75371d9c3a8ecdb7bc79cf8346988659f0ba`, para frontend #6. Backend compañero en la rama homónima desde `46267e7c273d889a85710e33f32ff7a839f52ec9`. Registro de validación local previo a publicación: entonces sin staging, commits, publicación ni modificaciones de Issues/Project. Consultar Git/PR para la publicación posterior; no implica integración.

El mapa consulta categorías activas mediante `/api/places/categories`; elegir/cambiar usa `/api/places?categoria=...` y quitar restaura el listado. La categoría es literal y de hasta 80 caracteres Unicode. El selector y el mapa muestran carga, vacío, error y reintento; el reintento conserva la categoría. Cubits/servicio descartan solicitudes anteriores, logout, cambio de generación y vistas cerradas. No se añade HTTP en widgets, geolocalización, radio de cercanía, niveles ficticios ni controles de saturación.

- Flutter 3.41.9 / Dart 3.11.5: `flutter analyze --no-pub` sin incidencias; `flutter test --no-pub` **254 aprobadas, 0 fallidas, 2 integraciones de autenticación opt-in omitidas** en este rerun. 28 casos nuevos de categoría además de los 226 existentes.
- Widgets con mapa/MarkerLayer reales y teselas en memoria: seleccionar/cambiar/quitar, sin coincidencias, reintentos, selector abierto durante logout, categorías largas, 360/390/1440 dp y texto 2×. Los primeros ensayos detectaron un overflow del filtro y una opción larga fuera del viewport; se corrigió la disposición/etiqueta y se repitió la suite sin ocultar excepciones.
- Backend compañero: 68/68 pruebas Node y 7 bloques PostgreSQL aislados aprobados, incluyendo catálogo/filtro ORM + HTTP sobre `crowdradar_hu31_test`; la consulta de sesión en ese runner usa un doble explícito. Fixtures revertidos y datos previos conservados. No equivale al recorrido completo del frontend con autenticación real.
- `git diff --check` correcto; sin cambios en dependencias, lockfile, Gradle, router, tema global ni modelos compartidos.
- Compilación Web final aprobada (99,0 s) con API local en `127.0.0.1:3002`. Recorrido interactivo en navegador integrado (IAB), app Flutter servida en `127.0.0.1:5502`: login con cuenta ficticia local y autenticación real PostgreSQL `crowdradar_dev`, 3 lugares demostrativos, catálogo Cultura/Parque/Plaza, selección Parque → 1 marcador, cambio Cultura → 1 marcador, quitar filtro → 3 marcadores y selección de lugar conservada. No se modificaron los lugares existentes ni se usaron credenciales reales del usuario; se creó una cuenta QA local identificable. Vacío/error y demás bordes se verificaron en pruebas automatizadas, no se atribuyen a este recorrido manual. IAB no equivale a Chrome normal. Android omitido expresamente por decisión del usuario; no declarado aprobado.

Esta rama parte de `develop` y no incluye los incrementos separados HU 3.2/3.3/3.4. Reconciliar mapa/servicio/cubit y las queries de búsqueda/categoría al integrar esos incrementos; no descartar uno en favor del otro. Revisión humana/integración/aceptación pendientes. Se revisó el informe de Software I en la carpeta autorizada del Drive para mantener el alcance de la HU; no se modificó Drive ni se atribuyeron reglas de cálculo de saturación no definidas.

Captura del recorrido IAB: [categoría Cultura aplicada](evidencias/hu_3_5/2026_10_11/cultura.jpg), sin credenciales ni datos personales.

## Corrección — margen Android del selector HU 3.6, 12/10/2026

`SafeArea` mantiene las opciones por encima de la barra de navegación, sin nuevas funciones, reglas, API ni dependencias. Solo cambia el selector y añade dos regresiones: ambas fallaron antes y aprobaron después del arreglo en una copia limpia del PR frontend #20, padre `63bf1ffc6ea15b7145a2f6e27b54c4e8ba6e281c`.

Validación individual: análisis limpio; 352 pruebas aprobadas, 0 fallidas y 2 integraciones auth opt-in omitidas; diff-check correcto. Los dos Dart son idénticos a los probados en Android sobre la copia conjunta. El [registro Android fechado](evidencias/hu_3_6/2026_10_12/VALIDACION_ANDROID.md) distingue aquel recorrido nativo y sus 463 pruebas de esta suite individual. Los antecedentes conservan su fecha: no acreditan revisión humana ni el futuro par integrado.

Los ajustes conjuntos de integración permanecen locales y fuera de esta publicación, por indicación del usuario. No se crean PR adicionales. No se fusionan ramas, no se cierran Issues y no se publica el entorno Android. Coordinación HU 3.2/HU 4.1 y comprobación después de integrar siguen pendientes.

## Corrección — mensaje vacío HU 3.6, 11/10/2026

El filtro sin coincidencias presenta literalmente el criterio del Issue #7: «No existen lugares cercanos que cumplan con ese criterio». Conserva el nivel seleccionado, los controles para cambiar/quitar y el reintento. Es un ajuste de redacción; no incorpora GPS, radio, cálculo de distancias ni cambios del contrato o algoritmo backend.

Validación local de la corrección: análisis sin problemas; suite completa, 350 aprobadas/0 fallidas/2 omitidas opt-in; pruebas del mensaje exacto en ausencia de resultados y layouts 360/390/1440 con texto2×; formato de los dos Dart afectados y diff-check correctos. Android continúa pospuesto y no se repitió el recorrido Web en esta corrección. Los registros anteriores mantienen su alcance y fecha.

## HU 3.6 — filtro de saturación, 11/10/2026

Rama `feature/hu-3-6-filtro-saturacion`, padre HU 3.2 frontend `9c831decf868b856248db96dad8e8db8464207b8`; backend compañero parte de `0605b51fb5aa6933de9b587e9ad9c73f5e46c2d1`. [Issue canónico #7](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/issues/7). Registro previo a publicación; el PR dependiente apunta al padre HU 3.2, aún no integrado en develop. Consultar los PR para el SHA final del par; no se modifican Issues/Project ni se realiza merge.

Selector Todos/Tranquilo/Moderado/Saturado, contexto del filtro y botón quitar. Usa el enum existente de HU 3.2 y método aditivo `getPlacesBySaturation`, conservando `getPlaces()`. HTTP solo en servicio; algoritmo/ventana/votos solo en backend. Actualizar/reintentar conservan el nivel; cambiar/quitar consulta otra lista. Carga, ausencia de coincidencias y errores públicos (401/400/503/timeout) no inventan niveles ni prometen radio o actualización automática.

Las solicitudes antiguas quedan descartadas por operación/sesión/dispose. Logout limpia filtro; retornar del selector exige contexto montado y misma sesión autenticada. Cada lista nueva retira selección previa y cierra la consulta HU 3.2, incluso con respuesta inmediata sin frame de carga. Seleccionar un resultado sigue mostrando su panel HU 3.2. Semántica/teclado del selector y textos identifican nivel sin depender solo del color.

- Flutter 3.41.9/Dart 3.11.5: `flutter analyze --no-pub`, sin problemas; `flutter test --no-pub`, 350 aprobadas/0 fallidas/2 omitidas (integraciones auth opt-in). 48 pruebas nuevas de servicio/cubit/UI: tres niveles/Todos/cambiar/quitar, vacío/error/reintento, latest/session/logout/dispose, selección anterior, layouts 360/390/1440 y texto2×/teclado/semántica.
- Revisión detectó riesgo en viewport bajo; el test 360×360/texto2× reprodujo overflow del encabezado. Se corrigió en MapPage con encabezados desplazables/altura limitada, quitar siempre visible y encuadre de cámara adaptado. Test corto, suite completa y análisis pasaron después. Se corrigieron fixtures de animación/tema/Tooltip antes de la suite final, sin ocultar excepciones.
- Formato de ocho Dart candidatos sin cambios, diff-check limpio; paquetes desde caché, sin modificar pubspec/lockfile, router/tema/SessionService/PlaceModel ni Gradle. Build Web final `flutter build web --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:3006`, aprobado en 57,4 s; build no publicado.
- Recorrido IAB en loopback:5506, API real HU 3.6 en 3006 y PostgreSQL `crowdradar_auth_test`: login QA → Tranquilo/Moderado/Saturado cada uno con un marcador y nivel individual coincidente/tres personas → cambio retira selección → actualizar conserva filtro → quitar recupera cuatro lugares, uno sin reportes → logout/nuevo login vuelve a Todos. Son fixtures ficticios transaccionales de tres usuarios, no reportes reales ni confirmados. Teselas reales OSM, atribución y aviso demostrativo visibles. El helper solo inyectó transacción en modelos/repositorios reales; no falseó respuestas HTTP. Errores/vacío/races/layouts son automatizados, no se atribuyen al recorrido positivo manual.
- Backend compañero: 92/92 Node y cinco bloques PostgreSQL/HTTP reales aprobados, rollback y filas/historial completos conservados. Al finalizar Web se cerraron procesos/conexiones; la verificación posterior de solo lectura confirmó ausencia de fixtures QA y cuatro migraciones anteriores. No nueva migración en HU 3.6 ni uso de Sprint 1/Supabase.
- Revisión independiente final del diff, de lectura, sin bloqueos; no sustituye la revisión humana del equipo. Android no ejecutado: se pospone expresamente; no se instala SDK/emulador ni se usa teléfono.

Captura sin credenciales: [filtro Saturado y consulta HU 3.2](evidencias/hu_3_6/2026_10_11/saturado.png), datos QA ilustrativos. Pendientes: acuerdo/coordinación HU 3.2/HU 4.1, integrar primero padre y luego par HU 3.6, reconciliar MapPage con los otros PR y validar Android. Si «cercanos» exige distancia, el equipo debe precisar radio/geolocalización antes de prometerla. PR abierto no equivale a HU Done.

## Incremento local HU 3.2 — consulta de saturación, 11/10/2026

Rama `feature/hu-3-2-consulta-saturacion`, base develop frontend `dfdb75371d9c3a8ecdb7bc79cf8346988659f0ba`. [Issue canónico backend #6](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/issues/6). Registro de validación local previo a publicación: entonces sin staging, commit, push, PR, merge ni cambios en el backlog. Consultar Git/PR para la publicación posterior; no implica integración. El backend compañero implementa un contrato aditivo y una migración explícita; este incremento no depende de los PR de detalles/búsqueda todavía en revisión.

Mapa → marcador → identificación + consulta autenticada de saturación. Presenta carga, error/reintento, tres niveles textuales, cero/pocos reportes y empate sin nivel. La actualización manual vuelve a consultar la ventana vigente; fecha de consulta y último reporte considerado se muestran en hora local. Panel desplazable de altura limitada, sin tapar permanentemente acciones; conserva atribución OSM y aviso demostrativo. No hay HTTP ni algoritmo de votos en widgets.

Política provisional confirmada para esta implementación: mínimo 3 personas distintas en 30 minutos, último reporte por usuario y nivel más votado; empate o pocos usuarios producen «Sin información suficiente». No es una regla ya acordada por todo el equipo ni aforo medido. Backend determina votos/ventana; frontend usa cifras/fechas del DTO y rechaza respuestas malformadas, incoherentes o para otro lugar. No incorpora formulario de reportes ni inventa saturación de los demos.

Validación automatizada local final: `flutter analyze --no-pub` sin problemas; `flutter test --no-pub`, 302 aprobadas, 0 fallidas, 2 omitidas (integraciones auth opt-in); `git diff --check` correcto y formato de los 8 Dart candidatos sin cambios. Las 76 pruebas nuevas cubren DTO/fechas/ID negativos, JWT/errores públicos/timeout, respuestas obsoletas por selección o sesión, retiro al cerrar/logout, reintento, niveles/pocos/empate y layouts 360/390/1440 dp con texto 2×, incluidos error y ausencia. Se corrigieron avisos de llaves y el fixture de una respuesta pendiente en tests antes de repetir análisis/suite; no se ocultaron excepciones. Las pruebas HTTP usan dobles y teselas en memoria: no prueban una API/base de datos real.

Build Web final aprobado (87,1 s), con `API_BASE_URL=http://127.0.0.1:3003`. Recorrido interactivo en navegador integrado (IAB), app Flutter en `127.0.0.1:5503` y backend `startServer` con PostgreSQL real `crowdradar_dev`: login con cuenta ficticia local previamente creada para HU 3.5; mapa con tres demos; seleccionar Parque muestra «Sin información suficiente», 0 personas y mínimo 3; desplazar el panel permite leer ventana de 30 minutos/fecha/aviso de estimación y acceder a Actualizar saturación; actualizar vuelve a consultar y cambia la fecha; cerrar retira el panel; seleccionar Plaza muestra la identificación y consulta correctas. Sin reportes ficticios persistidos ni credenciales reales del usuario. La migración compartida se aplicó explícitamente en dev, comprobando conservación de usuarios/lugares/reportes/historial previos. IAB no equivale a Chrome normal; niveles conocidos/empates y errores se prueban automatizadamente, no se atribuyen al recorrido manual sin reportes.

Backend compañero: 78/78 pruebas Node y cinco bloques PostgreSQL reales en `crowdradar_auth_test`, incluyendo HTTP de los tres niveles/insuficiencia/empate y sesiones persistidas. Fixtures completamente revertidos; detalle en su ESTADO_ACTUAL. Android expresamente omitido por decisión del usuario: no se instala SDK/emulador ni se usa teléfono, y no se afirma validación Android. Revisión humana, acuerdo de equipo de la política/dependencia HU 4.1 e integración en develop siguen pendientes. El historial de otras ramas/plataformas que sigue debajo conserva su fecha; no acredita este incremento.

No se cambian pubspec/lockfile, Gradle, router, tema, PlaceModel ni SessionService. Paquetes resueltos desde caché con `flutter pub get --offline`, sin actualizar versiones. Reconciliar los cambios compartidos del mapa con HU 3.3/3.4/3.5 al integrar y repetir las regresiones del par.

Captura del recorrido IAB: [lugar sin reportes suficientes](evidencias/hu_3_2/2026_10_11/sin-informacion.jpg), sin credenciales ni datos personales.

## Corrección — error persistente en cambio de contraseña, 10/10/2026

Rama `fix/hu-2-3-error-cambio-password` desde develop `cffd3d5` (HU 3.1, A, B y C ya integrados por #9, #11, #12 y #13). El recorrido Chrome del 10/10 mostró que, tras «La contraseña actual no es correcta.», el mensaje seguía visible mientras se corregían los campos y junto a errores de validación nuevos. Ahora editar cualquier campo (`Form.onChanged`) retira el error del envío anterior; carga, guardas de sesión y doble envío no cambian. `flutter analyze --no-pub` limpio; `flutter test --no-pub` 226 aprobadas/2 omitidas opt-in (la prueba de error corregible comprueba la retirada). Sin cambios de contrato ni dependencias.

## Corrección — Referer y teselas del mapa, 10/10/2026

Rama `fix/web-referrer-mapa`, padre C `652ea260480a39774b11dcea6bdd4c53b85f5fb0`. El recorrido en Chrome del par C mostró todas las teselas como «Access blocked»: la meta `no-referrer` añadida en C impedía enviar Referer y OpenStreetMap lo exige. Comprobado con las mismas teselas: sin Referer, imagen de bloqueo (HTTP 200, ~7 kB); con Referer de origen, tesela real. La meta pasa a `strict-origin-when-cross-origin`: solo sale el origen; el token de recuperación va tras `#` y nunca forma parte del Referer. La cabecera `no-referrer` de las respuestas de la API backend no cambia.

- `flutter analyze --no-pub` limpio; `flutter test --no-pub` 226 aprobadas/2 omitidas opt-in; `git diff --check` correcto.
- Chrome normal 10/10 tras reiniciar `flutter run`: el mapa muestra las teselas reales de Lima con los tres marcadores demostrativos. En la misma sesión, con backend `feature/hu-2-1-correo-smtp` y correo real (Brevo), el enlace recibido abrió el formulario, el restablecimiento volvió a login con aviso y el enlace reutilizado no mostró formulario.
- Pendiente: Android y la integración `local_recovery_api_test.dart`, que presupone el clon hermano `../CrowdRadar-Backend/` (en esta PC los clones se llaman `CR-BackEnd`/`CR-FrontEnd`).

## Hito C — HU 2.1–2.2, avance verificable, 08/10/2026

Rama `feature/hu-2-1-2-recuperacion`, padre B frontend `1e62c754682f3abe2b166b178d44b7e6e7d1fad0`; backend compañero parte de `97e607ed22b48561bed30a4e821099f76360210d`. A/B/C dependen de HU 3.1 todavía sin integrar (PR #9/#26 abiertos en borrador). Publicar estas ramas no cambia develop/main ni completa un Sprint; no se abrieron nuevos PR ni se modificó backlog.

Login → recuperación pública con mensaje uniforme → enlace GoRouter → validación HTTP antes de mostrar campos → nueva contraseña/confirmación → login normal. Enlace inválido/expirado/usado no muestra formulario. Servicio sanea respuestas/timeout; cubits bloquean dobles envíos y descartan respuestas de otra operación/sesión. Éxito limpia la sesión vigente y reemplaza la ruta sensible; no abre sesión automáticamente. Meta Web `no-referrer`, token no mostrado en widgets ni persistido en almacenamiento. La invalidación real de JWT y el consumo atómico pertenecen al backend/migración003.

**Entrega real pendiente:** el equipo confirmó que no hay proveedor elegido. El servidor normal devuelve indisponibilidad uniforme, sin generar enlaces ni simular envío. Correo/aviso capturados en pruebas no demuestran entrega real; HU 2.1/Sprint2 no están terminados. Tampoco se verificó apertura de enlaces en la app nativa Android.

- `flutter analyze --no-pub`: sin problemas.
- `flutter test --no-pub`: 226 aprobadas, 0 fallidas, 2 omitidas (integraciones locales opt-in). 79 casos nuevos C: contratos/errores/timeout, validación antes de formulario, enlace inválido, doble envío, respuestas antiguas, navegación pública/guardas y layouts360/390/1440, texto2×/teclado. Fallos iniciales de estilo/compilación y un fixture de navegación se corrigieron antes de la ejecución final; no se ocultaron excepciones.
- Opt-in C: 1/1 aprobada con widgets VM + HTTP real + PostgreSQL18 `crowdradar_auth_test`. Solicitud y correo en RAM → enlace real del servicio → respuesta200 de validación antes de campos → reset → JWT anterior401 → contraseña vieja rechazada/nueva válida/perfil → aviso RAM → enlace usado400 sin formulario. No es navegador/Android ni email real. El helper privado inicia/cierra puerto3031, no expone buzón por HTTP ni imprime enlaces/credenciales. Deja cuenta QA aleatoria identificable en la DB aislada.
- Opt-in B reejecutado sobre C: 1/1 aprobado contra backend3000 y `crowdradar_dev`.
- `flutter build web --no-pub --dart-define=API_BASE_URL=http://localhost:3000`: correcto,63,8s. `flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000`: correcto,33,9s. Contingencia temporal corta de Gradle documentada; aviso SDKXML4/herramienta3 no bloqueante. Builds/APK ignorados, no publicados.
- `git diff --check` correcto; pubspec, lockfile, Gradle y dependencias sin modificaciones. No se instaló ni actualizó ningún paquete.

Para repetir C, con ambos clones hermanos en esta rama de revisión, `.env` backend local configurado y PostgreSQL18 activo:

```powershell
# Primero en CrowdRadar-Backend; crea/reutiliza solo la base auth_test protegida.
npm run test:db:auth
npm run test:db:recovery
# Después en CrowdRadar-FrontEnd (no simultáneo con los runners DB).
$env:CROWDRADAR_RECOVERY_INTEGRATION = '1'
flutter test --no-pub test/local_recovery_api_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:3031
Remove-Item Env:CROWDRADAR_RECOVERY_INTEGRATION
```

El helper requiere permiso de migración en `crowdradar_auth_test`; no cambia la `.env`, no usa dev/entrega/Supabase y no necesita que el servidor3000 envíe correo. Sus presupuestos de abuso se separan por ejecución sin borrar contadores; el runner backend comprueba los límites reales. Backend500/503 y doble/respuesta antigua se comprueban con dobles controlados, no todos como fallos inyectados en PostgreSQL.

No se repitió recorrido Chrome normal, IAB ni Android para A/B/C; se respetó la detención de seguridad previa sin eludirla con otra herramienta. Capturas disponibles: widgets antes/después de A abajo, no capturas actuales de correo ni prueba manual de B/C. Recepción real, enlaces nativos, revisión/integración y reproducción en otra PC siguen pendientes.

## Hito B — HU 2.3, 08/10/2026

Rama `feature/hu-2-3-cambio-password`, padre A `0361ae13017def4d9c135a78b3b95ab1f07bf635`. Backend compañero misma rama desde HU 3.1 `c2aa7c0`; requiere migración 002 explícita. Bases aún sin integrar: no se abrió PR nuevo ni se modificaron PR HU 3.1, develop/main o backlog.

Perfil → Cambiar contraseña: tres campos ocultos con visibilidad opcional, confirmación, 8 caracteres Unicode/72 bytes UTF-8, rechazo de reutilización, teclado y formulario estable durante carga/error. Servicio sanea códigos/timeout; cubit bloquea doble envío y conserva guardas de generación. Éxito/401 de sesión vigente limpia datos y vuelve a login con aviso fijo; respuesta antigua nunca cierra una sesión nueva. El backend invalida efectivamente todos los JWT anteriores mediante versión persistente.

`flutter analyze --no-pub`: sin problemas. Suite normal: 147 aprobadas, 0 fallidas, 1 omitida (integración local opt-in); 37 casos nuevos de HU 2.3. Un fallo intermedio del fixture de scroll se corrigió bombeando el frame final, sin alterar viewport ni ocultar errores. Layouts 360/390/1440, texto 2× y teclado simulado.

Integración opt-in contra backend real/crowdradar_dev: 1/1 aprobada con widgets VM; registro/login/perfil, actual incorrecta, cambio correcto/cierre/aviso, ruta protegida, JWT viejo401, cambio sinJWT401, login viejo rechazado y nuevo correcto. Cuenta QA aleatoria conservada, sin credencial publicada. No es navegador ni Android.

Para reproducir solo esa prueba, con servidor local migrado en `crowdradar_dev`:

```powershell
$env:CROWDRADAR_API_INTEGRATION = '1'
flutter test --no-pub test/local_api_smoke_test.dart --dart-define=API_BASE_URL=http://localhost:3000
Remove-Item Env:CROWDRADAR_API_INTEGRATION
```

Build Web aprobado (32,0 s) y APK debug aprobado (32,9 s), con URL localhost/10.0.2.2 respectivamente. Se utilizó la contingencia temporal corta documentada para Gradle; permanece el aviso de XML SDK versión4/herramienta3, sin impedir compilación. APK/builds ignorados, no publicados.

Chrome normal/Android y entrega de correo no probados manualmente en este incremento; no afirmar validación manual ni cierre de Sprint. Recuperación/restablecimiento aún fuera de B. El pulido y sus capturas constan abajo.

## Hito A — pulido aplicado, 08/10/2026

Rama `feature/ui-flujos-ciudadano`, padre `feature/hu-3-1-mapa-lugares` en `f2437a2991293fa275626e4d5e8819a22b1aed2a`. HU 3.1/PR #9 sigue sin integrar; esta rama no modifica ese PR ni `develop`/`main`.

Tema neutro, tarjetas claras, formularios contenidos, logo compacto y espaciado compartido. Perfil/edición 680/560 dp, carga inicial/reintento, errores públicos y timeout 15 s; guardar no elimina formulario y bloquea doble envío. Navegación inferior crece con texto ampliado. Mapa conserva datos demostrativos y atribución, sin funciones nuevas. Contratos, dependencias y sesión no cambiaron.

Validación: `flutter analyze --no-pub` sin problemas; `flutter test --no-pub` 110/110 (69 anteriores +37 perfil/edición +4 layouts); build Web correcto. Widgets 360/390/1440 dp, texto 2× y teclado simulado, no recorrido manual. La primera ejecución focalizada detectó overflow de 2 px en navegación 2× y un fixture lazy; ambos corregidos, suite global aprobada sin ocultar excepciones.

[Capturas antes/después y límites](evidencias/ui_flujos_2026_10_08/README.md). No se repitió Chrome normal, IAB ni Android: revisión manual pendiente. No se eludió la detención de seguridad de Chrome. Sin afirmar certificación de accesibilidad ni cierre de Sprint.

## Registro histórico — cierre local HU 3.1 / Web, 07/10/2026

Fotografía de la validación local del 07/10/2026, anterior a su publicación: rama `feature/hu-3-1-mapa-lugares`, HEAD/base `f214886d7a40aabfc3b10b0af1a266128cc421fe`, entonces sin staging, commit ni publicación. HU 2.4 integrada se conserva, con JWT sin revocación backend. Para conocer la publicación/integración posterior, comprobar Git y los PR relacionados; los resultados siguientes conservan su fecha y alcance.

## Validación final Web y formularios

- `dart format` únicamente sobre los 17 Dart candidatos; el formateo incidental de otros archivos se revirtió y no queda en el diff.
- `flutter analyze --no-pub`: `No issues found!`, código 0.
- `flutter test --no-pub`: **69: All tests passed!**, código 0. Incluye los 25 casos anteriores HU 2.4, 23 de lugares/mapa, 7 de layout/navegación Web y 14 de usabilidad/servicio de autenticación. Cubre 1440×900, 390×844 y 360×360, sin ocultar overflows/excepciones.
- `flutter build web --no-pub --dart-define=API_BASE_URL=http://localhost:3000`: **Built build/web**, `58,7 s`, código 0; dry-run Wasm correcto, avisos informativos de tree-shaking. No se probó un despliegue de ese build release; el recorrido fue sobre el servidor de desarrollo de la misma app.
- `git diff --check`: código 0. Sin cambios de pubspec, lockfile, Gradle ni dependencias. `web/index.html` solo bootstrap de Flutter.

Los intentos intermedios detectaron getters incorrectos en el test de visibilidad y avisos de estilo; después, 68 pruebas pasaron y 1 falló por una respuesta simulada con texto español sin charset UTF-8. Se corrigió el doble HTTP (el backend real usa JSON UTF-8), sin ocultar el resultado. La ejecución final anterior aprobó los 69 casos.

## Recorrido manual Web verificado

URL **http://localhost:5500/#/login**, API **http://localhost:3000**, PostgreSQL 18 local `crowdradar_dev`. Chrome fue iniciado con `flutter run -d chrome --web-hostname=localhost --web-port=5500 --no-pub --dart-define=API_BASE_URL=http://localhost:3000`; no usa `--disable-web-security`. Oracle sigue en IPv4 `127.0.0.1:5500`; Flutter en IPv6 `::1:5500`. No se cambió a 5000 ni se detuvo Oracle.

**Alcance de la evidencia:** el recorrido interactivo siguiente se ejecutó en el navegador integrado (IAB), sobre esa app Flutter y URL local. El control del Chrome normal no estuvo disponible de forma fiable; queda pendiente repetirlo allí con Rael. No se presenta IAB como Chrome normal. Contraseña aleatoria local de 40 caracteres ASCII, solo en memoria, oculta en capturas; sin credencial predeterminada ni autoalmacenamiento.

| Paso | Resultado observado en IAB |
| --- | --- |
| Registro nuevo | Rael / Chang, correo QA único, teléfono 9 dígitos y Miraflores. Volvió a login con «Cuenta creada. Ya puedes iniciar sesión…». SQL confirmó usuario y bcrypt en crowdradar_dev. |
| Correo repetido | «El correo ya está registrado. Inicia sesión o usa otro correo.», sin perder los campos. |
| Validación de seis campos | Formulario vacío mostró errores por nombre/apellido/distrito, correo, contraseña y teléfono; requisitos visibles. Malformados/límite UTF-8 cubiertos además por tests. |
| Login recién registrado | Abrió `/#/map`; consulta autenticada y 3 lugares recibidos. |
| Contraseña incorrecta | «Correo o contraseña incorrectos.», sin abrir sesión. |
| Backend apagado | Se detuvo solo nuestro servidor, puerto 3000 sin listener; login mostró mensaje comprensible y formulario conservado. Se reinició backend y GET / respondió 200. |
| Mapa y marcadores | Teselas OpenStreetMap y 3 marcadores; aviso demostrativo/sin tiempo real. |
| Selección | Demo · Parque Central / Parque · Demostrativo; no detalles completos. |
| Cierre | Perfil mostró Rael Chang; Cerrar sesión volvió a login con campos vacíos. |
| Reingreso protegido | Entradas a `/#/map`, `/#/validar`, `/#/favoritos`, `/#/profile`, `/#/profile/edit` redirigieron a `/#/login`. |
| Recargas | Recarga completa en `/#/login`: formulario vacío; en `/#/register`: registro público; en `/#/map` sin sesión: URL final `/#/login`. Una espera automatizada de accesibilidad expiró mientras cargaba Flutter; después se inspeccionó y activó la accesibilidad, sin cambiar la app ni desactivar seguridad. La prueba automatizada también cubre éxito de registro sin historial previo. |
| Diseño y teclado | 390×844 y 1440×900 inspeccionados; Tab desde Distrito alcanzó Registrarme; mostrar/ocultar probado sin revelar la credencial. No es una auditoría completa WCAG/lector de pantalla. |

Capturas nuevas (no reemplazan las Android): [mapa/identificación](evidencias/hu_3_1/web_2026_10_07/01_mapa_identificacion.jpg), [backend apagado](evidencias/hu_3_1/web_2026_10_07/02_login_backend_apagado.jpg), [login móvil](evidencias/hu_3_1/web_2026_10_07/03_login_movil.jpg), [registro móvil](evidencias/hu_3_1/web_2026_10_07/04_registro_movil.jpg), [validaciones escritorio](evidencias/hu_3_1/web_2026_10_07/05_validaciones_escritorio.jpg).

### Problema observado y corrección contenida

Antes no se explicaban todos los requisitos; el formulario desaparecía durante la solicitud y errores de red podían mostrar `ClientException`. Registro directo podía intentar volver sin historial. Se añadieron ayudas, validación coherente 8 caracteres/72 bytes, mostrar/ocultar, estados inline públicos con región accesible, campos/botones deshabilitados durante la solicitud y descarte de respuestas antiguas. Un error de registro no se muestra como error de login. Ancho máximo 480, centrado/scroll; no se rediseñó el resto. No hay prueba que permita atribuir todo el fallo original de Rael a una única causa de infraestructura; las deficiencias de interfaz/código sí están identificadas.

Pendientes reales: Chrome normal, clonación limpia de este incremento aún no publicado, revisión de equipo y fuente canónica; sesión solo en memoria, JWT no revocado, User.sync histórico, OSM requiere Internet. No se repitió Android tras las últimas correcciones de formulario. No se implementaron recuperación/restablecimiento/cambio, saturación ni detalle completo.

## Inventario final para revisión (sin staging)

29 archivos: 9 modificados y 20 nuevos. `M`/`??` reproducen `git status --porcelain=v1 --untracked-files=all` desde la raíz del repositorio frontend. Incluyen el incremento previo conservado, no solo los ajustes de este cierre.

```text
 M README.md
 M docs/ESTADO_ACTUAL.md
 M lib/components/cr_bottom_nav.dart
 M lib/configs/api_config.dart
 M lib/cubits/login_cubit.dart
 M lib/pages/login/login_page.dart
 M lib/pages/map/map_page.dart
 M lib/pages/register/register_page.dart
 M lib/services/auth_service.dart
?? docs/evidencias/hu_3_1/2026_10_07/01_mapa_lugares.png
?? docs/evidencias/hu_3_1/2026_10_07/02_identificacion.png
?? docs/evidencias/hu_3_1/2026_10_07/03_error_backend_apagado.png
?? docs/evidencias/hu_3_1/2026_10_07/04_reintento_correcto.png
?? docs/evidencias/hu_3_1/web_2026_10_07/01_mapa_identificacion.jpg
?? docs/evidencias/hu_3_1/web_2026_10_07/02_login_backend_apagado.jpg
?? docs/evidencias/hu_3_1/web_2026_10_07/03_login_movil.jpg
?? docs/evidencias/hu_3_1/web_2026_10_07/04_registro_movil.jpg
?? docs/evidencias/hu_3_1/web_2026_10_07/05_validaciones_escritorio.jpg
?? lib/components/auth_fields.dart
?? lib/components/auth_form_layout.dart
?? lib/cubits/places/places_cubit.dart
?? lib/cubits/places/places_state.dart
?? lib/models/place_model.dart
?? lib/services/place_service.dart
?? test/auth_usability_test.dart
?? test/map_page_test.dart
?? test/places_test.dart
?? test/web_layout_navigation_test.dart
?? web/index.html
```

Revisión de candidatos: sin archivos mayores de 5 MB, generados ni asignaciones de credenciales locales detectadas; JWT real ausente en los textos revisados, `.env` no rastreado. `.dart_tool`, `build/web`, `local.properties`, SDK/AVD y APK siguen fuera de Git. `HEAD = develop = origin/develop` (referencias locales verificadas), diferencia `0 0`; el trabajo está en archivos, no en commits. `origin/main` conserva `6286e0a9c17b41e1e4c3303e32ca102316bc095d`; no existe rama local main en este checkout y no se creó. Evidencias HU 2.4 sin cambios.

## Registro inicial HU 3.1 — 07/10/2026

Rama local `feature/hu-3-1-mapa-lugares`, desde `develop` / merge HU 2.4 `f214886d7a40aabfc3b10b0af1a266128cc421fe`. Se verificó limpio y sincronizado con `origin/develop` antes de crear la rama. Cambios sin staging, commit ni publicación. Issue [#4](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/issues/4) leído, sin modificaciones.

## Flujo implementado y comprobado

- `PlaceModel` valida datos y coordenadas finitas/rangos. `PlaceService` consulta `/api/places` con JWT, tiempo máximo de 15 segundos y mensajes públicos; no muestra excepciones técnicas.
- `PlacesCubit` aplica generación de sesión, última solicitud y guarda de vista cerrada. Logout borra inmediatamente la lista; respuestas antiguas no repueblan el estado. Las guardas globales HU 2.4 permanecen intactas.
- `MapPage` reutiliza AppTheme/AppColors y navegación inferior. Muestra carga, vacío, error/reintento y marcadores dinámicos; encuadra los puntos y permite desplazar el mapa. Selección breve con nombre/categoría y cierre, sin HU 3.3 completa. No hay búsqueda o controles decorativos.
- No existía catálogo canónico en el código/Issue revisados. Los tres puntos del fixture backend son ilustrativos, con nombres `Demo · ...`, bandera `demostrativo` y aviso visible **Sin monitoreo en tiempo real**. No se atribuyen a lugares realmente monitoreados.

## Validación real

- `flutter analyze --no-pub`: **No issues found!**, código 0.
- `flutter test --no-pub`: **48: All tests passed!**, código 0: 25 anteriores, 18 de servicio/modelo/cubit y 5 widget del mapa.
- Los widgets usan 360 × 800 dp, tema real, FlutterMap/MarkerLayer reales y teselas en memoria solo para evitar red externa en tests. Prueban carga, vacío, marcadores/coordenadas, selección, desplazamiento, error/reintento y retiro de marcadores al cerrar sesión.
- Primera suite nueva: 43 aprobadas y 5 fallidas por `A RenderFlex overflowed by 1.00 pixels on the bottom.` Se corrigió exclusivamente el ajuste del texto de CrBottomNav a una línea con elipsis; sin ampliar el fixture ni ocultar excepciones. Se corrigieron tres avisos de estilo observados durante el desarrollo; análisis final limpio.
- `git diff --check`: sin errores. Sin cambios en pubspec, lockfile, Gradle, SDK ni dependencias.

## Android 16 / API 36

Se reutilizó `CrowdRadar_API36`, `emulator-5554`, arranque completo `sys.boot_completed=1`. `flutter run -d emulator-5554 --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000` compiló el APK debug (assembleDebug 31,9 s), lo instaló y abrió la app. Se usó una cuenta local existente, sin registrar otro usuario.

1. Login desde interfaz contra backend local/PostgreSQL 18 en `crowdradar_dev`.
2. [Mapa OpenStreetMap cargado y tres marcadores](evidencias/hu_3_1/2026_10_07/01_mapa_lugares.png).
3. [Selección: Demo · Parque Central / Parque · Demostrativo](evidencias/hu_3_1/2026_10_07/02_identificacion.png).
4. Se detuvo únicamente nuestro backend; Actualizar mostró [error público y Reintentar](evidencias/hu_3_1/2026_10_07/03_error_backend_apagado.png), sin ClientException visible.
5. Backend reiniciado; pulsar Reintentar recuperó [los tres marcadores y el mapa](evidencias/hu_3_1/2026_10_07/04_reintento_correcto.png).

La carga y el vacío se probaron automáticamente, no se capturó una base real vacía en Android. El error manual corresponde al backend apagado, no a una caída de OpenStreetMap. Persistió la advertencia no bloqueante `This version only understands SDK XML versions up to 3 but an SDK XML file of version 4 was encountered.`

## Criterios y límites

Los tres criterios técnicos del Issue #4 están demostrados localmente: consulta autenticada con marcadores, coordenadas recibidas exactas y error informativo con recuperación. Pendientes de revisión del equipo, commit/publicación autorizada y fuente canónica de lugares para un uso real. No se marcó el Issue como completado.

La identificación no incluye descripción completa, aforo ni saturación. No hay HU 3.2, HU 3.3 completa, favoritos, geolocalización, reportes, búsqueda ni filtros. JWT sigue sin revocación backend. La migración de `places` no resuelve todavía `User.sync()` histórico. OpenStreetMap necesita Internet; no se añadió modo offline ni tratamiento específico de errores de teselas.

## Registro histórico — HU 2.4

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
