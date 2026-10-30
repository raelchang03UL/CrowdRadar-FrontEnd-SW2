# Evidencia Web local — Sprint 3, 18/10/2026

Incremento local, no aceptación humana ni despliegue. Frontend funcional a5e33ac9078cc882474a6d22961f9502f61c6ac0; backend funcional 4f489b250eaaf191ed359b1f9c9b7ace5a7c8ad3. Backend final 5f933ea (incluye el servidor QA limitado a127.0.0.1; test de binding) (runner, selección limitada y servicio legible) repite138/138 y7/7 PostgreSQL; no altera el contrato visual.

IAB real, Web5533 → API3033 → PostgreSQL18 en crowdradar_consolidacion_fresh_20261017. SMTP deshabilitado. Todas las cuentas y observaciones son QA sintética, no datos de visitas reales.

| Captura | Recorrido comprobado |
| --- | --- |
| 01_lista_validacion_web.jpg | Lista con fecha Lima, conteos y marca de reporte propio |
| 02_voto_denuncia_web.jpg | Confirmación por teclado, conteos 3→4, peso 7→9; denuncia persistida, sin botones repetidos |
| 03_estado_propio_web.jpg | Autor consulta ausencia de votos, sin autovoto/autodenuncia |
| 04_historial_horario_web.jpg | 12–14/10:72 bloques,3 tranquilos/3 moderados/66 insuficientes |
| 05_comparacion_web.jpg | Período A con datos, B insuficiente; conteos sin media ficticia |
| 06_horarios_web.jpg | 10:00–11:00 Lima,3/3 días tranquilos; aviso no predictivo |
| 07_horarios_movil.jpg | Mismo recorrido a 390×844, sin recortes observados |
| 10_revision_final_web.jpg | Compilación final y API5f933ea enloopback: elección/denuncia persistidas tras reinicio y login |
| 09_historial_a_estado_final_web.jpg | Perfil → historial propio → estado; compilación final/API reiniciada |
| 08_api_caida_movil.jpg | Nuestra API detenida intencionalmente; error público y Reintentar |

La primera revisión usó build Web 81,1 s; la final 58,7 s añade claves por ID y tests de lista, sin rediseño. El ajuste SQL posterior limita candidatos antes de agregar y pasó de nuevo las pruebas reales. Se reinició API y recargó Web final para smoke de cierre. No atribuir al recorrido manual los casos de concurrencia/401 cubiertos automáticamente.

Antes/después del mismo mapa a390×844 y1440×900: ../consolidacion_2026_10_17; referencia origin/develop dfdb753, no el experimento visual. Estas capturas S3 son de nuevas funcionalidades y no simulan un “antes” inexistente.

Análisis limpio;448 pruebas aprobadas/2 opt-in omitidas;17 nuevas S3 a 360/390/1440 con texto2x. No Android final, Chrome normal, SMTP real ni certificación WCAG. Viewport temporal restaurado.
