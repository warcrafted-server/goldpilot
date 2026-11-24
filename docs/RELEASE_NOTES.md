# 0.3.0 (2026-11-24) — English

### Added
- Inventory window with saved bags and bank contents, per item values and recommendations, account and character scopes, filtering, reservations, and watch controls.
- Item details show quantities by character and location, vendor and observed auction prices, age, and net auction value.

> Auction prices are GoldPilot's own observations. Bank contents are available after visiting the bank with each character. This release has not yet been verified in game.

# 0.3.0 (2026-11-24) — Español

### Añadido
- Ventana Inventario con bolsas y bancos guardados, valores y recomendaciones por objeto, ámbitos de personaje y cuenta, filtro, reservas y seguimiento.
- La ficha muestra cantidades por personaje y ubicación, precios de vendedor y subasta observados, antigüedad y valor neto de subasta.

> Los precios de subasta son observaciones de GoldPilot. El banco está disponible después de visitarlo con cada personaje. Esta versión aún no se ha comprobado en juego.

# 0.2.0 (2026-11-24) — English

### Added
- GoldPilot records bank contents when the bank is opened and queues watched items, current bags and bank, and saved bags and banks from other characters for auction price observations.
- Hovering an item while the auction house is open prioritizes a query when its last observation is at least ten minutes old. The latest auction session is recorded in `GoldPilotDB.ahLast`.

### Changed
- House keys use faction only, and character keys use character name only. Schema migration 2 merges existing keys.
- The diagnostic refresh preserves previously recorded auction, mail, loot and profession sections. Prices come from GoldPilot's own auction observations.

> Early version. It has not yet been verified in game.

---

# 0.2.0 (2026-11-24) — Español

### Añadido
- GoldPilot registra el banco al abrirlo y encola objetos seguidos, bolsas y banco actuales, y bolsas y bancos guardados de otros personajes para observar precios de subasta.
- Al pasar el cursor con la subasta abierta, se prioriza una consulta si la observación tiene al menos diez minutos. La última sesión queda registrada en `GoldPilotDB.ahLast`.

### Cambiado
- Las claves de casa usan solo la facción y las claves de personaje solo el nombre. La migración 2 combina las claves anteriores.
- El diagnóstico renueva sus datos sin borrar las secciones guardadas de subasta, correo, botín y profesiones. GoldPilot obtiene precios de sus propias observaciones de subasta.

> Versión temprana. Aún no se ha verificado en juego.
