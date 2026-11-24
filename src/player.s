; Sonda: movimiento, calor, disparos, choque y vidas. Efectos de explosión.
.include "hardware.s"
.include "gfx.inc"
.import spr_x, spr_y, spr_t, spr_f
.import ter_choca, ter_punto, ter_fila
.import w_izq, w_der, w_isi, w_isd, w_tip, w_fri
.importzp joy, sc_y, dsc
.export jug_init, jug_frame, jug_dibuja, jug_danio, bx, by, fx_grande
.import snd_play
.export sube, jug_sale, chk_aviso
.import ter_chk, d_cal, d_apag, msg, suma_chk, en_respiro
.exportzp est, calor, vidas, apagon, px, py, disp, inv
.exportzp perf_t, doble_t, escudo, combo
NBALA   = 4
NFX     = 4
SPR_BALA = 4
SPR_FX  = 28
VEL_BALA = 5
CADENCIA = 8                ; frames entre disparos
.zeropage
est:    .res 1              ; EST_VUELO, EST_MUERE, EST_FIN
px:     .res 1              ; sonda (x 64..240, y 32..216)
py:     .res 1
calor:  .res 1              ; 0..CAL_MAX
apagon: .res 1              ; frames de sistemas apagados
vidas:  .res 1
inv:    .res 1              ; frames de invulnerabilidad
perf_t: .res 1              ; bala perforante (x4 frames)
doble_t: .res 1             ; disparo doble (x4 frames)
escudo: .res 1
combo:  .res 1              ; bajas seguidas sin daño (máx. 15)
muere:  .res 1              ; frames hasta reaparecer
cad:    .res 1
enfr:   .res 1              ; divisor del calor
disp:   .res 1              ; disparos hechos (8 bits, para las pruebas)
jt:     .res 1
jf:     .res 1
.bss
chk_aviso: .res 1           ; frames de aviso de checkpoint
bx:   .res NBALA
by:   .res NBALA            ; 0 = libre
fx_x: .res NFX
fx_y: .res NFX
fx_n: .res NFX              ; frames que le quedan (0 = libre)
fx_g: .res NFX              ; 0 = chispa 8x8, SCALE2X = grande
.code
.proc jug_init
    lda #0
    sta disp
    sta combo
.endproc
.proc jug_sale              ; sale de un checkpoint
    lda #0
    sta est
    sta calor
    sta apagon
    sta muere
    sta cad
    sta enfr
    sta chk_aviso
    sta perf_t
    sta doble_t
    sta escudo
    ldx #NBALA-1
@b: sta by,x
    sta fx_n,x              ; NFX = NBALA
    dex
    bpl @b
    lda #120
    sta inv
    lda #152
    sta px
    lda #190
    sta py
    rts
.endproc

; Checkpoints: guarda el punto, premia y da un respiro.
.proc meta
    lda chk_aviso
    beq @mira
    dec chk_aviso
    bne @mira
    lda #MSG_NADA
    sta msg
@mira:
    lda est
    bne @r
    lda py
    clc
    adc #8
    jsr ter_chk
    bcc @r
    cmp #0                  ; jefe vencido: además, una vida
    bne @premio
    lda vidas
    cmp #9
    bcs @premio
    inc vidas
@premio:
    lda #0
    sta calor
    sta apagon
    lda #MSG_CHK
    sta msg
    lda #FX_CHK
    jsr snd_play
    lda #100
    sta chk_aviso
    jsr en_respiro
    jmp suma_chk
@r: rts
.endproc

.proc jug_frame
    lda est
    beq @vuelo
    cmp #EST_MUERE
    bne @fx
    dec muere
    bne @fx
    jsr reaparece
    jmp @fx
@vuelo:
    jsr mejoras
    jsr mover
    jsr temperatura
    jsr disparo
    jsr choque
    jsr meta
    lda enfr                ; alarma con el calor alto
    and #31
    bne @fx
    lda calor
    cmp #CAL_ALTO
    bcc @fx
    lda #FX_ALARMA
    jsr snd_play
@fx:
    jsr balas
    jmp efectos
.endproc

.proc mover                 ; 2 px/frame; con los sistemas apagados, 1
    lda joy
    and #J_LEFT
    beq @der
    lda px
    cmp #66
    bcc @der
    dec px
    lda apagon
    bne @der
    dec px
@der:
    lda joy
    and #J_RIGHT
    beq @arr
    lda px
    cmp #239
    bcs @arr
    inc px
    lda apagon
    bne @arr
    inc px
