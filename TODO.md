# TODO

## Bloqueante: decisiones del autor

- [ ] Pasar las decisiones «propuesta» de [docs/DECISIONES.md](docs/DECISIONES.md) a «aceptada» o cambiarlas.
- [ ] D12: de dónde saca la aplicación los precios regionales (credencial propia de Battle.net, servidor propio o sin API).

## Media: coordinación con otros proyectos (requiere permiso para tocarlos)

- [ ] PocketBank: acordar una API pública mínima (existencias por personaje) para que GoldPilot no duplique datos, y que PocketBank pueda mostrar valores de GoldPilot.
- [ ] wowdata: importar los nodos observados por GoldPilot (`importar_obs.py`) para sustituir las semillas de Classic.

## Bloqueante antes de publicar la 0.3.0 (pruebas en juego, 2026-11-24)

- [ ] Ventana de Inventario con mala presentación: lista estrecha, barra de desplazamiento suelta y fondo casi transparente; rediseñar maquetación y fondo.
- [ ] Botones Reservar/Seguir y ficha de detalle: no se ven al abrir (ficha vacía hasta elegir fila); comprobar solapes.
- [ ] Filtro: el texto de ayuda («Filtrar por nombre») cuenta como búsqueda real y vacía la lista; tras borrar el filtro vuelve a salir todo, bien. Usar texto de ayuda atenuado que no filtre.
- [ ] «Seguir» no tiene efecto visible (solo prioriza la cola de subasta): marcar con estrella en la lista, filtro «Seguidos» y explicarlo en la ficha.
- [ ] Botón del minimapa: se puede arrastrar hacia dentro y fuera del anillo (debe quedarse sobre el borde del minimapa) y usa el icono antiguo; regenerar `Media/Icon.tga` con el logo nuevo.
- [ ] Comprobar en juego fuera de ciudad: no se abre ni redibuja en combate.
- [ ] Comprobado y correcto: tooltip, aviso al terminar la cola, precios tras `/reload`, valor de bolsas, métricas, reservar, `/gp diag` (21 presentes, 2 ausentes esperadas), SavedVariables 24 KB con 44 objetos.

## Alta: 0.1.0

- [ ] Comprobar la versión 0.1.0 en juego (ver [docs/COMPROBACIONES.md](docs/COMPROBACIONES.md)).

## Media

- [ ] 0.2.0: asistente de venta y libro de operaciones.
- [ ] 0.3.0: verificar en juego la pestaña Inventario (ver [docs/COMPROBACIONES.md](docs/COMPROBACIONES.md)).
- [ ] Precio externo opcional: no se usa Auctionator ni TSM; solo se revisará más adelante si hay demanda.
- [ ] Probar la API web de Blizzard para Forever (rutas, frecuencia, términos de uso).

## Descartado

- Tiempos de reaparición de nodos: la observación propia no los predice con muchos jugadores por capa (D8).
- Escaneo completo periódico en juego: limitado por el servidor y ya cubierto por TSM y Auctionator.
- Automatizar acciones de subasta: requiere clic del jugador y rozaría las normas.
- Rutas de recolección dibujadas: ya las ofrecen Gatherer Reforged y GatherMate; GoldPilot recomienda la zona.
- Base de precios empaquetada en el addon: datos viejos presentados como actuales.
