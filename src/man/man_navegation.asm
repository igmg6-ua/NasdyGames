INCLUDE "man/man_map.inc"
INCLUDE "scn/scn_game.inc"

DEF NAV_UNVISITED = $FF
DEF NAV_TARGET    = $FE



SECTION "Navigation queue", WRAMX[$D000], BANK[1]
	nav_queue: ds MAP_SIZE * 2


SECTION "Navigation vars", WRAM0

	nav_read:  ds 2
	nav_write: ds 2


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

	ld a, l
	ld [nav_queue], a
	ld a, h
	ld [nav_queue + 1], a
	ld a, 1
	ld [nav_write], a

	ld bc, walk_dist
	add hl, bc

	ld [hl], NAV_TARGET
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
		ld a,1
		sub a, 2
		ret



	