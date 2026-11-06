INCLUDE "man/man_map.inc"
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/gfx.inc"

DEF NAV_UNVISITED = $FF
DEF NAV_TARGET    = $FE

SECTION "Navigation queue", WRAMX[$D000], BANK[1]
	nav_queue: ds MAP_SIZE * 2


;; Ultima ruta terminada: la IA la lee mientras walk_dist se reconstruye.
SECTION "Saved navigation", WRAM0
nav_last_route:: ds MAP_SIZE

SECTION "Navigation vars", WRAM0

	nav_read:  ds 2
	nav_write: ds 2
	nav_busy:   ds 1
	nav_target: ds 2


SECTION "Navigation", ROM0



navegation_init::
	xor a
	ld [nav_read], a
	ld [nav_write], a
	ld [nav_write + 1], a
	ld [nav_read + 1], a
	ld hl, walk_dist
	ld bc, MAP_SIZE
	ld a, NAV_UNVISITED
	call memset16
	call navigation_get_player_index

	ld a, l
	ld [nav_queue], a
	ld [nav_target], a
	ld a, h
	ld [nav_queue + 1], a
	ld [nav_target + 1], a
	ld a, 1
	ld [nav_write], a
	ld [nav_busy], a

	ld bc, walk_dist
	add hl, bc

	ld [hl], NAV_TARGET
									;; TESTSper
									;;ld a, $FF
								    ;;ld [nav_write], a
								    ;;ld a, $03
								    ;;ld [nav_write + 1], a


									;;ld a, $00
									;;ld [nav_write], a
									;;ld a, $04
									;;ld [nav_write + 1], a

									;;ld de, $0123
									;;call navegation_add_queue
	ret

;; Devuelve HL = fila * MAP_WIDTH + columna del jugador.
;; Modifica A, BC y HL. Conserva DE.
navigation_get_player_index:
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

	ret

navegation_read_queue:
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


navegation_add_queue:

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


search_try_neighbor:

	ld a, [hl]
	cp NAV_UNVISITED
	jr nz, .end

	push hl
	ld de, map_ram + MAP_WIDTH - walk_dist
	add hl, de

	ld   a, [hl+]
    cp   TILE_FIRST_SOLID
    jr   nc, .blocked

    ld   a, [hl]
    cp   TILE_FIRST_SOLID
    jr   nc, .blocked


	pop hl
	push hl

    ld   a, l
    sub  LOW(walk_dist)
    ld   l, a

    ld   a, h
    sbc  HIGH(walk_dist)
    ld   h, a

	ld e, l
	ld d, h

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

	    ld bc, walk_dist
	    add hl, bc

	    ld b, DIR_DOWN
	    call search_try_neighbor
	    pop de


	.not_up

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
		ld bc, MAP_WIDTH + walk_dist
		add hl, bc

		ld b, DIR_UP

		call search_try_neighbor
		pop de

	.not_down
		ld a, e
		and MAP_WIDTH - 1
		jr z, .not_left

		push de
		ld l, e
		ld h, d
		dec hl

		ld bc, walk_dist
		add hl, bc

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

		ld bc, walk_dist
		add hl, bc

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

navegation_build::
	.repeat
		call navigation_step
		jr nc, .repeat
		xor a
		ld [nav_busy], a
		jp navigation_save_route

navegation_update::

	ld a, [nav_busy]
	or a
	jr z, .check_target
	ld a, 4
	.call
		push af
		call navigation_step
		jr c, .end_search
		pop af
		dec a
		jr nz, .call
		jr .end
	.end_search
		pop af
		xor a
		ld [nav_busy], a
		jp navigation_save_route
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

;; Publicar solo al terminar: conservar la busqueda original sin cambiar
;; sus accesos a walk_dist. Modifica A, BC, DE y HL.
navigation_save_route:
	ld hl, walk_dist
	ld de, nav_last_route
	ld bc, MAP_SIZE
	jp memcpy16
