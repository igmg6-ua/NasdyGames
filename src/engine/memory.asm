;;==============================================================
;; engine/memory.asm -- Copiar y rellenar memoria
;;==============================================================
SECTION "Memory", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Copies B bytes.
;; 📥 HL = source, DE = destination, B = bytes (1-255; 0 = 256)
;; ⫷▬ HL and DE have advanced B bytes
;; ❌ Modifies A, B, DE, HL
memcpy8::
    ld   a, [hl+]               ;; \ [DE++] = [HL++]
    ld   [de], a                ;; |
    inc  de                     ;; /
    dec  b                      ;; \ while B > 0
    jr   nz, memcpy8            ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fills B bytes with A.
;; 📥 HL = destination, A = value, B = bytes (1-255; 0 = 256)
;; ❌ Modifies B, HL
memset8::
    ld   [hl+], a
    dec  b
    jr   nz, memset8
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Copies BC bytes (BC >= 1).
;; 📥 HL = source, DE = destination, BC = bytes
;; ❌ Modifies A, BC, DE, HL
memcpy16::
    ld   a, [hl+]
    ld   [de], a
    inc  de
    dec  bc                     ;; \ dec bc does not change the flags:
    ld   a, b                   ;; | Z only when B = 0 and C = 0
    or   c                      ;; /
    jr   nz, memcpy16
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fills BC bytes with A (BC >= 1).
;; 📥 HL = destination, A = value, BC = bytes
;; ❌ Modifies A, BC, D, HL
memset16::
    ld   d, a
.loop
    ld   a, d
    ld   [hl+], a
    dec  bc
    ld   a, b
    or   c
    jr   nz, .loop
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; "call call_hl" is "call hl" (an instruction that does not exist).
call_hl::
    jp   hl
