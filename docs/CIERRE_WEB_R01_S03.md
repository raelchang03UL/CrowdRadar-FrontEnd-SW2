# Cierre Web R01/S3 — evidencia frontend

## Corrección solicitada por N1c19 — 21/10/2026

Sobre frontend `e87c090c785f2b45ad6c0698f64133544ea3666d`, `PlaceHistoryPage` valida el formulario antes de cambiar de modo. Una fecha inválida conserva Historial y sus datos, muestra el mensaje de validación y no consulta al servicio. Corregirla permite consultar Comparar/Horarios normalmente. No se reescriben servicios, cubits o modelos ni se altera el diseño.

Regresión reproducible: `flutter test --no-pub test/place_history_mode_test.dart`. Primero carga Historial válido y prueba Desde A vacía/malformada hacia Comparar/Horarios, además de la consulta correcta posterior al error. Antes del arreglo: **4 TypeError** por interpretar los datos anteriores como Map/List de otro modo; **3/7** casos aprobados. Después: **7/7**, mensaje visible, cero consultas inválidas, modo/datos coherentes y sin TypeError. Incluye carga pendiente y respuestas antiguas exitosas/SESSION_INVALID que no restauran datos ni afectan otra sesión.

Validación funcional final: `flutter analyze --no-pub` sin problemas; `flutter test --no-pub` **569 aprobadas, 2 opt-in omitidas, cero fallidas**; `flutter build web --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:3053` correcto en 41,0 s, con salida absoluta nueva fuera del repositorio; `git diff --check` correcto. No instalaciones, SQL nuevo, correo real ni comprobación Android/navegador nueva. Las dos opt-in no se repitieron en este paquete; no atribuirles los resultados históricos inferiores.

El [backend compañero](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/pull/39) corrige únicamente el aislamiento SMTP de QA. Los nuevos SHA del par y resultados se registran en las conversaciones de revisión de ambos PR. **Changes requested** sigue pendiente de revisión de Nick sobre los heads actuales; publicación no implica merge, aceptación ni despliegue.

## Verificación de aceptación Web — 20/10/2026

