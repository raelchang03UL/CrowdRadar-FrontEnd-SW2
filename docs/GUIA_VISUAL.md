# Guía visual — pulido sobrio

Dirección propuesta el 07/10 y aplicada el 08/10/2026 en `feature/ui-flujos-ciudadano`, dependiente de HU 3.1 todavía sin integrar. Login, registro, perfil, edición y mapa comparten el tema; no incluye nuevos módulos. Validación automatizada y capturas de widgets, no aprobación manual de Chrome/Android.

## Dirección

- Conservar el logo, azul principal `#1A3C8F` y Material 3. Reutilizar AppTheme/AppColors, no crear un tema distinto por página.
- Fondo neutro `#F5F7FA`, superficies blancas, texto secundario `#526078` y error `#B42318`. Revisión manual de plataformas pendiente.
- Espaciado coherente de 8/16/24/32 dp; márgenes de 16–24 en móvil. Evitar espacios grandes sin función entre logo, título y formulario.
- Una acción principal por bloque. Títulos, subtítulos y ayudas con jerarquía clara; sombras discretas, iconos existentes y radios moderados coherentes.
- Sin degradados llamativos, tarjetas anidadas sin motivo, animaciones continuas, indicadores inventados ni controles decorativos.

## Pantallas

Login/registro/recuperación/cambio: bloque de marca compacto, título y ayuda breve, formulario con ancho máximo legible; conservar campos durante carga/error, mostrar/ocultar contraseña, confirmación y foco/teclado adecuados. La ayuda al ciudadano debe hablar de la acción, no de servidores, SDK ni detalles de arquitectura; el diagnóstico técnico pertenece a documentación/logs privados.

Perfil/edición: identidad y datos agrupados, anchos máximos 680/560 dp, cierre de sesión reconocible. La acción de contraseña se añadirá únicamente junto con su función real. Edición directa carga datos; guardar conserva formulario y errores públicos. No incluye gestión de roles.

Mapa: jerarquía entre título, contexto, mapa y selección. Mantener visible la advertencia de datos demostrativos y la atribución OpenStreetMap. Selección legible con botón de cerrar claro. No añadir buscador, filtros, tarjetas de saturación ni detalle completo como parte del pulido.

## Criterios de revisión

1. Comprobar móvil 360/390 dp y escritorio 1440 dp, además de teclado visible y texto ampliado cuando afecte formularios.
2. Sin overflow, recortes de botones ni dependencia exclusiva del color; controles táctiles adecuados, etiquetas y foco visibles.
3. Contraste suficiente, estados deshabilitado/carga/error/éxito distinguibles y texto accesible. No afirmar certificación de accesibilidad sin evaluación.
4. Capturas antes/después de las mismas pantallas/tamaños sin credenciales, mensajes privados ni datos personales.
5. Repetir análisis/tests y build/recorrido pertinente; probar Android si se modifican componentes compartidos. Los cambios de tema afectan varias pantallas aunque el archivo sea uno.

Autorizar un único conjunto inicial de tokens/componentes y coordinar formularios con quienes trabajan HU 2.1–2.3. La persona que pule el tema no edita simultáneamente la lógica de autenticación de otra rama. La UI no determina cuándo una HU de backend está completa.
