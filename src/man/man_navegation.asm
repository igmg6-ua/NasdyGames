;; Navegacion compartida: una BFS sale desde el jugador y descubre los vecinos.
;; Cada casilla guarda la direccion para volver hacia el destino (0..3).
;; $FE marca el destino y $FF una casilla aun no visitada.
;; La cola guarda indices de 16 bits: fila * MAP_WIDTH + columna.
;; La IA consulta la tabla activa; la otra se borra/reconstruye por partes.
;; Al terminar, se intercambian punteros sin copiar la tabla completa.
INCLUDE "man/man_map.inc"
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/gfx.inc"

DEF NAV_UNVISITED = $FF
DEF NAV_TARGET    = $FE

SECTION "Navigation queue", WRAMX[$D000], BANK[1]
	nav_queue: ds MAP_SIZE * 2


;; Segunda tabla: la IA lee una tabla completa mientras la BFS escribe la otra.
SECTION "Navigation buffer", WRAM0
nav_buffer: ds MAP_SIZE

SECTION "Navigation vars", WRAM0

	nav_read:  ds 2       ;; proxima entrada a consumir (no es una direccion)
	nav_write: ds 2       ;; primera entrada libre; cola vacia si read == write
	nav_busy::   ds 1     ;; 0=publicada, 1=borrado, 2=expansion
	nav_target: ds 2      ;; destino fijo de la busqueda en curso o terminada
    nav_clear_ptr: ds 2
    nav_clear_left: ds 1
    nav_build_ptr: ds 2   ;; base del buffer que se esta preparando
    nav_active_ptr:: ds 2 ;; base de la tabla completa que siguen los cazadores

;; Limitar el trabajo de cada frame; borrar y expandir son fases separadas.
DEF NAV_STEPS_PER_FRAME = 4
DEF NAV_CLEAR_CHUNK = 128


SECTION "Navigation", ROM0

	

;; Inicio de nivel, despues de colocar la pistola y con LCD apagado.
;; Establece los buffers antes de la primera construccion completa.
navegation_start::
    ld hl, walk_dist
    ld a, l
    ld [nav_build_ptr], a
    ld a, h
    ld [nav_build_ptr + 1], a
    ld hl, nav_buffer
    ld a, l
    ld [nav_active_ptr], a
    ld a, h
    ld [nav_active_ptr + 1], a
    call navegation_init
    jp navegation_build

;; A partir de aqui la tabla de escritura nunca es la que consulta la IA.
navegation_init::
    ;; Una busqueda nueva descarta la cola anterior, pero no la tabla activa.
    ;; No hace falta borrar los bytes de cola: los contadores dicen que es valido.
	xor a
	ld [nav_read], a
	ld [nav_write], a
	ld [nav_write + 1], a
	ld [nav_read + 1], a
    ;; Limpiar el buffer por bloques durante el juego, no 1024 bytes de golpe.
    ld a, [nav_build_ptr]
    ld [nav_clear_ptr], a
    ld a, [nav_build_ptr + 1]
    ld [nav_clear_ptr + 1], a
    ld a, MAP_SIZE / NAV_CLEAR_CHUNK
    ld [nav_clear_left], a
	call navigation_get_player_index

    ;; Sembrar la cola con el jugador: primero byte bajo, despues alto.
	ld a, l
	ld [nav_queue], a
	ld [nav_target], a
	ld a, h
	ld [nav_queue + 1], a
	ld [nav_target + 1], a
	ld a, 1
	ld [nav_write], a
	ld [nav_busy], a

	ret

;; nav_busy: 0 = tabla publicada, 1 = borrado, 2 = expansion BFS.
;; Un bloque por frame. Al iniciar el nivel se ejecuta completa con LCD apagado.
navigation_clear_step:
    ld a, [nav_clear_ptr]
    ld l, a
    ld a, [nav_clear_ptr + 1]
    ld h, a
    ld b, NAV_CLEAR_CHUNK
    ld a, NAV_UNVISITED
    call memset8
    ld a, l
    ld [nav_clear_ptr], a
    ld a, h
    ld [nav_clear_ptr + 1], a
    ld hl, nav_clear_left
    dec [hl]
    ret nz
    ld a, [nav_target]
    ld l, a
    ld a, [nav_target + 1]
    ld h, a
    call navigation_build_address
    ld [hl], NAV_TARGET
    ld a, 2
    ld [nav_busy], a
    ret

