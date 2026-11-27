# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

## [0.21.0] - 2026-11-27

### Añadido
- Gangas: secciones de reventa y de vendedor, precio máximo a pagar, comprobación en vivo del objeto abierto y casilla para incluir las ganancias pequeñas.

### Cambiado
- Gangas ya no muestra por defecto beneficios de menos de 50 cobres.

### Corregido
- «hace hace» en la antigüedad de los precios y caracteres rotos al recortar nombres con acentos.

## [0.20.1] - 2026-11-27

### Corregido
- Gangas: al hacer clic en un objeto se cargan sus precios; si hace falta usar el buscador, la búsqueda se lanza sola.

## [0.20.0] - 2026-11-27

### Añadido
- Gangas: en la pestaña Comprar, GoldPilot señala los objetos más baratos de lo que valen (vendedor o reventa) y los abre con un clic.
- Ajuste «Gangas en la subasta».

## [0.19.2] - 2026-11-27

### Cambiado
- El asistente de venta muestra cuánto paga el vendedor cuando aconseja venderle a él.
- Mis subastas deja más sitio a los nombres de los objetos.

## [0.19.1] - 2026-11-27

### Cambiado
- Los recuadros de venta y de Mis subastas tienen el mismo estilo que la ventana de GoldPilot, y Mis subastas muestra cada subasta en una sola línea.

### Corregido
- Mis subastas mostraba «?» en lugar de acentos y signos.

## [0.19.0] - 2026-11-27

### Añadido
- Mis subastas: en la pestaña Subastas, GoldPilot señala las subastas que te han rebajado con el precio que conviene ahora, las que van bien y las vendidas, y permite cancelar las rebajadas con confirmación.
- Ajuste «Asistente de Mis subastas».

## [0.18.2] - 2026-11-27

### Corregido
- El asistente de venta muestra el depósito también con equipo y otros objetos que no son materiales.

## [0.18.1] - 2026-11-27

### Cambiado
- El recuadro del asistente de venta va fuera de la ventana de la subasta para no tapar la lista de precios, se ajusta a su contenido, alinea las cantidades y muestra la confianza en palabras.

## [0.18.0] - 2026-11-27

### Añadido
- Asistente de venta: al poner un objeto en la ventana de venta de la subasta, GoldPilot muestra la referencia, el mínimo de otros vendedores, el precio sugerido y lo que cobrarás, con un botón para usar ese precio.
- Ajuste «Asistente de venta en la subasta».

## [0.17.2] - 2026-11-27

### Corregido
- Las consultas de precios en segundo plano se pausan mientras compras o vendes en la subasta, para no estorbar tus búsquedas ni tus compras.

### Añadido
- El diagnóstico `/gpilot diag ah` registra también los errores de la subasta.

## [0.17.1] - 2026-11-26

### Añadido
- `/gpilot diag ah`: diagnóstico de la ventana de subasta (funciones, paneles y eventos) para preparar el asistente de venta.

## [0.17.0] - 2026-11-26

### Añadido
- Ajustes definidos en un solo sitio: la pestaña Ajustes se genera sola y `/gpilot set` los lista y cambia.
- Ajuste «Usar precios de la aplicación de escritorio», preparado para la futura aplicación.

## [0.16.6] - 2026-11-26

### Corregido
- Barra del escaneo: se ensancha con el texto para que no se salga del recuadro.

## [0.16.5] - 2026-11-26

### Cambiado
- Decisión D6 aceptada: precio en vivo desde el juego, historial desde la aplicación y botón para recargar.
- Notas de versión en docs/notas/X.Y.Z.md; el CI genera las de CurseForge con todas las versiones desde el último tag publicado.

## [0.16.4] - 2026-11-26

### Corregido
- Barra del escaneo: a la derecha bajo la subasta, sin tapar las pestañas, y sin el símbolo `~` que la fuente del juego no tiene.

### Añadido
- docs/PUBLICACIONES.md: cola de versiones preparadas con su commit, para publicarlas en orden en CurseForge.

## [0.16.3] - 2026-11-26

### Añadido
- docs/PUBLICACIONES.md: cola de versiones preparadas con su commit, para publicarlas en orden en CurseForge.

### Cambiado
- Temporizadores cancelables y mensajes internos entre módulos; el escaneo completo y su barra los usan.

