# GoldPilot Forever: propuesta de producto

Versión 1 de la propuesta, 2026-11-23. Basada en [investigacion/01-api-y-mercado.md](investigacion/01-api-y-mercado.md). El diseño técnico está en [ARQUITECTURA.md](ARQUITECTURA.md) y las decisiones razonadas en [DECISIONES.md](DECISIONES.md).

## 1. Visión y ventajas

**GoldPilot es un piloto, no un escáner.** Consultar precios y contar oro por hora ya lo hacen TSM, Auctionator y una decena de contadores de recolección en Forever. GoldPilot se sitúa una capa por encima: usa los precios que observa por sí mismo y, opcionalmente, los datos de su aplicación, y responde a tres preguntas con una explicación corta y un grado de confianza visible:

1. **¿Qué hago ahora para ganar oro?** (recolectar dónde, vender qué, fabricar qué).
2. **¿Qué hago con lo que tengo?** (vender en subasta, al vendedor o conservar).
3. **¿Estoy ganando dinero de verdad?** (beneficio con ventas confirmadas, no con estimaciones).

Ventajas frente a lo existente:

- **Honestidad del dato como seña de identidad.** Cada cifra lleva su clase: observada, registrada, confirmada, externa o estimada (ver ARQUITECTURA §4). Una estimación nunca se presenta como hecho. Nadie en Forever lo hace.
- **Valor realizable, no valor teórico.** El oro/hora de una sesión pondera cada material por lo que de verdad se puede vender (liquidez, cantidad en venta, comisión y depósito), no por el precio mínimo listado.
- **Contabilidad real** a partir de las facturas del correo de la subasta: compras, ventas, comisiones, depósitos perdidos y objetos que no se venden.
- **Asesor de recolección que aprende del juego**: arranca con una semilla de nodos por zona (`wowdata`, en buena parte heredada de Classic) y la corrige con lo que el jugador recolecta de verdad en Forever.
- **Autosuficiente:** no usa Auctionator ni TSM; el jugador puede no tenerlos instalados.
- **Castellano completo**, estética coherente con LoreWake y código abierto.

## 2. Arquitectura recomendada (resumen)

Un **addon autosuficiente** con la misma estructura probada en LoreWake (núcleo con detección de capacidades, colectores de estado, motor de recomendaciones con funciones puras, interfaz y traducciones por claves, sin librerías) y una **aplicación externa opcional** que nunca habla con el juego en tiempo real: lee los SavedVariables al cerrar sesión o hacer `/reload` y escribe un **addon de datos** aparte (`GoldPilot_Market`) que el addon principal carga si existe. Detalle y alternativas descartadas en [ARQUITECTURA.md](ARQUITECTURA.md) y [DECISIONES.md](DECISIONES.md).

## 3. Funcionalidades viables (núcleo del producto)

