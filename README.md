# LABERINTO: un juego para Game Boy (DMG)

Juego para la **GBRetroDev'26**, escrito entero en ensamblador SM83 (RGBDS). Es un
proyecto de **GBTelera** (creado con `gbt_mkproject`) y sigue la arquitectura de los
**Challenges** de la asignatura: entidades de 16 bytes con componentes, sistemas que se
recorren con `man_entity_forall_matching`, OAM con DMA desde la HRAM, mapa de 32×32 con
scroll, HUD en la window, niveles con estructura `LVL_` e IA con `THINK` y `rng_next`.

Cartucho: **MBC1 + RAM + BATTERY** (tipo 3), 32 KiB de ROM y 8 KiB de RAM con pila
(se guardan el récord y las opciones).

## Compilar y jugar

```
make                    # genera laberinto.gb
gbt_bgb laberinto.gb    # BGB 1.6.4    (o: gbt_emulicious laberinto.gb)
make assets             # regenera tiles, niveles y música desde tools/ (Python 3)
make clean              # borra obj/
```

- La ROM (`laberinto.gb`) se genera al compilar y no se incluye en el código fuente.
- Compila sin avisos con el Makefile de GBTelera (`-E -Weverything`), con RGBDS 0.8.0 y 0.9.4.
- Los símbolos quedan en `obj/laberinto.sym`: BGB y Emulicious muestran los nombres al depurar.

## Cómo se juega

| Botón | En el juego |
|---|---|
| Cruceta | Andar (al soltarla se para) |
| A | Disparar hacia donde miras (una bala a la vez) |
| START | Pausa |

- **Objetivo:** llegar al **portal** de cada uno de los **3 laberintos** antes de que se acabe el tiempo (120 s por nivel).
- **Corazones:** empiezas con 3. Si un espectro te toca pierdes uno y parpadeas un momento (no te pueden volver a dañar). Sin corazones, fin de la partida.
- **Espectros:** cada uno derrotado da **+5 monedas**. Si derrotas a todos los de un nivel ganas **un corazón** (máximo 5).
  - Nivel 1: deambulan. Nivel 2: la mitad te persigue. Nivel 3: unos son rápidos y otros cazan.
- **Puntos = monedas × 10 + los segundos que te sobran en cada portal.** El récord se guarda en el cartucho.

Pantallas: portada → ajustes (idioma ES/EN, chico/chica, música sí/no, nombre de hasta 8 letras)
→ nivel 1 → juego → nivel 2 → … → final (victoria o fin de la partida) → portada.

## Estructura (`src/`)

| Carpeta / fichero | Qué hay |
|---|---|
| `main.asm` | Arranque y bucle principal: `halt` hasta el VBLANK → VRAM → botones → música → escena |
| `engine/` | Hardware (`hardware.inc`), DMA, interrupciones (VBLANK y raster del logo), vídeo y fundidos, botones, `rng_next`, textos, memoria, sonido y guardado en SRAM |
| `engine/ui/hud.asm` | El HUD en la window: corazones, monedas, espectros, tiempo y nivel |
| `man/` | Gestor de entidades (`man_entity`) y del mapa (`man_map`: `map_tile_address`, `map_is_solid_at`, tiles que cambian) |
| `sys/` | Los sistemas: `input`, `ai`, `physics`, `animation`, `selfdestroy`, `collision`, `camera`, `prerender`, `render` |
| `scn/` | Escenas: `scn_title`, `scn_setup`, `scn_level`, `scn_game` (+ `scn_game_rules`: plantillas, niveles, monedas, disparos, corazones, tiempo, portal), `scn_end` |
| `assets/` | Gráficos, niveles, canciones y textos. `gfx/`, `levels/` y `snd/` los **generan** los scripts de `tools/` |


## Herramientas (`tools/`, Python 3)

| Script | Para qué |
|---|---|
| `sprites.py` | Los diseños de todos los gráficos (texto con 4 colores) |
| `preview_sprites.py` | Hoja de sprites ampliada en PNG, para revisarlos |
| `gen_tiles.py` | Tiles + `gfx.inc` + `charmap.inc` |
| `gen_maze.py` | Genera un laberinto nuevo en `levels/` (punto de partida para editarlo a mano) |
| `map2asm.py` | `levels/nivel*.txt` → `levels.asm`, comprobando que todo es alcanzable |
| `music.py` | Las canciones (nombres de notas) → `songs.asm` |
| `capture.py` | Un bot juega la partida entera en PyBoy y genera capturas, GIFs, tráiler, portada y banner (`pip install pyboy pillow` + ffmpeg) |

Leyenda de los niveles: `#` pared, `.` suelo, `o` moneda, `P` jugador, `E` espectro, `S` portal.

## Licencia

MIT (fichero `LICENSE`). El Makefile, `cfg/` y `src/header.asm` son de la plantilla de GBTelera (MIT).
