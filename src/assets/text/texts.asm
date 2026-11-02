;;==============================================================
;; assets/text/texts.asm -- Todos los textos del juego, en español y en inglés
;;
;; BITEXT etiqueta, "español", "inglés": text_get elige según [language].
;; La fuente no tiene tildes: se escribe sin ellas (la Ñ sí existe).
;;==============================================================
INCLUDE "engine/macros.inc"
INCLUDE "engine/charmap.inc"

SECTION "Texts", ROM0

;; Title screen
    BITEXT TxtPressStart, "PULSA START", "PRESS START"
    BITEXT TxtRecord,     "RECORD", "BEST"
    BITEXT TxtCredits,    "NASDYGAMES  2026", "NASDYGAMES  2026"

;; Settings
    BITEXT TxtSettings,   "MENU", "MENU"
    BITEXT TxtLanguage,   "IDIOMA", "LANGUAGE"
    BITEXT TxtLangName,   "ESPAÑOL", "ENGLISH"
    BITEXT TxtHero,       "HEROE", "HERO"
    BITEXT TxtBoy,        "CHICO", "BOY"
    BITEXT TxtGirl,       "CHICA", "GIRL"
    BITEXT TxtMusic,      "MUSICA", "MUSIC"
    BITEXT TxtOn,         "SI", "ON"
    BITEXT TxtOff,        "NO", "OFF"
    BITEXT TxtName,       "NOMBRE", "NAME"
    BITEXT TxtMedals,     "MEDALLONES", "MEDALS"
    BITEXT TxtPlay,       "JUGAR", "PLAY"
    BITEXT TxtHelp,       "A:CAMBIA START:JUGAR", "A:CHANGE START:PLAY"
    BITEXT TxtHelpEdit,   "<>:MUEVE  A:LISTO", "<>:MOVE  A:DONE"

;; Level intro
    BITEXT TxtLevel,      "NIVEL", "LEVEL"
    BITEXT TxtGoodLuck,   "SUERTE,", "GOOD LUCK,"
    BITEXT TxtGoal,       "LLEGA AL PORTAL", "REACH THE PORTAL"
    BITEXT TxtShoot,      "A: DISPARAR", "A: SHOOT"
    BITEXT TxtPauseHelp,  "START: PAUSA", "START: PAUSE"
    BITEXT TxtBonus,      "BONUS", "BONUS"
    BITEXT TxtPickups,    "ESCUDO Y CORAZON!", "SHIELD AND HEART!"

;; Game
    BITEXT TxtPause,      "- PAUSA -", "- PAUSED -"

;; Summary of a level
    BITEXT TxtCleared,    "SUPERADO!", "CLEARED!"
    BITEXT TxtTime,       "TIEMPO", "TIME"
    BITEXT TxtMedal,      "MEDALLON", "MEDALLION"
    BITEXT TxtYes,        "SI", "YES"
    BITEXT TxtNo,         "NO", "NO"

;; Medallion and gallery
    BITEXT TxtMedalWon,   "ESPECTROS DERROTADOS", "ALL SPECTRES BEATEN"
    BITEXT TxtBack,       "B: VOLVER", "B: BACK"

;; End
    BITEXT TxtVictory,    "HAS ESCAPADO!", "YOU ESCAPED!"
    BITEXT TxtGameOver,   "FIN DE LA PARTIDA", "GAME OVER"
    BITEXT TxtTimeUp,     "SIN TIEMPO!", "TIME UP!"
    BITEXT TxtWellDone,   "BIEN HECHO,", "WELL DONE,"
    BITEXT TxtCoins,      "MONEDAS", "COINS"
    BITEXT TxtSpectres,   "ESPECTROS", "SPECTRES"
    BITEXT TxtScore,      "PUNTOS", "SCORE"
    BITEXT TxtNewRecord,  "NUEVO RECORD!", "NEW RECORD!"

;; The letters of a name, in the order UP goes through them
NameChars::
    db " ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"
NameCharsEnd::
