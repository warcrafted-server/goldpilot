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
| Dependencias | Ninguna obligatoria; TomTom es opcional (marca la siguiente parada de la ruta) |
| Capturas | En `docs/img/capturas/`, en este orden: `tooltip.png`, `ahora.png`, `inventario.png`, `libro.png`, `zonas.png`, `ruta-mapa.png`. Recortadas a la ventana y sin nombres de personajes. `zonas.png` y `ruta-mapa.png` se hicieron con las semillas locales de desarrollo, así que muestran más puntos de los que tendrá una instalación nueva |

## Summary (English, máx. 250 caracteres)

```
GoldPilot Forever for WoW Forever: item tooltips with vendor and auction prices, a full market scan when you open the auction house, bag and bank values, a sales ledger, and gathering routes with gold per hour. No Auctionator or TSM needed.
```

## Resumen (castellano)

```
GoldPilot Forever para WoW Forever: tooltips con precios de vendedor y de subasta, escaneo completo del mercado al abrir la subasta, valor de bolsas y banco, libro de ventas y rutas de recolección con oro por hora. Sin Auctionator ni TSM.
```

## Description (English)

**GoldPilot Forever** helps you decide what to do with what you carry and where to earn more. It reads the auction house itself while you play, remembers what it saw and tells you, on every item, what the vendor pays, what the auction house is asking and which is better for you. The `/gpilot` window brings it all together in five tabs: **Now**, **Inventory**, **Ledger**, **Zones** and **Settings**.

### What it does
- **Item tooltips:** vendor price, last price seen, median and a one-word recommendation (Auction or Vendor). Hold Shift to also see the units on sale and the price trend.
- **Full auction scan:** when you open the auction house, GoldPilot downloads the whole listing in 30–40 seconds. It is on by default and can be turned off in Settings; `/gpilot scan` runs it by hand. The server limits it to once every 15 minutes.
- **Item-by-item queries:** whatever the full scan does not cover — watched items, equipped gear, and the bags and banks of all your characters — is queried one item at a time, respecting the game's limits.
- **Prices per variant:** equipment variants keep their own prices.
- **Now:** advice on whether to sell at auction or to a vendor, mail to collect, items stored on other characters, price trends and your best zone. Switch between the current character and the whole account.
- **Inventory:** saved bags and bank contents with quantities by character and location, known vendor and auction values, and a sale recommendation. Filter by name, hide reserved items, reserve stock and watch items for auction queries.
- **Ledger:** sales and purchases confirmed by the mail invoices, plus returns, grouped by item. Choose the last 7 days, 30 days or the whole history.
- **Zones:** measured gold per hour for each zone, session history and a gathering route for herbs and ore drawn on the world map. The route is built from the nodes you have gathered yourself, highlights the next stop and can mark it in TomTom.
- **Gathering session panel:** a movable panel shows the gold per hour of the session and summarizes it when it ends.
- **Honest data:** every price says where it comes from and how old it is. Old prices are marked as old and nothing is ever invented: no data means "no price".
- **Standalone:** no Auctionator, TradeSkillMaster or any other addon needed. Spanish and English.

### Commands
- `/gpilot` or `/gpilot window`: open or close the window.
- `/gpilot bags`: value of your bags.
- `/gpilot scan`: full auction house scan (with the auction house open).
- `/gpilot watch <link or item>`: watch or stop watching an item.
- `/gpilot ledger`: summary of the month's sales and purchases.
- `/gpilot session`, `/gpilot session end`, `/gpilot hud`: gathering session summary and panel.
- `/gpilot route`: state of the gathering route drawing.
- `/gpilot diag`: technical report of what your client supports (useful when reporting a problem).
- `/gpilot minimap`: show or hide the minimap button.
- `/gpilot version`, `/gpilot help`.

### Good to know
- Prices are what **you** have seen on your own auction house: open it to refresh them, or run a full scan to cover every listed item.
- The game does not tell addons the auction house cut, so GoldPilot assumes 5% and says so.
- Bank contents are saved the first time you open the bank with each character.
- The gathering route starts with very few points and grows with each visit, using only the nodes you have gathered.

