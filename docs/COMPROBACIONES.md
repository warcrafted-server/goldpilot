# Comprobaciones manuales en juego

## Imprescindibles antes de la primera publicación

Con `GoldPilotDev` activo:

- [ ] Carga sin errores de Lua y `/gpilot version` muestra la 0.15.4.
- [ ] Tooltip: precio de vendedor, precio de subasta con su antigüedad y, con Mayús, el detalle.
- [ ] Subasta: el escaneo completo arranca y termina; al reabrir antes de 15 min no lo repite.
- [ ] Ahora: aparecen las tarjetas, seis caben sin tocar el borde y el selector de ámbito responde.
- [ ] Inventario: lista, selectores oscuros, barra de desplazamiento, Reservar y Seguir.
- [ ] Libro: las operaciones aparecen tras abrir el buzón y reabrirlo no las duplica.
- [ ] Sesión: al recoger sale el panel, suma una sola vez y pasa a pausa a los 3 min.
- [ ] Zonas: crear y quitar una ruta; se ve en el mapa y sigue alineada con el zoom.
- [ ] Ajustes: los textos caben en su columna y las casillas responden.
- [ ] En combate no se abre ni redibuja nada.
- [ ] `/reload` conserva precios, libro y sesiones.

Con el paquete publicable (`python tools/empaquetar.py`, descomprimir `dist/GoldPilot-0.15.4.zip` en `AddOns` y desactivar `GoldPilotDev`):

- [ ] Carga sin errores y, sin nodos propios, crear una ruta avisa sin fallar.
- [ ] Capturas para CurseForge: tooltip, Ahora, Inventario, Libro y Zonas con la ruta.

## Lista completa

- [ ] GoldPilot carga sin errores.
- [ ] `/gpilot version` muestra la versión del archivo `VERSION`.
- [ ] Abrir Inventario con `/gpilot` y con clic izquierdo en el minimapa.
- [ ] Cambiar entre Personaje actual y Toda la cuenta.
- [ ] Filtrar objetos por nombre y comprobar la lista.
- [ ] Seleccionar un objeto, reservarlo y dejar de reservarlo; Mayús reserva una unidad.
- [ ] Seguir un objeto y dejar de seguirlo.
- [ ] Revisar las métricas de mejor venta, todo al vendedor, objetos sin precio y datos viejos.
- [ ] Sin objetos, la ventana muestra un estado vacío claro; sin precios, invita a abrir la subasta.
- [ ] No aparecen errores de Lua al abrir, filtrar, reservar o seguir.
- [ ] La ventana no se abre ni redibuja en combate.
- [ ] `/gpilot diag` genera el diagnóstico sin errores.
- [ ] El botón del minimapa aparece, se puede mover y sus clics funcionan; `/gpilot minimap` lo muestra y oculta.
- [ ] Abrir la subasta encola consultas y, al terminar, aparece el aviso `Subasta: N objetos leídos`.
- [ ] Un objeto compatible sin observación muestra el precio de vendedor y que no hay precio de subasta observado.
- [ ] Un objeto compatible con observación muestra el precio de subasta, su antigüedad y la recomendación.
- [ ] Mantener Mayús en el tooltip muestra el detalle adicional de la observación.
- [ ] `/gpilot bags` muestra las valoraciones de vendedor, subasta neta y mejor combinación.
- [ ] El addon no realiza acciones ni crea elementos de interfaz en combate.
- [ ] `/reload` conserva los precios observados.
- [ ] Tras abrir la subasta, ejecutar `/reload` y revisar `GoldPilotDB.ahLast`.
- [ ] El tamaño de las SavedVariables resulta razonable tras usar el addon.

## 0.3.2

- [ ] `/gpilot watch` con un enlace de objeto (Mayús+clic desde la bolsa con el chat abierto) lo sigue; repetido, lo deja de seguir.
- [ ] En la subasta, el chat muestra «Subasta: N/M objetos» cada 10 objetos.
- [ ] El tooltip con Mayús muestra «en venta» y la variación de la mediana (necesita datos de un día anterior).

## 0.4.0