## [0.16.2] - 2026-11-26

### Cambiado
- La barra del escaneo muestra siempre el porcentaje y los segundos que lleva; mientras espera al servidor, el porcentaje es una estimación según el escaneo anterior.

## [0.16.1] - 2026-11-26

### Corregido
- Abrir la subasta durante el límite de 15 minutos ya no deja el escaneo completo olvidado: avisa de la hora, muestra la cuenta atrás y empieza solo si la subasta sigue abierta.

## [0.16.0] - 2026-11-26

### Añadido
- Barra con el porcentaje del escaneo completo junto a la subasta.

### Corregido
- Cerrar la subasta a mitad del escaneo avisa de la interrupción en lugar de perderlo en silencio; el aviso del límite de 15 minutos dice a qué hora se podrá volver a escanear.

## [0.15.7] - 2026-11-26

### Cambiado
- Capturas de Libro y del tooltip con el aspecto actual y sin nombres de personajes.

### Corregido
- Ahora: la tarjeta de correo sin oro muestra cuántos correos hay, mantiene la confianza en su sitio y, si no hay lista, pide abrir el buzón.

## [0.15.6] - 2026-11-25

Parche: el paquete deja de incluir datos de terceros; la ruta funciona igual con los nodos propios.

### Eliminado
- `Data/Generated/NodeSeeds.lua` sale del TOC y del repositorio: venía de wowdata con datos de Questie y de una lista de origen sin verificar. El generador lo escribe ahora en `Data/Local/` (ignorada) y solo lo carga el TOC de desarrollo.

### Cambiado
- Capturas para la ficha de CurseForge en `docs/img/capturas/` (tooltip, Ahora, Inventario, Libro, Zonas y la ruta en el mapa), recortadas y sin nombres de personajes; sustituyen a `tooltip-objeto.png`.

## [0.15.5] - 2026-11-25

Parche: cambia la estructura del repositorio, no el addon instalado.

### Cambiado
- El addon pasa de la subcarpeta `GoldPilot/` a la raíz del repositorio, como los demás addons; `.pkgmeta` ya no usa `move-folders`.
- `GoldPilotDev.toc` carga los archivos sin prefijo y su icono apunta a `AddOns/GoldPilotDev`.
- `tools/empaquetar.py` genera el mismo contenido que el empaquetador de CurseForge (carpeta `GoldPilot/` con TOC, código, `LICENSE`, `README.md` y `CHANGELOG.md`).

## [0.15.4] - 2026-11-25

Parche: solo documentación, sin cambios en el addon.

### Cambiado
- Puesta al día de `README.md`, `TODO.md`, la ficha de CurseForge (`docs/CURSEFORGE.md`) y las notas de publicación (`docs/RELEASE_NOTES.md`) para la primera versión publicada.
- `docs/COMPROBACIONES.md`: lista corta de pruebas imprescindibles antes de publicar.

## [0.15.3] - 2026-11-25

Parche: segunda pasada visual y correcciones de texto, sin función nueva.

### Cambiado
- Los selectores de ámbito, periodo y vista son oscuros y con flecha; los botones rojos quedan solo para acciones. En Ahora, el de ámbito pasa arriba, como en el resto.
- La ficha tiene el mismo borde que la lista, ahora bronce, y la barra de desplazamiento solo aparece si hace falta.
- Ajustes en dos columnas: General y Recolección, y Tooltip.
- Zonas: el tiempo activo y las sesiones se alinean como el resto de datos. Tooltip: la comisión supuesta ya no repite la palabra.

### Corregido
- Ahora: con un solo objeto, «visto» mostraba el número de objetos en vez de la antigüedad, y la tendencia, en vez del porcentaje.
- Los nombres y motivos usan todo el hueco libre: se cortan o pasan de línea menos.
- Textos en plural con una sola unidad («1 objetos», «1 sesiones»).

## [0.15.2] - 2026-11-25

Parche: correcciones y retoques visuales, sin función nueva.

### Cambiado
- Listas: icono mayor y sin borde gris, fondo alterno, selección dorada con banda y brillo suave al pasar el ratón (también en las tarjetas de Ahora).
- Libro: los objetos vendidos buscan su icono por nombre (en el cliente y en el escaneo completo) y lo recuerdan; si no se conoce, sale el de interrogación.
- Ahora: la ficha del correo dice qué hay en el buzón (hasta 6 correos, con su importe).

