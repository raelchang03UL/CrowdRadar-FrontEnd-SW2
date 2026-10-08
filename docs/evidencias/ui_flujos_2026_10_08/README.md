# Capturas de widgets — hito A

`antes/`: login/registro de la base `f2437a2991293fa275626e4d5e8819a22b1aed2a`.
`despues/`: mismos tamaños 360×800 y 1440×900 tras el pulido.
Son renderizados de `test/visual_layout_test.dart`, no capturas de un navegador ni Android.
Arial del sistema se carga optativamente como fuente de prueba e iconos Material del SDK.
El render de pruebas anterior conserva algunos glifos Ahem; no demuestra tipografía nativa.
Sin cuentas ni contraseñas. El registro necesita scroll; la captura muestra el inicio, no todo el formulario.

Para regenerar solo el estado actual (PowerShell, rutas de fuente propias):

```powershell
$env:CROWDRADAR_WIDGET_CAPTURE_DIR = 'build/widget-captures'
$env:CROWDRADAR_WIDGET_FONT = 'C:/Windows/Fonts/arial.ttf'
# Opcional: ruta instalada de MaterialIcons-Regular.otf
$env:CROWDRADAR_WIDGET_ICON_FONT = '<ruta-local-de-la-fuente>'
flutter test --no-pub test/visual_layout_test.dart
```

Sin esas variables se ejecutan las mismas pruebas de layout, sin escribir imágenes.
Chrome normal y Android del incremento final quedan pendientes; no se eludió la detención de seguridad del control de Chrome.
