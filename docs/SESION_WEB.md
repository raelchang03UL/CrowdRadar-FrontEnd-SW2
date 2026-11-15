# Continuidad de sesión Web

**Integrado en `develop`, publicado y con recorrido público de sesión aprobado en IAB**, corte del **13/11/2026**. El [PR #33](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/pull/33) se fusionó mediante `2e7c33d433ddee53269ba16ec0c2ebfba387c5c6`, con padres `ba40207812a64af6b68c5ddc0d5374ff7e091d85` y `9e72ec067360ca0e663f8b03a1d779b4485f686a`. Su árbol coincide con el candidato probado (`ced1818c4a0d09d2de7075077068c277634e0c04`); la implementación de recuperación está conservada en `be308424b9178a5e5371c1f0cafa75fa9c4a1752`.

La ejecución nueva sobre SHA limpio `9e72ec0` aprobó análisis (**54,4 s**), **843 pruebas, 0 fallos y 2 opt-in omitidas** (**41 s**) y build Web de producción (**39,4 s**) para la API HTTPS y Firebase de la demo. `main.dart.js` tiene SHA256 `bd7cb14e8cc32842015955265e4f3eaecea4826c75ebcce2ff451241b4be4029`. El paquete se publicó sin recompilar como `dpl_D7icCscCXuzPg327CQQZX7HdavnC`, READY, con alias `crowdradar-demo-web.vercel.app` asignado. El smoke público aprobó **37/37**, incluidos 28 archivos estáticos coincidentes y TLS, sin autenticación. [Evidencia de publicación](evidence/session-reload-20261113/release-verification.json).

La comprobación pública posterior, registrada a las **21:15:59.975 UTC**, se realizó en el navegador integrado: login de cuenta sintética existente → mapa con cinco lugares → perfil con 60 puntos → recarga con el mismo perfil y saldo sin nuevas credenciales → logout → recarga conservando login con campos vacíos. [Aceptación pública](evidence/session-reload-20261113/public-browser-acceptance.json) y [captura tras recargar](evidence/session-reload-20261113/public-profile-after-reload.png). No acredita Chrome normal nuevo, FCM/correo real, ON/OFF de alertas, Android/iOS, multitab ni cierre prolongado. La prueba de interrupción/reintento se hizo antes en QA local; no se detuvo la API pública.

La API y la base de datos se conservaron. Se mantiene `dpl_4BcTtyyXUAfXxztGv2dDgLsS2sy9` como destino de reversión del mismo alias con comprobación posterior de hashes, sin rollback SQL/API; no se ejecutó. [Estado y límites](ESTADO_ACTUAL.md).

La validación local documentada se ejecutó antes del commit, con backend QA `55fee83bdf09e19afe01e2523522c6ca8ac4bdb9`. Las 14 fuentes/pruebas coinciden por hash con las ahora conservadas en `be308424`; esto no convierte las pruebas anteriores en una nueva ejecución sobre SHA limpio. [Resumen versionable](evidence/session-reload-20261113/local-validation.json). Este documento describe el cambio autorizado para conservar la sesión al recargar; no cambia las evidencias históricas ni el contrato de autenticación del backend.

## Decisión y datos conservados

Web guarda bajo `crowdradar.session.v1` un único registro de `sessionStorage` con cuatro campos:

| Campo | Uso |
| --- | --- |
| `version` | Esquema del registro: 1. No es la versión de sesión del backend. |
| `apiOrigin` | Valor exacto de `ApiConfig.baseUrl`; impide recuperar el registro al compilar contra otra API. |
| `token` | JWT recibido al iniciar sesión; se conserva sin renovarlo. |
| `alertsEnabledForReload` | Decisión ON/OFF; ausente se interpreta como OFF. No concede permisos. |

No se guarda una copia del perfil/`UserModel`, contraseña, binding del dispositivo ni transición histórica. El JWT sí contiene los claims que ya emite el servidor; guardar el token no elimina esos datos. Android/iOS usan el adaptador sin persistencia y conservan la sesión solo en memoria. No se añade `localStorage`, refresh token, cookie, endpoint ni dependencia.

El alcance es la recarga de la sesión de página. `sessionStorage` se separa por origen y pestaña; una página con `opener` puede recibir una copia inicial, que después evoluciona de forma independiente. No hay sincronización de logout ni garantía de continuidad entre pestañas. Cerrar/reabrir el navegador indefinidamente no es parte del contrato. [MDN: duración, separación y excepciones de sessionStorage](https://developer.mozilla.org/en-US/docs/Web/API/Window/sessionStorage).

## Recuperación y caducidad

1. `main` llama a `prepareRestore` antes de construir el router. El registro pasa filtros de claves/tipo/versión/API, longitud y formato JWT HS256 con `exp` futuro. No se verifica la firma en Flutter: el candidato permanece privado, con `token`/usuario públicos vacíos y autenticación falsa.
2. `restore` consulta `GET /api/users/profile?_sessionCheck=…` con `Authorization: Bearer`, una clave nueva por intento y timeout de 15 s. Evita reutilizar una URL de comprobación anterior sin cambiar el endpoint. No añade cabeceras de caché que modifiquen CORS.
3. Solo HTTP 200 con perfil válido, ID positivo admitido, rol conocido y estado ACTIVO habilita la sesión. El usuario/rol procede de esa respuesta; no se confía en un perfil almacenado ni en los claims decodificados localmente. Se vuelve a comprobar la caducidad antes de autenticar.
4. Durante la espera o un fallo temporal, `/session-restore` mantiene bloqueadas las rutas. Red, timeout, 503, otros estados distintos de 200/401 o un perfil malformado permiten **Reintentar**; no exponen datos protegidos ni convierten el error en sesión válida. Solo hay una validación en curso.
5. Un 401 de la recuperación vigente descarta el candidato y lleva al login con aviso. **Iniciar sesión con otra cuenta** cancela la recuperación. Tras un éxito, el router retoma únicamente un destino interno y vuelve a aplicar las guardas de sesión/rol.

El backend emite JWT con vigencia original de **dos horas**. Recargar/reintentar no cambia `exp`, no pide otro JWT y no prolonga el registro FCM más allá de esa sesión. La lectura local de `exp` es un filtro temprano; la API sigue validando firma, versión y autorización en cada petición. No se añade un temporizador de renovación. Un cambio/reset de contraseña conserva la invalidación de versiones existente en backend; el siguiente rechazo vigente limpia el cliente.

Intento, generación y candidato capturado impiden que un 200 o 401 pendiente restaure una sesión cerrada o elimine la de otra cuenta, incluso si se repite el mismo token. Los servicios protegidos mantienen `rejectIfCurrent`; un rechazo antiguo se ignora.

## Logout y almacenamiento fallido

Logout elimina token, usuario y preferencia en memoria, invalida la restauración e intenta retirar el registro antes de notificar a los observadores. Bloquea las rutas sin requerir un endpoint nuevo; no revoca por sí solo un JWT todavía válido en el servidor.

Un registro corrupto, vencido o de otra API se descarta sin consultar el perfil. Si leer el almacenamiento lanza una excepción, se conserva el flujo de login en memoria. Si escribir una cuenta nueva u OFF falla, se intenta borrar el registro anterior para no recuperar A/ON por accidente. Si `removeItem` también está bloqueado, solo se garantiza la invalidación en memoria: no se puede asegurar la eliminación física ni que un registro residual desaparezca al recuperar el acceso al almacenamiento. No se oculta esa limitación como logout persistente garantizado.

## Elección de alertas al recargar

La primera activación sigue requiriendo el gesto explícito del usuario. Solo un POST de registro confirmado guarda ON. Tras recuperar y validar la sesión, ON permite consultar el permiso existente con `getNotificationSettings`; únicamente `authorized` permite continuar. No se llama a `requestPermission` durante la reanudación. OFF, sesión ausente/vencida/pendiente o permiso no concedido no obtienen un token ni registran el dispositivo.

La reanudación conserva la caché FCM del SDK, obtiene su token con `getToken` y hace una sola alta HTTP por generación observada. El backend actualiza el registro de ese token y devuelve un `registrationId` nuevo. **Cada POST conserva el contrato existente de borrar el outbox asociado al registro anterior, incluidos pendientes**; no es una operación de solo lectura ni promete conservar mensajes en tránsito. La deduplicación entre inicialización y restauración evita un segundo POST por el mismo aviso de sesión. El binding anterior y su contexto histórico no se restauran desde almacenamiento.

Desactivar guarda OFF **antes del DELETE** e invalida de inmediato la autorización local. Solo 204 confirma la baja remota; si falla o vence el plazo, no se reanuda automáticamente al recargar. Las colas y guardas descartan permisos/tokens/altas tardías y compensan registros de sesiones abandonadas antes de registrar otra cuenta. La aplicación no abre mensajes de un binding anterior. El worker sigue requiriendo una pestaña autenticada viva; no se extiende la garantía a aplicación cerrada.

## Riesgo y compatibilidad

La elección conserva el Bearer actual entre Web y API de distintos orígenes, bajo el CORS existente. El registro pertenece al origen Web, aunque identifique la API destinataria. No se migró la autenticación a cookies `HttpOnly`; hacerlo requeriría otro diseño de servidor/cliente y no forma parte de este cambio.

`sessionStorage` sigue accesible a JavaScript del origen. Una inyección XSS puede leer o alterar el JWT; la menor duración del almacenamiento no elimina ese riesgo. Validar el perfil evita aceptar contenido almacenado como autorización, pero no impide que un script malicioso use un token robado. Esta decisión acotada de continuidad no es una recomendación general de guardar identificadores de sesión en Web Storage. [OWASP: almacenamiento, XSS y diferencia frente a HttpOnly](https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html#storage-apis).

## Matriz de validación local previa a la publicación

| Comportamiento | Evidencia del candidato y alcance |
| --- | --- |
| Registro mínimo; perfil fresco antes de autenticar; formato/API/caducidad; 401 vigente; red/503/timeout y reintento único; 200/401 antiguos; almacenamiento bloqueado y fallo de escritura con limpieza | [session_restore_test.dart](../test/session_restore_test.dart), **30 casos**. |
| Ruta protegida sin consulta previa; espera/reintento a 360 y texto 2×; 401→login; otra cuenta cancela respuesta tardía | [session_restore_route_test.dart](../test/session_restore_route_test.dart), **4 casos**. |
| ON confirmado; una alta al reanudar; caché/binding nuevo; sin permiso automático; OFF/baja incierta; carrera de cuentas; compensación y timeout | [push_session_reload_test.dart](../test/push_session_reload_test.dart), **14 casos**, Firebase/HTTP simulados. |
| Regresiones completas | [Resumen y huella del log](evidence/session-reload-20261113/local-validation.json): **843 PASS, 0 fallos, 2 opt-in omitidas**. Son **48 casos nuevos sobre 795**, ya incluidos; no sumar de nuevo suites dirigidas. |
| Análisis y compilación | [Resumen versionable](evidence/session-reload-20261113/local-validation.json): análisis sin incidencias y Web correcto en **63,7 s**, Flutter 3.41.9/Dart 3.11.5, API local 3067 y Firebase deshabilitado. Incluye hash del build local. |
| Contrato API en QA local | [Resumen saneado](evidence/session-reload-20261113/local-validation.json): 12 solicitudes, incluida aceptación del cache-buster y rechazo de JWT vencido/versión anterior. No prueba por sí sola la recarga del navegador. |
| Recarga, interrupción/reintento y logout en Chrome local | Observación de interfaz y confirmación humana, correlacionadas con GET frescos; [browser-session-acceptance.json](evidence/session-reload-20261113/browser-session-acceptance.json). La última recarga tras logout fue confirmada por el usuario, no por el control automatizado. |

Los originales completos `analyze-final.log`, `tests-final.log`, `build-final.log`, `api-smoke-final-evidence.json` y `browser-session-acceptance.json` se conservan en QA local. Sus resúmenes versionables no incluyen credenciales, rutas privadas ni contenido de logs; no requieren enlazar archivos ajenos al repositorio.

## Recorrido en Chrome local

El **13/11/2026**, antes de la publicación y sobre el build local con la API QA 3067, se comprobaron estos recorridos. La [copia saneada de la evidencia local](evidence/session-reload-20261113/browser-session-acceptance.json) distingue observación automatizada, solicitudes seguras de API y confirmaciones del usuario; no contiene credenciales.

1. **Sesión conservada:** se observó login y perfil de la cuenta sintética QA Recarga. El usuario confirmó que recargar conserva el perfil sin volver a iniciar sesión. Los GET de perfil con `_sessionCheck` respondieron 200 a las **19:34:03.506 y 19:34:04.411 UTC**; corroboran la validación fresca sin atribuir una petición concreta al mensaje humano.
2. **API interrumpida y recuperación:** se detuvo únicamente la API local propia. Recargar Chrome mediante su barra mostró `/session-restore?returnTo=/profile`, «No pudimos comprobar tu sesión» y **Reintentar**, sin datos del perfil. Tras reiniciar la API, pulsar Reintentar devolvió el perfil QA Recarga sin introducir credenciales. El GET fresco respondió 200 a las **19:38:59.297 UTC**.
3. **Logout conservado:** Cerrar sesión llevó a `/login` con campos vacíos. El control automatizado no pudo completar la siguiente recarga por una URL indeterminada. El usuario la realizó y confirmó que seguía mostrando **Iniciar sesión**. La conclusión de ese último paso procede de su confirmación directa, conservada literalmente en la evidencia.

Este recorrido valida esos tres comportamientos de sesión, no toda la interfaz. Firebase estaba deshabilitado y los **14 casos nuevos de reanudación push siguen siendo simulados**. No se probaron el control ON/OFF en GUI, FCM/correo reales, Android/iOS, multitab ni cierre/reapertura prolongada. No se ejecutó ningún envío para documentar el resultado. Las aceptaciones de correo/FCM del 04/11 permanecen históricas. [Resumen vigente y procedencia](ESTADO_ACTUAL.md).
