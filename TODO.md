# TODO

## Bloqueante: decisiones del autor

- [ ] Pasar las decisiones «propuesta» de [docs/DECISIONES.md](docs/DECISIONES.md) a «aceptada» o cambiarlas.
- [ ] D12: de dónde saca la aplicación los precios regionales (credencial propia de Battle.net, servidor propio o sin API).

## Media: coordinación con otros proyectos (requiere permiso para tocarlos)

- [ ] PocketBank: acordar una API pública mínima (existencias por personaje) para que GoldPilot no duplique datos, y que PocketBank pueda mostrar valores de GoldPilot.
- [ ] wowdata: importar los nodos observados por GoldPilot (`importar_obs.py`) para sustituir las semillas de Classic.

## Bloqueante antes de publicar la 0.3.0 (pruebas en juego, 2026-11-24)

- [ ] Verificar en juego los arreglos de la 0.3.1: lista ancha con fondo opaco, ficha con botones siempre visibles, filtro con texto de ayuda, estrella y filtro «Solo seguidos», botón del minimapa pegado al borde con el icono nuevo.
- [ ] Comprobar en juego fuera de ciudad: no se abre ni redibuja en combate.
- [ ] Comprobado y correcto: tooltip, aviso al terminar la cola, precios tras `/reload`, valor de bolsas, métricas, reservar, `/gp diag` (21 presentes, 2 ausentes esperadas), SavedVariables 24 KB con 44 objetos.

## Alta: precios por variante (ver el plan, pasos A y B)

- [ ] El equipo con sufijo («del oso»…) comparte un solo precio por objeto: las variantes se mezclan y su mediana no es fiable.
- [ ] Escaneo de resumen como el de Auctionator (sin `ReplicateItems`), aprovechando el suyo si ya está en marcha.

## Media: escenario con API de Blizzard (tras D12)

- [ ] Aplicación de escritorio que descargue los precios actuales con la API web y los deje en SavedVariables (el addon no puede hacer peticiones web); el tooltip pasaría a «Vendedor, precio actual (API) y mediana», con su propia clase de dato.
- [ ] Afinado visual final del tooltip y de la ventana con Opus, cuando todo esté hecho.
- [ ] Diagnóstico pendiente en juego: botín y nodos de recolección (`/gp diag`) y correos de subastas caducadas o canceladas.

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
