;;==============================================================
;; man/man_entity.asm -- Gestor de entidades (Challenge 6)
;;==============================================================
INCLUDE "man/man_entity.inc"

SECTION "Entity array", WRAM0, ALIGN[8]
entity_array::  ds ENTITY_ARRAY_SIZE  ;; in ONE page: see man_entity.inc

SECTION "Entity manager", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; All the entities free (CMP = 0).
;; ❌ Modifies A, BC, HL
man_entity_init::
    ld   hl, entity_array
    ld   b, ENTITY_ARRAY_SIZE
    xor  a
    jp   memset8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Finds a free entity.
;; ⫷▬ DE = the entity, carry = 0
;;     carry = 1: there is none
;; ❌ Modifies A, DE
man_entity_alloc::
    ld   de, entity_array
.next
    ld   a, [de]                      ;; \ CMP = 0: free (or a clears the carry)
    or   a                            ;; |
    ret  z                            ;; /
    ld   a, e                         ;; \ Next entity (same page: only E changes)
    add  SIZEOF_ENTITY                ;; |
    ld   e, a                         ;; /
    cp   LOW(entity_array) + ENTITY_ARRAY_SIZE ;; \ Past the last one?
    jr   nz, .next                    ;; /
    scf                               ;; Full
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Creates an entity: a free one, filled with a copy of a template.
;; 📥 HL = template (SIZEOF_ENTITY bytes)
;; ⫷▬ DE = the new entity, carry = 0
;;     carry = 1: there was no free entity (nothing is created)
;; ❌ Modifies A, B, DE, HL
man_entity_create::
    call man_entity_alloc             ;; DE = a free entity
    ret  c                            ;; None
    push de
    ld   b, SIZEOF_ENTITY             ;; \ Copy the template
    call memcpy8                      ;; /
    pop  de
    and  a                            ;; carry = 0
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Frees an entity. 📥 DE = entity  ❌ Modifies A
man_entity_free::
    xor  a
    ld   [de], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Calls a routine for every entity that has ALL the components of a mask.
;; This is how the systems work: each one only processes the entities that have
;; its components, and does not have to check anything else.
;; 📥 B = mask of components (CMP_...), HL = routine (it gets DE = entity)
;; ⚠️ The routine may modify A, BC, DE, HL: they are saved here.
;;    It may free its entity (the loop goes on with the next one).
;; ❌ Modifies A, DE
man_entity_forall_matching::
    ld   de, entity_array
.next
    ld   a, [de]                      ;; \ Does it have all the components of B?
    and  b                            ;; | (CMP & B == B; a free entity has CMP = 0)
    cp   b                            ;; |
    jr   nz, .skip                    ;; /
    push bc                           ;; \ Call the routine with DE = entity
    push de                           ;; |
    push hl                           ;; |
    call call_hl                      ;; |
    pop  hl                           ;; |
    pop  de                           ;; |
    pop  bc                           ;; /
.skip
    ld   a, e                         ;; \ Next entity
    add  SIZEOF_ENTITY                ;; |
    ld   e, a                         ;; |
    cp   LOW(entity_array) + ENTITY_ARRAY_SIZE ;; |
    jr   nz, .next                    ;; /
    ret
