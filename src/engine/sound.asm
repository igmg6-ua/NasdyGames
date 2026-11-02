;;==============================================================
;; engine/sound.asm -- Efectos de sonido y música
;;
;; Canales:  1 (pulso con barrido) y 4 (ruido) -> efectos
;;           2 (pulso) -> melodía           3 (onda) -> bajo
;; Así un efecto nunca corta la música.
;;
;; Una canción son dos listas de pares (nota, frames). music_update se llama
;; una vez por frame: cuando se acaba una nota, toca la siguiente.
;;==============================================================
INCLUDE "engine/hardware.inc"
INCLUDE "engine/sound.inc"

DEF MELODY_DUTY   = %10000000         ;; NR21: 50 % duty
DEF MELODY_ENV    = $A3               ;; NR22: volume 10, fading slowly
DEF BASS_LEVEL    = %00100000         ;; NR32: wave at 100 %

SECTION "Sound vars", WRAM0
music_pause::   ds 1                  ;; 1: the game is paused (the music is silent)
mus_song:       ds 2                  ;; the song playing (for the loop)
mus_mel_ptr:    ds 2                  ;; next pair of each voice (high byte 0: stopped)
mus_mel_wait:   ds 1                  ;; frames left of the current note
mus_bass_ptr:   ds 2
mus_bass_wait:  ds 1
music_tempo::   ds 1                  ;; ticks of the song per 4 frames: TEMPO_NORMAL...
mus_tempo_acc:  ds 1                  ;; quarters of a tick not played yet

SECTION "Sound", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Turns the sound on and loads the wave of channel 3.
;; ❌ Modifies A, B, DE, HL
sound_init::
    ld   a, AUDENA_ON                 ;; \ Sound on, all channels, both speakers
    ldh  [rAUDENA], a                 ;; |
    ld   a, AUDTERM_ALL               ;; |
    ldh  [rAUDTERM], a                ;; |
    ld   a, AUDVOL_MAX                ;; |
    ldh  [rAUDVOL], a                 ;; /
    xor  a                            ;; \ Channel 3 off to write its wave
    ldh  [rAUD3ENA], a                ;; /
    ld   hl, BassWave                 ;; \ The wave: a soft triangle
    ld   de, WAVE_RAM                 ;; |
    ld   b, 16                        ;; |
    call memcpy8                      ;; /
    xor  a
    ld   [music_pause], a
    jp   music_stop

BassWave:
    db $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Plays a sound effect.
;; 📥 A = SFX_*
;; ❌ Modifies A, B, HL
sfx_play::
    ld   l, a                         ;; \ HL = SfxTable + A * 6
    add  a                            ;; |
    add  l                            ;; | (A * 3)
    add  a                            ;; | (A * 6)
    ld   hl, SfxTable                 ;; |
    add  l                            ;; |
    ld   l, a                         ;; |
    jr   nc, .no_carry                ;; |
    inc  h                            ;; |
.no_carry                             ;; /
    ld   a, [hl+]                     ;; \ Channel 4 (noise)?
    cp   4                            ;; |
    jr   z, .noise                    ;; /
    ld   a, [hl+]                     ;; \ Channel 1: sweep, duty, envelope, frequency
    ldh  [rAUD1SWEEP], a              ;; |
    ld   a, [hl+]                     ;; |
    ldh  [rAUD1LEN], a                ;; |
    ld   a, [hl+]                     ;; |
    ldh  [rAUD1ENV], a                ;; |
    ld   a, [hl+]                     ;; |
    ldh  [rAUD1LOW], a                ;; |
    ld   a, [hl]                      ;; |
    ldh  [rAUD1HIGH], a               ;; / (bit 7: start)
    ret
.noise
    ld   a, [hl+]                     ;; \ Channel 4: length, envelope, noise, start
    ldh  [rAUD4LEN], a                ;; |
    ld   a, [hl+]                     ;; |
    ldh  [rAUD4ENV], a                ;; |
    ld   a, [hl+]                     ;; |
    ldh  [rAUD4POLY], a               ;; |
    ld   a, [hl]                      ;; |
    ldh  [rAUD4GO], a                 ;; /
    ret

