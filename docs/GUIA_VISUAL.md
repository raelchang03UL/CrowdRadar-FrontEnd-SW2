# Guía visual — pulido sobrio

## Cierre19/10 — sin rediseño adicional

Se conserva C2:I1/I2/mapa/catalogo/perfil. Solo navegación F11 corregida; [evidencia final versionada](CIERRE_WEB_R01_S03.md). Publicación no equivale a aceptación visual ni integración. Cortes inferiores fechados son antecedentes, no instrucciones para repetir otro pulido.

## Catálogo y perfil ciudadano — 19/10/2026

Extensión acotada de I3, no otro tema: catálogo300dp desde1100dp con control textual Ocultar/Mostrar catálogo; mapa de identidad estable conserva selección/filtros/cámara. Móvil conserva Ver lista y ficha expandible. Acciones esenciales siempre fuera de Más información; ubicación breve con texto completo dentro del desplegable, sin direcciones inventadas. Búsqueda principal única; acceso a ruta anterior desde Más opciones. Contadores en singular/plural.

Perfil: tarjeta de puntos con saldo real y explicación de0inicial/10por reporte aceptado/no premio extra por cooldown. Sin niveles/beneficios nuevos. Oculta Rol/Estado solo visualmente; teléfono/distrito y funciones permanecen, sin controles de privilegios en formularios. Composición Column/Wrap para texto2×, no valores largos en trailing.

Comparación controlada y resultados en ESTADO_ACTUAL/informe local. En360×640 la ficha abierta ocupa gran parte del mapa; cerrar recupera área y la información secundaria usa scroll, no se reduce el texto. Texto200% se verificó en widgets, no manual/lector/Android. Validación visual humana pendiente; no certificación WCAG.

## Recorrido local I1–I3 — 19/10/2026

Objetivo: encontrar un lugar registrado, entender su estado, reportar y consultar el resultado, sin convertir el mapa en un dashboard. Se conservan tema, logo, colores y rutas. Implementación en el candidato, no en el experimento original ni en develop.

- Campo Buscar por nombre + Buscar/Enter; desde 1000 dp útiles, ancho de búsqueda 640 dp con filtros al lado. En móvil se apilan con Wrap; categoría y saturación llevan texto visible y selección removible. Se conserva la lógica AND de PlacesCubit y la lupa del buscador previo.
- Catálogo lateral de 300 dp desde 1100 dp; Ver lista reutiliza el selector en móvil. Marcadores superpuestos conservan contador/selector; ningún desplazamiento ficticio de lugares ni GPS del usuario.
- Ficha con nombre/categoría, Reportar saturación, Ver detalles, Historial del lugar y Mis reportes; estado textual y actualización. Más información despliega explicación, ventana, conteos y fechas reales. En áreas de mapa bajas se permite hasta 85 % de altura (60 % en las demás, máximo 480 dp), con scroll interno; los controles superiores también desplazan con texto ampliado/teclado. No se reduce la escala del texto para ocultar problemas.
- Éxito, cooldown confirmado e incertidumbre son estados distintos. Incertidumbre no ofrece otro envío: conduce a Mis reportes o Cerrar. Solo se muestra karma de API. Sesión rechazada vuelve a login con aviso; error de red conserva la sesión.
- Referencias consultadas como documentación: Flutter adaptativo, W3C texto 200 %/teclado y checklist comunitario Flutter Design Taste. NN/g no pudo recuperarse en esta ejecución (timeout); no se atribuye una revisión completada de esa página. Sin skills/scripts externos instalados, nuevo tema, degradados ni datos decorativos. No certificación WCAG.

Resultados y capturas antes/después en ESTADO_ACTUAL y `../../../../tmp/cierre-ux-20261019`. Las capturas del 18/10 inferiores son históricas, no el build final de I3. Aceptación visual humana y Android final siguen separados.

## Revisión del acceso a reportes, 18/10/2026

En `fix/mapa-reportes-ux-20261018`, el mapa ofrece Agregar reporte antes de seleccionar un marcador, selector buscable de lugares y catálogo lateral desde 1100 dp. Las acciones reutilizan el tema con medidas compactas; no cambian la identidad global ni el experimento anterior. Marcadores con coordenadas exactamente iguales muestran contador y permiten elegir: no se separan posiciones ficticiamente ni se promete agrupación por proximidad.

