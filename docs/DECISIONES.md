# Decisiones técnicas

Registro breve de las decisiones importantes: contexto, decisión, alternativas descartadas. Estado: **propuesta** (pendiente de tu revisión), **aceptada** o **sustituida**.

## D1. Ser una capa de decisión, no otro escáner de precios — aceptada (2026-11-26)

- **Contexto:** TSM (con app de escritorio), Auctionator y una decena de contadores de oro/hora ya funcionan en Forever.
- **Decisión:** GoldPilot se centra en recomendar, explicar y medir el beneficio real; obtiene precios de sus propias observaciones y de su aplicación opcional.
- **Actualización (2026-11-24):** a petición del autor se hace escaneo completo al abrir la subasta (30-40 s, límite de 15 min), como fuente de datos propia; la diferencia sigue siendo la recomendación.
- **Aceptada (2026-11-26):** la función principal es decir qué es lo mejor en cada momento para ganar el máximo oro. El escaneo es el medio. Las herramientas de subasta (vender, mis subastas, comprar) entran para poder prescindir de Auctionator, siempre al servicio del consejo.

## D2. Clase de dato obligatoria en cada cifra — aceptada (2026-11-26)

- **Decisión:** `GAME`, `OBS`, `REG`, `CONF`, `EXT`, `EST` (ARQUITECTURA §4). La interfaz siempre la muestra.
- **Por qué:** es tu requisito explícito y la principal diferencia frente a la competencia.
- **Aceptada con cambio (2026-11-26):** por dentro se mantienen las seis clases; al jugador solo se le muestran tres etiquetas: «confirmado» (CONF), «observado» (OBS, GAME, REG, EXT) y «estimado» (EST).

## D3. Venta confirmada = factura del correo — aceptada (2026-11-26)

- **Decisión:** solo `GetInboxInvoiceInfo` (o equivalente verificado) produce ventas `CONF`. Publicar es `REG`; desaparecer de la subasta no es vender.
- **Riesgo:** si el jugador no abre el buzón, las ventas quedan pendientes; la interfaz lo indica («3 ventas sin recoger del buzón»).

## D4. Arquitectura y convenciones de LoreWake — aceptada (2026-11-26)

- **Decisión:** misma separación Core/State/Engine/UI, sin librerías, módulos con capacidades, traducciones por claves y pruebas con `lupa`.
- **Por qué:** ya está probada en el cliente de Forever, la conoces y reduce el riesgo.
- **Descartado:** Ace3 (más código de terceros y licencias) y una arquitectura nueva sin justificación.
- **Aceptada (2026-11-26):** sin Ace3, pero adoptando sus buenas ideas con código propio escrito desde cero, sin copiar su código: temporizadores cancelables (`Core/Timer.lua`), mensajes internos `GOLDPILOT_` en `Core/Events.lua` y ajustes declarativos (pendiente).

## D5. Addon en la raíz del repositorio — aceptada (2026-11-25)

- **Decisión:** el addon vive en la raíz (`GoldPilot.toc`, `Core/`, `UI/`…), como FishForever, PocketBank y BestIcon; `.pkgmeta` excluye con `ignore` lo que no es del addon. Si llega la aplicación, irá en su propia carpeta ignorada por `.pkgmeta` o en otro repositorio.
- **Sustituye a:** addon en la subcarpeta `GoldPilot/` con `move-folders`, distinto de los demás addons y sin probar en el empaquetador.

## D6. Canal con la aplicación: SavedVariables + addon de datos — aceptada (2026-11-26)

- **Decisión:** juego → app leyendo SavedVariables; app → juego escribiendo `GoldPilot_Market`. Asíncrono, sin captura de pantalla.
- **Descartado:** canal de píxeles en tiempo real (AskForever): innecesario para datos económicos y con más superficie de seguridad.
- **Aceptada (2026-11-26):** el precio del momento sale en vivo del juego (escaneo y consultas). La aplicación aporta el historial, la mediana regional y las tendencias, que se cargan al entrar. GoldPilot tendrá un botón «Actualizar precios» que recarga la interfaz (lo añadiremos cuando exista la aplicación). El canal de píxeles solo sirve del juego a la aplicación y se reserva para cuando haga falta tiempo real en ese sentido.

## D7. Aplicación en Python — aceptada (2026-11-26)

- **Decisión:** Python, como `wowdata`, las herramientas de LoreWake y AskForever (empaquetado con PyInstaller ya resuelto allí).
- **Descartado:** Node/Electron (más pesado) y una web pública (los datos del jugador son locales y privados).

## D8. Sin temporizadores de reaparición de nodos — aceptada (2026-11-26)

- **Decisión:** se sustituye por densidad observada por zona.
- **Por qué:** con muchos jugadores por capa, la observación propia no predice la reaparición; sería una cifra falsa.

