;;==============================================================
;; scn/scn_setup.asm -- Ajustes: idioma, héroe, música y nombre
;;
;; Cada línea del menú se vuelve a dibujar sólo cuando cambia, en la fila
;; de texto del VBLANK (row_begin / row_commit): una línea por frame.
;; setup_dirty dice qué líneas faltan por dibujar (un bit cada una).
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"
INCLUDE "engine/charmap.inc"

;; The items of the menu (setup_sel) and their rows
RSRESET
DEF ITEM_LANG   RB 1
DEF ITEM_HERO   RB 1
DEF ITEM_MUSIC  RB 1
DEF ITEM_NAME   RB 1
DEF ITEM_PLAY   RB 1
DEF ITEM_COUNT  RB 0
DEF FIRST_ITEM_ROW = 4                ;; item i is in row 4 + 2 * i
DEF TITLE_ROW      = 1
DEF HELP_ROW       = 16
DEF LABEL_COLUMN   = 2
DEF VALUE_COLUMN   = 11               ;; "<ESPAÑOL>": columns 11-19
DEF NAME_COLUMN    = VALUE_COLUMN + 1
DEF NAME_LETTERS   = NAME_SIZE - 1    ;; 8

;; The lines (bits of setup_dirty): the items, then the title and the help
DEF LINE_TITLE = ITEM_COUNT
DEF LINE_HELP  = ITEM_COUNT + 1
DEF LINE_COUNT = ITEM_COUNT + 2
DEF DIRTY_ALL  = (1 << LINE_COUNT) - 1

DEF CURSOR_OAM_X  = OAM_X_OFFSET      ;; column 0
DEF PREVIEW_OAM_Y = TITLE_ROW * 8 + OAM_Y_OFFSET - 4
DEF PREVIEW_OAM_X = 17 * 8 + OAM_X_OFFSET
DEF BLINK_MASK    = %00001111         ;; the letter being edited blinks every 16 frames
DEF BLINK_BIT     = 4

SECTION "Setup vars", WRAM0
setup_sel:      ds 1                  ;; the item with the cursor
setup_edit:     ds 1                  ;; 1: writing the name
name_pos:       ds 1                  ;; the letter of the name being written
setup_dirty:    ds 1                  ;; lines to draw again (1 bit each)

SECTION "Setup scene", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ❌ Modifies A, BC, DE, HL
scn_setup_init::
    call screen_clear
    xor  a
    ld   [setup_sel], a
    ld   [setup_edit], a
    ld   a, DIRTY_ALL                 ;; \ All the lines, now (the screen is off:
    ld   [setup_dirty], a             ;; | each one is copied at once)
.line                                 ;; |
    call setup_draw_next              ;; |
    call row_vblank                   ;; |
    ld   a, [setup_dirty]             ;; |
    or   a                            ;; |
    jr   nz, .line                    ;; /
    call setup_sprites
    ld   hl, scn_setup_update
    ld   a, LCDC_NO_WINDOW
    jp   scene_set

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ❌ Modifies A, BC, DE, HL
scn_setup_update:
    ld   a, [setup_edit]
    or   a
    jr   z, .menu
    call setup_edit_update
    jr   .draw
.menu
    call setup_menu_update
.draw
    call setup_draw_next
    jp   setup_sprites

;; Moving through the menu and changing the options
setup_menu_update:
    ld   a, [input_pressed]
    ld   b, a
    bit  BTN_START_BIT, b             ;; \ START: play, from any item
    jr   nz, setup_play               ;; /
    ld   hl, setup_sel
    bit  BTN_UP_BIT, b                ;; \ UP: the item above (the last one, from the first)
    jr   z, .not_up                   ;; |
    ld   a, [hl]                      ;; |
    or   a                            ;; |
    jr   nz, .up                      ;; |
    ld   a, ITEM_COUNT                ;; |
.up                                   ;; |
    dec  a                            ;; |
    ld   [hl], a                      ;; |
    jr   .moved                       ;; /
.not_up
    bit  BTN_DOWN_BIT, b              ;; \ DOWN: the item below
    jr   z, .not_down                 ;; |
    ld   a, [hl]                      ;; |
    inc  a                            ;; |
    cp   ITEM_COUNT                   ;; |
    jr   c, .down                     ;; |
    xor  a                            ;; |
.down                                 ;; |
    ld   [hl], a                      ;; /