### Corregido
- Ahora: en la ficha sin importe, la confianza ya no se descoloca.
- Listas: los nombres largos se recortan en vez de pisar el importe, las filas recicladas no heredan colores y la selección sigue al objeto cuando la lista se reordena.
- `docs/COMPROBACIONES.md`: el título ya no indica una versión antigua (0.7.0).

## [0.15.1] - 2026-11-24

### Corregido
- La ruta de recolección no se veía bajo el arte del mapa ni con mapas unidos: ahora se dibuja por encima de las chinchetas y dentro del rectángulo del mapa que la contiene, y se reintenta el dibujo si el lienzo aún no tiene tamaño. `/gpilot route` resume su estado y lo guarda en el diagnóstico.

## [0.15.0] - 2026-11-24

### Añadido
- Seguimiento de la ruta de recolección: la siguiente parada se resalta en el mapa y se marca en TomTom, y las visitas con y sin nodo ajustan el peso de los puntos.

## [0.14.0] - 2026-11-24

### Añadido
- Pestaña Zonas con el oro por hora medido de cada zona, el historial de sesiones y una ruta de recolección de hierbas y minerales dibujada en el mapa del mundo.

## [0.13.1] - 2026-11-24

### Añadido
- Motor de rutas de recolección, lectura de la habilidad, valor por recogida en los nodos y generador de la semilla local (interno).

## [0.13.0] - 2026-11-24

### Añadido
- Panel movible con el oro por hora de la sesión de recolección; resumen al terminar y `/gpilot session`; `/gpilot hud` y ajuste; consejo «Tu mejor zona» en Ahora.

## [0.12.1] - 2026-11-24

### Añadido
- Registro interno de sesiones de recolección y de la posición de los nodos a partir del botín (aún sin interfaz).

## [0.12.0] - 2026-11-24

### Cambiado
- El comando corto pasa a ser `/gpilot` (incompatible: `/gp` deja de existir porque es el del chat de grupo); `/goldpilot` sigue igual.

## [0.11.0] - 2026-11-24

### Añadido
- Pestaña Libro con ventas, compras y devoluciones por objeto, periodo y personaje o cuenta.

### Corregido
- El aviso de lista vacía ya no queda tapado por el fondo de la lista.

## [0.10.0] - 2026-11-24

### Añadido
- Interruptor de ámbito en Ahora, recordado por personaje.

### Corregido
- El título de la tarjeta del banco ya no se parte en dos líneas.

## [0.9.0] - 2026-11-24

### Añadido
- Pestaña Ahora con consejos de venta, correo, objetos en otros personajes y tendencias de precios.

## [0.8.5] - 2026-11-24

### Añadido
- Motor de consejos y foto del buzón pendiente (interno).

## [0.8.4] - 2026-11-24

### Corregido
- Parche: las pestañas inferiores ya no se solapan.

## [0.8.3] - 2026-11-24

### Cambiado
- Parche de presentación: ventana nativa con retrato, pestañas bajo la ventana y métricas en tarjetas.

### Corregido
- Abrir la ventana desde el minimapa refresca la pestaña activa.

## [0.8.2] - 2026-11-24

### Cambiado
- Parche de presentación: la ficha del inventario va en dos columnas y por secciones (mejor opción, precio por unidad, mercado y dónde lo tienes), sin siglas; la ayuda de Reservar y Seguir pasa al cursor.

## [0.8.1] - 2026-11-24

### Corregido
- Parche: el escaneo publica sus precios al terminar la lectura y resuelve después, en segundo plano, los enlaces de equipo pendientes (tardaba unos 100 s).
- Las pestañas de la ventana no se veían y no se podía llegar a Ajustes.
- Las métricas del inventario se salían de la ventana; la ficha y las métricas reutilizan sus textos en lugar de crear otros en cada refresco.

## [0.8.0] - 2026-11-24

### Cambiado
- Los objetos para valorar, seguir y consultar se obtienen del juego (subasta, bolsas, banco y equipo).

### Eliminado
- La lista de objetos generada desde wowdata; wowdata sigue generando las semillas de nodos.

## [0.7.0] - 2026-11-24

### Añadido
- Precio de vendedor obtenido del cliente, con carga diferida cuando faltan datos.
- Inventario por variante de equipo, cantidades ligadas y valoración separada de unidades libres.

