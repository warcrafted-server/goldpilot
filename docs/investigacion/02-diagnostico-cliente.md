# Diagnóstico del cliente: correo de subasta (Forever 1.60.1, 2026-11-24)

Observado con `/gp diag` (sección `GoldPilotDB.diag.correos`, por personaje) en el buzón de personajes reales de la Alianza.

## Tipos de correo de la casa de subastas

Remitente «Casa de subastas de la Alianza» (por facción). El asunto distingue el caso:

| Asunto | Significado | Adjuntos | `money` de la cabecera | Factura (`GetInboxInvoiceInfo`) |
|---|---|---|---|---|
| `Subasta lograda: <objeto> (<cantidad>)` | Venta confirmada | ninguno | dinero neto cobrable | `seller` |
| `Subasta ganada: <objeto>` | Compra | el objeto | 0 | `buyer` |
| `Subasta terminada: <objeto>` | Sin vender, objeto devuelto | el objeto | 0 | vacía |

El asunto está localizado (esES): para otros idiomas habrá que apoyarse en el tipo de factura y en `money`/adjuntos, no en el texto.

## Factura (cliente moderno)

`GetInboxInvoiceInfo(i)` devuelve: tipo (`"seller"`/`"buyer"`), nombre del objeto, comprador (nil en las tres muestras revisadas), precio total, un número que coincide con la cantidad (en el juego actual ahí va la compra directa: sin explicar), depósito, comisión, tres campos a 0, cantidad y un booleano. Comprobado con seis correos:

- Venta de 23 Flor de paz: precio 3036, depósito 46, comisión 151, cobrable 2931 = 3036 + 46 − 151 (coincide con `money` y con la ventana del correo).
- Las otras cuatro ventas cuadran igual (precio/depósito/comisión → cobrado): 765/69/38 → 796; 841/58/42 → 857; 294/18/14 → 298; 536/8/26 → 518.
- **Comisión = 5 %** del precio, redondeada hacia abajo (151/3036, 38/765), como se suponía.
- El depósito vuelve al vendedor cuando se vende.
- La factura llega **sin abrir** cada correo: solo se abrió uno y las seis venían completas. Basta con abrir el buzón.

## Consecuencias

- El libro de operaciones puede registrar ventas, compras y devoluciones sin leer el chat, con precio bruto, depósito y comisión reales.
- `GetAuctionHouseCut` no existe en este cliente: el 5 % se mantiene como valor supuesto, ahora confirmado por las facturas.
- Pendiente: correos de subastas **caducadas** o **canceladas** (no observados) y el botín/nodos de recolección.
