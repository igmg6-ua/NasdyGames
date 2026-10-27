;;==============================================================
;; engine/dma.asm -- Copiar los sprites a la OAM con DMA (Challenge 6, ej. 1)
;;==============================================================
INCLUDE "engine/hardware.inc"

DEF DMA_WAIT_LOOPS = 40               ;; 40 loops x 4 cycles = 160: what the copy lasts

SECTION "Shadow OAM", WRAM0, ALIGN[8]
shadow_oam::    ds OAM_SIZE           ;; copy of the OAM in WRAM. Aligned ($xx00)

SECTION "DMA", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; This is the code that will run from HRAM (see dma_init). Its addresses are absolute
;; (ldh [rDMA]...) and it uses no jumps to the outside, so it works from any place.
DMARoutine:
    ld   a, HIGH(shadow_oam)          ;; \ rDMA = the page of the shadow OAM:
    ldh  [rDMA], a                    ;; / the copy starts now
    ld   a, DMA_WAIT_LOOPS            ;; \ Wait for the copy to end,
.wait                                 ;; | doing nothing (only HRAM can be read):
    dec  a                            ;; | 40 loops x 4 cycles
    jr   nz, .wait                    ;; /
    ret
DMARoutineEnd:

;; Its place in HRAM (after the routine: its size must be known here)
SECTION "DMA routine in HRAM", HRAM
hDMARoutine:    ds DMARoutineEnd - DMARoutine

SECTION "DMA init", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Copies the DMA routine to HRAM. It is done once, when the console starts.
;; ❌ Modifies A, B, DE, HL
dma_init::
    ld   hl, DMARoutine               ;; \ HL = the routine in the ROM
    ld   de, hDMARoutine              ;; | DE = its place in HRAM
    ld   b, DMARoutineEnd - DMARoutine ;; | B = its size
    jp   memcpy8                      ;; / Copy it

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Launches the DMA: copies the shadow OAM to the OAM. In VBLANK.
;; ❌ Modifies A
dma_run::
    jp   hDMARoutine