;; 6 bytes each: channel, then the registers of that channel
SfxTable:
    db 4, $00, $F1, $32, $80, 0       ;; SFX_SHOOT:  a short hiss
    db 1, $17, $80, $F2, $7B, $87     ;; SFX_COIN:   a high "ding" that goes up
    db 4, $00, $F4, $55, $80, 0       ;; SFX_KILL:   a deeper noise
    db 1, $1E, $40, $F3, $D6, $86     ;; SFX_HURT:   a tone that falls
    db 1, $76, $80, $F7, $0A, $86     ;; SFX_PORTAL: a long tone that rises
    db 1, $00, $80, $81, $83, $87     ;; SFX_MENU:   a short blip
    db 1, $00, $80, $61, $40, $87     ;; SFX_TYPE:   a click
    db 1, $14, $80, $F4, $A4, $86     ;; SFX_LIFE:   rising, bright
ASSERT @ - SfxTable == SFX_COUNT * 6

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Starts a song.
;; 📥 HL = song (dw melody, dw bass)
;; ❌ Modifies A, HL
music_play::
    ld   a, l
    ld   [mus_song], a
    ld   a, h
    ld   [mus_song + 1], a
    ld   a, [hl+]                     ;; \ The two voices from the start
    ld   [mus_mel_ptr], a             ;; |
    ld   a, [hl+]                     ;; |
    ld   [mus_mel_ptr + 1], a         ;; |
    ld   a, [hl+]                     ;; |
    ld   [mus_bass_ptr], a            ;; |
    ld   a, [hl]                      ;; |
    ld   [mus_bass_ptr + 1], a        ;; /
    ld   a, 1                         ;; \ The first note sounds in the next update
    ld   [mus_mel_wait], a            ;; |
    ld   [mus_bass_wait], a           ;; /
    ld   a, TEMPO_NORMAL              ;; \ Every song starts at its normal speed
    ld   [music_tempo], a             ;; |
    xor  a                            ;; |
    ld   [mus_tempo_acc], a           ;; /
    ld   a, $80                       ;; (channel 3 on)
    ldh  [rAUD3ENA], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Stops the music. ❌ Modifies A
music_stop::
    xor  a
    ld   [mus_mel_ptr + 1], a
    ld   [mus_bass_ptr + 1], a
    ; continues in music_mute

music_mute:
    xor  a
    ldh  [rAUD2ENV], a                ;; \ Melody silent
    ld   a, $80                       ;; |
    ldh  [rAUD2HIGH], a               ;; /
    xor  a                            ;; \ Bass silent
    ldh  [rAUD3LEVEL], a              ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Once per frame. The tempo: every frame music_tempo quarters of a tick are
;; added; each full tick (4 quarters) advances the song one frame of its notes.
;; TEMPO_NORMAL (4) = 1 tick per frame: the song as it is written.
;; 5 = 1.25 times faster, 6 = 1.5 times faster (2 ticks in some frames).
;; The volume never changes: only the speed.
;; ❌ Modifies A, BC, DE, HL
music_update::
    ld   a, [music_choice]            ;; \ Music off in the menu, or paused: silence
    or   a                            ;; | (the song does not advance)
    jp   z, music_mute                ;; |
    ld   a, [music_pause]             ;; |
    or   a                            ;; |
    jp   nz, music_mute               ;; /
    ld   a, [music_tempo]             ;; \ acc += tempo
    ld   hl, mus_tempo_acc            ;; |
    add  [hl]                         ;; |
    ld   [hl], a                      ;; /
.tick
    ld   a, [mus_tempo_acc]           ;; \ A full tick?
    cp   TEMPO_NORMAL                 ;; |
    ret  c                            ;; /
    sub  TEMPO_NORMAL                 ;; \ acc -= 1 tick
    ld   [mus_tempo_acc], a           ;; /
    call music_tick
    jr   .tick

;; One tick: the waits go down, and a voice whose note has ended plays the next one.
music_tick:
    ld   a, [mus_mel_ptr + 1]         ;; \ Melody
    or   a                            ;; | (stopped if the high byte is 0)
    jr   z, .bass                     ;; |
    ld   hl, mus_mel_wait             ;; |
    dec  [hl]                         ;; |
    jr   nz, .bass                    ;; |
    ld   hl, mus_mel_ptr              ;; |
    call music_next                   ;; | B = note, C = frames
    ld   a, c                         ;; |
    ld   [mus_mel_wait], a            ;; |
    call melody_note                  ;; /
