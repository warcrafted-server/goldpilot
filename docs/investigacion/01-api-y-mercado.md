# 01 - API del cliente, casa de subastas y fuentes de datos económicos

Fecha de consulta: 2026-11-23. Cliente de referencia: WoW Forever 1.60.1.70862, Interface 16001 (verificado en el cliente local para LoreWake, `lorewake/docs/investigacion/07` y `08`).

Clasificación de cada dato:

| Clave | Significado |
|---|---|
| **VC** | Verificado en el cliente (archivos o diagnóstico en juego) |
| **CF** | Confirmado por fuente técnica (wiki de la API, foro de desarrolladores) |
| **TER** | Fuente terciaria (guías, webs de fans, páginas de CurseForge) |
| **HER** | Heredado de Mainline 12.x; probable, sin probar en Forever |
| **DESC** | Desconocido |

Nada de la API de subastas, correo ni profesiones está probado aún en el cliente de Forever. El primer paso de desarrollo es un diagnóstico en juego (ver `docs/PROPUESTA.md`, roadmap).

## 1. Cómo funciona la casa de subastas de Forever

| Dato | Estado | Fuente |
|---|---|---|
| Interfaz y API de subasta **moderna** (`C_AuctionHouse`): los objetos apilables («commodities»: tela, mineral, hierbas, polvos…) se venden por unidad, sin pujas, con la oferta de todos los vendedores agrupada; el comprador elige cantidad y se lleva primero lo más barato | TER (coinciden varias) | hearthproof.com, wowfah.com, ahledger.com |
| Los objetos no apilables (equipo) se subastan uno a uno con puja y compra inmediata; algunos anuncios son solo de puja | TER + CF | ídem; foro de la API (ver §4) |
| **Sin reinos**: una sola casa por facción (y las neutrales) para toda la región y ruleset. Mercado muy grande y líquido | TER | hearthproof.com, conquestcapped.com |
| Casas de facción y neutrales (Bahía del Botín, Gadgetzan, Everlook) | TER + VC | guías; tabla `AuctionHouse` del cliente |
| Comisión al vender: **5 %** en la casa de facción, **15 %** en la neutral | TER + VC | guías; `AuctionHouse.ConsignmentRate` = 5 / 15 en el cliente |
| Depósito: la tabla del cliente da `DepositRate` 5 (facción) y 25 (neutral), como en Classic; varias guías dicen que el **depósito mínimo bajó a 1 cobre** en noviembre (fechas contradictorias: 10 o 17 de nov.). La fórmula real del depósito no está publicada | VC (tabla) / TER (cambios) / **DESC** (fórmula) | `wowdata` (`auctionhouse`); guías |
| Escaneo completo (`ReplicateItems`): un desarrollador informó en la beta de que queda limitado durante más de 162 s y después devuelve un mercado vacío en lugar de un error | TER | timesaver.gg y guías de addons |
| Duraciones de subasta disponibles en Forever | DESC | Verificar en juego |

**Consecuencia:** el addon no puede depender de escaneos completos frecuentes. Las búsquedas dirigidas (los objetos que el jugador tiene, sigue o necesita) son el camino fiable dentro del juego. La validez de las comisiones debe leerse del cliente cuando sea posible (`C_AuctionHouse.GetAuctionHouseCut`, HER) y no fijarse en el código.

## 2. Qué puede saber un addon (por verificar con `/gp diag`)