| Área | Funcionalidad | Por qué es viable | Fuente del dato |
|---|---|---|---|
| Precios | Línea en el tooltip de cualquier objeto: precio de vendedor, precio de subasta con su antigüedad y fuente, y una recomendación de una palabra (Subasta / Vendedor / Conservar) | `sellPrice` es un hecho del cliente; el precio de subasta se observa al abrir la subasta | Vendedor (hecho), observado, externo |
| Precios | Búsqueda dirigida al abrir la subasta: lo que llevas en bolsas, lo que sigues y los reactivos de tus recetas, respetando el límite de consultas | Evita el escaneo completo limitado | Observado |
| Precios | Historial compacto por objeto y día (mínimo, mediana de las primeras unidades, cantidad en venta) y tendencia simple | Tamaño acotado (ARQUITECTURA §5) | Observado, externo |
| Venta | **Asistente de venta** en la subasta: precio sugerido, suelo (precio de vendedor y coste de adquisición), aviso de guerra de subcotización («bajar 1 cobre no cambia tu posición; con esta cantidad en venta tardarás días») y beneficio neto tras comisión y depósito | Datos de la búsqueda + comisión del cliente | Observado + estimado |
| Contabilidad | Libro de operaciones: publicado, comprado, vendido (factura del correo), caducado, cancelado; beneficio por objeto y por periodo; objetos que no se venden | `GetInboxInvoiceInfo` y eventos de la subasta (por verificar) | Registrado, confirmado |
| Recolección | Sesión de recolección: materiales obtenidos, valor realizable y oro/hora con pausa por inactividad | Botín y su origen (`LOOT_READY`), sin depender de eventos de hechizos | Observado + estimado |
| Recolección | Asesor de zonas: para tu habilidad de minería, herboristería y desuello, qué zonas tienen nodos de tu rango y cuánto valen sus materiales hoy | Lo observado en juego manda; `wowdata` solo como semilla inicial, que se confirma o se descarta con lo observado (D11) | Observado + semilla + estimado |
| Inventario | Valor de bolsas y banco por personaje, qué vender ya y qué conservar (reactivos de tus recetas, objetos reservados por el usuario), aviso de espacio | `C_Container`; banco al visitarlo | Observado |
| Cuenta | Existencias y oro de todos tus personajes (los guardados al conectarse), con los datos de PocketBank si está instalado | SavedVariables de cuenta; API de PocketBank | Observado |
| Asesor | Pestaña «Ahora» con 3-5 recomendaciones ordenadas, cada una con su porqué, su beneficio estimado y su confianza | Motor de LoreWake adaptado | Estimado (explicado) |

## 4. Funcionalidades que requieren investigación

| Funcionalidad | Qué falta saber | Cómo se resuelve |
|---|---|---|
| Fabricación y rentabilidad de recetas | Las profesiones están rediseñadas en Forever; no se sabe qué da `C_TradeSkillUI` | Diagnóstico con la ventana de profesión abierta; `wowdata` como respaldo de recetas y reactivos |
| Identificar la casa de subastas actual (facción, neutral, ruleset) | No hay API conocida que lo diga | Diagnóstico; respaldo: PNJ subastador por zona + facción |
| Liquidez y demanda | Desde el juego no se ven las ventas ajenas. Con instantáneas sucesivas de la API web se puede estimar (lo que desaparece pudo venderse, caducar o cancelarse) | Solo en la aplicación, marcado como estimación |
| Precio externo opcional | Si hay demanda de fuentes adicionales | Revisar más adelante; GoldPilot no usa Auctionator ni TSM |
| Depósito exacto | Fórmula no publicada y cambiada en noviembre | Medirlo: el addon registra el depósito real que cobra el juego |
| API web de Blizzard para Forever | Sin documentación oficial; frecuencia de actualización; términos de uso sobre redistribución | Prueba técnica de la aplicación (roadmap 0.7) |
| Detección de nodos por el GUID del objeto | GUID parcialmente ofuscado | Diagnóstico al recolectar |

## 5. Funcionalidades que descarto (y por qué)

| Funcionalidad | Motivo |
|---|---|
| Tiempos de reaparición de nodos | En Forever hay muchos jugadores por capa y fases; un nodo desaparece porque otro lo recoge. Un temporizador basado en observaciones propias sería ruido presentado como dato. Se sustituye por «densidad observada por zona» (nodos vistos por hora) |
| Escaneo completo periódico dentro del juego | Limitado por el servidor y devuelve vacío; además TSM y Auctionator ya lo hacen. La visión completa del mercado viene de la aplicación |
| Cualquier automatización (publicar, comprar, cancelar en bloque sin clic) | Exige pulsación del jugador por diseño del juego y rozaría las normas. El asistente rellena precios; el jugador confirma cada acción |
| Alertas de chollos en tiempo real | Imposible sin escanear continuamente; la aplicación solo ve instantáneas |
| Base de precios propia empaquetada en el addon | Datos de días de antigüedad presentados como actuales; posible conflicto con los términos de la API. La aplicación la genera para cada usuario con su propia clave |
| Gráficas detalladas dentro del juego | Caras de dibujar y poco legibles en la interfaz del juego; en el juego basta una mini tendencia (subiendo, estable, bajando) y el detalle va a la aplicación |