;; Devuelve HL = fila * MAP_WIDTH + columna del jugador.
;; Modifica A, BC y HL. Conserva DE.
navigation_get_player_index:
    ;; Dividir las coordenadas en pixeles entre 8 obtiene fila y columna.
    ;; Se conserva el calculo original con un bucle compartido para ambos ejes.
	ld a, [PLAYER_ENTITY + E_Y]
	ld b, a
	ld a, 3
	ld c, 0

	.desp_bit
		srl b
		dec a
		jr nz, .desp_bit
		inc a
		cp c
		jr z, .contX

	ld h, 0
	ld l, b

	ld a,5
	.MULT
		add hl, hl
		dec a
		jr nz, .MULT

	ld a, [PLAYER_ENTITY + E_X]
	ld b, a
	ld c, 1
	ld a, 3
	jr .desp_bit

	.contX
	ld a, b
	ld b, 0
	ld c, a
	add hl, bc
    ;; Redondear un jugador entre tiles puede elegir una huella bloqueada.
    ;; Probar las esquinas vecinas de su celda, sin salir del tablero.
    push de
    push hl
    call navigation_target_free
    jr c, .valid_floor
    pop hl
    push hl
    inc hl
    call navigation_target_free
    jr c, .valid_other
    pop hl
    push hl
    ld de, MAP_WIDTH
    add hl, de
    call navigation_target_free
    jr c, .valid_other
    pop hl
    push hl
    ld de, MAP_WIDTH + 1
    add hl, de
    call navigation_target_free
    jr c, .valid_other
    ;; No deberia ocurrir con pies validos: conservar destino anterior.
    pop hl
    ld a, [nav_target]
    ld l, a
    ld a, [nav_target + 1]
    ld h, a
    pop de
    ret
.valid_floor
    pop hl
    pop de
    ret
.valid_other
    pop de                       ;; descartar solo el indice original
    pop de                       ;; restaurar el puntero de entidad
    ret


;; HL = indice. Carry si sus dos tiles de pies son transitables.
;; Conserva HL; modifica A, BC, DE.
navigation_target_free:
    ld a, h
    cp HIGH(MAP_SIZE - MAP_WIDTH)
    jr c, .row_ok
    jr nz, .invalid
    ld a, l
    cp LOW(MAP_SIZE - MAP_WIDTH)
    jr nc, .invalid
.row_ok
    ld a, l
    and MAP_WIDTH - 1
    cp MAP_WIDTH - 1
    jr nc, .invalid
    push hl
    ld de, map_ram + MAP_WIDTH
    add hl, de
    ld a, [hl+]
    cp TILE_FIRST_SOLID
    jr nc, .blocked
    ld a, [hl]
    cp TILE_FIRST_SOLID
    jr nc, .blocked
    pop hl
    scf
    ret
.blocked
    pop hl
.invalid
    and a
    ret

;; HL = indice -> HL = entrada del buffer de construccion. Modifica A, BC, HL.
navigation_build_address:
    ld a, [nav_build_ptr]
    ld c, a
    ld a, [nav_build_ptr + 1]
    ld b, a
    add hl, bc
    ret

;; HL = entrada del buffer de construccion -> HL = indice.
;; Conserva BC (B contiene la direccion del vecino). Modifica A, DE, HL.
navigation_build_index:
    ld a, [nav_build_ptr]
    ld e, a
    ld a, [nav_build_ptr + 1]
    ld d, a
    ld a, l
    sub e
    ld l, a
    ld a, h
    sbc d
    ld h, a
    ret

;; Publicar solo tras terminar: intercambiar los punteros cuesta pocos ciclos.
;; Las interrupciones no consultan estos punteros; la IA se ejecuta despues.
navigation_publish:
    ld a, [nav_active_ptr]
    ld c, a
    ld a, [nav_active_ptr + 1]
    ld b, a
    ld a, [nav_build_ptr]
    ld [nav_active_ptr], a
    ld a, [nav_build_ptr + 1]
    ld [nav_active_ptr + 1], a
    ld a, c
    ld [nav_build_ptr], a
    ld a, b
    ld [nav_build_ptr + 1], a
    xor a
    ld [nav_busy], a
    ret

;; Extraer una entrada FIFO. DE = indice si carry=0; carry=1 si vacia.
;; Modifica A, BC, HL; DE no cambia al devolver vacio.
navegation_read_queue:
    ;; Comparar ambos bytes antes de acceder a memoria de la cola.
	ld a, [nav_read]
	ld l, a


	ld a, [nav_write]
	ld c, a

	cp l
	jr nz, .fine
	
	ld a, [nav_write + 1]
	ld b, a

	ld a, [nav_read + 1]
	ld h, a
	cp b
	jr nz, .different

	jr z, .empty
	.fine
		ld a, [nav_read +1]
		ld h, a
	.different
		push hl

		ld bc, nav_queue
		add hl, hl
		add hl, bc

		ld a, [hl+]
		ld e, a
		ld a, [hl]
		ld d, a

		pop hl
		inc hl


		ld a, l
		ld [nav_read], a
		ld a, h
		ld [nav_read + 1], a
		xor a 
		ret

	.empty
		xor a
		cp 1
		ret


;; DE = indice que se quiere insertar. Carry=0: insertado; carry=1: llena.
;; Conserva DE; modifica A, BC, HL. No reutiliza huecos durante esta busqueda:
;; cada casilla solo se descubre una vez, asi que basta capacidad MAP_SIZE.
navegation_add_queue:
    ;; Comparacion de 16 bits: alto primero; bajo solo si los altos coinciden.
	
	ld a, [nav_write]
	ld l, a
	ld a, [nav_write + 1]
	ld h, a
	push hl

	cp HIGH(MAP_SIZE)
	jr c, .cont
	jr nz, .no_space

	ld a, l
	cp LOW(MAP_SIZE)
	jr c, .cont
	jr .no_space

	.cont	
		pop hl
		push hl
		
		add hl, hl
		
		ld bc, nav_queue
		
		add hl, bc

		
		ld a, e
		ld [hl+], a
		ld a, d
		ld [hl], a
		
		pop hl
		inc hl
		
		ld a, l
		ld [nav_write], a
		ld a, h
		ld [nav_write + 1], a 
		
		xor a
		ret

	.no_space
		xor a
		cp 1
		pop hl
		ret