### Corregido
- Los objetos ligados no reciben consejo de subasta ni se encolan para consulta.

## [0.6.2] - 2026-11-24

### Corregido
- Parche: el escaneo insiste mientras el cliente siga cargando equipo (en juego se descartaban 20 547 anuncios de 314 675 por falta de enlace).

## [0.6.1] - 2026-11-24

### Corregido
- Versión parche: escaneo, búsquedas y tooltip separan precios de variantes de equipo.

## [0.6.0] - 2026-11-24

### Cambiado
- Versión menor: el cambio de formato del almacén de precios incluye migración automática antes de 1.0.0.
- Las claves distinguen variantes de equipo y el historial se poda según los objetos de interés.

## [0.5.0] - 2026-11-24

### Añadido
- Versión menor: libro de operaciones con ventas y compras confirmadas y devoluciones detectadas en el buzón, consultable con `/gp ledger`.

### Cambiado
- El escaneo completo al abrir la subasta queda activado por defecto (comprobado en juego: 30-40 s sin tirones) y la cola no repite lo leído hace menos de 15 min.

### Corregido
- La cola de subasta carga los datos de cada objeto antes de buscarlo: los de otros personajes agotaban 8 s cada uno.
- El diagnóstico de subasta ya no escribe cada evento en el chat.
- El diagnóstico del buzón avisa una sola vez por apertura.
- El dinero usa los iconos de moneda del juego también cuando la función está en `C_CurrencyInfo`.

## [0.4.0] - 2026-11-24

Menor: funcionalidad nueva y compatible (los datos guardados siguen valiendo; las nuevas opciones tienen valores por defecto).

### Añadido
- Escaneo completo de la subasta con `ReplicateItems`, como Auctionator: al abrir la subasta (opción en Ajustes, desactivada por defecto como en Auctionator) o con `/gp scan`, respetando el límite del servidor de 15 min. Actualiza el precio de todos los objetos conocidos con ofertas y, si falla o no responde, se vuelve a la cola por objetos.
- Cualquier resultado de búsqueda de la subasta (del jugador u otro addon) actualiza el precio y saca el objeto de la cola.
- El escaneo completo guarda el precio de todos los objetos con ofertas, no solo los de la lista interna de GoldPilot (se excluyen las jaulas de mascota, que comparten identificador). El tooltip también los muestra, sin precio de vendedor cuando se desconoce.
- Los objetos equipados (propios y de otros personajes) entran en la cola de subasta.
- Ajustes: casillas para cada línea del tooltip (vendedor, último visto, mediana, mejor opción) y para el escaneo completo.
- Diagnóstico del buzón: guarda cabeceras (remitente, asunto, dinero, devuelto) y adjuntos de hasta 20 correos, por personaje, y se actualiza con `MAIL_INBOX_UPDATE`.
- El diagnóstico del buzón no guarda textos de correos de jugadores.
- Diagnóstico de los últimos 300 botines y muestra de variantes de equipo de la subasta.
- El diagnóstico de subasta avisa una sola vez por tipo de evento y guarda como máximo 40.

### Corregido
- Refrescar la lista del inventario ya no pierde la posición de desplazamiento.

### Cambiado
- Tooltip rediseñado en filas de dos columnas con cabecera «GoldPilot», antigüedad y clase de dato; la mediana y el último visto se muestran por separado.

## [0.3.2] - 2026-11-24

Parche (según la hoja de ruta, mejoras pequeñas); funcionalidad pequeña y compatible.

### Añadido
- `/gp watch <enlace o número>` (también `/gp seguir`) alterna el seguimiento de un objeto; con Mayús+clic en la bolsa se inserta el enlace.
- El tooltip con Mayús muestra las unidades en venta y la variación de la mediana frente al último día anterior observado.
- Progreso de la cola de subasta en el chat («Subasta: 12/40 objetos»), cada 10 objetos.

### Cambiado
- El límite de la cola de subasta sube de 300 a 1000 objetos.

## [0.3.1] - 2026-11-24

Parche: corrige fallos de la 0.3.0 vistos en juego, sin cambios de datos ni de compatibilidad.