| Información | API probable | Estado | Notas |
|---|---|---|---|
| Precio actual de un commodity (por unidad, cantidades) | `C_AuctionHouse.SendSearchQuery` / `SendSellSearchQuery`, `GetCommoditySearchResultInfo`, evento `COMMODITY_SEARCH_RESULTS_UPDATED` | HER | Solo con la ventana de subasta abierta. Hay límite de consultas (`AUCTION_HOUSE_THROTTLED_*`) |
| Precio actual de un objeto no apilable | `SendSearchQuery` + `GetItemSearchResultInfo` | HER | Ídem |
| Navegación por categorías | `SendBrowseQuery`, `GetBrowseResults` | HER | Sirve para escaneos parciales por categoría |
| Escaneo completo | `ReplicateItems`, `GetNumReplicateItems`, `GetReplicateItemInfo` | HER + TER (limitado) | No usar como base |
| Subastas propias activas | `C_AuctionHouse.QueryOwnedAuctions`, `GetOwnedAuctions` | HER | Con la subasta abierta |
| Lo que el jugador publica o compra | eventos `AUCTION_HOUSE_AUCTION_CREATED`, `COMMODITY_PURCHASE_SUCCEEDED`, ganchos sobre `PostCommodity`/`PostItem`/`ConfirmCommoditiesPurchase` | HER | Es **operación registrada**: aún no es venta |
| **Ventas confirmadas** | Correo: `GetInboxInvoiceInfo(index)` devuelve tipo (`seller`, `buyer`), objeto, comprador, puja, compra, depósito y comisión | HER | Es la única **venta confirmada** fiable. Solo al abrir el buzón |
| Subastas caducadas o canceladas | Asunto y adjuntos del correo de la subasta | HER | Distingue «no vendido» de «vendido» |
| Precio de venta al vendedor | `C_Item.GetItemInfo` (campo `sellPrice`) | HER (la tabla `ItemSparse.SellPrice` está en el cliente: VC) | Hecho, no estimación |
| Bolsas | `C_Container.*`, `BAG_UPDATE_DELAYED` | VC (existe `C_Container`) | |
| Banco | `C_Container` con el banco abierto | HER | Solo se actualiza al visitar el banco (como PocketBank) |
| Dinero | `GetMoney`, `PLAYER_MONEY` | HER | |
| Botín y origen (recolección) | `LOOT_READY`, `GetLootSourceInfo`, `GetLootSlotInfo`, GUID de tipo `GameObject` | HER | El GUID tiene ofuscados servidor y spawn (CF, beta 5), pero el ID de objeto debería seguir siendo legible: **verificar** |
| Profesiones y nivel | `GetProfessions`, `GetProfessionInfo` | VC | |
| Recetas conocidas y reactivos | `C_TradeSkillUI.*` con la ventana de profesión abierta | VC (existe) / DESC (comportamiento: profesiones rediseñadas en Forever) | Pieza de mayor incertidumbre |
| Mapa y posición | `C_Map.GetBestMapForUnit`, `GetPlayerMapPosition` | VC | |
| Identificar en qué casa de subastas estás (facción / neutral / ruleset) | DESC | DESC | Necesario para no mezclar precios de casas distintas |
| Acceso a Internet, ficheros o procesos | No existe | CF | Toda comunicación externa pasa por SavedVariables o archivos de addon |

Restricciones generales de Forever (de la investigación de LoreWake): restricciones de Midnight activas (valores secretos y registro de combate cerrado en combate), funciones protegidas en combate, posible retirada futura de eventos de lanzamiento de hechizos (12.2, no confirmado). GoldPilot no necesita nada de combate y **no debe depender de eventos de hechizos** para detectar la recolección: se usa el botín y su origen.

## 3. Ecosistema existente (competencia y posibles integraciones)

| Addon | Qué hace en Forever | Estado | Fuente |
|---|---|---|---|
| **TradeSkillMaster 4.15** | Soporte de Forever desde noviembre (archivo 4.15.8 del 18-11-2026, Interface 16001); precios de región con su app de escritorio (las guías se contradicen sobre si ya llegan datos de Forever) | TER | tradeskillmaster.com, wowfah.com, wowcalc.net |
| **Auctionator** | Escaneo y precios en Forever desde antes del lanzamiento; API pública para otros addons | TER | varias guías |
| auxForever, Auctionizer | Compra y venta en la subasta | TER | CurseForge |
| Resource Farmer, AetherForge Gatherer, MyGatherTracker, Gold Forever, ForeverSessionGold, Yield… | Contadores de oro/hora de recolección (precios de TSM o Auctionator, si no del vendedor) | TER | CurseForge |
| Gatherer Reforged | Nodos de recolección con bases de GatherMate2 que incluyen Forever | TER | CurseForge |
| Forever Companion (All Rights Reserved) | Profesiones con beneficio según subasta, puntos de recolección, datos de subasta | TER | `lorewake/docs/investigacion/04` |
| Webs: outof.games, azerite.exchange, ahledger.com, wowfah.com | Precios y movimientos de la subasta de Forever | TER | Probablemente a partir de la API web de Blizzard (§4) |

**Lectura:** consultar precios y contar oro/hora ya está cubierto, varias veces. Lo que no existe es una capa que **decida y explique**, distinga lo observado de lo estimado, y mida el **beneficio real** con ventas confirmadas. Ese es el hueco de GoldPilot. Integrarse con Auctionator y TSM (leer su API pública en tiempo de ejecución, si están instalados) es mejor que competir con ellos en escaneo.

