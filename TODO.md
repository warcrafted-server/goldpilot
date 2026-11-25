# TODO

## Alta: antes de la primera publicación

- [ ] Probar en juego la 0.15.3 y las casillas imprescindibles de [docs/COMPROBACIONES.md](docs/COMPROBACIONES.md).
- [ ] Revisar la licencia de los datos de wowdata de [NodeSeeds.lua](GoldPilot/Data/Generated/NodeSeeds.lua), ya publicados en el repositorio.
- [ ] Comprobar el secreto CF_API_KEY en GitHub, completar la ficha de CurseForge con capturas y, con aprobación expresa, crear el tag.

## Media

- [ ] Asistente de venta en la subasta (requiere antes un diagnóstico de la ventana de subasta en juego).
- [ ] Diagnóstico pendiente en juego: botín de mineral y correos de subastas canceladas a mano.
- [ ] PocketBank: acordar una API pública mínima (existencias por personaje) para que GoldPilot no duplique datos, y que PocketBank pueda mostrar valores de GoldPilot (requiere permiso para tocarlo).
- [ ] wowdata: importar los nodos observados por GoldPilot (`importar_obs.py`) para sustituir las semillas de Classic (requiere permiso para tocarlo).

## Pendiente de decisión del autor

- [ ] Pasar las decisiones «propuesta» de [docs/DECISIONES.md](docs/DECISIONES.md) a «aceptada» o cambiarlas.
- [ ] D12: de dónde saca la aplicación los precios regionales (credencial propia de Battle.net, servidor propio o sin API).

## Baja: tras D12

- [ ] Aplicación de escritorio que descargue los precios actuales con la API web y los deje en SavedVariables (el addon no puede hacer peticiones web); el tooltip pasaría a «Vendedor, precio actual (API) y mediana», con su propia clase de dato.
- [ ] Probar la API web de Blizzard para Forever (rutas, frecuencia, términos de uso).
- [ ] Precio externo opcional: no se usa Auctionator ni TSM; solo se revisará más adelante si hay demanda.

## Descartado

- Tiempos de reaparición de nodos: la observación propia no los predice con muchos jugadores por capa (D8).
- Escaneo de resumen como el de Auctionator: el completo da también la mediana, en 30-40 s sin tirones.
- Automatizar acciones de subasta: requiere clic del jugador y rozaría las normas.
- Base de precios empaquetada en el addon: datos viejos presentados como actuales.
