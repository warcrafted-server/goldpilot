# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

## [0.3.0] - 2026-11-24

### Añadido
- Pestaña Inventario con valor por objeto, recomendación, reservar y seguir.

## [0.2.5] - 2026-11-24

### Añadido
- Ventana principal con pestañas y componentes de interfaz.

### Cambiado
- `/gp` abre la ventana y `/gp help` muestra la ayuda.

## [0.2.4] - 2026-11-24

### Añadido
- Captura del tooltip de objeto para la ficha de CurseForge (`docs/img/capturas/tooltip-objeto.png`)

## [0.2.3] - 2026-11-24

### Añadido
- Identificador del proyecto de CurseForge (`X-Curse-Project-ID`) en el TOC

## [0.2.2] - 2026-11-24

### Cambiado
- Logo rediseñado (moneda de oro con rosa de los vientos; `tools/generar_logo.py` ahora usa Pillow, solo para desarrollo)
- `docs/CURSEFORGE.md` pasa a ser la ficha completa del proyecto: categorías, resúmenes y descripciones en inglés y castellano

## [0.2.1] - 2026-11-24

### Añadido
- Logo del proyecto (`docs/img/logo.png`, generado con `tools/generar_logo.py`), pruebas automáticas en GitHub y `tools/comprobar_release.py` para revisar la versión antes de etiquetar

### Corregido
- La ruta de instalación manual del README apuntaba a `_classic_era_`; la de Forever es `_forever_`

## [0.2.0] - 2026-11-24

### Añadido
- Registro del banco, consultas de subasta para bolsas y bancos de otros personajes, consultas prioritarias al pasar el cursor y registro compacto de la última sesión.

### Cambiado
- Las claves de casas y personajes ya no incluyen reino; el esquema migra las claves guardadas.
- El diagnóstico conserva las sondas ya guardadas. GoldPilot obtiene precios solo de sus propias observaciones en la subasta.

### Corregido
- Se conserva el banco anterior hasta abrir el banco, y cada resultado de consulta queda registrado.

## [0.1.1] - 2026-11-24

### Corregido
- El icono del minimapa se carga también desde la copia de desarrollo.

### Cambiado
- La versión de la copia de desarrollo muestra el número real con sufijo `-dev`.

## [0.1.0] - 2026-11-23

### Añadido
- Primera versión usable: tooltips con precio de vendedor y observación de subasta, antigüedad y recomendación; consultas dirigidas al abrir la subasta; valoración de bolsas y comandos de diagnóstico y minimapa.

## [0.0.8] - 2026-11-23

### Añadido
- Asesor de vendedor/subasta, tema, tooltip y valor de bolsas

## [0.0.7] - 2026-11-23

### Añadido
- Colectores de bolsas y subasta con cola dirigida

## [0.0.6] - 2026-11-23

### Añadido
- Almacén de precios observados (resumen p50, historial diario y semanal empaquetado, poda) y elección del precio de referencia con clase de dato

## [0.0.5] - 2026-11-23

### Añadido
- `tools/generar_desde_wowdata.py`: genera `Data/Generated/Items.lua` (objetos comerciables) y `NodeSeeds.lua` (semillas de nodos) desde wowdata

## [0.0.4] - 2026-11-23

### Añadido
- Icono del addon y botón arrastrable del minimapa (`/gp minimap`)

## [0.0.3] - 2026-11-23

### Añadido
- Diagnóstico `/gp diag` y sondas de subasta, correo, botín y profesiones

## [0.0.2] - 2026-11-23

### Añadido
- Esqueleto del addon: núcleo (init, eventos, módulos, compatibilidad, registro y migraciones), localización enUS/esES, pruebas y empaquetado, y `tools/toc_dev.py` para la copia de desarrollo.

## [0.0.1] - 2026-11-23

### Añadido
- Documentación inicial: propuesta del producto, arquitectura, decisiones técnicas e investigación de la API del cliente, la casa de subastas y las fuentes de datos económicos de WoW Forever.
- Licencia WNCL-TP-1.0 (WarCrafted).
