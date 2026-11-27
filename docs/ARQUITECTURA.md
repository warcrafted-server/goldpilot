# Arquitectura de GoldPilot Forever

Diseño técnico inicial (2026-11-23). Producto y prioridades en [PROPUESTA.md](PROPUESTA.md); el porqué de cada decisión, en [DECISIONES.md](DECISIONES.md). Parte de la arquitectura de LoreWake, ya probada en el cliente de Forever, y solo cambia lo que el dominio económico exige.

## 1. Principios

1. **Funciona con lo que exista.** Cada módulo declara las capacidades de la API que necesita; si falta alguna, se desactiva y lo dice en `/gpilot diag`, sin romper el resto.
2. **El dato lleva su clase.** Todo precio, cantidad o beneficio indica de dónde sale y cuándo (§4). La interfaz nunca muestra una estimación como hecho.
3. **El jugador actúa; el addon aconseja.** Ninguna acción de subasta, correo o comercio se ejecuta sin clic del jugador.
4. **Nada en combate.** No se crea ni redibuja interfaz en combate y no se usa nada del registro de combate ni de eventos de hechizos.
5. **Lógica pura y comprobable.** El motor y el almacén de precios no llaman a la API del juego: se prueban fuera del juego.
6. **Sin librerías embebidas.** Ni Ace3 ni LibStub, como LoreWake: menos material de terceros y menos riesgo con Forever.
7. **Coste acotado.** Sin `OnUpdate` permanente; consultas a la subasta en cola y con límite; SavedVariables con presupuesto de tamaño.

## 2. Estructura del repositorio

```
Raíz del repo = carpeta del addon (lo que se instala en Interface/AddOns/GoldPilot)
GoldPilot.toc
Core/                    Init, Events, Modules, Compat, Log, Diag, Migrations, Settings
Locales/                 Locale.lua, enUS.lua, esES.lua
Data/Local/              Semillas de wowdata solo para pruebas locales (ignorada por git y por .pkgmeta)
Store/                   Almacén de precios, historial, libro de operaciones (subasta y vendedor) y visitas de la ruta (lógica pura)
State/                   Colectores: Bags, Bank, Money, AuctionHouse, Mail, Loot, Professions, RoutePlan, RouteFollow, Location
Engine/                  Valoración, asistente de venta, asesor, proveedores de recomendaciones y rutas de recolección (lógica pura)
Sources/                 Fuentes de precio propias y datos externos de la aplicación, si se habilitan
UI/                      Tema, ventana principal, pestañas, tooltip, asistente de venta, HUD de sesión, mapa y rutas
API.lua                  API pública mínima para otros addons
companion/               Aplicación externa opcional (Python), fuera del paquete (ignorada en .pkgmeta)
tests/                   Pruebas fuera del juego (lupa + simulación de la API)
tools/                   Empaquetar, generar datos desde wowdata, validar
docs/
```

- El addon vive en la raíz del repositorio, como los demás addons. El empaquetado de CurseForge (BigWigs packager, como PocketBank) usa `.pkgmeta` con `ignore` para publicar solo los archivos del addon.
- **Globales permitidos:** `GoldPilot` (espacio de nombres y API pública), `GoldPilotDB`, `GoldPilotCharDB`, los de los comandos (`SLASH_GOLDPILOT1/2`, `SlashCmdList.GOLDPILOT`), la función del compartimento de addons y los nombres de las ventanas que deban cerrarse con Escape. Una prueba lo comprueba.
- **Semillas locales:** `tools/generar_desde_wowdata.py` genera `Data/Local/NodeSeeds.lua` (tipo y objeto de cada nodo) y `tools/generar_semilla_local.py` genera `Data/Local/NodeSpots.lua` (posiciones) desde `wowdata` en modo lectura para probar en local; no se publican ni se versionan porque proceden de Questie y de datos de origen sin verificar, y el TOC de desarrollo las carga si existen. El paquete publicado clasifica y valora los nodos por su botín.
- **TOC:** `## Interface: 16001`, `## SavedVariables: GoldPilotDB`, `## SavedVariablesPerCharacter: GoldPilotCharDB`, `## OptionalDeps: GoldPilot_Market, TomTom`, `## X-Curse-Project-ID` cuando exista el proyecto.

## 3. Núcleo (`Core/`)

Igual que LoreWake: un único frame de eventos con suscripción por módulo y agrupación de ráfagas (`BAG_UPDATE_DELAYED`, resultados de subasta); registro de módulos con `requires`; `Compat.has(cap)` y `Compat.call` con `pcall`; registro con niveles; `/gpilot diag` que guarda el informe en `GoldPilotDB.diag`.