;; HL = entrada del vecino en el buffer de escritura; B = flecha hacia su padre.
;; El llamador ya ha comprobado bordes. Modifica A, DE, HL; conserva BC.
search_try_neighbor:
    ;; Visitar una sola vez impide ciclos y entradas duplicadas en la cola.
	
	ld a, [hl]
	cp NAV_UNVISITED
	jr nz, .end

    ;; Para una imagen de 16x16, los pies ocupan dos tiles en la fila inferior.
    ;; Guardar la entrada permite volver a ella despues de mirar el mapa.
	push hl
	call navigation_build_index
	ld de, map_ram + MAP_WIDTH
	add hl, de

	ld   a, [hl+]
    cp   TILE_FIRST_SOLID
    jr   nc, .blocked

    ld   a, [hl]
    cp   TILE_FIRST_SOLID
    jr   nc, .blocked


	pop hl
	push hl

	call navigation_build_index

	ld e, l
	ld d, h
	
    ;; La insercion cambia BC/HL: recuperar la flecha y el puntero antes de marcar.
	push bc
	call navegation_add_queue
	pop bc
	pop hl

	jr c, .end
	ld a, b
	ld [hl], a

	ret

	.blocked
		pop hl
		ret
	.end
		ret

;; Consumir un nodo y descubrir arriba, abajo, izquierda y derecha.
;; Carry=1 solo si la cola estaba vacia; carry=0 si se proceso un nodo.
;; Cada vecino guarda la direccion opuesta: sirve para volver hacia el origen.
navigation_step:

	call navegation_read_queue
	jr c, .empty

	xor a
	cp d
	jr nz, .cont_up

	ld a, e
	cp MAP_WIDTH
	jr nc, .cont_up
	jr .not_up

	

	.cont_up
		push de
		ld l, e
		ld h, d

		ld   a, l
	    sub  LOW(MAP_WIDTH)
	    ld   l, a

	    ld   a, h
	    sbc  HIGH(MAP_WIDTH)
	    ld   h, a

	    call navigation_build_address

	    ld b, DIR_DOWN
	    call search_try_neighbor
	    pop de
		

	.not_up

        ;; Ademas del vecino inferior, debe existir la fila de sus pies.
		ld bc, MAP_SIZE - 2*MAP_WIDTH
		ld a, d
		cp b
		jr c, .cont_down
		jr nz, .not_down

		ld a, e
		cp c
		jr c, .cont_down
		jr .not_down
	
	.cont_down
		push de

		ld l, e
		ld h, d
		ld bc, MAP_WIDTH
		add hl, bc
		call navigation_build_address

		ld b, DIR_UP
		
		call search_try_neighbor
		pop de
	
	.not_down
        ;; Los cinco bits bajos del indice son la columna (ancho fijo de 32).
		ld a, e
		and MAP_WIDTH - 1
		jr z, .not_left

		push de
		ld l, e
		ld h, d
		dec hl

		call navigation_build_address

		ld b, DIR_RIGHT
		call search_try_neighbor
		pop de

	.not_left
		ld a, e
		and MAP_WIDTH - 1
		cp MAP_WIDTH - 2
		jr nc, .end

		push de
		ld l, e
		ld h, d
		inc hl

		call navigation_build_address

		ld b, DIR_LEFT
		call search_try_neighbor
		pop de
	
	.end
		xor a 
		ret
	.empty 
		xor a 
		cp 1
		ret

;; Construccion completa, solo al cargar un nivel con la pantalla apagada.
;; Durante la partida se usa navegation_update para repartir este trabajo.
navegation_build::
.clear
    call navigation_clear_step
    ld a, [nav_busy]
    cp 1
    jr z, .clear
	.repeat
		call navigation_step
		jr nc, .repeat
		jp navigation_publish

;; Un paso de mantenimiento por frame, despues de comprobar la pausa.
;; No reiniciar una busqueda a medias aunque el jugador vuelva a moverse:
;; primero publicarla y despues detectar el destino mas reciente.
navegation_update::
	
	ld a, [nav_busy]
	or a
	jr z, .check_target
    cp 1
    jp z, navigation_clear_step
	ld a, NAV_STEPS_PER_FRAME
	.call
        ;; AF guarda el presupuesto, pero comprobar carry ANTES de recuperarlo.
		push af
		call navigation_step
		jr c, .end_search
		pop af
		dec a
		jr nz, .call
		jr .end
	.end_search
		pop af
		jp navigation_publish
	.check_target
		call navigation_get_player_index
		
		ld a, [nav_target]
		cp l
		jp nz, navegation_init
		ld a, [nav_target + 1]
		cp h
		jp nz, navegation_init
	.end
		ret