@arr:
    lda joy
    and #J_UP
    beq @aba
    lda py
    cmp #34
    bcc @aba
    dec py
    lda apagon
    bne @aba
    dec py
@aba:
    lda joy
    and #J_DOWN
    beq @fin
    lda py
    cmp #215
    bcs @fin
    inc py
    lda apagon
    bne @fin
    inc py
@fin:
    rts
.endproc

.proc mejoras
    inc enfr                ; también divide el calor
    lda enfr
    and #3
    bne @r
    lda perf_t
    beq @d
    dec perf_t
@d: lda doble_t
    beq @r
    dec doble_t
@r: rts
.endproc

; --- calor ------------------------------------------------------------------
.proc temperatura
    lda apagon
    beq @normal
    dec apagon
    beq @listo
    lda calor               ; se vacía durante el apagón
    beq @r
    dec calor
@r: rts
@listo:
    lda #0
    sta calor
    rts
@normal:
    lda py
    clc
    adc #8
    jsr ter_fila            ; X = fila del mapa bajo la sonda
    lda px
    clc
    adc #8
    lsr
    lsr
    lsr
    sta jt                  ; columna del centro
    lda w_fri,x             ; corriente fría: 4 columnas desde w_fri
    bmi @lava
    sta jf
    lda jt
    cmp jf
    bcc @lava
    sbc jf
    cmp #4
    bcs @lava
    lda #1
    jmp baja
@lava:
    lda w_tip,x
    cmp #1
    bne @enfria
    lda jt                  ; a 4 columnas o menos de la pared caliente
    sec
    sbc w_izq,x
    cmp #5
    bcc @quema
    lda w_der,x
    sec
    sbc jt
    cmp #5
    bcs @enfria
@quema:
    lda enfr
    and #3
    bne @fin
    lda #1
    jmp sube
@enfria:
    lda enfr
    and #3
    bne @fin
    lda #1
    jmp baja
@fin:
    rts
.endproc

.proc sube                  ; calor += A; al tope, apagón
.ifdef TURBO
    rts
.endif
    clc
    adc calor
    cmp #CAL_MAX
    bcc @ok
    lda #FX_APAGON
    jsr snd_play
    lda d_apag
    sta apagon
    lda #CAL_MAX
@ok:
    sta calor
    rts
.endproc

.proc baja                  ; calor -= A, sin bajar de 0
    sta jt
    lda calor
    sec
    sbc jt
    bcs @ok
    lda #0
@ok:
    sta calor
    rts
.endproc

; --- disparos ---------------------------------------------------------------
.proc disparo
    lda cad
    beq @puede
    dec cad
    rts
@puede:
    lda joy
    and #J_FIRE
    beq @fin
    lda apagon
    bne @fin
    ldx #NBALA-1
@b: lda by,x
    beq @libre
    dex
    bpl @b
    rts
@libre:
    lda py
    sec
    sbc #4
    sta by,x
    lda px
    clc
    adc #4
    ldy doble_t
    beq @una
    sbc #3                  ; (C = 0: resta 4) bala izquierda
    sta bx,x
@b2:
    dex                     ; y la derecha, si queda hueco
    bmi @ya
    lda by,x
    bne @b2
    lda py
    sec
    sbc #4
    sta by,x
    lda px
    clc
    adc #8
@una:
    sta bx,x
@ya:
    lda #CADENCIA
    sta cad
    inc disp
    lda #FX_DISP
    jsr snd_play
    lda d_cal
    jmp sube
@fin:
    rts
.endproc

.proc balas
    ldx #NBALA-1
@b: lda by,x
    beq @otra
    sec
    sbc #VEL_BALA
    bcc @fuera              ; por debajo de 0 daría la vuelta
    cmp #24
    bcc @fuera
    sta by,x
    stx jf
    tay
    iny
    iny
    lda bx,x
    clc
    adc #4                  ; centro de la bala
    tax
    jsr ter_punto
    ldx jf
    bcc @otra
    lda bx,x                ; chispa en la pared
    sta jt
    ldy by,x
    lda #0
    sta by,x
    lda jt
    jsr fx_chispa
    lda #FX_CHISPA
    jsr snd_play
    ldx jf
    jmp @otra
@fuera:
    lda #0
    sta by,x
@otra:
    dex
    bpl @b
    rts
.endproc

; --- choque y vidas ---------------------------------------------------------
.proc choque                ; caja 10x11: perdona las puntas del dibujo
    lda inv
    beq @mira
    dec inv
    rts