- [ ] Con la casilla de escaneo completo activada en Ajustes, al abrir la subasta el chat dice «Escaneo completo…» y después «Escaneo completo: N objetos…»; `/gpilot scan` antes de 15 min avisa del límite. Si no devuelve datos, vuelve a la cola por objetos.
- [ ] Tras el escaneo, el tooltip de objetos que no estaban en las bolsas muestra precio reciente; el tamaño de `GoldPilotDev.lua` tras un escaneo completo (se guardan todos los objetos con ofertas, decenas de miles; anotar el tamaño y el tiempo de carga al entrar).
- [ ] Una búsqueda a mano en la subasta actualiza el «último visto» del objeto.
- [ ] El tooltip se ve ordenado en dos columnas (cabecera GoldPilot con antigüedad, Vendedor, Último visto, Mediana, Mejor opción); con Mayús añade En venta y Tendencia.
- [ ] Ajustes: cada casilla de línea del tooltip la muestra u oculta; la del escaneo completo lo desactiva.
- [ ] Buzón: abrir el buzón con una compra y con una devolución, `/reload`, y revisar `GoldPilotDB.diag.mail.cabeceras`.

## 0.5.0

- [x] Abrir el buzón con facturas de venta y compra; comprobar el aviso de registros nuevos y `GoldPilotDB.ledger`.
- [x] Reabrir el buzón no duplica operaciones (2026-11-24, totales comprobados con las seis facturas).
- [x] Con el buzón abierto un rato y tras `/reload` tampoco se duplican (2026-11-24).
- [x] Las dos devoluciones de Charman se registran (2026-11-24).
- [x] Reabrir el buzón de Charman no repite las devoluciones.
- [x] Al abrir la subasta arranca el escaneo completo (33 s, 7140 objetos); al reabrir antes de 15 min no hay cola de objetos ya leídos.
- [ ] `/gpilot ledger` muestra el resumen de 30 días y representa los balances negativos con signo menos.
- [ ] El buzón no escribe registros en combate ni en modo seguro.

## 0.6.0

- [ ] Tras cargar datos de esquema 2, la migración conserva el historial de consumibles, elimina las variantes antiguas de equipo y mantiene los datos desconocidos.
- [ ] Al observar variantes de equipo diferentes, cada una conserva su precio por bonus.

## 0.6.1

- [x] El escaneo y las búsquedas de equipo registran cada variante por separado.
- [x] El tooltip de cada variante muestra su propio precio.
- [ ] La poda del historial se ejecuta al entrar, fuera de combate.
- [ ] Tras usar el almacén, el tamaño de SavedVariables permanece por debajo del presupuesto esperado.

## 0.7.0

- [ ] Los precios de vendedor se obtienen del cliente incluso para objetos nunca vistos.
- [ ] Las variantes de equipo aparecen por separado en bolsas y banco.
- [ ] Los objetos ligados muestran su precio de vendedor y nunca recomiendan subasta.


## 0.8.0

- [ ] La versión 0.8.0 coincide en VERSION, TOC y README.
- [ ] Los objetos salen del juego; wowdata genera solo semillas de nodos.
- [ ] Un objeto nunca visto con precio de subasta aparece en tooltip e inventario.
- [ ] Los objetos ligados al recoger y de misión no se encolan; objetos sin datos sí.

## 0.9.0

- [ ] `/gpilot` abre la pestaña Ahora con métricas, tarjetas y ficha.
- [ ] Sin precios, Ahora invita a abrir la casa de subastas; con datos pero sin consejos muestra el estado vacío.
- [ ] Seleccionar consejos conserva la selección al refrescar y selecciona la primera tarjeta si desaparece.
- [ ] Ver en Inventario abre Inventario desde consejos de subasta, vendedor y otros sitios.
- [ ] Las tarjetas de correo, tendencias y actualización muestran sus detalles.
- [ ] La ventana no se redibuja durante el combate.

## 0.10.0

- [ ] Ahora permite alternar entre el personaje actual y toda la cuenta, y recuerda el ámbito por personaje.
- [ ] El ámbito de personaje excluye correo y objetos de otros personajes, pero conserva el banco propio.
- [ ] Los títulos largos de las tarjetas permanecen en una línea.

## 0.11.0