.moved
    ld   a, SFX_MENU
    jp   sfx_play
.not_down
    ld   a, b                         ;; \ LEFT, RIGHT or A: change the item
    and  BTN_LEFT | BTN_RIGHT | BTN_A ;; |
    ret  z                            ;; /
    ld   a, [hl]
    cp   ITEM_LANG
    jr   z, .language
    cp   ITEM_HERO
    jr   z, .hero
    cp   ITEM_MUSIC
    jr   z, .music
    bit  BTN_A_BIT, b                 ;; \ The name and PLAY: only with A
    ret  z                            ;; /
    cp   ITEM_PLAY
    jr   z, setup_play
    jp   setup_edit_start
.language
    ld   hl, language
    ld   c, DIRTY_ALL                 ;; (all the texts change)
    jr   .toggle
.hero
    ld   hl, gender
    ld   c, 1 << ITEM_HERO
    jr   .toggle
.music
    ld   hl, music_choice
    ld   c, 1 << ITEM_MUSIC
.toggle
    ld   a, [hl]                      ;; \ The option: 0 <-> 1
    xor  1                            ;; |
    ld   [hl], a                      ;; /
    ld   a, [setup_dirty]             ;; \ Its line(s), again
    or   c                            ;; |
    ld   [setup_dirty], a             ;; /
    jr   .moved

;; Let's play: the options are saved, and a new game starts.
setup_play:
    call save_store
    call game_new
    ld   a, SFX_PORTAL
    call sfx_play
    ld   hl, scn_level_init
    jp   scene_request

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writing the name: UP / DOWN change the letter, LEFT / RIGHT move, B deletes,
;; A or START end. While writing, the name always has NAME_LETTERS letters
;; (spaces at the end); when it ends, those spaces are removed.

;; Starts writing: the name, padded with spaces
setup_edit_start:
    ld   hl, player_name
    ld   bc, NAME_LETTERS << 8        ;; B = letters, C = 0: the end not found yet
.pad
    ld   a, [hl]                      ;; \ From the end of the name: spaces
    cp   TEXT_END                     ;; |
    jr   nz, .letter                  ;; |
    inc  c                            ;; | (C != 0: the end has been found)
.letter                               ;; |
    ld   a, c                         ;; |
    or   a                            ;; |
    jr   z, .keep                     ;; |
    ld   [hl], " "                    ;; |
.keep                                 ;; |
    inc  hl                           ;; |
    dec  b                            ;; |
    jr   nz, .pad                     ;; /
    ld   [hl], TEXT_END
    xor  a
    ld   [name_pos], a
    inc  a
    ld   [setup_edit], a
    jp   setup_edit_dirty

setup_edit_update:
    ld   a, [input_pressed]
    ld   b, a
    and  BTN_A | BTN_START            ;; \ A or START: done
    jr   nz, setup_edit_end           ;; /
    bit  BTN_UP_BIT, b
    jr   nz, .next_letter
    bit  BTN_DOWN_BIT, b
    jr   nz, .previous_letter
    bit  BTN_RIGHT_BIT, b
    jr   nz, .right
    bit  BTN_LEFT_BIT, b
    jr   nz, .left
    bit  BTN_B_BIT, b
    jr   nz, .delete
    ld   a, [frame_counter]           ;; \ Nothing pressed: the blink
    and  BLINK_MASK                   ;; |
    ret  nz                           ;; |
    jr   setup_name_dirty             ;; /
.next_letter
    ld   c, 1
    jr   .change
.previous_letter
    ld   c, NameCharsEnd - NameChars - 1 ;; (-1: the same as going round minus one)
.change
    call name_letter_address          ;; \ A = the index of its letter in NameChars
    call name_char_index              ;; /
    add  c                            ;; \ + 1 or - 1, going round
    cp   NameCharsEnd - NameChars     ;; |
    jr   c, .in_range                 ;; |
    sub  NameCharsEnd - NameChars     ;; |
.in_range                             ;; /
    add  LOW(NameChars)               ;; \ The new letter
    ld   e, a                         ;; |
    ld   a, HIGH(NameChars)           ;; |
    adc  0                            ;; |
    ld   d, a                         ;; |
    ld   a, [de]                      ;; |
    ld   [hl], a                      ;; /
    ld   a, SFX_TYPE
    call sfx_play
    jr   setup_name_dirty
.right
    ld   a, [name_pos]
    cp   NAME_LETTERS - 1
    ret  nc
    inc  a
    jr   .move
