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