### Corregido
- Inventario: lista más ancha, fondos opacos y ficha con texto ajustado; los botones Reservar y Seguir se ven siempre (desactivados hasta elegir un objeto).
- El texto de ayuda del filtro ya no cuenta como búsqueda.
- Los objetos seguidos llevan estrella en la lista, hay filtro «Solo seguidos» y la ficha explica qué hace seguir.
- El botón del minimapa se queda sobre el borde al arrastrarlo y usa el icono nuevo.

## [0.3.0] - 2026-11-24

### Añadido
- Pestaña Inventario con valor por objeto, recomendación, reservar y seguir.

## [0.2.5] - 2026-11-24

### Añadido
- Ventana principal con pestañas y componentes de interfaz.

### Cambiado
- `/gp` abre la ventana y `/gp help` muestra la ayuda.

## [0.2.4] - 2026-11-24

### Añadido
- Captura del tooltip de objeto para la ficha de CurseForge (`docs/img/capturas/tooltip-objeto.png`)

## [0.2.3] - 2026-11-24

### Añadido
- Identificador del proyecto de CurseForge (`X-Curse-Project-ID`) en el TOC

## [0.2.2] - 2026-11-24

### Cambiado
- Logo rediseñado (moneda de oro con rosa de los vientos; `tools/generar_logo.py` ahora usa Pillow, solo para desarrollo)
- `docs/CURSEFORGE.md` pasa a ser la ficha completa del proyecto: categorías, resúmenes y descripciones en inglés y castellano

## [0.2.1] - 2026-11-24

### Añadido
- Logo del proyecto (`docs/img/logo.png`, generado con `tools/generar_logo.py`), pruebas automáticas en GitHub y `tools/comprobar_release.py` para revisar la versión antes de etiquetar

### Corregido
- La ruta de instalación manual del README apuntaba a `_classic_era_`; la de Forever es `_forever_`

## [0.2.0] - 2026-11-24

### Añadido
- Registro del banco, consultas de subasta para bolsas y bancos de otros personajes, consultas prioritarias al pasar el cursor y registro compacto de la última sesión.

### Cambiado
- Las claves de casas y personajes ya no incluyen reino; el esquema migra las claves guardadas.
- El diagnóstico conserva las sondas ya guardadas. GoldPilot obtiene precios solo de sus propias observaciones en la subasta.

### Corregido
- Se conserva el banco anterior hasta abrir el banco, y cada resultado de consulta queda registrado.

## [0.1.1] - 2026-11-24

### Corregido
- El icono del minimapa se carga también desde la copia de desarrollo.

### Cambiado
- La versión de la copia de desarrollo muestra el número real con sufijo `-dev`.

## [0.1.0] - 2026-11-23

### Añadido
- Primera versión usable: tooltips con precio de vendedor y observación de subasta, antigüedad y recomendación; consultas dirigidas al abrir la subasta; valoración de bolsas y comandos de diagnóstico y minimapa.

## [0.0.8] - 2026-11-23

### Añadido
- Asesor de vendedor/subasta, tema, tooltip y valor de bolsas

## [0.0.7] - 2026-11-23

### Añadido
- Colectores de bolsas y subasta con cola dirigida

## [0.0.6] - 2026-11-23

### Añadido
- Almacén de precios observados (resumen p50, historial diario y semanal empaquetado, poda) y elección del precio de referencia con clase de dato

## [0.0.5] - 2026-11-23

### Añadido
- `tools/generar_desde_wowdata.py`: genera `Data/Generated/Items.lua` (objetos comerciables) y `NodeSeeds.lua` (semillas de nodos) desde wowdata

## [0.0.4] - 2026-11-23

### Añadido
- Icono del addon y botón arrastrable del minimapa (`/gp minimap`)

## [0.0.3] - 2026-11-23

### Añadido
- Diagnóstico `/gp diag` y sondas de subasta, correo, botín y profesiones

## [0.0.2] - 2026-11-23

### Añadido
- Esqueleto del addon: núcleo (init, eventos, módulos, compatibilidad, registro y migraciones), localización enUS/esES, pruebas y empaquetado, y `tools/toc_dev.py` para la copia de desarrollo.

## [0.0.1] - 2026-11-23

### Añadido
- Documentación inicial: propuesta del producto, arquitectura, decisiones técnicas e investigación de la API del cliente, la casa de subastas y las fuentes de datos económicos de WoW Forever.
- Licencia WNCL-TP-1.0 (WarCrafted).
