# Comprobaciones manuales en juego — 0.7.0

- [ ] GoldPilot carga sin errores.
- [ ] `/gpilot version` muestra `0.7.0`.
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