`Events.lua` entrega además mensajes internos entre módulos con `addon.Events:send("GOLDPILOT_...")`: se suscriben igual que los eventos, pero nunca se registran en el frame del juego.

`Timer.lua`: temporizadores de un disparo y repetidos, con dueño, que se pueden cancelar (`addon.Timer.after/every/cancelAll`); si la función falla, se registra el error sin romper el resto.

**Capacidades a diagnosticar desde el primer paso:** `C_AuctionHouse` (búsquedas, commodities, propias, `GetAuctionHouseCut`, `ReplicateItems`), eventos de subasta y de límite de consultas, `GetInboxInvoiceInfo` y lectura del buzón, `GetLootSourceInfo` y formato del GUID de objetos de mundo, `C_TradeSkillUI` con la ventana abierta, `C_Container` del banco, API pública de Auctionator (`Auctionator.API.v1`) y TSM (`TSM_API`).

`Migrations.lua`: lista ordenada de funciones `[n] = function(db) ... end` que llevan `GoldPilotDB.schema` de `n-1` a `n`. Se ejecutan en `ADDON_LOADED` antes que cualquier módulo; si una falla, se guarda copia de la tabla original en `GoldPilotDB.backup` y el addon arranca en modo seguro (solo lectura y diagnóstico).

`Settings.lua`: cada ajuste se define una sola vez (clave, tipo, valor por defecto, sección y etiqueta); de esa definición salen la pestaña Ajustes y `/gpilot set`.

## 4. Clases de dato

| Clase | Clave | Qué es | Ejemplo |
|---|---|---|---|
| Hecho del juego | `GAME` | Valor fijo del cliente | Precio de vendedor, tamaño de pila, comisión |
| Observado | `OBS` | Visto por el jugador en su casa de subastas, con fecha | 1,2 de plata por Hierro, 4 300 en venta, hace 2 h |
| Registrado | `REG` | Acción propia anotada por el addon | Publicaste 40 lingotes a 1 de oro |
| Confirmado | `CONF` | Hecho comunicado por el juego | Factura del correo: vendidos 20, recibiste X tras comisión |
| Externo | `EXT` | Llegado de la aplicación opcional, con su origen y fecha | Mediana regional de la API web |
| Estimado | `EST` | Derivado por GoldPilot | Valor realizable, oro/hora, liquidez |

Cada estimación guarda las entradas que la producen para poder explicarla en la ficha («calculado con 3 observaciones de las últimas 24 h y una comisión del 5 %»).

**Elección del precio de referencia** (`Engine/Valuation.lua`): la fuente más reciente y fiable dentro de una ventana de validez configurable (por defecto 48 h), en este orden de preferencia: `OBS` propio > `EXT` de la aplicación > sin precio (se dice, no se inventa). El precio de vendedor (`GAME`) siempre se muestra aparte como suelo.

## 5. Almacenamiento

`GoldPilotDB` (cuenta):

```lua
GoldPilotDB = {
  schema = 1,
  settings = { ... },
  houses = { ["<houseKey>"] = { name=..., cut=0.05, lastSeen=t } },
  prices = { ["<houseKey>"] = { [itemKey] = "<t>:<min>:<p50>:<qty>|<d>|<w>" } },
  ledger = { [año] = { {t=, kind="sell", item=, qty=, gross=, cut=, deposit=, src="CONF"}, ... } },
  itemNames = { ["Nombre"] = itemID },  -- objetos del Libro, aprendidos por nombre
  mailPending = { ["Nombre"] = { t=, money=, items=, total=, expires=, counted=,
                  list={ {name=, qty=, money=}, ... } } },  -- list: los 6 primeros correos con algo que recoger
  chars = { ["Nombre-Ruleset"] = { money=, bags={[itemID]=n}, bank={...}, bankSeen=t, profs={...} } },
  watch = { [itemKey] = true },
  reserved = { [itemID] = n },
  sessions = { { start=t, stop=t, char="Nombre", active=n, coin=, loots=, nodes=, items={[itemKey]=n},
                 lastMap=mapID, maps={[mapID]={active=, coin=, items={[itemKey]=n}}} }, ... },
            -- últimas 50 sesiones de recolección, resumidas
  nodes = { [mapID] = { [objectID] = { n=, first=t, last=t,
            spots={ {x=, y=, n=, t=}, ... } } } },  -- x, y = coordenada del mapa * 10000
  routeVisits = { [mapID] = { ["<tipo>:<celda>"] = { v=, h=, t= } } },  -- visitas y aciertos de la ruta
  diag = { ... },
}
```