## D9. Historial compacto con poda — propuesta

- **Decisión:** diario 90 días, semanal hasta 52 semanas, cadenas empaquetadas; sin escaneos en bruto en SavedVariables. El historial largo es de la aplicación.
- **Por qué:** tiempo de carga y tamaño de SavedVariables.

## D10. Precio de referencia = mediana de las primeras unidades — propuesta

- **Decisión:** `p50` de las unidades que cubren el 15 % de la oferta (ajustable), además del mínimo.
- **Por qué:** el mínimo se manipula con un anuncio de una unidad; la mediana completa refleja anuncios que nadie compra.

## D11. Nodos: lo observado manda, `wowdata` es semilla — aceptada (2026-11-23)

- **Contexto:** muchos nodos de `v_nodo_zona` vienen de Classic y pueden no existir (o estar en otras zonas) en Forever.
- **Decisión:** cada par zona + tipo de nodo tiene origen `seed` (exportado de `wowdata`) u `obs` (visto en juego al recolectar). Las semillas sirven solo para rellenar al principio y se muestran como «sin confirmar».
  - Una semilla vista en juego pasa a `obs`.
  - Una semilla se **descarta** cuando el jugador ha recolectado bastante en esa zona con esa profesión sin encontrarla nunca (por defecto: 20 nodos de la profesión recogidos en la zona, configurable en `Engine/Weights.lua`).
  - Lo observado nunca se borra por esta regla; solo se aplica a lo exportado de `wowdata`.
  - Los descartes y confirmaciones se guardan en SavedVariables, encima del archivo generado (que no se modifica en juego).
  - Lo observado vuelve a `wowdata` (como ya hace con LoreWake y FishForever) y en la siguiente generación de datos sustituye a la semilla.
- **Descartado:** fiarse de los datos de Classic, o no usar semilla (el asesor estaría vacío hasta recolectar mucho).

## D12. Precios regionales para la aplicación: de dónde salen — pendiente

- **Contexto:** la API web de Blizzard da todas las casas de Forever, pero hace falta una credencial de desarrollador de Battle.net (cliente gratuito: identificador y secreto).
- **Opciones:**
  - **A. Cada usuario su credencial:** sin servidor ni coste; requiere que cada jugador la cree (unos minutos); cada uno acepta los términos de Blizzard.
  - **B. Servidor propio (tu VPS) con una credencial:** el usuario no configura nada; implica mantener un servicio y revisar si los términos permiten redistribuir los datos.
  - **C. Sin API:** la aplicación solo analiza lo que el jugador observa (historial largo, libro, informes).
- **Recomendación:** la aplicación funciona en modo C sin configurar nada y ofrece A como opción avanzada; B solo tras revisar los términos y si hay demanda.

## D13. Archivos de agentes fuera del repositorio — aceptada (2026-11-23)

- **Decisión:** `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.agentrelay/` y `.claude/` en `.gitignore`. El commit inicial de AgentRelay se rehace para que no queden en el historial (el remoto aún está vacío).

## D14. Sin dependencias de otros addons de precios — aceptada (2026-11-24)

- **Contexto:** el jugador puede no tener Auctionator ni TSM instalados.
- **Decisión:** GoldPilot obtiene precios mediante sus propias consultas y observaciones de la subasta.
- **Descartado:** leer precios de Auctionator o TSM.


## D15. Objetos solo del juego — aceptada (2026-11-24)

- **Contexto:** wowdata no incluía objetos reales de Forever (2973, 9747).
- **Decisión:** se descarta la lista de objetos generada. Los objetos salen solo del juego: subasta, bolsas, banco y equipo. Las semillas de nodos de D11 continúan generándose desde wowdata.

## D16. Rutas de recolección — aceptada (2026-11-24)

- **Contexto:** la propuesta las descartaba porque Gatherer Reforged y GatherMate ya muestran nodos.
- **Decisión:** GoldPilot propone un circuito por zona ordenado por oro por hora con los precios observados y la habilidad del jugador. Las posiciones propias mandan; las de wowdata solo son semilla (D11) y no se publican hasta revisar si su licencia permite redistribuirlas.
- **Límite:** no se conoce el terreno (montañas, agua, enemigos): la ruta es orientativa y se corrige con el recorrido real.
- **Descartado:** copiar rutas o imágenes de guías de terceros.

## D17. Asistente: «qué hago ahora» es el centro — aceptada (2026-11-24)

- **Decisión:** la pestaña principal será «Ahora»: una lista corta de acciones ordenadas por oro por hora o por ganancia, cada una con su porqué y su confianza. Las demás pestañas (Inventario, Libro, Rutas) la alimentan.
- **Orden:** primero lo que ya se puede aconsejar con datos (vender, recoger correo, reservar), y se amplía según haya sesión de recolección y rutas.
