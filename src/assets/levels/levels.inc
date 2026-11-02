;;==============================================================
;; Los niveles del juego: estructura (Challenge 6, ampliada)
;;==============================================================
IF !DEF(LEVELS_INC)
DEF LEVELS_INC = 1

;; The structure of a level (the offsets of its fields).
;; The levels are generated in assets/levels/levels.asm from levels/*.txt
RSRESET
DEF LVL_MAP        RW 1      ;; 0  the address of its map (WIDTH x HEIGHT tiles, by rows)
DEF LVL_SONG       RW 1      ;; 2  the address of its song (music_play)
DEF LVL_WIDTH      RB 1      ;; 4  size of the map in tiles (up to 32 x 32)
DEF LVL_HEIGHT     RB 1      ;; 5
DEF LVL_PLAYER_TX  RB 1      ;; 6  where the hero starts: column, row (tiles)
DEF LVL_PLAYER_TY  RB 1      ;; 7
DEF LVL_EXIT_TX    RB 1      ;; 8  where the portal appears
DEF LVL_EXIT_TY    RB 1      ;; 9
DEF LVL_TIME       RB 2      ;; 10 seconds to finish it (BCD, high byte first)
DEF LVL_TIME_HALF  RB 2      ;; 12 half of them: below, the music goes faster
DEF LVL_TIME_THIRD RB 2      ;; 14 a third: below, faster still
DEF LVL_AI_EVEN    RB 1      ;; 16 the AI of the even spectres (E_AI_TYPE)
DEF LVL_AI_ODD     RB 1      ;; 17 and of the odd ones
DEF LVL_ENEMIES    RB 1      ;; 18 how many enemies, then each one's TX, TY
DEF LVL_ENEMY_LIST RB 0      ;; 19

ENDC