- **`itemKey`**: el ID numérico para objetos sin variantes; para equipo con variantes, `itemID:bonus` (los bonus ordenados numéricamente).
- **`houseKey`**: identificador de la casa de subastas (por investigar cómo obtenerlo); mientras tanto, `faction|neutral` + ruleset.
- **Historial empaquetado en cadenas**: `d` y `w` usan el formato `<día>:<min>:<p50>:<qty>;...` dentro del valor de `prices`; reduce el tamaño y solo se desempaqueta al consultar el historial.
- **`p50`**: mediana ponderada por cantidad de las primeras N unidades en venta (por defecto las que cubren el 15 % de la oferta), más robusta que el mínimo, que es fácil de manipular con un anuncio de una unidad.
- **Poda** (al iniciar sesión, en una tarea diferida): 90 días diarios para objetos de interés, 7 días para claves numéricas y 2 días para variantes; solo los objetos de interés acumulan historial semanal (hasta 52 semanas). Los objetos sin observar caducan a los 180 días si interesan y a los 30 días en caso contrario. Presupuesto objetivo < 5 MB; las pruebas generan un caso intensivo y miden el tamaño serializado.
- `GoldPilotCharDB` (personaje): ajustes de interfaz y la sesión en curso.

## 6. Colectores (`State/`)

| Colector | Lee | Cuándo |
|---|---|---|
| `Bags`, `Money` | contenido de bolsas y oro | `BAG_UPDATE_DELAYED` (agrupado), `PLAYER_MONEY` |
| `Bank` | banco y bolsas del banco; si PocketBank está instalado, sus existencias de toda la cuenta (su API pública, en tiempo de ejecución) | Al abrir el banco |
| `AuctionHouse` | resultados de búsquedas, propias, cola de consultas | Solo con la subasta abierta |
| `Mail` | facturas de subasta y correos de caducidad | Al abrir el buzón |
| `Loot` | objeto, cantidad, origen (nodo, PNJ) y mapa | `LOOT_READY` / `LOOT_CLOSED` |
| `Professions` | profesiones y nivel; recetas al abrir la ventana (`State/Professions.lua` lee la habilidad sin caché para las rutas) | `SKILL_LINES_CHANGED`, apertura de profesión |
| `Location` | mapa y zona | `ZONE_CHANGED_NEW_AREA` |

**Cola de consultas a la subasta**: prioridad (objeto que el jugador va a vender > seguidos > bolsas > reactivos), una consulta en vuelo a la vez, se pausa con los eventos de límite y se reanuda; se detiene al cerrar la subasta.

## 7. Motor (`Engine/`)

`Engine/Sell.lua` calcula el precio sugerido, el mínimo que supera al vendedor y el neto tras comisión y depósito sin acceder a la API del juego.

`Engine/Deals.lua` evalúa gangas de vendedor y reventa a partir de precios observados e historial diario, sin acceder a la API del juego.

`Engine/Trading.lua` calcula medias de compra y venta, reventa FIFO, existencias y balance del historial del libro, sin acceder a la API del juego.

Proveedores puros `proveedor(State, Store, Data, Settings) -> oportunidades`, como en LoreWake. Oportunidad:

```lua
{ id=, kind="sell"|"gather"|"craft"|"hold"|"buy",
  title=<clave>, reasons={ {<clave>, valor}, ... },
  benefit={ copper=, perHour= }, conf=<clase>, inputs={...}, action=<qué hacer> }
```

Puntuación: `beneficio esperado × confianza × liquidez × peso del perfil`, con todos los pesos y constantes en `Engine/Weights.lua`. Proveedores previstos: vender lo que tienes (subasta frente a vendedor), recolectar en la mejor zona para tu habilidad, liquidar objetos lentos, fabricar (cuando exista), comprar reactivos baratos para tus recetas (solo con datos `OBS` o `EXT` recientes).

`Engine/Routes.lua` (puro) reúne los puntos propios y los de la semilla local, descarta los que no tienen precio o no puede recoger la habilidad, los agrupa en paradas y ordena y poda el recorrido; cada parada conserva sus puntos agrupados. `State/RoutePlan.lua` lo une al juego: lee el mapa actual, su nombre, el aspecto y el ancho en yardas, valora los puntos con las sesiones y con el factor de visitas, y guarda el plan activo (sin SavedVariables). `State/RouteFollow.lua` sigue el plan: consulta la posición cada 2 s, resalta y marca la siguiente parada, y registra las visitas con y sin nodo en `GoldPilotDB.routeVisits` para que `Store/Visits.lua` (puro) ajuste el peso de los puntos.

