;;==============================================================
;; engine/input.asm -- Lectura del joypad
;;==============================================================
INCLUDE "engine/hardware.inc"

DEF P1_SELECT_DPAD = %00100000        ;; bit 4 at 0: the D-pad
DEF P1_SELECT_BTNS = %00010000        ;; bit 5 at 0: the buttons
DEF P1_SELECT_NONE = %00110000

SECTION "Input vars", WRAM0
input_held::    ds 1                  ;; buttons held now      (1 = pressed)
input_pressed:: ds 1                  ;; buttons pressed this frame only

SECTION "Input", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads the D-pad and the buttons. Byte format (BTN_*_BIT):
;;   bit 0 right, 1 left, 2 up, 3 down, 4 A, 5 B, 6 select, 7 start
;; ❌ Modifies A, B
input_update::
    ld   a, P1_SELECT_BTNS            ;; \ Buttons -> high nibble
    ldh  [rP1], a                     ;; |
    ldh  a, [rP1]                     ;; | (read several times: the
    ldh  a, [rP1]                     ;; |  contacts need a moment)
    ldh  a, [rP1]                     ;; |
    and  $0F                          ;; |
    swap a                            ;; |
    ld   b, a                         ;; /
    ld   a, P1_SELECT_DPAD            ;; \ D-pad -> low nibble
    ldh  [rP1], a                     ;; |
    ldh  a, [rP1]                     ;; |
    ldh  a, [rP1]                     ;; |
    ldh  a, [rP1]                     ;; |
    and  $0F                          ;; |
    or   b                            ;; |
    cpl                               ;; / 0 = pressed in the hardware -> 1 = pressed
    ld   b, a
    ld   a, [input_held]              ;; \ pressed = not held before AND held now
    cpl                               ;; |
    and  b                            ;; |
    ld   [input_pressed], a           ;; /
    ld   a, b
    ld   [input_held], a
    ld   a, P1_SELECT_NONE
    ldh  [rP1], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Forgets the buttons (so a button that changes the scene does not act twice).
;; ❌ Modifies A
input_clear::
    ld   a, $FF
    ld   [input_held], a
    xor  a
    ld   [input_pressed], a
    ret