Par funcional B`5d467ca66adb7a9dc26d2d0e13b87c957258e69d` / F`1ef1b9b7312bd8d57d508c10888427bb2cb1d005`. Documentación posterior sin cambios funcionales;par publicado en [F#21](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/pull/21) y [B#39](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/pull/39). Pendiente revisión ajena/merge;ningún develop,Release oSprintse declara aceptado automáticamente.

562pruebas generales aprobadas y2opt-in excluidas por defecto,pero ejecutadas aparte:1/1cambio de contraseña en3053 y1/1recuperación en3031,widgetsVM+HTTP/PostgreSQL real. Perfil explícito `cierre-20261019`;hijo de recuperación confirma base/procedencia y usa correoRAM porIPC. No recepción SMTP nueva. La espera inicial del smoke apuntaba a un título bajo el viewport;se ajustó a identidadQA conservando aserciones de clave incorrecta,cambio,JWPrevio401,logout ylogin nuevo. Repetición1/1. Análisis limpio;Web58s/API3053;diff-check correcto. [QA/correo histórico/plan nube backend](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/integration/cierre-web-r01-s03-20261019/docs/CIERRE_WEB_R01_S03.md).

RecorridoIAB5553 con cuenta sintética propia y PostgreSQLcierre real:alta/login,buscarQAParque/seleccionar,reporteMODERADO+10,historial→perfil,ciclo inverso yMapa,voto ajeno definitivo,denuncia persistida sin ocultar/permitir duplicados,actualizar estado,historia12–14oct(72bloques/6suficientes),comparación yhorario10:00/3días,logout y acceso directo protegido. Capturas nuevas:

- [Reporte confirmado](evidencias/aceptacion_web_2026_10_20/01-reporte.png).
- [Participación y denuncia persistidas](evidencias/aceptacion_web_2026_10_20/03-validacion-denuncia.png).
- [Horario histórico con datos suficientes](evidencias/aceptacion_web_2026_10_20/05-horarios.png).

Capturas sin credenciales;datos sintéticos,no negocio real. Respuestas antiguas/doble envío/200% corresponden a widgets,distinguir de navegador/SQL. Rael aprobó dirección ausente explícita y catálogo disponible sinGPS/radio20/10;criterios reconciliados sin cambiar implementación. Aceptación global pendiente de revisión ajena,merge ysmoke develop. Sin cambios del tema/Favoritos/HU7/8;Android/Chrome normal/lector/manual200%sin ejecutar.

## Evidencia histórica de publicación — 19/10/2026

19/10/2026. Rama `integration/cierre-web-r01-s03-20261019`; publicación/par final acreditados por PR, no integración/aceptación/despliegue.

## Versión y procedencia

Desde `18cec26d0f2da755b9e436f04b715f431f54563d`,con26commits sobre develop`dfdb75371d9c3a8ecdb7bc79cf8346988659f0ba` y pendientes F3/C2. Historial/autores de Nick/Manu conservados; base de Diego ya en develop. No cherry-picks de reconstrucción/rebase/force. Backend compañero parte de`eeff38b86c53d22180655ee5aa6fa501a2a5b061`,develop`ffe9b19`. Par final en los cuerpos PR para evitar una referencia circular al SHA del propio documento.

Nick:PR[16](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/pull/16),[17](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/pull/17),[18](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/pull/18),[19](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/pull/19),[20](https://github.com/raelchang03UL/CrowdRadar-FrontEnd-SW2/pull/20);heads incorporados como ascendencia. Manu:`5791c59/218a35d/26eb200/5f09315` paraHU4. Diego:autenticación/SMTP/mapa yF#14/#15 integrados antes. Base-equipoF#10/B#27 conservada, no cerrada. [Procedencia completa/contrato/evidencia backend](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/integration/cierre-web-r01-s03-20261019/docs/CIERRE_WEB_R01_S03.md). No confundir este PR de consolidación con una HU nueva.

## Qué se cierra

I1:401 vigente invalida sesión sin afectar una posterior;errores de red no expulsan. I2:confirmación/cooldown/incertidumbre diferenciados, sin premio inventado ni reenvío incierto. I3/C2:mapa/AND/selecciónID,ficha/catálogo plegable y puntos reales en perfil. F11:CrBottomNav compara índice **y ruta efectiva** antes de ignorar la pulsación, de modo que Historial→Perfil funciona sin reescribir router.

7regresiones F11 (1aprobada/6fallidas antes,7/7después):historial→perfil,perfil→historial→perfil,mapa/logout/rutas y respuestas200/401tardías sin restaurar datos ni navegar. Tema/OSM/Favoritos/I1/I2 conservados. No nuevo rediseño,HU7/8,dependencias/Gradle ni nube.

## Comprobación final

- Analyze sin problemas(42s);**562aprobadas,2opt-in omitidas,0fallidas**(16s).
- Build Web API3043 correcto31,2s;SHA256 main.dart.js:`4ae6c604b64025361b874ffe9504ff8438b39c99cf8c119b8ffd622e8ccc4fc8`. Intento relativo falló al escribir shaders; repetido únicamente con salida absoluta nueva, sin cambios de código.
- Backend173/173;SQL real demo cuenta sintética2:0/0/0→1reporte/1premio/10puntos;datos previos de otra cuenta conservados. No correo real.
- IAB final:alta/login,buscar Kennedy/seleccionar,plegar/reabrir con Enter conservando búsqueda/selección,reporte MODERADO confirmado,historial→perfil directo,ciclo perfil/historial,mapa,saldo10,logout y accesos protegidos devuelven login.
- Widgets cubren360/390/1440,texto200%,foco/filtros/error/selección/cámara y regresiones sesión/doble envío/cooldown/incertidumbre. No atribuir las carreras simuladas a SQL/navegador real.

### Capturas finales, sin contraseñas

| Comprobación | Captura |
| --- | --- |
| Catálogo plegado/búsqueda conservada |[01](evidencias/cierre_web_2026_10_19/01_catalogo_plegado.jpg) |
| Confirmación API+10 |[02](evidencias/cierre_web_2026_10_19/02_reporte_confirmado.jpg) |
| Historial real1reporte |[03](evidencias/cierre_web_2026_10_19/03_historial.jpg) |
| F11:Historial→Perfil/saldo10 |[04](evidencias/cierre_web_2026_10_19/04_historial_a_perfil.jpg) |
| Logout/rutas protegidas |[05](evidencias/cierre_web_2026_10_19/05_logout_rutas_protegidas.jpg) |

Comparaciones C2 históricas depuradas:misma cuenta/saldo0,catálogo5,Kennedy,0observaciones y tamaños1440×900/390×844 antes del envío:[escritorio antes](evidencias/cierre_web_2026_10_19/c2_antes_escritorio.jpg)/[después](evidencias/cierre_web_2026_10_19/c2_despues_escritorio.jpg),[móvil antes](evidencias/cierre_web_2026_10_19/c2_antes_movil.jpg)/[después](evidencias/cierre_web_2026_10_19/c2_despues_movil.jpg). No compararQA9lugares con demo5 como si fuera solo cambio visual. Las3capturas mapa_ux_2026_10_18 son históricas/intermedias, no el build final.

## Entrada y límites

[README](../README.md) y [demo canónica backend](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/integration/cierre-web-r01-s03-20261019/docs/CATALOGO_DEMO_LOCAL.md):locks/configuración propia,aprovisionamiento manual,migraciones/seed,API3043/Web5543,cuenta sintética propia. Sin tmp personal,QA ajena ni claves compartidas. SMTP demo apagado,sesión en memoria.

Pendientes:2opt-in,QA R01 desde cero,SMTP real,Android/Chrome normal/lector/manual200%,criterios/catálogo/aceptación visual/revisión humana,integración y nube.360×640 conserva poco mapa con ficha abierta. Npm audit10paquetes,1crítico sin fix;no aprobación para Internet. Publicación de revisión no acepta R01/S3 ni resuelve esos pendientes.
