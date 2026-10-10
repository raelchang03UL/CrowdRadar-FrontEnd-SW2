# Guía visual — propuesta de pulido sobrio

Dirección propuesta por coordinación el 07/10/2026 tras revisar capturas Web y tema actual. **Todavía no aplicada al código**; será un cambio visual delimitado tras integrar la base HU 3.1. Busca claridad y consistencia para una aplicación académica que pueda evolucionar.

## Dirección

- Conservar el logo, azul principal `#1A3C8F` y Material 3. Reutilizar AppTheme/AppColors, no crear un tema distinto por página.
- Sustituir el fondo verde pálido actual por un neutro suave propuesto (`#F5F7FA`) y mantener superficies blancas. Validar visualmente antes de fijarlo.
- Espaciado coherente de 8/16/24/32 dp; márgenes de 16–24 en móvil. Evitar espacios grandes sin función entre logo, título y formulario.
- Una acción principal por bloque. Títulos, subtítulos y ayudas con jerarquía clara; sombras discretas, iconos existentes y radios moderados coherentes.
- Sin degradados llamativos, tarjetas anidadas sin motivo, animaciones continuas, indicadores inventados ni controles decorativos.

## Pantallas del siguiente pulido

Login/registro/recuperación/cambio: bloque de marca compacto, título y ayuda breve, formulario con ancho máximo legible; conservar campos durante carga/error, mostrar/ocultar contraseña, confirmación y foco/teclado adecuados. La ayuda al ciudadano debe hablar de la acción, no de servidores, SDK ni detalles de arquitectura; el diagnóstico técnico pertenece a documentación/logs privados.

Perfil/edición: separar identidad y datos editables, acción de contraseña visible y cierre de sesión reconocible. Mantener navegación y operaciones actuales; no convertir la tarea en gestión de roles o nuevos módulos.

Mapa: jerarquía entre título, contexto, mapa y selección. Mantener visible la advertencia de datos demostrativos y la atribución OpenStreetMap. Selección legible con botón de cerrar claro. No añadir buscador, filtros, tarjetas de saturación ni detalle completo como parte del pulido.

## Criterios de revisión

1. Comprobar móvil 360/390 dp y escritorio 1440 dp, además de teclado visible y texto ampliado cuando afecte formularios.
2. Sin overflow, recortes de botones ni dependencia exclusiva del color; controles táctiles adecuados, etiquetas y foco visibles.
3. Contraste suficiente, estados deshabilitado/carga/error/éxito distinguibles y texto accesible. No afirmar certificación de accesibilidad sin evaluación.
4. Capturas antes/después de las mismas pantallas/tamaños sin credenciales, mensajes privados ni datos personales.
5. Repetir análisis/tests y build/recorrido pertinente; probar Android si se modifican componentes compartidos. Los cambios de tema afectan varias pantallas aunque el archivo sea uno.

Autorizar un único conjunto inicial de tokens/componentes y coordinar formularios con quienes trabajan HU 2.1–2.3. La persona que pule el tema no edita simultáneamente la lógica de autenticación de otra rama. La UI no determina cuándo una HU de backend está completa.
