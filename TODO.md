# TODO

## Alta

- [ ] Rotación en Gangas, calculada dentro del addon: tus ventas y devoluciones por objeto, unidades en venta y salidas estimadas entre escaneos.
- [ ] Probar en juego: Comercio, ventas a vendedor, «Cancelar» en Mis subastas y quitar objetos de Mi lista.
- [ ] Mi lista: los nombres salen centrados; alinearlos a la izquierda.

## Media

- [ ] Rutas por valor y nivel de profesión, terreno recorrido y grabar la ruta propia.
- [ ] Diagnóstico pendiente en juego: botín de mineral y correos de subastas canceladas a mano.
- [ ] Probar la casa de subastas neutral.
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
- Rotación estimada con la API de Blizzard y un recolector en un VPS: haría depender el addon de un servidor privado y no serviría a quien lo descargue.
