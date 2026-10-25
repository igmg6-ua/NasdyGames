;;==============================================================
;; Gestor de entidades: estructura y componentes
;; (la misma entidad que el Challenge 6)
;;==============================================================
IF !DEF(MAN_ENTITY_INC)
DEF MAN_ENTITY_INC = 1
;;--------------------------------------------------------------
;; Entities: array of MAX_ENTITIES entities of SIZEOF_ENTITY bytes
;;--------------------------------------------------------------
DEF MAX_ENTITIES = 12
RSRESET
DEF E_CMP        RB 1         ;; 0  Which components the entity has (bitflags)
DEF E_SPRITE     RB 1         ;;    SPRITE (offset): the same 4 bytes as an OAM entry
DEF E_Y = E_SPRITE            ;; 1 ┐ E_Y = E_SPRITE. WORLD coordinates in pixels
DEF E_X          RB 1         ;; 2 │ (top left of its image): 0-255, as the map
DEF E_TILE       RB 1         ;; 3 │ TILE: the first tile of the image it shows now
DEF E_ATTR       RB 1         ;; 4 ┘ ATTR: flips (and palette) of its sprites
DEF E_VY         RB 1         ;; 5 ┐ PHYSICS: velocity (signed) in pixels per frame
DEF E_VX         RB 1         ;; 6 ┘
DEF E_KIND       RB 1         ;; 7  COLLIDER: what kind of thing this entity is
DEF E_DIR        RB 1         ;; 8  The way it faces: DIR_DOWN, DIR_UP...
DEF E_SHEET      RB 1         ;; 9  ANIMATION: the first tile of its sheet of images
DEF E_TICK       RB 1         ;; 10 ANIMATION: frames it has been walking (its step)
DEF E_LIFE       RB 1         ;; 11 SELFDESTROY: frames left before it disappears
DEF E_THINK      RB 1         ;; 12 AI: frames left until it chooses where to go
DEF E_RESERVED   RB 3         ;; 13 Free: for the components of the game (below)
DEF SIZEOF_ENTITY RB 0        ;; = 16
DEF ENTITY_ARRAY_SIZE = MAX_ENTITIES * SIZEOF_ENTITY

;; Los 3 bytes libres, en este juego:
DEF E_AI_TYPE = E_RESERVED    ;; 13 AI: cómo persigue (AI_HUNT_BIT, AI_FAST_BIT)

;;--------------------------------------------------------------
;; ALIGNMENT: the array is in ONE page (ALIGN[8], <= 256 bytes):
;;  1. The HIGH byte is the same for ALL the entities and their fields.
;;  2. The address of a field is the low byte of the entity + the offset.
;;  3. An entity can be remembered with ONE byte: its low byte.
;;     ENTITY_NONE is not an entity, so it means "there is none".
;;--------------------------------------------------------------
DEF ENTITY_NONE = $FF
ASSERT ENTITY_ARRAY_SIZE <= ENTITY_NONE

;; The image of an entity: 16 x 16 pixels (2 sprites of 8 x 16, side by side)
DEF IMAGE_WIDTH  = 16
DEF IMAGE_HEIGHT = 16

;; Bits of CMP. CMP = 0 -> the entity is FREE.
DEF CMP_SPRITE_BIT      = 0
DEF CMP_PHYSICS_BIT     = 1
DEF CMP_COLLIDER_BIT    = 2
DEF CMP_SELFDESTROY_BIT = 3
DEF CMP_INPUT_BIT       = 4
DEF CMP_ANIMATION_BIT   = 5
DEF CMP_AI_BIT          = 6
DEF CMP_ALIVE_BIT       = 7
DEF CMP_SPRITE      = 1 << CMP_SPRITE_BIT       ;; It is drawn (2 sprites of 8x16)
DEF CMP_PHYSICS     = 1 << CMP_PHYSICS_BIT      ;; It moves, and the map stops it
DEF CMP_COLLIDER    = 1 << CMP_COLLIDER_BIT     ;; It collides with other entities
DEF CMP_SELFDESTROY = 1 << CMP_SELFDESTROY_BIT  ;; It disappears after E_LIFE frames
DEF CMP_INPUT       = 1 << CMP_INPUT_BIT        ;; Controlled by the player
DEF CMP_ANIMATION   = 1 << CMP_ANIMATION_BIT    ;; Its image follows step and DIR
DEF CMP_AI          = 1 << CMP_AI_BIT           ;; It decides where to go by itself
DEF CMP_ALIVE       = 1 << CMP_ALIVE_BIT

;; Directions: the value of E_DIR, the index of DirVelocity and DirImage
DEF DIR_DOWN  = 0
DEF DIR_UP    = 1
DEF DIR_LEFT  = 2
DEF DIR_RIGHT = 3
DEF DIR_MASK  = %00000011

ENDC
