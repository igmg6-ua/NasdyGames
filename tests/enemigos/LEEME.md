# Mapa temporal para probar enemigos

ATENCIÓN: este mapa sustituye temporalmente al nivel 1. Restaurarlo antes de integrar o entregar el juego.

- mapa-test.txt: mapa de 19×15 casillas.
- nivel1-original.txt: copia del nivel 1 de develop al preparar esta prueba.
- preparar.py: activa/restaura el mapa y regenera los niveles.

El héroe empieza en la sala superior. Hay tres enemigos en la inferior y una pared horizontal con un paso a la derecha. El portal está arriba a la izquierda. No hay monedas. La pistola sigue usando la aparición normal del juego.

La activación asigna IA cazadora a los tres enemigos del primer nivel, sin cambiar sys_ai.asm ni tools/map2asm.py. Los niveles restantes conservan su configuración. Los cazadores actuales alternan persecución y decisiones aleatorias: no es una reproducción determinista y pueden acabar encontrando la abertura.

## Activar y jugar (desde la raíz del repositorio)

    python3 tests/enemigos/preparar.py activar
    make clean
    make
    gbt_bgb -nowriteini -set StartDebug=0 laberinto.gb

Comienza una partida nueva para entrar al mapa de prueba. Mantente aproximadamente en la posición inicial y observa cómo los enemigos llegan a la pared inferior. Después muévete lateralmente por arriba. Para investigar el movimiento, evita dispararles. Esc abre el depurador y detiene la emulación; F9 continúa.

Comprueba si insisten contra la pared, si encuentran el paso derecho y si se superponen. La existencia de un camino se valida con el conversor, pero la reproducción visual del atasco debe comprobarse jugando.

## Restaurar el juego normal

    python3 tests/enemigos/preparar.py restaurar
    make clean
    make

Se restaura el nivel original y la configuración normal de IA, y se regeneran levels.asm y level_count.inc. No borres esta carpeta antes de restaurar: contiene el respaldo. Si alguien actualiza el nivel original en remoto, conserva esos cambios antes de reutilizar este respaldo antiguo.

IMPORTANTE: ejecutar make assets o tools/map2asm.py directamente mientras el test está activo regenera el mapa con enemigos que deambulan, porque esa es la IA normal del nivel 1. Para mantener los perseguidores, usa preparar.py activar.

Verificado al preparar la prueba: mapa válido para el conversor (portal accesible y entidades con espacio), compilación correcta y restauración que devuelve los archivos de niveles al contenido original. No se han cambiado las rutinas del comportamiento enemigo.
