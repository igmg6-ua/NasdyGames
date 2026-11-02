;;==============================================================
;; Sonido: códigos de las notas y de los efectos
;;==============================================================
IF !DEF(SOUND_INC)
DEF SOUND_INC = 1

DEF NOTE_REST = $FE           ;; silence
DEF NOTE_LOOP = $FF           ;; go back to the start of the song
DEF NOTE_STOP = $FD           ;; the song ends

;; Tempo (music_tempo): quarters of a tick per frame
DEF TEMPO_NORMAL = 4          ;; as written
DEF TEMPO_FAST   = 5          ;; 1.25 times: half of the time of the level has gone
DEF TEMPO_FASTER = 6          ;; 1.5 times: only a third of the time is left

;; Sound effects (index of SfxTable)
RSRESET
DEF SFX_SHOOT  RB 1
DEF SFX_COIN   RB 1
DEF SFX_KILL   RB 1
DEF SFX_HURT   RB 1
DEF SFX_PORTAL RB 1
DEF SFX_MENU   RB 1
DEF SFX_TYPE   RB 1
DEF SFX_LIFE   RB 1
DEF SFX_COUNT  RB 0

ENDC