- [ ] El Libro muestra ventas, compras y devoluciones por objeto y actualiza sus métricas al cambiar el periodo.
- [ ] Alternar entre personaje actual y toda la cuenta conserva el ámbito por personaje.
- [ ] Seleccionar un objeto muestra sus operaciones recientes y balances por personaje.
- [ ] El Libro muestra un texto claro cuando no hay registros o cuando no existen operaciones para el periodo.
- [ ] La ventana no crea ni redibuja elementos del Libro durante el combate.

## 0.12.0

- [ ] `/gpilot` y `/goldpilot` abren la ventana, y el comando de grupo del juego vuelve a hablar al grupo.

## 0.13.0

- [ ] El panel aparece al recoger y no duplica botín (una hierba recogida suma solo una vez).
- [ ] El panel se mueve y recuerda el sitio.
- [ ] El panel se oculta con la cruz, con el ajuste y con `/gpilot hud`.
- [ ] El panel pasa a pausa a los 3 min.
- [ ] `/gpilot session` y `/gpilot session end` responden.
- [ ] Tras 20 min activos aparece la zona en Ahora.
- [ ] Nada cambia en combate.
- [ ] Los nodos con posición están en `GoldPilotDB.nodes` tras `/reload`.

## 0.14.0

- [ ] La pestaña Zonas aparece entre Libro y Ajustes.
- [ ] Se alterna entre Zonas y Sesiones y entre Hierbas y minerales, Hierbas y Minerales.
- [ ] Crear ruta la activa y Quitar ruta la limpia.
- [ ] La ruta se ve solo en su mapa.
- [ ] La ruta sigue alineada al hacer zoom en el mapa del mundo.
- [ ] Nada se crea ni se redibuja en combate.
- [ ] Sin puntos con precio, crear ruta avisa y no da errores.

## 0.15.0

- [ ] La ruta avanza de parada al llegar y la siguiente se resalta en verde.
- [ ] TomTom marca una sola parada y la mueve al cambiar la siguiente; la casilla de Ajustes la activa y la desactiva.
- [ ] Quitar ruta limpia el punto de TomTom.
- [ ] Tras visitar paradas con y sin nodo, `/reload` y revisar que `GoldPilotDB.routeVisits` guarda visitas y aciertos.
- [ ] En vuelo o muerto no se registran visitas.
- [ ] Nada se crea ni se redibuja en combate; el punto de TomTom se marca al salir.

## 0.15.1

- [ ] La ruta se ve sobre el arte del mapa, encima de las chinchetas, sin quedar tapada y sin errores de Lua.
- [ ] Con un mapa unido abierto, la ruta aparece dentro del rectángulo de su mapa dentro del mapa mostrado.
- [ ] Al alejar el mapa hasta que la ruta ocupe una franja estrecha, los puntos se ven más pequeños y sin números.
- [ ] Abrir el mapa con la ruta activa la dibuja aunque el lienzo tarde en tener tamaño (un solo reintento, sin bucle).
- [ ] `/gpilot route` imprime una línea con el estado y no falla sin el mapa del mundo abierto; `GoldPilotDB.diag.route` guarda el estado.

## 0.15.2

- [ ] Listas de Inventario, Libro y Zonas: icono, fondo alterno, selección dorada y nombres largos recortados sin pisar el importe.
- [ ] Al reordenarse la lista, la fila resaltada es la de la ficha.
- [ ] Libro: las ventas muestran icono tras un escaneo completo (o antes, si el objeto está en bolsas).
- [ ] Ahora: la ficha de correo lista los correos; con correo solo de objetos la confianza queda alineada a la izquierda.

## 0.15.3

- [ ] Los selectores oscuros muestran su texto y la flecha, y cambian al pulsarlos (Ahora, Inventario, Libro y Zonas).
- [ ] En Ahora, seis tarjetas caben sin tocar el borde inferior.
- [ ] La ficha y la lista tienen borde bronce; nada lo tapa ni lo pisa.
- [ ] La barra de desplazamiento sale en Inventario con muchos objetos y se oculta en Zonas.
- [ ] Ajustes: los textos caben en su columna y las casillas responden.
- [ ] «Subasta del banco» con un objeto dice «visto hace…».
