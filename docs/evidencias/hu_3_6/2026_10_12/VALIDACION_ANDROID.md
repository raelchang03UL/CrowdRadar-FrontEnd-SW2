# Validación local Android — 12/10/2026

## Alcance de esta publicación

El único cambio de producto corresponde a HU 3.6: `SafeArea` evita que la opción Saturado quede parcialmente debajo de la barra de navegación Android. Se añaden dos pruebas del margen inferior del sistema, con texto 1× y 2×. No se añaden opciones, funciones, dependencias, reglas de saturación ni cambios de API.

Los ajustes conjuntos de integración de HU 3.2–3.6 permanecen locales y no se publican. Tampoco se crean PR adicionales ni se fusionan los existentes.

## Rama individual HU 3.6

La corrección se trasladó a una copia limpia de `feature/hu-3-6-filtro-saturacion`, sobre el commit `63bf1ffc6ea15b7145a2f6e27b54c4e8ba6e281c` del PR frontend #20.

- Antes del arreglo, las dos regresiones fallaron: el botón llegaba a y=812 frente al límite seguro y=796, en una vista 390×844 con margen inferior de 48 dp.
- Después del arreglo, las dos regresiones aprobaron y comprobaron también que Saturado podía seleccionarse.
- `flutter analyze --no-pub`: sin problemas.
- `flutter test --no-pub`: 352 aprobadas, ninguna fallida y dos integraciones de autenticación opt-in omitidas.
- Compilación Web de esta rama: correcta; no se repitió su recorrido manual individual.
- Compilación Android debug x86_64 de esta rama: correcta, con el SDK existente; APK no publicado. No se repitió su recorrido nativo individual.
- Diff-check correcto; dependencias, lockfile y configuración Android sin cambios.

Los dos archivos Dart coinciden exactamente con los utilizados en la prueba Android conjunta descrita a continuación. La suite individual no equivale a repetir aquel recorrido nativo ni a validar `develop` integrado.

## Evidencia Android previa sobre la copia conjunta

La prueba nativa del 12/10/2026 se realizó sobre una copia local conjunta de HU 3.2–3.6:

- Backend: `56e6637c97394b11229310701af037938c860bfd`.
- Frontend: `57977c2cc2998c5573010278b792d2df6388204e`, más la corrección del selector y sus dos regresiones.

Resultados de esa copia, no de cada PR individual:

- Análisis Flutter sin problemas; 463 pruebas aprobadas, ninguna fallida y dos integraciones de autenticación opt-in omitidas.
- Compilaciones Android debug y Web correctas.
- Recorrido nativo: login, mapa, información insuficiente y nivel calculado, búsqueda, detalle/dirección, filtros por categoría y saturación, retirada de filtros, vacío, error de conexión/reintento, cierre y nueva sesión.
- Las cuatro opciones del selector quedaron completas por encima de la barra Android y Saturado pudo seleccionarse.
- Comprobación Web final del selector: selección Saturado y regreso a Todos correctos.

Entorno: emulador AOSP Android 16/API 36 x86_64, perfil Pixel 7, APK debug, Flutter 3.41.9/Dart 3.11.5. Usuarios y lugares sintéticos, API y PostgreSQL de prueba reales; no datos ni servicios de producción. No se ejecutó el envío de reportes de HU 4.1. Los fixtures no se confirmaron y las comprobaciones de cierre conservaron filas e historial de la base de prueba.

## Límites y pendientes

Los registros anteriores que indicaban Android pendiente conservan su fecha y alcance: esta sección añade la evidencia posterior sobre la copia conjunta, sin atribuirla a todas las ramas individuales. No acredita dispositivos físicos ARM, distribución release/tienda, todos los fabricantes/versiones ni entrega real de correo. Persistió un aviso no bloqueante de XML del SDK, sin actualizar dependencias para ocultarlo.

No se publica APK, SDK, emulador, cachés, base de datos, configuración local, helpers ni credenciales. La revisión humana, coordinación del almacenamiento HU 3.2/HU 4.1, integración autorizada y comprobación del par definitivo en `develop` siguen pendientes. Ningún Issue se marca como terminado por esta evidencia.
