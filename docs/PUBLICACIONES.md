# Cola de publicación en CurseForge

Cada versión es un commit completo en `master`: lleva `VERSION`, el TOC y el CHANGELOG, y un `docs/RELEASE_NOTES.md` con solo sus notas. Se publican **en orden**, de una en una. Para publicar una, se crea el tag sobre **su** commit y se sube con aprobación:

```
git tag v0.15.7 751f102
git push origin v0.15.7
```

El CI (`release.yml`) empaqueta exactamente ese commit y sube a CurseForge las notas de ese commit. Que `master` ya vaya por delante no afecta. Después de publicar una versión, marca aquí la fecha.

| Versión | Commit | Qué trae | Probada en el juego | Publicada |
|---|---|---|---|---|
| 0.15.6 | dd1e53e | Primera versión | sí | 2026-11-25 |
| 0.15.7 | 751f102 | Ahora: tarjeta de correo sin oro con recuento | no | no |
| 0.16.0 | 9b20bcc | Barra de progreso del escaneo y aviso al interrumpirlo | no | no |
| 0.16.1 | 830935e | Escaneo programado al acabar el límite de 15 min | no | no |
| 0.16.2 | bbc3914 | Barra con porcentaje y segundos también en la espera | no | no |
| 0.16.3 | 6f9d9e1 | Interno: temporizadores cancelables y mensajes entre módulos | no | no |

Sugerencia: no publicar una versión hasta que esté probada en el juego. Si se encuentra un fallo en una versión preparada pero aún sin publicar, se corrige en la siguiente y se publican juntas, o se salta la defectuosa sin tag. Ninguna versión publicada se retira.
