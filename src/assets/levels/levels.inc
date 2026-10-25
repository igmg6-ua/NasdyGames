;;==============================================================
;; Los niveles del juego: estructura (Challenge 6)
;;==============================================================
IF !DEF(LEVELS_INC)
DEF LEVELS_INC = 1

;; The structure of a level (the offsets of its fields).
;; The levels are generated in assets/levels/levels.asm from levels/*.txt
RSRESET
DEF LVL_MAP        RW 1      ;; 0  the address of its map (MAP_SIZE tiles)
DEF LVL_SONG       RW 1      ;; 2  the address of its song (music_play)
DEF LVL_PLAYER_TX  RB 1      ;; 4  where the hero starts: column, row (tiles)
DEF LVL_PLAYER_TY  RB 1      ;; 5
DEF LVL_EXIT_TX    RB 1      ;; 6  where the portal appears
DEF LVL_EXIT_TY    RB 1      ;; 7
DEF LVL_ENEMIES    RB 1      ;; 8  how many enemies, then each one's TX, TY
DEF LVL_ENEMY_LIST RB 0      ;; 9

ENDC
