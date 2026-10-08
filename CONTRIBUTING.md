# Cómo contribuir a CrowdRadar

Somos siete integrantes activos. Cada persona usa su clon, su cuenta Git y una rama por tarea; responde por el código que produzca con ayuda de IA.

## Lectura inicial

1. [Reglas de este repositorio](AGENTS.md).
2. [Arquitectura frontend](docs/ARQUITECTURA.md), [guía visual](docs/GUIA_VISUAL.md) y [estado técnico](docs/ESTADO_ACTUAL.md).
3. Guías canónicas en backend: [coordinación](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/develop/docs/COORDINACION_EQUIPO.md), [contrato API](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/develop/docs/CONTRATO_API.md) y [configuración](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/develop/docs/CONFIGURACION_LOCAL.md).
4. Issue aprobado en el [Project](https://github.com/users/raelchang03UL/projects/1).

**Vigencia de los enlaces:** las guías se introducen en `feature/hu-3-1-mapa-lugares`. Los enlaces a `develop` serán utilizables después de integrar el PR backend. Mientras esté pendiente, consultar [coordinación en la rama de revisión](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/feature/hu-3-1-mapa-lugares/docs/COORDINACION_EQUIPO.md) y [contrato en esa rama](https://github.com/raelchang03UL/CrowdRadar-Backend-SW2/blob/feature/hu-3-1-mapa-lugares/docs/CONTRATO_API.md), o leer ambos archivos en el clon backend hermano de la misma rama. No afirmar que clonar `develop` incorpora trabajo con PR aún abierto.

El contexto maestro/AGENTS de la carpeta padre no se descarga al clonar. Las guías versionables de ambos repositorios son el punto de entrada compartido.

## Trabajo diario

La base compartida es `develop`, no la última rama de Rael ni la de otro administrador. Para un clon nuevo usar `git clone -b develop` en ambos repositorios, como indica CONFIGURACION_LOCAL backend. PR aprobado/publicado no significa PR integrado: el merge autorizado incorpora el aporte y los compañeros lo descargan al actualizar `develop`. Registrar el par de SHA backend/frontend probado, no solo la fecha del último push.

Después de comprobar que el clon está limpio y los remotos son correctos:

```powershell
git fetch origin
git switch develop
git pull --ff-only origin develop
git switch -c feature/hu-X-Y-descripcion
```

No ejecutar esta secuencia sobre archivos ajenos sin guardar. No trabajar en `main` ni actualizar desde `upstream`. Clonar también backend para probar la integración; cada PC mantiene PostgreSQL/secretos propios.

- Acordar el contrato antes de implementar una pantalla dependiente de API. Una respuesta simulada permite adelantar UI, pero no completa la HU.
- Coordinar cambios de `app_router`, `SessionService`, `AuthCubit`, `ApiConfig`, tema y modelos compartidos. Una sola persona modifica cada conjunto compartido a la vez.
- Ejecutar análisis/tests y las comprobaciones de plataforma afectadas. Capturar estados normales/negativos sin contraseñas ni datos personales.
- Con autorización, preparar commits de rutas explícitas y PR hacia `develop` con la [plantilla](.github/pull_request_template.md). No cerrar el Issue padre hasta probar también backend si la HU es transversal.
- Tras una integración, actualizar `develop` solo con árbol limpio y `--ff-only`. Si hay divergencia/conflicto, revisar el contrato y coordinar la resolución; nunca pedir a la IA que descarte los cambios de otra persona.

Git conserva el cambio exacto; PR, pruebas y capturas explican el resultado. README se actualiza al cambiar ejecución/configuración/capacidades, no a cada commit. Los estados diarios pertenecen al Project.

## Automatización

En la auditoría del 07/10/2026 no existe `.github/workflows`. La CI Flutter está propuesta en el acuerdo compartido, no configurada. No confundir pruebas locales aprobadas con checks de un PR.
