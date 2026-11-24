# Ficha del proyecto en CurseForge

Guía para rellenar el formulario de creación (no se pega entera: cada bloque va en su campo). Los nombres de las categorías son los que ofrece CurseForge para addons de World of Warcraft; comprueba que coinciden con el desplegable.

| Campo | Valor |
|---|---|
| Nombre | GoldPilot Forever |
| Slug (URL) | `goldpilot` |
| Juego / tipo | World of Warcraft · Addons |
| Categoría principal | Auction & Economy |
| Categorías adicionales | Bags & Inventory, Tooltip |
| Logo | `docs/img/logo.png` (512×512) |
| Licencia | Licencia personalizada: WNCL-TP-1.0 (texto de `LICENSE`) |
| Comentarios | Activados (es el canal de soporte mientras no haya otro) |
| Distribución por terceros | Según prefieras; la licencia ya prohíbe el uso comercial |
| Enlaces | Código fuente: `https://github.com/warcrafted-server/goldpilot` (solo si el repositorio es público); incidencias: `…/issues` (idem) |
| Donaciones | Ninguna |
| Dependencias | Ninguna (ni obligatorias ni opcionales) |
| Capturas | El tooltip de un objeto con precio de subasta; la lista de bolsas (`/gpilot bags`); el botón del minimapa |

## Summary (English, máx. 250 caracteres)

```
Smarter selling for WoW Forever: item tooltips with vendor and auction prices, what your bags and bank are worth, and whether to auction or vendor each item. Works on its own: no Auctionator or TSM needed.
```

## Resumen (castellano)

```
Vende mejor en WoW Forever: precios de vendedor y de subasta en el tooltip de cada objeto, cuánto valen tus bolsas y tu banco, y si te conviene subastar o vender al vendedor. Funciona solo, sin Auctionator ni TSM.
```

## Description (English)

**GoldPilot Forever** helps you decide what to do with the things you carry. It reads the auction house itself while you play, remembers what it saw and tells you, on every item, what the vendor pays, what the auction house is asking and which is better for you.

**Inventory is now available.** It shows saved bags and bank contents by character or across the account, with clear price sources and recommendations.

### What it does
- **Item tooltips:** vendor price, observed auction price with its age, and a one-word recommendation (Auction or Vendor). Hold Shift for the lowest price seen and how many units were on sale.
- **Reads the auction house for you:** when you open it, GoldPilot looks up the items in your bags (reagent bag included), your bank and your other characters, one query at a time and respecting the game's limits. Hover over any item while the auction house is open and it is looked up right away.
- **Bag value:** `/gpilot bags` shows what your bags are worth at the vendor, on the auction house after the cut, and the best mix of both.
- **Inventory window:** `/gpilot` lists saved bags and bank contents, quantities by character and location, known vendor and auction values, and a sale recommendation. Switch between the current character and the whole account, filter by name, hide reserved items, reserve stock, and watch items for auction queries.
- **Honest data:** every price says where it comes from and how old it is. Old prices are marked as old and nothing is ever invented: no data means "no price".
- **Standalone:** no Auctionator, TradeSkillMaster or any other addon needed. Spanish and English.

### Commands
- `/gpilot` or `/gpilot window`: open or close the Inventory and Settings window.
- `/gpilot bags`: value of your bags.
- `/gpilot diag`: technical report of what your client supports (useful when reporting a problem).
- `/gpilot minimap`: show or hide the minimap button.
- `/gpilot version`, `/gpilot help`.

### Good to know
- Prices are what **you** have seen on your own auction house: open it to refresh them. There is no full market scan.
- The game does not tell addons the auction house cut, so GoldPilot assumes 5% and says so.
- Bank contents are saved the first time you open the bank with each character.

Problems or ideas? Leave a comment, and if you report a bug, include the output of `/gpilot diag`.

## Descripción (castellano)

**GoldPilot Forever** te ayuda a decidir qué hacer con lo que llevas encima. Lee la casa de subastas por sí mismo mientras juegas, recuerda lo que vio y te dice, en cada objeto, cuánto paga el vendedor, cuánto piden en la subasta y qué te conviene más.

**Inventario ya está disponible.** Muestra las bolsas y el banco guardados por personaje o en toda la cuenta, con el origen de los precios y las recomendaciones.

### Qué hace
- **Tooltips de objeto:** precio de vendedor, precio de subasta observado con su antigüedad y una recomendación de una palabra (Subasta o Vendedor). Con Mayús ves el mínimo observado y cuántas unidades había en venta.
- **Lee la subasta por ti:** al abrirla, GoldPilot consulta los objetos de tus bolsas (incluida la de componentes), de tu banco y de tus otros personajes, de una en una y respetando los límites del juego. Si pasas el cursor por un objeto con la subasta abierta, se consulta al momento.
- **Valor de bolsas:** `/gpilot bags` muestra cuánto valen tus bolsas al vendedor, en subasta tras la comisión y con la mejor combinación.
- **Ventana Inventario:** `/gpilot` lista bolsas y bancos guardados, cantidades por personaje y ubicación, precios conocidos de vendedor y subasta, y una recomendación de venta. Cambia entre el personaje actual y toda la cuenta, filtra por nombre, oculta objetos reservados, reserva existencias y sigue objetos para consultarlos en la subasta.
- **Datos honestos:** cada precio indica de dónde sale y qué antigüedad tiene. Los precios viejos se marcan como viejos y nunca se inventa nada: sin datos, «sin precio».
- **Autónomo:** no necesita Auctionator, TradeSkillMaster ni ningún otro addon. En castellano e inglés.

### Comandos
- `/gpilot` o `/gpilot window`: abre o cierra la ventana de Inventario y Ajustes.
- `/gpilot bags`: valor de tus bolsas.
- `/gpilot diag`: informe técnico de lo que soporta tu cliente (útil al comunicar un problema).
- `/gpilot minimap`: muestra u oculta el botón del minimapa.
- `/gpilot version`, `/gpilot help`.

### Conviene saber
- Los precios son los que **tú** has visto en tu casa de subastas: ábrela para refrescarlos. No hay escaneo completo del mercado.
- El juego no dice a los addons la comisión de la subasta, así que GoldPilot supone un 5 % y lo indica.
- El contenido del banco se guarda la primera vez que abres el banco con cada personaje.

¿Problemas o ideas? Deja un comentario y, si informas de un fallo, incluye lo que muestra `/gpilot diag`.