## 8. Interfaz (`UI/`)

`UI/SellAssist.lua` lee las ofertas y el depósito en la subasta, muestra el consejo junto al formulario de venta y rellena el precio solo cuando el jugador pulsa el botón.

`UI/Deals.lua` muestra gangas o «Mi lista» junto a la pestaña Comprar, abre el objeto seleccionado en la interfaz de Blizzard y avisa de precios que cumplen el máximo guardado; no ejecuta compras. `Store/Shopping.lua` conserva los máximos por objeto en `GoldPilotDB.shopping` y evalúa observaciones recientes.

`UI/TradingUI.lua` muestra la pestaña Comercio con el resumen completo del libro, el valor estimado de las existencias y el filtro para apartar objetos personales.

- Tema derivado de `lorewake/Lorewake/UI/Theme.lua` (mismo autor; se copia y adapta, no se comparte en tiempo de ejecución).
- Componentes reutilizables: ventana con pestañas, lista con secciones + ficha, franja de métricas, insignia de clase de dato, mini tendencia de texto (▲ ▼ ●) en lugar de gráficas.
- Tooltip: ganchos con `TooltipDataProcessor` (HER, verificar); dos líneas como máximo, ampliables con Mayús.
- Panel de subasta anclado a la ventana de la subasta; se crea al primer `AUCTION_HOUSE_SHOW`.
- HUD de sesión de recolección, movible y desactivable.
- Pestaña Zonas (`UI/Zones.lua`): oro por hora medido por zona, sesiones guardadas y creación de rutas; `UI/RouteMap.lua` dibuja la ruta activa sobre el mapa del mundo con líneas y paradas numeradas.
- Nada se crea ni se redibuja en combate.

## 9. Traducciones

Como LoreWake: tabla `L` con respaldo a `enUS` y aviso de claves ausentes; ningún texto visible en la lógica; nombres de objetos, zonas y profesiones pedidos al cliente por ID (ya localizados). Una prueba exige las mismas claves en `enUS` y `esES`. Formato de dinero con los iconos de oro, plata y cobre del juego, nunca con texto traducido.

## 10. Comunicación con la aplicación externa

Los addons no tienen red ni acceso a archivos. Canal elegido, asíncrono y sin riesgo:

1. **Juego → aplicación:** la aplicación lee `WTF/Account/<cuenta>/SavedVariables/GoldPilot.lua` (libro, precios observados, personajes) cuando cambia el archivo (al salir o con `/reload`). Lectura con `lupa`, como en `wowdata`.
2. **Aplicación → juego:** la aplicación escribe un addon de datos aparte, `Interface/AddOns/GoldPilot_Market/` (`.toc` + `Market.lua` generado), con precios regionales recientes, liquidez estimada y fecha de generación. El addon principal lo lee si está cargado y marca esos datos como `EXT`. Se recarga con `/reload`.
3. Versión de formato en ambos sentidos (`GoldPilot_Market.format = 1`); si no coincide, el addon lo ignora y lo dice en el diagnóstico.

Alternativa descartada: el canal de píxeles en tiempo real de AskForever. Aquí no hace falta tiempo real y añadiría captura de pantalla, latencia y una superficie de seguridad que no aporta nada.

## 11. Pruebas

- `python tests/run.py` (Lua 5.1 real con `lupa`, simulación `tests/wowmock.lua`, mismas comprobaciones que LoreWake: compilación, claves de traducción, `VERSION` igual al TOC, globales permitidos) y pruebas `tests/test_*.lua` del almacén, la valoración, las migraciones y los proveedores.
- **Fixtures reales**: copias anonimizadas de SavedVariables y del diagnóstico para reproducir casos del juego.
- Pruebas de la aplicación con `pytest`.
- `docs/COMPROBACIONES.md`: lista manual en juego por versión.

## 12. Versionado y publicación

- `VERSION` y `## Version` del TOC iguales (una prueba lo comprueba); `GoldPilotDB.schema` independiente.
- Publicación como PocketBank: tag `v<versión>` → GitHub Actions con `BigWigsMods/packager@v2` → CurseForge (secreto `CF_API_KEY`), notas bilingües en `docs/RELEASE_NOTES.md` (`manual-changelog`) y descripción en `docs/CURSEFORGE.md`. Ningún tag ni push sin tu aprobación.