## 4. API web de Blizzard para Forever

Fuente: hilo de la comunidad «WoW: Forever API: what works so far, plus a TS client» en el foro de desarrolladores de Blizzard (posts del 5 al 18 de noviembre de 2026). **Sin documentación ni confirmación oficial de Blizzard**; rutas extraídas del hilo, a verificar con una llamada real.

| Dato | Valor según el hilo |
|---|---|
| Espacios de nombres | `dynamic-forever-{region}`, `static-forever-{region}`, `profile-forever-{region}`; regiones US, EU, KR, TW |
| Índice de rulesets | `/data/wow/ruleset/index`; detalle `/data/wow/ruleset/{id}` |
| Casas | `/data/wow/ruleset/{id}/auctions/` (barra final obligatoria): 15 casas, IDs 110-121 y 123-125 (coinciden con los IDs de la tabla `AuctionHouse` del cliente) |
| Objetos no apilables | Campo `auctions` de `/data/wow/ruleset/{id}/auctions/{houseId}` (puja, compra, cantidad, tiempo restante) |
| Commodities | `/data/wow/ruleset/{id}/auctions/{houseId}/commodities` (`unit_price`, `quantity`, `time_left`) |
| Disponible desde | 6 de noviembre de 2026 |
| Avisos | Todos los rulesets devuelven las mismas casas y anuncios (puede ser un error); tres casas vacías; respuestas de hasta ~9 MB; el 43 % de los IDs de objeto de una casa devolvía 404 en `/data/wow/item/{id}`; la ruta antigua `/data/wow/auctions/commodities` da 404; frecuencia de actualización desconocida |

**Consecuencia:** una aplicación externa puede obtener instantáneas completas de **todas** las casas de la región, cosa que el addon no puede hacer dentro del juego. Es el valor principal de la aplicación opcional. Requiere que el usuario cree su propio cliente gratuito en el portal de desarrolladores de Battle.net y aceptar sus términos de uso (pendiente de revisar: redistribución de datos).

## 5. Datos del juego disponibles localmente (`wowdata`)

El proyecto `Projectes/wowdata` ya extrae del cliente y de Questie, con origen por fila:

| Vista | Filas (2026-11-23) | Uso en GoldPilot |
|---|---|---|
| `v_nodo_zona` | 540 | Nodos de minería y herboristería por zona con habilidad mínima. **Muchos vienen de Classic**: solo semilla, corregida con lo observado en juego (DECISIONES D11) |
| `v_desuello` | 884 | PNJ desollables por zona |
| `v_receta`, `v_receta_reactivo` | 2 694 / 9 640 | Recetas, reactivos y colores de habilidad (coste de fabricación) |
| `v_vendedor_objeto` | 19 125 | Reactivos que se compran a vendedor (precio fijo, cota superior de coste) |
| `v_objeto` + `ItemSparse` | 26 401 | Precio de vendedor, tamaño de pila, vinculación (lo ligado no va a subasta) |
| `auctionhouse` | 15+ | Casas con depósito y comisión |

Los datos se generan como tablas Lua (`Data/Generated/`), igual que en LoreWake, con `conf` y `src` por registro.

## 6. Fuentes

- hearthproof.com/economy/auction-house/ · wowforeverclasses.com/articles/how-to-use-auction-house-wow-forever · ahledger.com/wow-forever/auction-house · wowfah.com/guides/wow-forever-commodities-and-items · conquestcapped.com/guides/wow-forever/wow-forever-auction-house/
- tradeskillmaster.com/news/tsm-4-15-brings-wow-forever-support-plus-new-desktop-app-1180 · wowfah.com/guides/tsm-wow-forever · wowcalc.net/en/forever/wiki/addons/tradeskillmaster · timesaver.gg/blog/wow-forever-addons-save-beta-ui-before-launch
- us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334
- github.com/jkc-be/goldbook/issues/67 (estado anterior, 28-10-2026: sin datos de subasta)
- CurseForge: auxforever, auctionizer, resourcefarmer, aetherforge-gatherer, gatherer-reforged, mygathertracker, gold-forever
- warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes · warcraft.wiki.gg/wiki/Category:API_systems/AuctionHouse
- Proyectos propios: `lorewake/docs/investigacion/01`, `07`, `08`; `wowdata/README.md`