## 6. Reparto entre addon y aplicación

| En el addon (siempre) | En la aplicación (opcional) |
|---|---|
| Precios observados por el jugador, tooltip, asistente de venta | Instantáneas completas de todas las casas de la región vía API web |
| Libro de operaciones y beneficio real | Historial largo (meses), volatilidad, liquidez estimada por desaparición de anuncios |
| Sesiones de recolección y asesor de zonas | Comparativas entre casas (facción frente a neutral), entre periodos y entre personajes |
| Inventario y existencias de la cuenta | Gráficas, exportación CSV, informes de beneficio |
| Asesor «Ahora» con lo que haya | Inyecta en el addon, a través de `GoldPilot_Market`, precios de mercado y liquidez estimada recientes, que el asesor usa marcados como **externos** |

Regla: si la aplicación no está, el addon funciona igual y simplemente tiene menos precios (los observados). Ninguna pantalla del addon depende de ella.

## 7. Interfaz y experiencia

Estética: la del Diario de aventuras que usa LoreWake (fondo marrón oscuro, filete dorado, títulos en amarillo Blizzard, texto hueso), con un acento propio de GoldPilot (oro y verde para beneficio, rojo apagado para pérdida). Se reutiliza el módulo de tema de LoreWake adaptado.

**Tres niveles de información:**

1. **En contexto, sin abrir nada** (nivel 0): una o dos líneas en el tooltip; un panel lateral discreto pegado a la ventana de subasta con el asistente de venta; un mini contador de sesión de recolección (oro/hora realizable) que se puede ocultar.
2. **Panel principal** (`/gp` o botón del minimapa), pestañas:
   - **Ahora**: franja de métricas (oro total de la cuenta, beneficio de los últimos 7 días confirmado, valor de inventario) y 3-5 recomendaciones con su porqué.
   - **Mercado**: buscador de objetos y lista de seguimiento; ficha del objeto con precio, tendencia, cantidad en venta, fuentes y antigüedad.
   - **Recolección**: zonas recomendadas para tus profesiones y sesiones pasadas.
   - **Inventario**: qué vender, qué conservar, existencias por personaje.
   - **Libro**: beneficio confirmado, operaciones, objetos lentos.
   - **Fabricación** (cuando se confirme la API).
   - **Ajustes**.
3. **Ficha de detalle** al pulsar cualquier fila (lista + ficha, como LoreWake): números completos, fuentes y por qué se recomienda.

**Indicadores de confianza**: un icono pequeño y un color por clase de dato (observado, confirmado, externo, estimado) y la antigüedad («hace 3 h»). Los precios de más de 48 h se muestran atenuados.

**Ajustes**: perfil del jugador (recolector, comerciante, mixto) que cambia los pesos del asesor; margen mínimo deseado; capital máximo a invertir; objetos reservados; módulos activables; idioma.

## 8. Almacenamiento y datos

Resumen (detalle en ARQUITECTURA §5): `GoldPilotDB` de cuenta con versión de esquema y migraciones; precios por casa y objeto en historial diario compacto (90 días, luego semanal hasta 1 año, con poda), libro de operaciones con rotación anual, sin guardar escaneos en bruto. Presupuesto objetivo: menos de 5 MB de SavedVariables para un jugador intensivo.

## 9. Pruebas y compatibilidad

- Pruebas fuera del juego con Lua 5.1 real (`lupa`) y simulación de la API, como LoreWake: motor, almacén de precios, migraciones, traducciones y empaquetado.
- Diagnóstico en juego (`/gp diag`) que comprueba cada capacidad y desactiva el módulo que la necesite si falta.
- Lista de comprobaciones manuales por versión (`docs/COMPROBACIONES.md`) antes de publicar: nada se publica como probado sin haberlo probado en juego.
- Compatibilidad: TOC con `## Interface: 16001`; versión del esquema de datos separada de la del addon.

