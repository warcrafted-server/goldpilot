# GoldPilot Forever

Addon de economía para **World of Warcraft: Forever**: te dice qué te conviene hacer para ganar oro (recolectar, vender, fabricar o conservar), explica por qué y distingue siempre los precios observados, las ventas confirmadas y las estimaciones. Pensado para recolectores y comerciantes, útil para cualquier jugador. Interfaz en inglés y castellano.

Comandos disponibles: `/gp diag` genera un diagnóstico del cliente y de las ventanas abiertas; el botón del minimapa abre la ayuda con clic izquierdo y ejecuta el diagnóstico con clic derecho. Usa `/gp minimap` para ocultarlo o mostrarlo.

> **Estado: fase de diseño (0.0.1).** Aún no hay código. Este repositorio contiene la propuesta del producto, la arquitectura y la investigación de la API del cliente.

## Documentación

- [Propuesta del producto](docs/PROPUESTA.md): visión, funcionalidades viables y descartadas, interfaz, roadmap, riesgos y decisiones pendientes.
- [Arquitectura](docs/ARQUITECTURA.md): módulos, clases de dato, almacenamiento, comunicación con la aplicación opcional y pruebas.
- [Decisiones técnicas](docs/DECISIONES.md).
- [Investigación: API, casa de subastas y fuentes de datos](docs/investigacion/01-api-y-mercado.md).
- [CHANGELOG](CHANGELOG.md) · [TODO](TODO.md)

## Requisitos

- Cliente WoW Forever (Interface 16001, build de referencia 1.60.1.70862).
- Sin dependencias. Opcionales previstos: Auctionator, TradeSkillMaster, TomTom y la aplicación externa GoldPilot (Windows).

## Instalación y uso

Todavía no hay versión instalable. La primera versión publicable será la 0.1.0 (ver roadmap en la propuesta).

## Desarrollo

La copia de pruebas del juego es un junction `AddOns\GoldPilotDev` que apunta a la raíz del repo, con su propio `GoldPilotDev.toc` (generado con `python tools/toc_dev.py`, ignorado por git; vuelve a ejecutarlo si cambia la lista de archivos del TOC). Convive con la copia publicada de CurseForge (`AddOns\GoldPilot`), pero solo una de las dos debe estar activa a la vez porque comparten SavedVariables. Montarla o desmontarla exige el juego cerrado. Pruebas: `python tests/run.py`.

## Créditos y licencia

**GoldPilot Forever** está desarrollado y mantenido por **WarCrafted**.
Copyright (C) 2026 WarCrafted.

Licencia [WNCL-TP-1.0](LICENSE): puedes usarlo, estudiarlo, modificarlo y compartirlo gratis con fines no comerciales. Venderlo o cualquier uso comercial requiere permiso por escrito. Solo cubre el material propio; los componentes de terceros conservan su licencia.

Las copias y los forks deben conservar esta atribución y enlazar a https://github.com/warcrafted-server/goldpilot.

Datos de juego de World of Warcraft (c) Blizzard Entertainment; proyecto no afiliado.

### Material de terceros

| Componente | Autor | Licencia | Enlace |
| --- | --- | --- | --- |

Este proyecto no contiene material de terceros.