.bass
    ld   a, [mus_bass_ptr + 1]        ;; \ Bass
    or   a                            ;; |
    ret  z                            ;; |
    ld   hl, mus_bass_wait            ;; |
    dec  [hl]                         ;; |
    ret  nz                           ;; |
    ld   hl, mus_bass_ptr             ;; |
    call music_next                   ;; |
    ld   a, c                         ;; |
    ld   [mus_bass_wait], a           ;; |
    jp   bass_note                    ;; /

;; Reads the next pair of a voice and advances its pointer.
;; 📥 HL = &pointer of the voice   ⫷▬ B = note, C = frames
music_next:
    push hl
    ld   a, [hl+]                     ;; \ DE = the pointer
    ld   e, a                         ;; |
    ld   d, [hl]                      ;; /
    ld   a, [de]                      ;; \ End of the voice?
    cp   NOTE_LOOP                    ;; |
    jr   nz, .not_loop                ;; /
    ld   a, [mus_song]                ;; \ Loop: back to the start of this voice
    ld   l, a                         ;; | (HL = song: dw melody, dw bass)
    ld   a, [mus_song + 1]            ;; |
    ld   h, a                         ;; |
    pop  bc                           ;; | which voice? BC = its pointer
    push bc                           ;; |
    ld   a, c                         ;; |
    cp   LOW(mus_mel_ptr)             ;; |
    jr   z, .melody_start             ;; |
    inc  hl                           ;; |
    inc  hl                           ;; |
.melody_start                         ;; |
    ld   a, [hl+]                     ;; |
    ld   e, a                         ;; |
    ld   d, [hl]                      ;; |
    ld   a, [de]                      ;; /
.not_loop
    cp   NOTE_STOP                    ;; \ The song has ended: stop this voice
    jr   nz, .note                    ;; |
    pop  hl                           ;; |
    inc  hl                           ;; |
    ld   [hl], 0                      ;; | (high byte 0)
    ld   bc, NOTE_REST << 8 | 1       ;; |
    ret                               ;; /
.note
    ld   b, a                         ;; \ B = note, C = frames
    inc  de                           ;; |
    ld   a, [de]                      ;; |
    ld   c, a                         ;; |
    inc  de                           ;; /
    pop  hl                           ;; \ Save the new pointer
    ld   a, e                         ;; |
    ld   [hl+], a                     ;; |
    ld   [hl], d                      ;; /
    ret

;; HL = NoteFreq[B] (11-bit value). ⫷▬ E = low, D = high
note_freq:
    ld   a, b
    add  a
    ld   l, a
    ld   h, 0
    ld   de, NoteFreq
    add  hl, de
    ld   a, [hl+]
    ld   e, a
    ld   d, [hl]
    ret

;; 📥 B = note
melody_note:
    ld   a, b
    cp   NOTE_REST
    jr   nz, .play
    xor  a                            ;; \ Rest: volume 0
    ldh  [rAUD2ENV], a                ;; |
    ld   a, $80                       ;; |
    ldh  [rAUD2HIGH], a               ;; /
    ret
.play
    call note_freq
    ld   a, MELODY_DUTY
    ldh  [rAUD2LEN], a
    ld   a, MELODY_ENV
    ldh  [rAUD2ENV], a
    ld   a, e
    ldh  [rAUD2LOW], a
    ld   a, d
    or   $80                          ;; start
    ldh  [rAUD2HIGH], a
    ret

;; 📥 B = note
bass_note:
    ld   a, b
    cp   NOTE_REST
    jr   nz, .play
    xor  a
    ldh  [rAUD3LEVEL], a
    ret
.play
    call note_freq
    ld   a, BASS_LEVEL
    ldh  [rAUD3LEVEL], a
    ld   a, e
    ldh  [rAUD3LOW], a
    ld   a, d
    or   $80
    ldh  [rAUD3HIGH], a
    ret