.left
    ld   a, [name_pos]
    or   a
    ret  z
    dec  a
.move
    ld   [name_pos], a
    ld   a, SFX_MENU
    call sfx_play
    jr   setup_name_dirty
.delete
    call name_letter_address          ;; \ A space, and one letter back
    ld   [hl], " "                    ;; |
    jr   .left                        ;; /

;; Ends writing: the spaces at the end are removed. An empty name is not allowed.
setup_edit_end:
    xor  a
    ld   [setup_edit], a
    ld   hl, player_name + NAME_LETTERS - 1
    ld   b, NAME_LETTERS
.trim
    ld   a, [hl]                      ;; \ From the end: spaces -> TEXT_END
    cp   " "                          ;; |
    jr   nz, .trimmed                 ;; |
    ld   [hl], TEXT_END               ;; |
    dec  hl                           ;; |
    dec  b                            ;; |
    jr   nz, .trim                    ;; /
    ld   hl, player_name              ;; \ All spaces: a name with one letter
    ld   [hl], "A"                    ;; /
.trimmed
    ld   a, SFX_COIN
    call sfx_play
    ; continues in setup_edit_dirty

;; The name and the help change
setup_edit_dirty:
    ld   a, [setup_dirty]
    or   1 << ITEM_NAME | 1 << LINE_HELP
    ld   [setup_dirty], a
    ret

;; The name changes
setup_name_dirty:
    ld   a, [setup_dirty]
    or   1 << ITEM_NAME
    ld   [setup_dirty], a
    ret

;; ⫷▬ HL = &player_name[name_pos]  ❌ Modifies A, HL
name_letter_address:
    ld   a, [name_pos]
    add  LOW(player_name)
    ld   l, a
    ld   a, HIGH(player_name)
    adc  0
    ld   h, a
    ret

;; 📥 HL = a letter   ⫷▬ A = its index in NameChars (0 if it is not there)
;; ❌ Modifies A, DE. Does NOT modify BC or HL
name_char_index:
    ld   de, NameChars
.find
    ld   a, [de]
    cp   [hl]
    jr   z, .found
    inc  de
    ld   a, e
    cp   LOW(NameCharsEnd)
    jr   nz, .find
    ld   de, NameChars                ;; Not there: the first one (space)
.found
    ld   a, e
    sub  LOW(NameChars)
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draws the first line that is waiting (if any) in the row of text.
;; ❌ Modifies A, BC, DE, HL
setup_draw_next:
    ld   a, [setup_dirty]
    or   a
    ret  z
    ld   b, a                         ;; \ C = the first bit at 1 (the line)
    ld   c, 0                         ;; | E = that bit alone
    ld   e, 1                         ;; |
.bit                                  ;; |
    ld   a, b                         ;; |
    and  e                            ;; |
    jr   nz, .found                   ;; |
    inc  c                            ;; |
    sla  e                            ;; |
    jr   .bit                         ;; /
.found
    ld   a, e                         ;; \ That line is not waiting any more
    cpl                               ;; |
    and  b                            ;; |
    ld   [setup_dirty], a             ;; /
    ld   a, c                         ;; \ HL = SetupLines[C]
    add  a                            ;; |
    add  LOW(SetupLines)              ;; |
    ld   l, a                         ;; |
    ld   a, HIGH(SetupLines)          ;; |
    adc  0                            ;; |
    ld   h, a                         ;; |
    ld   a, [hl+]                     ;; |
    ld   h, [hl]                      ;; |
    ld   l, a                         ;; /
    call call_hl                      ;; Build it
    jp   row_commit

;; The routine that builds each line
SetupLines:
    dw line_language, line_hero, line_music, line_name, line_play
    dw line_title, line_help
ASSERT @ - SetupLines == LINE_COUNT * 2

MACRO ITEM_ROW      ;; \1 = item: A = its row, and the row starts
    ld   a, FIRST_ITEM_ROW + 2 * (\1)
    call row_begin
ENDM

line_language:
    ITEM_ROW ITEM_LANG
    ld   de, TxtLanguage
    call put_label
    ld   de, TxtLangName
    jr   put_value

line_hero:
    ITEM_ROW ITEM_HERO
    ld   de, TxtHero
    call put_label
    ld   a, [gender]
    or   a
    ld   de, TxtBoy
    jr   z, put_value
    ld   de, TxtGirl
    jr   put_value