@mira:
    lda px
    clc
    adc #3
    tax
    lda py
    clc
    adc #3
    tay
    jsr ter_choca
    bcc fin_choque
.endproc
; Daño: gasta el escudo o mata. Destruye A, X, Y.
.proc jug_danio
    lda inv
    bne fin_choque
    sta combo
.if .defined(TURBO) .or .defined(INMORTAL)
    lda #90
    sta inv
    rts
.endif
    lda escudo
    beq @muere
    lda #0
    sta escudo
    lda #FX_ESCUDO
    jsr snd_play
    lda #90
    sta inv
    rts
@muere:
    lda #FX_MUERE
    jsr snd_play
    lda #EST_MUERE
    sta est
    lda #60
    sta muere
    ldy py
    lda px
    jmp fx_grande
.endproc
fin_choque:
    rts

.proc reaparece
    lda #EST_REAP
    dec vidas
    bne @e
    lda #EST_SINV
@e: sta est
    rts
.endproc

; --- efectos ----------------------------------------------------------------
; A = x, Y = y. Si no hay hueco, no se ve.
.proc fx_chispa
    pha
    lda #0
    beq fx_nuevo
.endproc
.proc fx_grande
    pha
    lda #SCALE2X
.endproc
.proc fx_nuevo
    sta jt
    ldx #NFX-1
@b: lda fx_n,x
    beq @libre
    dex
    bpl @b
    pla
    rts
@libre:
    pla
    sta fx_x,x
    tya
    sta fx_y,x
    lda jt
    sta fx_g,x
    beq @corto
    lda #31
    bne @n
@corto:
    lda #11
@n: sta fx_n,x
    rts
.endproc

.proc efectos
    ldx #NFX-1
@b: lda fx_n,x
    beq @o
    dec fx_n,x
    lda fx_y,x              ; quieta respecto al terreno: baja con el scroll
    clc
    adc dsc
    sta fx_y,x
    cmp #240
    bcc @o
    lda #0
    sta fx_n,x
@o: dex
    bpl @b
    rts
.endproc

; --- dibujo -----------------------------------------------------------------
.proc jug_dibuja
    ldx #NBALA-1
@b: lda by,x
    bne @bv
    lda #SPR_OFF
@bv:
    sta spr_y+SPR_BALA,x
    lda bx,x
    sta spr_x+SPR_BALA,x
    lda #S_BALA
    sta spr_t+SPR_BALA,x
    lda #1
    sta spr_f+SPR_BALA,x
    dex
    bpl @b
    ldx #NFX-1
@f: lda fx_n,x
    bne @fv
    lda #SPR_OFF
    sta spr_y+SPR_FX,x
    bne @fo
@fv:
    ldy fx_g,x
    beq @chispa
    lsr
    lsr
    lsr                     ; 31..1 -> 3..0
@chispa:
    lsr
    lsr                     ; chispa 11..1 -> 2..0; grande -> 0
    cpy #0
    beq @pat
    lda fx_n,x
    lsr
    lsr
    lsr
    cmp #3
    bcc @pat
    lda #2
@pat:
    tay
    lda t_boom,y
    sta spr_t+SPR_FX,x
    lda fx_x,x
    sta spr_x+SPR_FX,x
    lda fx_y,x
    sta spr_y+SPR_FX,x
    lda fx_g,x
    ora #1
    sta spr_f+SPR_FX,x
@fo:
    dex
    bpl @f

    lda est
    bne @oculta
    lda inv                 ; parpadea
    and #4
    beq @ve
@oculta:
    lda #SPR_OFF
    sta spr_y
    sta spr_y+1
    sta spr_y+2
    sta spr_y+3
    rts
@ve:
    lda px
    sta spr_x
    sta spr_x+2
    clc
    adc #8
    sta spr_x+1
    sta spr_x+3
    lda py
    sta spr_y
    sta spr_y+1
    clc
    adc #8
    sta spr_y+2
    sta spr_y+3
    lda #S_SONDA_A
    sta spr_t
    sta spr_t+1
    lda #S_SONDA_B
    sta spr_t+2
    sta spr_t+3
    lda #0
    ldx apagon              ; apagada: paleta roja
    beq @pal
    lda #2
@pal:
    sta spr_f
    sta spr_f+2
    ora #FLIP_X
    sta spr_f+1
    sta spr_f+3
    rts
.endproc

.rodata
t_boom: .byte S_BOOM_C, S_BOOM_B, S_BOOM_A
