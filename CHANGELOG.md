# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/).

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

## [Sin publicar]

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
