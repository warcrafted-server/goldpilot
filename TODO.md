# TODO

## Bloqueante: decisiones del autor

- [ ] Pasar las decisiones «propuesta» de [docs/DECISIONES.md](docs/DECISIONES.md) a «aceptada» o cambiarlas.
- [ ] D12: de dónde saca la aplicación los precios regionales (credencial propia de Battle.net, servidor propio o sin API).

## Media: coordinación con otros proyectos (requiere permiso para tocarlos)

- [ ] PocketBank: acordar una API pública mínima (existencias por personaje) para que GoldPilot no duplique datos, y que PocketBank pueda mostrar valores de GoldPilot.
- [ ] wowdata: importar los nodos observados por GoldPilot (`importar_obs.py`) para sustituir las semillas de Classic.

## Alta: 0.1.0

- [ ] Comprobar la versión 0.1.0 en juego (ver [docs/COMPROBACIONES.md](docs/COMPROBACIONES.md)).

## Media

- [ ] 0.2.0: asistente de venta y libro de operaciones.
- [ ] 0.3.0: sesiones y asesor de recolección.
- [ ] Precio externo opcional: no se usa Auctionator ni TSM; solo se revisará más adelante si hay demanda.
- [ ] Crear la ventana principal.
- [ ] Probar la API web de Blizzard para Forever (rutas, frecuencia, términos de uso).

## Descartado

- Tiempos de reaparición de nodos: la observación propia no los predice con muchos jugadores por capa (D8).
- Escaneo completo periódico en juego: limitado por el servidor y ya cubierto por TSM y Auctionator.
- Automatizar acciones de subasta: requiere clic del jugador y rozaría las normas.
- Rutas de recolección dibujadas: ya las ofrecen Gatherer Reforged y GatherMate; GoldPilot recomienda la zona.
- Base de precios empaquetada en el addon: datos viejos presentados como actuales.
