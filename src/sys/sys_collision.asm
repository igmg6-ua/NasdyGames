;;==============================================================
;; sys/sys_collision.asm -- ¿Se tocan dos entidades?
;;==============================================================
INCLUDE "scn/scn_game.inc"

SECTION "Collision", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Two entities touch if their images are closer than HIT_H in Y and HIT_W in X.
;; All the images are 16 x 16, so comparing their top left corners is enough.
;; HIT_H and HIT_W (12) are a bit smaller than the image: the corners of the
;; images are usually empty, and touching "just a pixel" would feel unfair.
;; 📥 HL = &entity A.Y, DE = entity B
;; ⫷▬ carry: they touch
;; ❌ Modifies A, HL. Does NOT modify BC or DE
sys_collision_overlap::
    push de
    ld   a, e                         ;; \ DE = &B.Y
    add  E_Y                          ;; |
    ld   e, a                         ;; /
    ld   a, [de]                      ;; \ A = |B.Y - A.Y|
    sub  [hl]                         ;; |
    jr   nc, .dy                      ;; |
    cpl                               ;; |
    inc  a                            ;; /
.dy
    cp   HIT_H                        ;; \ Too far in Y? (no carry)
    jr   nc, .end                     ;; /
    inc  e                            ;; \ A = |B.X - A.X|
    inc  l                            ;; |
    ld   a, [de]                      ;; |
    sub  [hl]                         ;; |
    jr   nc, .dx                      ;; |
    cpl                               ;; |
    inc  a                            ;; /
.dx
    cp   HIT_W                        ;; carry: close in X too: they touch
.end
    pop  de
    ret
