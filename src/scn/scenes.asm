;;==============================================================
;; scn/scenes.asm -- Las escenas (pantallas) y el paso de una a otra
;;
;; Una escena es una rutina de inicio (con la pantalla apagada: dibuja todo y
;; elige su rutina de cada frame) y una rutina de cada frame.
;;   portada -> ajustes -> nivel N -> juego -> (nivel N+1 ...) -> final -> portada
;; El cambio se pide con scene_request y lo hace el bucle principal, al acabar
;; el frame: fundido a blanco, pantalla apagada, inicio, pantalla encendida y
;; fundido desde blanco.
;;==============================================================
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"

SECTION "Scene vars", WRAM0
scene_update_ptr: ds 2                ;; the routine of each frame of the scene
scene_lcdc::     ds 1                 ;; rLCDC of the scene (with or without window)
next_scene:      ds 2                 ;; the start of the next scene (0: none)
scene_timer::    ds 1                 ;; free for the scenes (frames since it started)

SECTION "Scenes", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; For the start routine of a scene: its routine of each frame and its rLCDC.
;; 📥 HL = routine of each frame, A = rLCDC
;; ❌ Modifies A
scene_set::
    ld   [scene_lcdc], a
    ld   a, l
    ld   [scene_update_ptr], a
    ld   a, h
    ld   [scene_update_ptr + 1], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; One frame of the current scene. ❌ Modifies A, BC, DE, HL
scene_update::
    ld   hl, scene_timer              ;; \ One frame more in this scene
    inc  [hl]                         ;; | (it stops at 255)
    jr   nz, .run                     ;; |
    dec  [hl]                         ;; /
.run
    ld   a, [scene_update_ptr]
    ld   l, a
    ld   a, [scene_update_ptr + 1]
    ld   h, a
    jp   hl

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Asks to change the scene at the end of this frame.
;; 📥 HL = start routine of the next scene
;; ❌ Modifies A
scene_request::
    ld   a, l
    ld   [next_scene], a
    ld   a, h
    ld   [next_scene + 1], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; If a change was asked, does it (main loop). ❌ Modifies A, BC, DE, HL
scene_check_change::
    ld   a, [next_scene]
    ld   l, a
    ld   a, [next_scene + 1]
    ld   h, a
    or   l
    ret  z
    xor  a
    ld   [next_scene], a
    ld   [next_scene + 1], a
    push hl
    call fade_out
    pop  hl
    ; continues in scene_start

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Starts a scene: everything clean with the screen off, its start routine,
;; and the screen on with a fade.
;; 📥 HL = start routine of the scene
;; ❌ Modifies A, BC, DE, HL
scene_start::
    push hl
    call lcd_off
    call raster_off
    call oam_clear
    call sys_camera_reset
    call hud_hide
    call render_reset
    call palettes_white
    xor  a
    ld   [scene_timer], a
    ld   [music_pause], a
    ldh  [rSCX], a
    ldh  [rSCY], a
    pop  hl
    call call_hl                      ;; The start of the scene
    ld   a, [scene_lcdc]
    call lcd_on
    call input_clear
    call fade_in
    jp   palettes_reset               ;; (OBP1 too: the hurt palette)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The whole background blank. ⚠️ The screen must be OFF
;; ❌ Modifies A, BC, D, HL
screen_clear::
    ld   hl, TILEMAP
    ld   bc, TILEMAP_WIDTH * TILEMAP_WIDTH
    ld   a, TILE_BLANK
    jp   memset16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Has START or A just been pressed? (to go on in the screens of text)
;; ⫷▬ NZ: yes
;; ❌ Modifies A
confirm_pressed::
    ld   a, [input_pressed]
    and  BTN_START | BTN_A
    ret