## 10. Roadmap

Cada versión publicada aporta algo útil y probado en juego. Lo marcado «interno» no se publica.

| Versión | Entregable | Publicable |
|---|---|---|
| 0.0.1 | Esta documentación | No (solo repositorio) |
| 0.0.x | Esqueleto (núcleo, traducciones, pruebas, empaquetado) y **diagnóstico** `/gp diag` de subasta, correo, botín y profesiones | Interno |
| **0.1.0** | Tooltip con precio de vendedor y de subasta observado (con antigüedad), búsqueda dirigida de tus objetos al abrir la subasta, valor de bolsas | Sí |
| **0.2.0** | Asistente de venta en la subasta y libro de operaciones con ventas confirmadas por correo | Sí |
| **0.3.0** | Sesiones de recolección con valor realizable y asesor de zonas por habilidad | Sí |
| **0.4.0** | Panel principal con «Ahora», Inventario (vender/conservar, reservas) y existencias de la cuenta | Sí |
| **0.5.0** | Historial y tendencias en juego; sin fuentes externas de otros addons | Sí |
| **0.6.0** | Fabricación: coste y rentabilidad de recetas (según el diagnóstico) | Sí |
| **0.7.0** | Aplicación externa alfa: instantáneas de la API web, historial, informe, `GoldPilot_Market` | Sí (app en GitHub; addon igual) |
| 1.0.0 | Estable: esquema de datos congelado, traducciones completas, documentación de usuario | Sí |

El plan ejecutable paso a paso está en `.agents/plans/goldpilot/goldpilot.PLAN.md`.

## 11. Riesgos y decisiones que necesitan tu intervención

### Riesgos técnicos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| La API de subasta o de correo de Forever difiere de Mainline | Asistente de venta o libro rotos | Diagnóstico antes de construir; detección de capacidades por módulo |
| La API web de Blizzard cambia o se cierra (no está documentada) | La aplicación pierde su fuente | La aplicación es opcional; el addon no depende de ella |
| Límite de consultas en la subasta | Precios incompletos | Búsquedas dirigidas, colas con prioridad y respeto de los eventos de límite |
| Crecimiento de SavedVariables | Cargas lentas | Historial compacto con poda y presupuesto medido en las pruebas |
| Precios de casas distintas mezclados | Recomendaciones erróneas | Clave de casa en todos los precios; investigar cómo identificarla |
| Fabricación inviable por API | Pestaña aplazada | Se publica el resto; respaldo con `wowdata` |

### Decisiones tomadas (2026-11-23)

1. **Licencia:** WNCL-TP-1.0 (aplicada).
2. **Autoría:** WarCrafted.
3. **Nombre visible y comando:** carpeta `GoldPilot`, título «GoldPilot Forever», comandos `/goldpilot` y `/gp`.
4. **Archivos de agentes fuera del repositorio:** `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.agentrelay/` y `.claude/` van en `.gitignore` y no se publican.
5. **Otros addons:** GoldPilot no depende de FarmAdvisor. Con PocketBank (en desarrollo activo) se coopera: si está instalado, GoldPilot usa sus existencias de banco y bolsas de toda la cuenta en lugar de duplicarlas, y le ofrece valores (`GoldPilot.API.GetPrice`) para que PocketBank pueda mostrar el valor del banco. Sin PocketBank, GoldPilot guarda solo cantidades mínimas.
6. **Nodos de recolección:** `wowdata` es solo semilla; lo observado en juego manda y las semillas no confirmadas se descartan (D11).

### Decisiones pendientes

- **Aplicación externa y cliente de Battle.net:** ver D12 en [DECISIONES.md](DECISIONES.md).
