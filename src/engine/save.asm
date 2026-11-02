;;==============================================================
;; engine/save.asm -- Guardar en la RAM del cartucho (con pila)
;;
;; El cartucho es MBC1 + RAM + BATTERY: 8 KiB de RAM que no se borran al
;; apagar. Se guardan el récord (puntos y nombre), las opciones del menú, el
;; mejor tiempo de cada nivel y los medallones conseguidos.
;; La RAM se habilita sólo mientras se lee o se escribe: así, si se apaga la
;; consola de golpe, es mucho más difícil que se estropee.
;;==============================================================
INCLUDE "engine/hardware.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/charmap.inc"
INCLUDE "assets/levels/level_count.inc"

SECTION "Save data", SRAM
sram_magic:     ds 4                  ;; "LBR3": there is a save of this version
sram_data:                            ;; the same order as save_vars (below)
sram_best:      ds 2
sram_best_name: ds NAME_SIZE
sram_options:   ds 3
sram_name:      ds NAME_SIZE
sram_level_best: ds NUM_LEVELS * 2
sram_medals:    ds 2
sram_data_end:
sram_check:     ds 1                  ;; the sum of the bytes of sram_data
DEF SAVE_SIZE = sram_data_end - sram_data

SECTION "Save vars", WRAM0
save_vars:
best_score::    ds 2                  ;; BCD, high byte first
best_name::     ds NAME_SIZE
language::      ds 1                  ;; 0 = español, 1 = English
gender::        ds 1                  ;; 0 = boy, 1 = girl
music_choice::  ds 1                  ;; 1 = music on
player_name::   ds NAME_SIZE
level_best::    ds NUM_LEVELS * 2     ;; best time of each level: minutes, seconds (BCD)
                                      ;; ($FF, $FF: not finished yet)
medals::        ds 2                  ;; one bit per level (bit 0 of the first byte = level 1)
save_vars_end:
ASSERT save_vars_end - save_vars == SAVE_SIZE

SECTION "Save", ROM0

SaveMagic:
    db "LBR3"

;; What there is when there is no save yet
SaveDefaults:
    db $00, $00                       ;; best_score
    db "-", TEXT_END
    ds NAME_SIZE - 2, TEXT_END        ;; best_name
    db 0, 0, 1                        ;; language, gender, music
    db "NASDY", TEXT_END
    ds NAME_SIZE - 6, TEXT_END        ;; player_name
    ds NUM_LEVELS * 2, $FF            ;; level_best: none
    db 0, 0                           ;; medals: none
ASSERT @ - SaveDefaults == SAVE_SIZE
ASSERT NUM_LEVELS <= 16               ;; (the medals are 16 bits)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads the save. If there is none (or it is damaged), uses the defaults.
;; ❌ Modifies A, BC, DE, HL
save_load::
    ld   a, CART_RAM_ENABLE           ;; \ Enable the RAM of the cartridge
    ld   [rRAMG], a                   ;; /
    ld   hl, sram_magic               ;; \ Is the magic word there?
    ld   de, SaveMagic                ;; |
    ld   b, 4                         ;; |
.magic                                ;; |
    ld   a, [de]                      ;; |
    cp   [hl]                         ;; |
    jr   nz, .defaults                ;; |
    inc  de                           ;; |
    inc  hl                           ;; |
    dec  b                            ;; |
    jr   nz, .magic                   ;; /
    call save_checksum                ;; \ Is the sum right?
    ld   hl, sram_check               ;; |
    cp   [hl]                         ;; |
    jr   nz, .defaults                ;; /
    ld   hl, sram_data                ;; \ Yes: copy it
    jr   .copy                        ;; /
.defaults
    ld   hl, SaveDefaults
.copy
    ld   de, save_vars
    ld   b, SAVE_SIZE
    call memcpy8
    ; continues in save_close

save_close:
    xor  a                            ;; \ Disable the RAM
    ld   [rRAMG], a                   ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writes the record and the options in the cartridge.
;; ❌ Modifies A, BC, DE, HL
save_store::
    ld   a, CART_RAM_ENABLE
    ld   [rRAMG], a
    ld   hl, save_vars                ;; \ The data
    ld   de, sram_data                ;; |
    ld   b, SAVE_SIZE                 ;; |
    call memcpy8                      ;; /
    call save_checksum                ;; \ The sum
    ld   [sram_check], a              ;; /
    ld   hl, SaveMagic                ;; \ The magic word, the last thing
    ld   de, sram_magic               ;; |
    ld   b, 4                         ;; |
    call memcpy8                      ;; /
    jr   save_close

;; ⫷▬ A = the sum of the bytes of sram_data (+ 1, so all 0 is wrong)
;; ⚠️ The RAM must be enabled. ❌ Modifies A, B, HL
save_checksum:
    ld   hl, sram_data
    ld   b, SAVE_SIZE
    ld   a, 1
.sum
    add  [hl]
    inc  hl
    dec  b
    jr   nz, .sum
    ret