line_music:
    ITEM_ROW ITEM_MUSIC
    ld   de, TxtMusic
    call put_label
    ld   a, [music_choice]
    or   a
    ld   de, TxtOn
    jr   nz, put_value
    ld   de, TxtOff
    jr   put_value

line_play:
    ITEM_ROW ITEM_PLAY
    ld   de, TxtPlay
    ; continues in put_label

;; The name of an item. 📥 DE = text (BITEXT)
put_label:
    ld   hl, row_buffer + LABEL_COLUMN
    jp   draw_ltext

;; The value of an item, between < and >. 📥 DE = text (BITEXT)
put_value:
    ld   hl, row_buffer + VALUE_COLUMN
    ld   [hl], TILE_CHAR_LT
    inc  hl
    call draw_ltext
    ld   [hl], TILE_CHAR_GT
    ret

line_name:
    ITEM_ROW ITEM_NAME
    ld   de, TxtName
    call put_label
    ld   hl, row_buffer + NAME_COLUMN ;; \ The name
    ld   de, player_name              ;; |
    call draw_text                    ;; /
    ld   a, [setup_edit]              ;; \ Writing it: the letter being written
    or   a                            ;; | blinks (an underscore)
    ret  z                            ;; |
    ld   a, [frame_counter]           ;; |
    bit  BLINK_BIT, a                 ;; |
    ret  z                            ;; |
    ld   a, [name_pos]                ;; |
    add  LOW(row_buffer + NAME_COLUMN) ;; |
    ld   l, a                         ;; |
    ld   a, HIGH(row_buffer + NAME_COLUMN) ;; |
    adc  0                            ;; |
    ld   h, a                         ;; |
    ld   [hl], TILE_CHAR_UNDERSCORE   ;; /
    ret

line_title:
    ld   a, TITLE_ROW
    call row_begin
    ld   de, TxtSettings
    jr   put_label

line_help:
    ld   a, HELP_ROW
    call row_begin
    ld   a, [setup_edit]
    or   a
    ld   de, TxtHelp
    jr   z, .draw
    ld   de, TxtHelpEdit
.draw
    jp   draw_ltext_centered

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The sprites: the cursor (an arrow that moves a little) and the chosen hero,
;; walking, next to the title.
;; ❌ Modifies A, BC, DE, HL
setup_sprites:
    call sys_prerender_begin
    ld   a, [setup_sel]               ;; \ B = OAM Y of the cursor: its row * 8,
    add  a                            ;; | 4 pixels up (it is 16 tall, the text 8)
    add  FIRST_ITEM_ROW               ;; |
    add  a                            ;; |
    add  a                            ;; |
    add  a                            ;; |
    add  OAM_Y_OFFSET - 4             ;; |
    ld   b, a                         ;; /
    ld   a, [frame_counter]           ;; \ C = OAM X: one pixel to the right, sometimes
    swap a                            ;; |
    and  1                            ;; |
    add  CURSOR_OAM_X                 ;; |
    ld   c, a                         ;; /
    ld   h, HIGH(shadow_oam)          ;; \ One sprite (8 x 16)
    ld   a, [shadow_cursor]           ;; |
    ld   l, a                         ;; |
    ld   a, b                         ;; |
    ld   [hl+], a                     ;; |
    ld   a, c                         ;; |
    ld   [hl+], a                     ;; |
    ld   a, TILE_CURSOR               ;; |
    ld   [hl+], a                     ;; |
    xor  a                            ;; |
    ld   [hl+], a                     ;; |
    ld   a, l                         ;; |
    ld   [shadow_cursor], a           ;; /
    ld   a, [frame_counter]           ;; \ The hero, walking towards us
    and  ANIM_STEP_MASK               ;; | D = sheet + step (0 or 4)
    rrca                              ;; |
    ld   d, a                         ;; |
    ld   a, [gender]                  ;; |
    or   a                            ;; |
    ld   a, TILE_BOY                  ;; |
    jr   z, .sheet                    ;; |
    ld   a, TILE_GIRL                 ;; |
.sheet                                ;; |
    add  d                            ;; |
    ld   d, a                         ;; |
    ld   e, 0                         ;; |
    ld   b, PREVIEW_OAM_Y             ;; |
    ld   c, PREVIEW_OAM_X             ;; |
    call sys_prerender_image          ;; /
    jp   sys_prerender_end