Problems or ideas? Leave a comment, and if you report a bug, include the output of `/gpilot diag`.

## Descripción (castellano)

**GoldPilot Forever** te ayuda a decidir qué hacer con lo que llevas encima y dónde ganar más. Lee la casa de subastas por sí mismo mientras juegas, recuerda lo que vio y te dice, en cada objeto, cuánto paga el vendedor, cuánto piden en la subasta y qué te conviene más. La ventana de `/gpilot` lo reúne todo en cinco pestañas: **Ahora**, **Inventario**, **Libro**, **Zonas** y **Ajustes**.

### Qué hace
- **Tooltips de objeto:** precio de vendedor, último precio visto, mediana y una recomendación de una palabra (Subasta o Vendedor). Con Mayús ves además las unidades en venta y la tendencia del precio.
- **Escaneo completo de la subasta:** al abrirla, GoldPilot descarga el listado entero en 30-40 s. Está activado por defecto y se puede desactivar en Ajustes; `/gpilot scan` lo lanza a mano. El servidor limita a uno cada 15 minutos.
- **Consultas objeto a objeto:** lo que no cubre el escaneo completo —objetos seguidos, equipo equipado y bolsas y bancos de todos tus personajes— se consulta de uno en uno, respetando los límites del juego.
- **Precios por variante:** las variantes de equipo mantienen su propio precio.
- **Ahora:** consejos para vender en subasta o al vendedor, recoger el correo, revisar objetos en otros personajes, tendencias de precios y tu mejor zona. Cambia entre el personaje actual y toda la cuenta.
- **Inventario:** bolsas y bancos guardados con cantidades por personaje y ubicación, precios conocidos de vendedor y subasta, y una recomendación de venta. Filtra por nombre, oculta objetos reservados, reserva existencias y sigue objetos para consultarlos en la subasta.
- **Libro:** ventas y compras confirmadas por las facturas del correo, además de las devoluciones, agrupadas por objeto. Elige los últimos 7 días, 30 días o todo el historial.
- **Zonas:** oro por hora medido de cada zona, historial de sesiones y una ruta de recolección de hierbas y minerales dibujada en el mapa del mundo. La ruta se crea con los nodos que has recogido tú, resalta la siguiente parada y puede marcarla en TomTom.
- **Panel de sesión de recolección:** un panel movible muestra el oro por hora de la sesión y la resume al terminar.
- **Datos honestos:** cada precio indica de dónde sale y qué antigüedad tiene. Los precios viejos se marcan como viejos y nunca se inventa nada: sin datos, «sin precio».
- **Autónomo:** no necesita Auctionator, TradeSkillMaster ni ningún otro addon. En castellano e inglés.

### Comandos
- `/gpilot` o `/gpilot window`: abre o cierra la ventana.
- `/gpilot bags`: valor de tus bolsas.
- `/gpilot scan`: escaneo completo de la subasta (con la subasta abierta).
- `/gpilot watch <enlace u objeto>`: sigue o deja de seguir un objeto.
- `/gpilot ledger`: resumen de ventas y compras del mes.
- `/gpilot session`, `/gpilot session end`, `/gpilot hud`: resumen y panel de la sesión de recolección.
- `/gpilot route`: estado del dibujo de la ruta de recolección.
- `/gpilot diag`: informe técnico de lo que soporta tu cliente (útil al comunicar un problema).
- `/gpilot minimap`: muestra u oculta el botón del minimapa.
- `/gpilot version`, `/gpilot help`.

### Conviene saber
- Los precios son los que **tú** has visto en tu casa de subastas: ábrela para refrescarlos o haz un escaneo completo para cubrir todos los objetos en venta.
- El juego no dice a los addons la comisión de la subasta, así que GoldPilot supone un 5 % y lo indica.
- El contenido del banco se guarda la primera vez que abres el banco con cada personaje.
- La ruta de recolección empieza con muy pocos puntos y crece con cada visita, usando solo los nodos que has recogido tú.

¿Problemas o ideas? Deja un comentario y, si informas de un fallo, incluye lo que muestra `/gpilot diag`.
