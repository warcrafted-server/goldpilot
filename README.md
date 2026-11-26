# GoldPilot Forever

Addon de economía para **World of Warcraft: Forever**. Muestra precios de vendedor y precios observados en la subasta en los tooltips, y valora el inventario de bolsas y banco por personaje o para toda la cuenta. Los precios de subasta proceden de lo que el jugador observa al abrir la casa de subastas; no se leen precios de otras fuentes. La ventana de `/gpilot` tiene cinco pestañas: Ahora, Inventario, Libro, Zonas y Ajustes.

Comandos disponibles: `/gpilot` abre o cierra la ventana principal, `/gpilot window` hace lo mismo, `/gpilot help` muestra la ayuda y `/gpilot version`, la versión. `/gpilot diag` genera un diagnóstico del cliente y de las ventanas abiertas; `/gpilot route` resume en el chat el estado del dibujo de la ruta y lo guarda en el diagnóstico; `/gpilot bags` muestra el valor estimado de las bolsas como vendedor, subasta neta y mejor combinación. El botón del minimapa abre la ventana con clic izquierdo y ejecuta el diagnóstico con clic derecho. Usa `/gpilot minimap` para ocultarlo o mostrarlo. `/gpilot watch <enlace>` sigue o deja de seguir un objeto; `/gpilot scan` hace un escaneo completo de la subasta abierta; `/gpilot ledger` resume las operaciones del mes; `/gpilot session` muestra la sesión de recolección en curso, `/gpilot session end` la cierra y `/gpilot hud` muestra u oculta su panel. `/gpilot set` lista los ajustes y `/gpilot set <clave> on|off` los cambia.

## Documentación

- [Propuesta del producto](docs/PROPUESTA.md): visión, funcionalidades viables y descartadas, interfaz, roadmap, riesgos y decisiones pendientes.
- [Arquitectura](docs/ARQUITECTURA.md): módulos, clases de dato, almacenamiento, comunicación con la aplicación opcional y pruebas.
- [Decisiones técnicas](docs/DECISIONES.md).
- [Investigación: API, casa de subastas y fuentes de datos](docs/investigacion/01-api-y-mercado.md).
- [CHANGELOG](CHANGELOG.md) · [TODO](TODO.md)

## Requisitos

- Cliente WoW Forever (Interface 16001, build de referencia 1.60.1.70862).
- Sin dependencias. Opcional: TomTom, ya usado para marcar la siguiente parada de la ruta. La aplicación externa GoldPilot (Windows) todavía no está disponible.

## Instalación

- Instálalo desde CurseForge cuando esté disponible, o copia la carpeta `GoldPilot` en `World of Warcraft\_forever_\Interface\AddOns` y reinicia el juego.
- Comprueba que el addon esté activado en la pantalla de selección de personaje.

## Uso

- Pasa el cursor por un objeto compatible para ver su precio de vendedor y, si se ha observado, su precio de subasta, antigüedad y recomendación. Mantén **Mayús** para ver más detalle.
- Al abrir la subasta, GoldPilot hace un escaneo completo si la casilla de Ajustes está activa (lo está por defecto): descarga el listado entero en 30-40 s y de ahí salen los precios y las medianas; una barra fina junto a la subasta muestra el progreso. `/gpilot scan` lo lanza a mano con la subasta abierta; el servidor limita a uno cada 15 minutos. Además consulta uno a uno los objetos seguidos, equipados, de las bolsas y de los bancos de los personajes guardados que no haya cubierto un escaneo (todos ellos, si no hay escaneo o no responde), y al pasar el cursor prioriza los objetos sin observación reciente. El banco se registra al abrirlo; al terminar la consulta muestra `Subasta: N objetos leídos`.
- Usa `/gpilot` para abrir la pestaña Ahora. Reúne consejos para vender, recoger correo y revisar objetos guardados en otros personajes. Selecciona una tarjeta para ver el motivo y los objetos más valiosos; desde las tarjetas de venta puedes abrir Inventario.
- Cambia entre el personaje actual y toda la cuenta con el botón de ámbito de Ahora.
- Inventario muestra el valor neto de lo vendible, el valor si todo se vende al vendedor, los objetos sin precio y las observaciones viejas. Cambia entre el personaje actual y toda la cuenta, filtra por nombre, oculta reservados y selecciona un objeto para ver cantidades por personaje y ubicación, precios y recomendación. Reservar aparta toda la cantidad (Mayús reserva una unidad más); Seguir añade el objeto a las consultas de subasta. Ajustes permite configurar la interfaz.
- Libro muestra ventas, compras y devoluciones agrupadas por objeto. Filtra por personaje o cuenta y por los últimos 7 días, 30 días o todo el historial.
- Zonas reúne el oro por hora medido de cada zona y el historial de sesiones; crea una ruta de recolección de hierbas y minerales que se dibuja en el mapa del mundo. La ruta se crea con los nodos que has recogido tú: el paquete publicado no incluye semillas de nodos ni de posiciones, así que empieza con pocos puntos y crece con cada visita. La ruta sigue tu posición, resalta la siguiente parada, la marca en TomTom si quieres y ajusta el peso de los puntos con las visitas con y sin nodo.
- Cualquier botín de nodos y criaturas (desuello incluido) abre un panel movible con el oro por hora de la sesión; pasa a pausa si dejas de recoger y resume la sesión en el chat al terminar. El panel se muestra u oculta con la casilla de Ajustes. Tras 20 minutos activos, Ahora añade el consejo de tu mejor zona.

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

El paquete publicado no contiene material de terceros. Las semillas de nodos generadas desde wowdata (con datos de Questie) solo se usan en local, en `Data/Local/`, y no se publican.
