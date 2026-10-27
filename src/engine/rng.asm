;;==============================================================
;; engine/rng.asm -- Números aleatorios (xorshift de 16 bits)
;;==============================================================
INCLUDE "engine/hardware.inc"

SECTION "RNG vars", WRAM0
rng_state::     ds 2

SECTION "RNG", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A random number. A 16-bit xorshift: it goes through all the 65535 values
;; that are not 0 before repeating.
;; ⫷▬ A = number (0-255)
;; ❌ Modifies A, B, HL. Does NOT modify C, DE
rng_next::
    ld   hl, rng_state                ;; \ HL = the state (H high, L low)
    ld   a, [hl+]                     ;; |
    ld   b, [hl]                      ;; |
    ld   l, a                         ;; |
    ld   h, b                         ;; /
    ld   a, h                         ;; \ The xorshift (7, 9, 8) in 8-bit steps
    rra                               ;; |
    ld   a, l                         ;; |
    rra                               ;; |
    xor  h                            ;; |
    ld   h, a                         ;; |
    ld   a, l                         ;; |
    rra                               ;; |
    ld   a, h                         ;; |
    rra                               ;; |
    xor  l                            ;; |
    ld   l, a                         ;; |
    xor  h                            ;; |
    ld   h, a                         ;; /
    ld   a, l                         ;; \ Save the new state
    ld   [rng_state], a               ;; |
    ld   a, h                         ;; |
    ld   [rng_state + 1], a           ;; /
    ret                               ;; A = the high byte

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Mixes the divider (it changes 16384 times a second) into the state. Called
;; when the player presses START, so every game is different.
;; ❌ Modifies A, HL
rng_seed::
    ld   hl, rng_state
    ldh  a, [rDIV]
    xor  [hl]
    ld   [hl+], a
    ldh  a, [rDIV]
    add  [hl]
    ld   [hl], a
    dec  hl                           ;; \ The state can not be 0
    or   [hl]                         ;; |
    ret  nz                           ;; |
    ld   a, $A5                       ;; |
    ld   [hl+], a                     ;; |
    ld   [hl], $5A                    ;; /
    ret
