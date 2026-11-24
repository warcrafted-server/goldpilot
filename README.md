# GoldPilot Forever

Addon de economía para **World of Warcraft: Forever**. Esta versión temprana muestra precios de vendedor y precios observados en la subasta en los tooltips, y permite consultar el valor estimado de las bolsas. Los precios de subasta proceden de lo que el jugador observa al abrir la casa de subastas; todavía no se leen precios de otras fuentes.

Comandos disponibles: `/gp diag` genera un diagnóstico del cliente y de las ventanas abiertas; `/gp bags` muestra el valor estimado de las bolsas como vendedor, subasta neta y mejor combinación. El botón del minimapa abre la ayuda con clic izquierdo y ejecuta el diagnóstico con clic derecho. Usa `/gp minimap` para ocultarlo o mostrarlo.

> **Versión 0.2.0 temprana.** Aún no se ha comprobado en juego. No incluye una ventana principal.

## Documentación

- [Propuesta del producto](docs/PROPUESTA.md): visión, funcionalidades viables y descartadas, interfaz, roadmap, riesgos y decisiones pendientes.
- [Arquitectura](docs/ARQUITECTURA.md): módulos, clases de dato, almacenamiento, comunicación con la aplicación opcional y pruebas.
- [Decisiones técnicas](docs/DECISIONES.md).
- [Investigación: API, casa de subastas y fuentes de datos](docs/investigacion/01-api-y-mercado.md).
- [CHANGELOG](CHANGELOG.md) · [TODO](TODO.md)

## Requisitos

- Cliente WoW Forever (Interface 16001, build de referencia 1.60.1.70862).
- Sin dependencias. Opcionales previstos: TomTom y la aplicación externa GoldPilot (Windows).

## Instalación

- Instálalo desde CurseForge cuando esté disponible, o copia la carpeta `GoldPilot` en `World of Warcraft\_forever_\Interface\AddOns` y reinicia el juego.
- Comprueba que el addon esté activado en la pantalla de selección de personaje.

## Uso

- Pasa el cursor por un objeto compatible para ver su precio de vendedor y, si se ha observado, su precio de subasta, antigüedad y recomendación. Mantén **Mayús** para ver más detalle.
- Al abrir la subasta, GoldPilot consulta objetos seguidos, bolsas y bancos de los personajes guardados; al pasar el cursor prioriza objetos sin observación reciente. El banco se registra al abrirlo. Al terminar muestra `Subasta: N objetos leídos`.
- Usa `/gp bags` para ver el valor de las bolsas al vendedor, en subasta neta y con la mejor combinación; `/gp diag` para el diagnóstico; `/gp minimap` para mostrar u ocultar el botón; y `/gp version` para ver la versión. El botón del minimapa abre la ayuda con clic izquierdo y ejecuta el diagnóstico con clic derecho.
- No hay ventana principal en esta versión.

## Desarrollo

La copia de pruebas del juego es un junction `AddOns\GoldPilotDev` que apunta a la raíz del repo, con su propio `GoldPilotDev.toc` (generado con `python tools/toc_dev.py`, ignorado por git; vuelve a ejecutarlo si cambia la lista de archivos del TOC). Convive con la copia publicada de CurseForge (`AddOns\GoldPilot`), pero solo una de las dos debe estar activa a la vez porque comparten SavedVariables. Montarla o desmontarla exige el juego cerrado. Pruebas: `python tests/run.py`.

## Créditos y licencia

**GoldPilot Forever** está desarrollado y mantenido por **WarCrafted**.
Copyright (C) 2026 WarCrafted.

Licencia [WNCL-TP-1.0](LICENSE): puedes usarlo, estudiarlo, modificarlo y compartirlo gratis con fines no comerciales. Venderlo o cualquier uso comercial requiere permiso por escrito. Solo cubre el material propio; los componentes de terceros conservan su licencia.

Las copias y los forks deben conservar esta atribución y enlazar a https://github.com/warcrafted-server/goldpilot.

Datos de juego de World of Warcraft (c) Blizzard Entertainment; proyecto no afiliado.

### Material de terceros

| Componente | Autor | Licencia | Enlace |
| --- | --- | --- | --- |

Este proyecto no contiene material de terceros.
