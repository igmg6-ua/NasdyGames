;;==============================================================
;; Hardware: registros, pantalla, OAM, sonido y botones
;; (los nombres y valores del Challenge 6, más los registros que usa el juego
;;  para interrupciones, sonido y SRAM)
;;==============================================================
IF !DEF(HARDWARE_INC)
DEF HARDWARE_INC = 1
;;--------------------------------------------------------------
;; Registers
;;--------------------------------------------------------------
DEF rP1     = $FF00               ;; Joypad
DEF rDIV    = $FF04               ;; Divider (changes all the time)
DEF rIF     = $FF0F               ;; Interrupts requested
DEF rLCDC   = $FF40               ;; LCD control. Bit 7: LCD on/off
DEF rSTAT   = $FF41               ;; LCD status (and which STAT interrupts are on)
DEF rSCY    = $FF42               ;; Scroll Y: pixels the background moves up
DEF rSCX    = $FF43               ;; Scroll X: pixels the background moves left
DEF rLY     = $FF44               ;; Line being drawn (144-153: VBLANK)
DEF rLYC    = $FF45               ;; Line compare
DEF rDMA    = $FF46               ;; DMA: writing a page here copies 160 bytes to OAM
DEF rBGP    = $FF47               ;; Background palette
DEF rOBP0   = $FF48               ;; Sprite palette 0
DEF rOBP1   = $FF49               ;; Sprite palette 1 (sprites with ATTR bit 4)
DEF rWY     = $FF4A               ;; Window: first line where it is drawn
DEF rWX     = $FF4B               ;; Window: its column + 7
DEF rIE     = $FFFF               ;; Interrupts enabled

DEF IEF_VBLANK = %00000001
DEF IEF_STAT   = %00000010
DEF STATF_MODE0 = %00001000       ;; STAT interrupt at every HBLANK

;; Sound
DEF rAUD1SWEEP = $FF10            ;; Channel 1 (pulse with sweep)
DEF rAUD1LEN   = $FF11
DEF rAUD1ENV   = $FF12
DEF rAUD1LOW   = $FF13
DEF rAUD1HIGH  = $FF14
DEF rAUD2LEN   = $FF16            ;; Channel 2 (pulse): the melody
DEF rAUD2ENV   = $FF17
DEF rAUD2LOW   = $FF18
DEF rAUD2HIGH  = $FF19
DEF rAUD3ENA   = $FF1A            ;; Channel 3 (wave): the bass
DEF rAUD3LEN   = $FF1B
DEF rAUD3LEVEL = $FF1C
DEF rAUD3LOW   = $FF1D
DEF rAUD3HIGH  = $FF1E
DEF rAUD4LEN   = $FF20            ;; Channel 4 (noise)
DEF rAUD4ENV   = $FF21
DEF rAUD4POLY  = $FF22
DEF rAUD4GO    = $FF23
DEF rAUDVOL    = $FF24            ;; Master volume (bits 6-4 left, bits 2-0 right)
DEF rAUDTERM   = $FF25            ;; Which channels go to which speaker (1 bit each)
DEF rAUDENA    = $FF26            ;; Bit 7: sound on/off (off: other writes are lost)
DEF WAVE_RAM   = $FF30            ;; 16 bytes: the shape of the wave of channel 3
DEF AUDENA_ON   = %10000000
DEF AUDTERM_ALL = %11111111
DEF AUDVOL_MAX  = %01110111

DEF VBLANK_LINE    = 144
DEF SCREEN_WIDTH   = 160
DEF SCREEN_HEIGHT  = 144
DEF LCDC_ON_BIT    = 7
DEF LCDC_VALUE     = %11110111    ;; LCD on · window map $9C00 · window on ·
                                  ;; tiles at $8000 · background map $9800 ·
                                  ;; sprites 8x16 · sprites on · background on
DEF LCDC_NO_WINDOW = %11010111    ;; the same, without the window (menus)
DEF PALETTE        = %11100100    ;; colour 0 = white ... colour 3 = black
DEF PALETTE_HURT   = %00011011    ;; the colours reversed (a hurt hero flashes with it)

DEF VRAM_TILES     = $8000
DEF TILEMAP        = $9800        ;; the background: 32 x 32 tiles = 256 x 256 pixels
DEF WINDOW_MAP     = $9C00        ;; the window (the HUD): it does not scroll
DEF TILEMAP_WIDTH  = 32
DEF OAM_START      = $FE00
DEF OAM_SIZE       = 160          ;; 40 sprites x 4 bytes
DEF HRAM_START     = $FF80
DEF WRAM_END       = $E000

;; Cartridge RAM (MBC1): write $0A to enable it, $00 to disable it
DEF rRAMG      = $0000
DEF CART_RAM_ENABLE  = $0A
DEF CART_RAM_DISABLE = $00
DEF SRAM_START = $A000

;;--------------------------------------------------------------
;; Sprites: ATTR bits (the 4th byte of a sprite in the OAM)
;;--------------------------------------------------------------
DEF ATTR_PALETTE_BIT = 4
DEF ATTR_XFLIP_BIT   = 5
DEF ATTR_YFLIP_BIT   = 6
DEF ATTR_PALETTE     = 1 << ATTR_PALETTE_BIT
DEF ATTR_XFLIP       = 1 << ATTR_XFLIP_BIT
DEF ATTR_YFLIP       = 1 << ATTR_YFLIP_BIT

;; Sprites are 8x16: each one shows two tiles, tile N above tile N + 1.
;; An entity (16x16 pixels) is drawn with 2 sprites, side by side.
DEF SPRITES_PER_ENTITY = 2
DEF SPRITE_WIDTH       = 8
DEF TILES_PER_SPRITE   = 2
DEF OAM_Y_OFFSET       = 16
DEF OAM_X_OFFSET       = 8

;;--------------------------------------------------------------
;; Buttons (input_held / input_pressed). 1 = pressed
;;--------------------------------------------------------------
DEF BTN_RIGHT_BIT  = 0
DEF BTN_LEFT_BIT   = 1
DEF BTN_UP_BIT     = 2
DEF BTN_DOWN_BIT   = 3
DEF BTN_A_BIT      = 4
DEF BTN_B_BIT      = 5
DEF BTN_SELECT_BIT = 6
DEF BTN_START_BIT  = 7
DEF BTN_RIGHT      = 1 << BTN_RIGHT_BIT
DEF BTN_LEFT       = 1 << BTN_LEFT_BIT
DEF BTN_UP         = 1 << BTN_UP_BIT
DEF BTN_DOWN       = 1 << BTN_DOWN_BIT
DEF BTN_A          = 1 << BTN_A_BIT
DEF BTN_B          = 1 << BTN_B_BIT
DEF BTN_START      = 1 << BTN_START_BIT
DEF BTN_DPAD       = BTN_RIGHT | BTN_LEFT | BTN_UP | BTN_DOWN

ENDC
