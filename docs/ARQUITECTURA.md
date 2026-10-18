# Arquitectura frontend

Corte local R01,17/10/2026. Una aplicación FlutterAndroid/Web,principalWebresponsive; conservaCubit,GoRouter,flutter_map ytemaMaterial3. Rama local no publicada,no incluyeexperimento visual de lacarpetaoriginal.

## Fronteras reales

Pages/components→cubits→serviciosHTTP→API. Models sonDTO;configs contiene soloAPI_BASE_URL pública. No SQL,SMTP ni clavesprivilegiadas enFlutter. AppTheme/AppColors controlan identidad. No cambio de framework/gestor/carpetas porapariencia.

AuthCubit/SessionService/router conservanJWT yusuario solo enmemoria,generación de sesión yguardas. Login/registro/recuperación sonpúblicos; el restoprotegidoporrouter yJWTbackend. Recargar pierde sesión. Logout noprovoca revocación backend; cambio/reset sí invalidanversiones. Las respuestasdeotraoperación/sesión ycubitscerrados sedescartan.

PlacesCubit mantiene nombre/categoría/nivel,última solicitud ylimpieza porsesión. PlaceService combinaobjetodeconsulta,saneaerrores ytimeouts; detalleusaclaveporID para reconstruirCubit al cambiode ruta. SatService/Cubit consultan laestimación deAPI,sin calcularaforo encliente.

ReportPlaceSheet reutiliza SaturationReportService deManu; solo presentación yestado delenvío. Bloquea doblepulsación ysalida durantepetición; limpiadatos al cambiarsesión ydescartarespuestatardía. Premioúnicamente delaAPI,no fallbackficticio. Perfil/historialdeManuusanlos endpoints propios; servidorautoriza yconservatransacciones.

## Patrones y decisiones

Cubit esgestiónreactivadeestado/presentación,no GoFState automático. SessionService notifica medianteListenable/ValueNotifier (Observer delframework),sin afirmarSingletonGoF. Reutilizarcomponentes/contratos evitaHTTPenwidgets; no seintroducenGenericService,FactoryMethod oeventbus sinproblema demostrado.

Alternativa aformulario modalcontrolado eraStatefulBuilder quepodíacerrarsedurantepetición yperderconfirmación; elcomponentepropio administra montaje,sesión ylistener/dispose. Coste: controlar asincronía/teclado/scroll;8pruebasnuevasde carreras/errores/responsive.

## Plataforma y evidencia

431 aprobadas/2opt-inomitidas,análisis limpio;buildWeb yrecorridoIAB+API/PostgreSQLQA.360/390/1440, texto2x probados enwidgets;IAB390×844 y1440×900. No equiparar IAB aChrome normal ni aAndroid; Androidfinal/SMTP real pendientes. ReferrerWeb strict-origin-when-cross-origin conservaOSM sin filtrarquery/fragmentoderecuperación. No persistirJWT ni desactivarseguridaddelnavegador.

Contrato yUML editable canónicos enbackend docs/CONTRATO_API.md ydocs/modelos/consolidacion.puml. Evidencias fechadasidentifican elpar yloslímites;verESTADO_ACTUAL.
