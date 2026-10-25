;;==============================================================
;; main.asm -- LABERINTO, para Game Boy (DMG)
;;
;; Arranque y bucle principal. Cada frame:
;;   1. Dormir hasta el VBLANK (halt)          wait_frame
;;   2. Escribir en la VRAM lo preparado        sys_render_vblank
;;   3. Leer los botones                        input_update
;;   4. La música                               music_update
;;   5. La escena: lógica y preparar el frame   scene_update
;;   6. ¿Cambio de escena?                      scene_check_change
;;==============================================================
INCLUDE "engine/hardware.inc"
INCLUDE "engine/gfx.inc"

DEF STACK_TOP   = WRAM_END            ;; the stack grows down from the end of the WRAM
DEF WRAM_START  = $C000
DEF STACK_SPACE = $100                ;; the last 256 bytes of the WRAM are for the stack
DEF RNG_START   = $ACE1               ;; any value but 0

SECTION "Main vars", WRAM0
frame_counter:: ds 1                  ;; +1 every frame (animations, blinks...)

SECTION "Main", ROM0

main::
    di
    ld   sp, STACK_TOP
    call lcd_off

    ld   hl, WRAM_START               ;; \ The WRAM at 0 (but the stack)
    ld   bc, WRAM_END - STACK_SPACE - WRAM_START ;; |
    xor  a                            ;; |
    call memset16                     ;; /

    ld   hl, tiles                    ;; \ The tiles, to the VRAM
    ld   de, VRAM_TILES               ;; |
    ld   bc, tiles_end - tiles        ;; |
    call memcpy16                     ;; /

    call dma_init                     ;; The DMA routine, to the HRAM
    call oam_clear
    xor  a                            ;; \ No window, no scroll
    ldh  [rSCX], a                    ;; |
    ldh  [rSCY], a                    ;; |
    call hud_hide                     ;; /
    call palettes_reset
    call sound_init
    call save_load                    ;; The record and the options
    ld   a, LOW(RNG_START)            ;; \ The random numbers
    ld   [rng_state], a               ;; |
    ld   a, HIGH(RNG_START)           ;; |
    ld   [rng_state + 1], a           ;; /

    xor  a                            ;; \ Only the VBLANK interrupt (the title
    ldh  [rIF], a                     ;; | turns on the STAT one for its logo)
    ldh  [rSTAT], a                   ;; |
    ld   a, IEF_VBLANK                ;; |
    ldh  [rIE], a                     ;; |
    ei                                ;; /

    ld   hl, scn_title_init
    call scene_start

.loop
    call wait_frame
    call sys_render_vblank
    ld   hl, frame_counter
    inc  [hl]
    call input_update
    call music_update
    call scene_update
    call scene_check_change
    jr   .loop
