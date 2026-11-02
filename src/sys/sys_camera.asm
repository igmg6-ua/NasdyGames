;;==============================================================
;; sys/sys_camera.asm -- La cámara (Challenge 6)
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "man/man_map.inc"

SECTION "Camera vars", WRAM0
cam_y::         ds 1                  ;; the pixel of the world at the top left
cam_x::         ds 1                  ;; of the screen
cam_max_y::     ds 1                  ;; the largest camera: it depends on the size of the map
cam_max_x::     ds 1                  ;; (sys_camera_set_limits)

SECTION "Camera", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ⫷▬ B = camera Y, C = camera X
;; ❌ Modifies A, BC. Does NOT modify DE or HL
sys_camera_get::
    ld   a, [cam_y]
    ld   b, a
    ld   a, [cam_x]
    ld   c, a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The camera for ONE axis: position - offset, not below 0 and not above the maximum.
;; 📥 A = position of the entity in that axis, B = offset, C = maximum of the camera
;; ⫷▬ A = the camera in that axis
;; ❌ Modifies A
camera_axis::
    sub  b                            ;; \ A = position - offset
    jr   nc, .not_negative            ;; / No carry: it did not go below 0

    xor  a                            ;; \ Below 0 (it wrapped around): the camera is 0
    ret                               ;; /

.not_negative
    cp   c                            ;; \ Is A below the maximum?
    ret  c                            ;; / Yes: it is the camera

    ld   a, c                         ;; \ No: the camera stays at its maximum
    ret                               ;; /

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The camera follows an entity: it stays in the middle of the screen, except
;; near the edges of the world.
;; 📥 DE = entity
;; ❌ Modifies A, BC, HL
sys_camera_update::
    FIELD_HL E_Y                      ;; HL = &entity.Y
    ld   a, [cam_max_y]               ;; \ cam_y = camera_axis(Y)
    ld   c, a                         ;; |
    ld   b, CAM_OFFSET_Y              ;; |
    ld   a, [hl+]                     ;; | (HL -> X)
    call camera_axis                  ;; |
    ld   [cam_y], a                   ;; /
    ld   a, [cam_max_x]               ;; \ cam_x = camera_axis(X)
    ld   c, a                         ;; |
    ld   b, CAM_OFFSET_X              ;; |
    ld   a, [hl]                      ;; |
    call camera_axis                  ;; |
    ld   [cam_x], a                   ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The limits of the camera for a map: it never shows what is outside it
;; (if the map is smaller than the screen, the camera stays at 0).
;;    cam_max_x = width * 8 - 160          cam_max_y = height * 8 - VIEW_HEIGHT
;; 📥 B = width, C = height (tiles)
;; ❌ Modifies A
sys_camera_set_limits::
    ld   a, b                         ;; \ X
    call .pixels                      ;; |
    jr   z, .x_full                   ;; | (0: the full 256 pixels)
    sub  SCREEN_WIDTH                 ;; |
    jr   nc, .x_ok                    ;; |
    xor  a                            ;; |
    jr   .x_ok                        ;; |
.x_full                               ;; |
    ld   a, LOW(-SCREEN_WIDTH)        ;; |
.x_ok                                 ;; |
    ld   [cam_max_x], a               ;; /
    ld   a, c                         ;; \ Y
    call .pixels                      ;; |
    jr   z, .y_full                   ;; |
    sub  VIEW_HEIGHT                  ;; |
    jr   nc, .y_ok                    ;; |
    xor  a                            ;; |
    jr   .y_ok                        ;; |
.y_full                               ;; |
    ld   a, LOW(-VIEW_HEIGHT)         ;; |
.y_ok                                 ;; |
    ld   [cam_max_y], a               ;; /
    ret
;; A = tiles * 8, NZ. A map of 32 tiles (256 pixels, that do not fit in a
;; byte) gives Z instead: its maximum is set apart (256 - 160 = 96).
.pixels
    cp   MAP_WIDTH                    ;; \ 32 tiles: Z
    jr   nc, .full                    ;; /
    add  a                            ;; \ * 8 (never 0: NZ)
    add  a                            ;; |
    add  a                            ;; /
    ret
.full
    xor  a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The camera at the top left (the menus). ❌ Modifies A
sys_camera_reset::
    xor  a
    ld   [cam_y], a
    ld   [cam_x], a
    ret