Se aplicaron como referencia [Flutter Design Taste](https://github.com/WellDunDun/skills/tree/main/skills/flutter-design-taste) y las [guías adaptativas oficiales](https://docs.flutter.dev/ui/adaptive-responsive/best-practices): acción principal reconocible, componentes pequeños, estados reales y comprobación con texto ampliado/teclado. No se instaló una skill global ni otra dependencia. La mejora sigue necesitando aceptación visual humana.

Corte histórico 18/10/2026: tema publicado ya integrado; incremento R01+HU5–6 entonces local. Experimento rechazado excluido; pantallas conservan colores/tipografía/componentes. Una mejora funcional no implica aprobación visual.

## Dirección

- Conservar el logo, azul principal `#1A3C8F` y Material 3. Reutilizar AppTheme/AppColors, no crear un tema distinto por página.
- Fondo neutro `#F5F7FA`, superficies blancas, texto secundario `#526078` y error `#B42318`. Revisión manual de plataformas pendiente.
- Espaciado coherente de 8/16/24/32 dp; márgenes de 16–24 en móvil. Evitar espacios grandes sin función entre logo, título y formulario.
- Una acción principal por bloque. Títulos, subtítulos y ayudas con jerarquía clara; sombras discretas, iconos existentes y radios moderados coherentes.
- Sin degradados llamativos, tarjetas anidadas sin motivo, animaciones continuas, indicadores inventados ni controles decorativos.

## Pantallas

Login/registro/recuperación/cambio: bloque de marca compacto, título y ayuda breve, formulario con ancho máximo legible; conservar campos durante carga/error, mostrar/ocultar contraseña, confirmación y foco/teclado adecuados. La ayuda al ciudadano debe hablar de la acción, no de servidores, SDK ni detalles de arquitectura; el diagnóstico técnico pertenece a documentación/logs privados.

Perfil/edición: identidad y datos agrupados, anchos máximos 680/560 dp, cierre de sesión reconocible. La acción de contraseña ya existe junto a su función real. Edición directa carga datos; guardar conserva formulario y errores públicos. No incluye gestión de roles.

Mapa: jerarquía entre título, contexto, mapa y selección. Mantener visible la advertencia de datos demostrativos y la atribución OpenStreetMap. Selección legible con botón de cerrar claro. Buscador, filtros, saturación y detalle proceden de sus HU funcionales, no de controles decorativos. Conservar avisos de insuficiencia y selección.

## Recorridos locales añadidos

- Reportar: selección clara, una acción pendiente, no cerrar durante envío, premio real y errores públicos.
- Validar: lista legible y revisión con conteos, regla provisional y elección definitiva. Motivo de denuncia opcional con confirmación; sin ocultación automática. Texto no depende solo de color.
- Historial: fecha/hora Lima explícita, controles de período, resumen categórico y mensajes distintos de ausencia/insuficiencia. Horarios históricos no son una predicción.
- Anchos máximos y ListView/Wrap permiten móvil y texto ampliado; teclado probado al confirmar y en filtros de R01. No afirmar cobertura manual de todos los controles.
- Evidencia actual en ESTADO_ACTUAL; pares antes/después del mapa R01 y nuevas capturas S3. Widgets probados a 360/390/1440 y texto 2x; IAB móvil y escritorio, no certificación WCAG ni Android final.

## Criterios de revisión

1. Comprobar móvil 360/390 dp y escritorio 1440 dp, además de teclado visible y texto ampliado cuando afecte formularios.
2. Sin overflow, recortes de botones ni dependencia exclusiva del color; controles táctiles adecuados, etiquetas y foco visibles.
3. Contraste suficiente, estados deshabilitado/carga/error/éxito distinguibles y texto accesible. No afirmar certificación de accesibilidad sin evaluación.
4. Capturas antes/después de las mismas pantallas/tamaños sin credenciales, mensajes privados ni datos personales.
5. Repetir análisis/tests y build/recorrido pertinente; probar Android si se modifican componentes compartidos. Los cambios de tema afectan varias pantallas aunque el archivo sea uno.

Autorizar un único conjunto inicial de tokens/componentes y coordinar formularios con quienes trabajan HU 2.1–2.3. La persona que pule el tema no edita simultáneamente la lógica de autenticación de otra rama. La UI no determina cuándo una HU de backend está completa.
