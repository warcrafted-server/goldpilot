# Cola de publicación en CurseForge

Cada versión es un commit completo en `master`: lleva `VERSION`, el TOC, el CHANGELOG y su nota en `docs/notas/`. Se publican **en orden**, de una en una. Para publicar una, se crea el tag sobre **su** commit y se sube con aprobación:

```
git tag v0.15.7 751f102
git push origin v0.15.7
```

El CI (`release.yml`) empaqueta exactamente ese commit y sube a CurseForge las notas generadas desde ese commit. Que `master` ya vaya por delante no afecta. Después de publicar una versión, marca aquí la fecha.

| Versión | Commit | Qué trae | Probada en el juego | Publicada |
|---|---|---|---|---|
| 0.15.6 | dd1e53e | Primera versión | sí | 2026-11-25 |
| 0.15.7 | 751f102 | Ahora: tarjeta de correo sin oro con recuento | no | no |
| 0.16.0 | 9b20bcc | Barra de progreso del escaneo y aviso al interrumpirlo | no | no |
| 0.16.1 | 830935e | Escaneo programado al acabar el límite de 15 min | barra sí; inicio automático no | 2026-11-26 (incluye 0.15.7 y 0.16.0) |
| 0.16.2 | bbc3914 | Barra con porcentaje y segundos también en la espera | no | no |
| 0.16.3 | 6f9d9e1 | Interno: temporizadores cancelables y mensajes entre módulos | no | no |
| 0.16.4 | 7951ef1 | Barra del escaneo a la derecha y «(est.)» en lugar de ~ | no | no |
| 0.16.5 | bff2de6 | Herramientas: notas de versión por archivo y generación en el CI | no hace falta | no |
| 0.16.6 | eee07f2 | Barra del escaneo con ancho según el texto | no | no |
| 0.17.0 | fcf0d4c | Ajustes declarativos, `/gpilot set` y ajuste de precios de la aplicación | no | no |
| 0.17.1 | 5989952 | Diagnóstico `/gpilot diag ah` | no | no |
| 0.17.2 | 0bfb777 | Pausa de la cola de precios al comprar o vender (no estorba tus compras) | no | no |
| 0.18.0 | 2904367 | Asistente de venta en la subasta (precio sugerido, neto, «Usar este precio») | no | no |
| 0.18.1 | 919453a | Aspecto del asistente de venta (fuera de la ventana, ajustado, confianza en palabras) | no | no |
| 0.18.2 | edb6bf0 | Depósito del asistente de venta también con equipo | no | no |
| 0.19.0 | 6068ce4 | Mis subastas: rebajadas, bien y vendidas, con cancelar | no | no |
| 0.19.1 | 0e81777 | Estilo de GoldPilot en los recuadros de subasta y acentos corregidos | no | no |

Sugerencia: no publicar una versión hasta que esté probada en el juego. Si se encuentra un fallo en una versión preparada pero aún sin publicar, se corrige en la siguiente y se publican juntas, o se salta la defectuosa sin tag. Ninguna versión publicada se retira.

Las notas de cada versión están en `docs/notas/X.Y.Z.md` y el CI las junta al publicar: las de la versión del tag y todas las posteriores al último tag publicado, de la más nueva a la más vieja. Así, si se publica una versión saltándose otras sin publicar, CurseForge recibe también las notas de esas versiones. Los tags v0.16.2, v0.16.3 y v0.16.4, al ser de commits anteriores, usan aún sus notas sueltas de `docs/RELEASE_NOTES.md`; son correctas si se publican en orden.
