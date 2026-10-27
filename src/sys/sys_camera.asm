;;==============================================================
;; sys/sys_camera.asm -- La cámara (Challenge 6)
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"

SECTION "Camera vars", WRAM0
cam_y::         ds 1                  ;; the pixel of the world at the top left
cam_x::         ds 1                  ;; of the screen

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
    ld   a, [hl+]                     ;; \ cam_y = camera_axis(Y)
    ld   b, CAM_OFFSET_Y              ;; |
    ld   c, CAM_MAX_Y                 ;; |
    call camera_axis                  ;; |
    ld   [cam_y], a                   ;; /
    ld   a, [hl]                      ;; \ cam_x = camera_axis(X)
    ld   b, CAM_OFFSET_X              ;; |
    ld   c, CAM_MAX_X                 ;; |
    call camera_axis                  ;; |
    ld   [cam_x], a                   ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The camera at the top left (the menus). ❌ Modifies A
sys_camera_reset::
    xor  a
    ld   [cam_y], a
    ld   [cam_x], a
    ret
