# Guía visual — pulido sobrio

Corte vigente 18/10/2026: tema publicado ya integrado antes de esta tarea; incremento R01 + HU5–6 solo local. No se usa el rediseño rechazado. Pantallas nuevas conservan colores, tipografía y componentes existentes. Una mejora funcional no implica aprobación visual del equipo.

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
