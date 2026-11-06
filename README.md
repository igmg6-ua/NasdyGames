# LABERINTO: un juego para Game Boy (DMG)

Juego para la **GBRetroDev'26**, escrito entero en ensamblador SM83 (RGBDS). Es un
proyecto de **GBTelera** (creado con `gbt_mkproject`) y sigue la arquitectura de los
**Challenges** de la asignatura: entidades de 16 bytes con componentes, sistemas que se
recorren con `man_entity_forall_matching`, OAM con DMA desde la HRAM, mapas de hasta 32×32 con
scroll, HUD en la window, niveles con estructura `LVL_` e IA con `THINK` y `rng_next`.

Cartucho: **MBC1 + RAM + BATTERY** (tipo 3), 32 KiB de ROM y 8 KiB de RAM con pila
(se guardan el récord, las opciones, el mejor tiempo de cada nivel y los medallones).

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

- **Objetivo:** llegar al **portal** de cada uno de los **10 laberintos** antes de que se acabe el tiempo. Cada nivel es más grande (de 19×19 a 31×31 tiles) y tiene más espectros (de 2 a 6). El tiempo depende del tamaño: de 90 s en el nivel 1 a 180 s en el 10.
- **Música:** cuando queda la mitad del tiempo se acelera, y cuando queda un tercio, un poco más.
- **Pistola:** al empezar cada nivel aparece cerca de ti, en un sitio aleatorio al que llegas andando entre 3 y 9 tiles (1 a 3 salas). Sin ella no puedes disparar.
- **Corazones:** empiezas con 3 (máximo 5). Si un espectro te toca pierdes uno y parpadeas un momento. Sin corazones, fin de la partida.
- **Espectros:** cada uno derrotado da **+5 segundos**. Su comportamiento cambia con el nivel: deambulan, te persiguen o son rápidos. Los cazadores comparten una tabla de navegación para rodear paredes; se actualiza por partes mientras siguen el último recorrido completo. Los enemigos mantienen separación entre sus cuerpos y prueban desvíos al bloquearse.
- **Medallón:** si derrotas a **todos** los espectros de un nivel ganas su medallón: lo ves girar al acabar el nivel y queda guardado. En el menú, **MEDALLONES** muestra los 10 (los que faltan, en silueta).
- **Desde el nivel 3**, en cada nivel aparecen en un sitio aleatorio (lejos de ti):
  - **Escudo:** para el siguiente golpe de un espectro y se pierde.
  - **Corazón:** recupera 1 corazón, o da **+15 s** si ya los tienes todos.
- **Al acabar cada nivel:** el tiempo que has tardado, tu récord en ese nivel (se guarda en el cartucho), espectros, monedas, bonus y si has ganado el medallón.
- **Puntos = monedas × 10 + los segundos que te sobran en cada portal.** El récord se guarda en el cartucho.

Pantallas: portada → menú (idioma ES/EN, chico/chica, música sí/no, nombre de hasta 8 letras,
medallones) → nivel 1 → juego → [medallón] → resumen → nivel 2 → … → final (victoria o fin
de la partida) → portada.

## Navegación

Los cazadores comparten una tabla de rutas para rodear paredes. Se reconstruye por partes mientras siguen la última tabla completa, por lo que existe retardo al cambiar el destino. Los enemigos mantienen separación entre cuerpos y prueban desvíos al bloquearse; pueden quedar esperas en pasos estrechos.

Se conservan los diez mapas reequilibrados: el primero tiene cuatro islas de paredes y rutas alternativas; los demás incorporan pequeños atajos. La mezcla de enemigos incluye perseguidores y patrulleros. El mapa temporal y los archivos de diagnóstico se retiraron de esta versión.

## Estructura (`src/`)

| Carpeta / fichero | Qué hay |
|---|---|
| `main.asm` | Arranque y bucle principal: espera al VBLANK → VRAM → botones → música → escena |
| `engine/` | Hardware (`hardware.inc`), DMA, interrupciones (VBLANK y raster del logo), vídeo y fundidos, botones, `rng_next`, textos, memoria, sonido y guardado en SRAM |
| `engine/ui/hud.asm` | El HUD en la window: corazones, escudo, pistola, monedas, espectros, tiempo y nivel |
| `man/` | Gestor de entidades (`man_entity`) y del mapa (`man_map`: `map_tile_address`, `map_is_solid_at`, tiles que cambian) |
| `sys/` | Los sistemas: `input`, `ai`, `physics`, `animation`, `selfdestroy`, `collision`, `camera`, `prerender`, `render` |
| `scn/` | Escenas: `scn_title`, `scn_setup`, `scn_level`, `scn_game` (+ `scn_game_rules`: plantillas, niveles, monedas, disparos, objetos, corazones, tiempo, portal), `scn_medal` (el medallón girando), `scn_clear` (resumen del nivel), `scn_medals` (galería), `scn_end` |
| `assets/` | Gráficos, niveles, canciones y textos. `gfx/`, `levels/` y `snd/` los **generan** los scripts de `tools/` |


## Herramientas (`tools/`, Python 3)

| Script | Para qué |
|---|---|
| `sprites.py` | Los diseños de todos los gráficos (texto con 4 colores) |
| `preview_sprites.py` | Hoja de sprites ampliada en PNG, para revisarlos |
| `gen_tiles.py` | Tiles + `gfx.inc` + `charmap.inc` |
| `gen_maze.py` | Genera los 10 laberintos de `levels/` (o uno nuevo, como punto de partida para editarlo a mano) |
| `map2asm.py` | `levels/nivel*.txt` (de 8×8 a 32×32) → `levels.asm`, comprobando que todo es alcanzable; calcula el tiempo de cada nivel |
| `music.py` | Las canciones (nombres de notas) → `songs.asm` |
| `capture.py` | Un bot juega la partida entera en PyBoy y genera capturas, GIFs, tráiler, portada y banner (`pip install pyboy pillow` + ffmpeg) |

Leyenda de los niveles: `#` pared, `.` suelo, `o` moneda, `P` jugador, `E` espectro, `S` portal.

## Licencia

MIT (fichero `LICENSE`). El Makefile, `cfg/` y `src/header.asm` son de la plantilla de GBTelera (MIT).
