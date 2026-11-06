;;==============================================================
;; Escena del juego: constantes y reglas
;;==============================================================
IF !DEF(GAME_INC)
DEF GAME_INC = 1

INCLUDE "man/man_entity.inc"
INCLUDE "assets/levels/level_count.inc"

;; KIND (one bit per kind, so a mask can select several)
DEF KIND_PLAYER = %0000001
DEF KIND_SHOT   = %0000010
DEF KIND_ENEMY  = %0000100
DEF KIND_PORTAL = %0001000
DEF KIND_GUN    = %0010000    ;; things the hero picks up:
DEF KIND_SHIELD = %0100000    ;;   it stops one hit of a spectre
DEF KIND_HEART  = %1000000    ;;   a heart more (or HEART_TIME_BONUS seconds)

;; The hero is always the first entity created after man_entity_init
DEF PLAYER_ENTITY EQUS "entity_array"

;;--------------------------------------------------------------
;; Game rules (all positions are WORLD pixels: 0-255, the map is 256 x 256)
;;--------------------------------------------------------------
DEF HEARTS_START    = 3       ;; hearts at the start of a game
DEF HEARTS_MAX      = 5       ;; most hearts (and cells of the HUD)
                              ;; NUM_LEVELS: assets/levels/level_count.inc (generated)
DEF WALK_SPEED      = 1       ;; pixels per frame of anything that walks
DEF SHOT_SPEED      = 3       ;; pixels per frame of a bullet
DEF SHOT_FRAMES     = 60      ;; frames a bullet lives if it hits nothing
DEF HURT_FRAMES     = 90      ;; frames the hero is immune after a hit (and flashes)
DEF HURT_FLASH_MASK = %00000100 ;; bit 2 of hurt_timer: palette changes every 4 frames
DEF POOF_FRAMES     = 16      ;; frames the cloud of a defeated spectre stays
DEF AI_THINK_MIN    = 24      ;; a spectre chooses a new way in 24 + (0..31) frames
DEF AI_THINK_MASK   = %00011111
DEF AI_STILL_BIT    = 2       ;; bit 2 (after moving the bits): stand still
DEF AI_HUNT_BIT     = 0       ;; E_AI_TYPE: it may go towards the hero
DEF AI_FAST_BIT     = 1       ;; E_AI_TYPE: it does not skip frames
DEF AI_SLOW_MASK    = %00000011 ;; a slow spectre skips 1 frame of 4
DEF ANIM_STEP_MASK  = %00001000 ;; bit 3 of TICK: the step changes every 8 frames
DEF HIT_H           = 12      ;; two entities touch if |dY| < HIT_H and |dX| < HIT_W
DEF HIT_W           = 12
DEF KILL_TIME_BONUS = $05     ;; seconds (BCD) for each spectre defeated
DEF HEART_TIME_BONUS = $15    ;; seconds (BCD) of a heart picked up with all the hearts
DEF TIME_MAX_HI     = $09     ;; the clock never goes over 999 seconds
DEF PICKUPS_LEVEL   = 2       ;; the shield and the heart appear from level 3 (index 2)
DEF GUN_NEAR_MIN    = 3      ;; the gun, near the hero: from 3 to 9 tiles WALKING
DEF GUN_NEAR_MAX    = 9      ;;   (a room is 3 tiles: 1 to 3 rooms away)
DEF PICKUP_MIN_DIST = 16      ;; the shield and the heart, at least 16
DEF PICKUP_TRIES    = 200     ;; random places tried before giving up
DEF FRAMES_PER_SEC  = 60
DEF CORNER_ASSIST   = 5       ;; pixels the hero slides to get round a corner

;; How a level ends (game_result)
DEF RESULT_NONE    = 0        ;; still playing
DEF RESULT_CLEAR   = 1        ;; the hero reached the portal
DEF RESULT_DEAD    = 2        ;; no hearts left
DEF RESULT_TIMEUP  = 3        ;; no time left
DEF RESULT_VICTORY = 4        ;; the portal of the last level
DEF ENDING_FRAMES  = 90       ;; the game stops 1.5 s before the next screen

;; The AI of the spectres of each level (E_AI_TYPE): one for the even spectres
;; and one for the odd ones
DEF AI_RANDOM = 0
DEF AI_HUNTER = 1 << AI_HUNT_BIT
DEF AI_FAST   = 1 << AI_FAST_BIT

;; The part of an entity that the map stops: its FEET, a box of 8 x 8 pixels.
DEF FEET_LEFT   = 4
DEF FEET_RIGHT  = 11
DEF FEET_TOP    = 8
DEF FEET_BOTTOM = 15

;; Camera: the hero stays in the middle of the part of the world that is seen
DEF VIEW_HEIGHT  = 144 - 8                     ;; the HUD takes the last row
DEF CAM_OFFSET_X = (160 - IMAGE_WIDTH) / 2     ;; 72
DEF CAM_OFFSET_Y = (VIEW_HEIGHT - IMAGE_HEIGHT) / 2   ;; 60
;; The maximum of the camera depends on the size of the map (cam_max_x, cam_max_y):
;;   width * 8 - 160 and height * 8 - VIEW_HEIGHT (0 if the map is smaller)

ENDC
