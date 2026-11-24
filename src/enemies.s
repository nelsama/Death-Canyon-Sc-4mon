; Enemigos, balas enemigas, mejoras, jefes y puntuación.
.include "hardware.s"
.include "gfx.inc"
.import spr_x, spr_y, spr_t, spr_f
.import w_izq, w_der, w_isi, ter_fila, ter_punto, rng
.import bx, by, jug_danio, fx_grande, sube
.import w_tip
.importzp px, py, est, inv, calor, perf_t, doble_t, escudo, combo, apagon
.importzp zona, zfila, vuelta, gen_fila, filas_n, jefe_est, sc_y, dsc
.export hz_n, vi_t, n_reb, en_init, en_limpia, en_frame, en_dibuja, suma_chk, en_respiro
.import snd_play
.import d_cad, d_nen, d_mul
.exportzp amenaza
.export puntos, jf_hp, bajas, n_disp, mj_t
NEN = 8
NEB = 6
NBALA = 4
SP_EN = 8
SP_JF = 16
SP_EB = 20
SP_MJ = 26
SP_ES = 27
TORRETA = 1
ENJAMBRE = 2
MINA = 3
; peligros de zona
ROCA = 4                    ; ceniza: cae más rápido que el terreno
GEISER = 5                  ; lava: entra en erupción y calienta
COMPUERTA = 6               ; ruinas: bloque que va de pared a pared
.zeropage
amenaza: .res 1
ult_fil: .res 1
sp_n:    .res 1             ; filas hasta el próximo enemigo
et:      .res 1
eu:      .res 1
ev:      .res 1
ex:      .res 1             ; origen de un disparo
ey:      .res 1
vx:      .res 1
vy:      .res 1
sgx:     .res 1
sgy:     .res 1
tic:     .res 1
s_n:     .res 1
.bss
hz_n:    .res 1             ; filas hasta el próximo peligro
vi_t:    .res 1             ; viento (hielo): 0-127 calma, 128-159 aviso, 160+ sopla
vi_d:    .res 1             ; sentido
vi_x:    .res 1
n_reb:   .res 1             ; rebotes (cristal), para las pruebas
eb_rb:   .res NEB           ; 1 = la bala ya ha rebotado
jf_on:   .res 1             ; 0 no, 1 entra/pelea
jf_x:    .res 1
jf_y:    .res 1
jf_hp:   .res 1
jf_a:    .res 1             ; fase del movimiento
jf_c:    .res 1             ; frames hasta disparar
jf_g:    .res 1             ; destello al recibir
jf_k:    .res 1             ; contador de disparos
mj_t:    .res 1             ; mejora: 0 no hay, 1-4
mj_x:    .res 1
mj_y:    .res 1
puntos:  .res 3             ; BCD, byte bajo primero
bajas:   .res 1             ; enemigos destruidos (pruebas)
n_disp:  .res 1             ; disparos enemigos (pruebas)
en_t: .res NEN
en_x: .res NEN
en_y: .res NEN
en_a: .res NEN              ; fase
en_b: .res NEN              ; x base (enjambre)
en_c: .res NEN              ; retardo o frames hasta disparar
eb_on: .res NEB
eb_x: .res NEB
eb_y: .res NEB
eb_fx: .res NEB             ; fracciones en 1/16 px
eb_fy: .res NEB
eb_vx: .res NEB             ; velocidad con signo en 1/16 px
eb_vy: .res NEB
.code
.proc en_init               ; partida nueva
    lda #0
    sta puntos
    sta puntos+1
    sta puntos+2
    sta bajas
    sta n_disp
    sta amenaza
.endproc
.proc en_limpia             ; quita todo lo que haya en pantalla
    lda #0
    ldx #NEN-1
@e: sta en_t,x
    sta en_x,x
    sta en_y,x
    dex
    bpl @e
    sta jf_on
    sta jf_hp
    sta jf_g
    sta mj_t
    sta mj_x
    sta tic
    sta vi_t
    sta vi_d
    lda #30
    sta hz_n
    lda filas_n
    sta ult_fil
    lda #16
    sta sp_n
.endproc
.proc en_limpia_balas
    lda #0
    ldx #NEB-1
@b: sta eb_on,x
    dex
    bpl @b
    rts
.endproc

.proc en_frame
    inc tic
    lda vuelta              ; amenaza = vuelta*20 + zona*4 + tramo
    asl
    asl
    adc vuelta              ; vuelta*5 (vuelta <= 2: C = 0)
    adc zona
    asl
    asl
    sta et
    lda zfila
    rol
    rol
    rol
    and #3
    clc
    adc et
    cmp #40
    bcc @am
    lda #39
@am:
    sta amenaza
    jsr mueve
    jsr balas
    jsr mejora
    jsr jefe
    jsr viento
    jsr golpes
    lda filas_n             ; ¿filas nuevas de terreno?
    cmp ult_fil
    beq @fin
    inc ult_fil
    jsr aparece
    jsr peligro
@fin:
    rts
.endproc

; --- peligros de zona ---------------------------------------------------------
.proc peligro
    lda jefe_est
    bne @r
    dec hz_n
    bne @r
    lda amenaza             ; cada 22 - amenaza/4 filas
    lsr
    lsr
    sta et
    lda #22
    sec
    sbc et
    sta hz_n
    lda zona
    beq @roca
    cmp #1
    beq @geiser
    cmp #4
    beq @comp
@r: rts                     ; cristal y hielo no ponen objetos
@roca:
    jsr hueco
    bcs @r
    lda #24
    jsr ter_fila
    lda w_der,x             ; x al azar dentro del paso
    sec
    sbc w_izq,x
    sbc #3
    sta et
    stx eu
    jsr rng
    and #15
@m: cmp et
    bcc @ok
    sbc et
    bcs @m
@ok:
    sec                     ; + 1
    adc w_izq,x
    asl
    asl
    asl
    pha
    jsr hueco
    pla
    bcs @r
    sta en_x,x
    lda #24
    sta en_y,x
    lda #ROCA
    sta en_t,x
    rts
@geiser:
    jsr hueco
    bcs @r
    jsr y_fila
    sta en_y,x
    jsr rng                 ; a un lado u otro del centro
    and #31
    sta eu
    jsr centro
    sec
    sbc #16
    clc
    adc eu
    sta en_x,x
    lda #GEISER
    bne @pon
@comp:
    jsr hueco
    bcs @r
    jsr y_fila
    sta en_y,x
    tya
    sta en_b,x              ; fila: de ahí salen sus topes
    jsr centro
    sta en_x,x
    jsr rng
    and #$80
    sta en_a,x
    lda #COMPUERTA
    sta en_t,x
    rts
@pon:
    sta en_t,x
    jsr rng
    sta en_a,x              ; fase de la erupción
    rts
.endproc

.proc roca                  ; baja 2 px más; se rompe al tocar pared
    lda en_y,x
    clc
    adc #2
    sta en_y,x
    cmp #228
    bcs @quita
    stx ev
    adc #14                 ; C = 0: borde inferior
    tay
    lda en_x,x
    clc
    adc #8
    tax
    jsr ter_punto
    ldx ev
    bcc @r
    lda en_y,x
    tay
    lda en_x,x
    jsr boom
    ldx ev
@quita:
    lda #0
    sta en_t,x
@r: rts
.endproc

.proc compuerta
    ldy en_b,x
    lda en_a,x
    bmi @iz
    inc en_x,x
    lda w_der,y
    sec
    sbc #2
    asl
    asl
    asl
    cmp en_x,x
    bcs @r
    bcc @vuelve
@iz:
    dec en_x,x
    lda w_izq,y
    clc
    adc #1
    asl
    asl
    asl
    cmp en_x,x
    bcc @r
@vuelve:
    lda en_a,x
    eor #$80
    sta en_a,x
@r: rts
.endproc

; C = 1 si el géiser X está en erupción (64 de cada 160 frames aprox.)
.proc erupcion
    lda en_a,x
    and #$7F
    cmp #72
    rts
.endproc

; Viento de la zona de hielo: aviso con rachas visibles y después empuja.
.proc viento
    lda zona
    cmp #3
    bne @nada
    lda jefe_est
    ora est
    beq @sopla
@nada:
    lda #0
    sta vi_t
    rts
@sopla:
    inc vi_t
    bne @v
    lda vi_d
    eor #1
    sta vi_d
@v: lda vi_t
    cmp #128
    bcc @r
    bne @x
    lda #FX_VIENTO
    jsr snd_play
@x: lda vi_d
    bne @izq
    lda vi_x
    clc
    adc #5
    sta vi_x
    jmp @emp
@izq:
    lda vi_x
    sec
    sbc #5
    sta vi_x
@emp:
    lda vi_t
    cmp #160
    bcc @r
    lsr                     ; 1 px cada 2 frames
    bcs @r
    lda vi_d
    bne @ei
    lda px
    cmp #240
    bcs @r
    inc px
    rts
@ei:
    lda px
    cmp #65
    bcc @r
    dec px
@r: rts
.endproc

.proc dib_viento            ; rachas en los sprites del jefe (no coinciden)
    lda vi_t
    cmp #128
    bcc @r
    ldx #3
@l: lda t_vy,x
    sta spr_y+SP_JF,x
    lda vi_x
    clc
    adc t_vx,x
    sta spr_x+SP_JF,x
    lda #S_VIENTO
    sta spr_t+SP_JF,x
    lda #SPR_PRIO|SCALE2X   ; detrás de la roca
    sta spr_f+SP_JF,x
    dex
    bpl @l
@r: rts
.endproc

; --- aparición ---------------------------------------------------------------
.proc aparece
    lda jefe_est            ; con jefe no salen otros
    bne @no
    dec sp_n
    beq @si
@no:
    rts
@si:
    lda amenaza             ; filas hasta el siguiente: 13 - amenaza/4, mín. 5
    lsr
    lsr
    sta et
    lda #13
    sec
    sbc et
    cmp #5
    bcs @ok
    lda #5
@ok:
    sta sp_n
    jsr rng
    and #3
    beq @torreta
    cmp #1
    beq @enj
    cmp #2
    bne @torreta
    lda amenaza
    cmp #4
    bcc @torreta
    jmp sale_mina
@enj:
    lda amenaza
    cmp #2
    bcc @torreta
    jmp sale_enjambre
@torreta:
    jmp sale_torreta
.endproc

; X = hueco libre. C = 1 si no hay. Respeta el máximo de la amenaza (6..8).
.proc hueco
    lda amenaza             ; base de la dificultad + 1 cada 4
    lsr
    lsr
    clc
    adc d_nen
    cmp #NEN
    bcc @t
    lda #NEN
@t: tax
    dex
@b: lda en_t,x
    beq @si
    dex
    bpl @b
    sec
    rts
@si:
    clc
    rts
.endproc

; Fila de nacimiento: gen_fila+1. La última generada puede estar hasta 7 px
; por encima de y = 0 y la coordenada daría la vuelta; ésta va de 1 a 8.
; Devuelve Y = fila y A = y de pantalla exacta.
.proc y_fila
    ldy gen_fila
    iny
    tya
    and #31
    tay
    asl
    asl
    asl
    sec
    sbc sc_y
    rts
.endproc

; El cañón mide dos filas: sólo se apoya donde la pared es recta en las dos.
; Prueba un lado y luego el otro; si ninguno vale, lo intenta en la fila
; siguiente.
.proc sale_torreta
    jsr hueco
    bcs @r
    jsr rng
    and #$80
    sta en_a,x              ; lado
    jsr y_fila
    sta en_y,x
    sty et                  ; fila de arriba
    iny
    tya
    and #31
    sta eu                  ; fila de abajo
    jsr @prueba
    bcc @pon
    lda en_a,x
    eor #$80
    sta en_a,x
    jsr @prueba
    bcc @pon
    lda #1
    sta sp_n
@r: rts
@pon:
    asl
    asl
    asl
    sta en_x,x
    lda #TORRETA
    sta en_t,x
    jsr cadencia
    sta en_c,x
    rts
@prueba:                    ; C = 0 y A = columna si la pared es recta
    lda en_a,x
    bmi @der
    ldy et
    lda w_izq,y
    ldy eu
    cmp w_izq,y
    bne @no
    clc
    adc #1
    clc
    rts
@der:
    ldy et
    lda w_der,y
    ldy eu
    cmp w_der,y
    bne @no
    sec
    sbc #2
    clc
    rts
@no:
    sec
    rts
.endproc

.proc sale_mina
    jsr hueco
    bcs @r
    jsr y_fila
    sta en_y,x
    lda #MINA
    sta en_t,x
    jsr centro              ; Y = fila de y_fila
    sta en_x,x
@r: rts
.endproc

.proc centro                ; Y = fila -> A = x de 16 px centrada en el paso
    lda w_isi,y
    bpl @c                  ; con isla: mitad izquierda
    lda w_der,y
@c: clc
    adc w_izq,y
    asl
    asl
    sec
    sbc #4
    rts
.endproc

.proc sale_enjambre
    lda #24
    jsr ter_fila            ; X = primera fila visible
    txa
    tay
    jsr centro
    sta eu
    cmp #92                 ; que la onda no se salga del campo
    bcs @a
    lda #92
@a: cmp #212
    bcc @b
    lda #212
@b: sta eu
    lda #4
    sta ev
@l: jsr hueco
    bcs @r
    lda #ENJAMBRE
    sta en_t,x
    lda #24
    sta en_y,x
    lda eu
    sta en_b,x
    sta en_x,x
    lda #0
    sta en_a,x
    lda ev                  ; salen uno cada 12 frames
    asl
    asl
    sta en_c,x
    asl
    adc en_c,x
    sta en_c,x
    dec ev
    bne @l
@r: rts
.endproc

.proc cadencia              ; A = base - 2*amenaza, mín. 30
    lda amenaza
    asl
    sta et
    lda d_cad
    sec
    sbc et
    bcc @m
    cmp #30
    bcs @r
@m: lda #30
@r: rts
.endproc

; --- movimiento --------------------------------------------------------------
.proc mueve
    ldx #NEN-1
@l: lda en_t,x
    beq @sig
    cmp #ENJAMBRE
    beq @enj
    jsr baja_scroll         ; torretas y minas van con el terreno
    bcs @sig
    lda en_t,x
    cmp #MINA
    beq @mina
    cmp #ROCA
    beq @roca
    cmp #GEISER
    beq @geiser
    cmp #COMPUERTA
    beq @comp
    jsr torreta
    jmp @toca
@roca:
    jsr roca
    jmp @toca
@geiser:
    inc en_a,x
    jmp @toca
@comp:
    jsr compuerta
    jmp @toca
@mina:
    jsr mina
    jmp @toca
@enj:
    jsr enjambre
@toca:
    jsr toca_sonda
@sig:
    dex
    bpl @l
    rts
.endproc

.proc baja_scroll           ; C = 1 si ha salido de la pantalla
    lda en_y,x
    clc
    adc dsc
    sta en_y,x
    cmp #240
    bcc @r
    lda #0
    sta en_t,x
    sec
@r: rts
.endproc

.proc torreta
    lda est
    bne @r
    lda en_y,x
    cmp #28
    bcc @r
    cmp #176
    bcs @r
    dec en_c,x
    bne @r
    jsr cadencia
    sta en_c,x
    jsr origen
    lda amenaza
    cmp #8
    bcc @fija
    jmp apunta              ; desde la amenaza 8, apuntan
@fija:
    lda #16                 ; en diagonal hacia dentro
    sta vy
    lda en_a,x
    bmi @d
    lda #16
    bne @x
@d: lda #$F0
@x: sta vx
    jmp dispara
@r: rts
.endproc

.proc mina
    lda est
    bne @r
    lda calor               ; persigue si la sonda está caliente
    cmp #40
    bcc @r
    lda tic
    lsr
    bcc @r
    lda en_y,x
    cmp #28
    bcc @r
    lda en_x,x
    cmp px
    beq @y
    bcs @iz
    inc en_x,x
    bne @y
@iz:
    dec en_x,x
@y: lda en_y,x
    cmp py
    beq @r
    bcs @ar
    inc en_y,x
    rts
@ar:
    dec en_y,x
@r: rts
.endproc

.proc enjambre
    lda en_c,x
    beq @va
    dec en_c,x
    rts
@va:
    inc en_a,x
    inc en_y,x
    lda amenaza             ; variante rápida desde la 20
    cmp #20
    bcc @n
    inc en_y,x
@n: lda en_y,x
    cmp #236
    bcc @d
    lda #0
    sta en_t,x
    rts
@d: lda en_a,x
    lsr
    and #31
    tay
    lda seno,y
    clc
    adc en_b,x
    sta en_x,x
    lda amenaza             ; disparan desde la 12, una vez por pasada
    cmp #12
    bcc @r
    lda en_a,x
    cmp #40
    bne @r
    lda est
    bne @r
    jsr origen
    jmp apunta
@r: rts
.endproc

.proc visible               ; C = 1 si el enemigo X cuenta (choca y se ve)
    lda en_t,x
    cmp #ENJAMBRE
    bne @y
    lda en_c,x
    beq @y
    clc
    rts
@y: lda en_y,x
    cmp #24
    rts
.endproc

.proc toca_sonda
    lda est
    bne @r
    lda en_t,x
    beq @r
    jsr visible
    bcc @r
    lda en_x,x
    sec
    sbc px
    clc
    adc #10
    cmp #21
    bcs @r
    lda en_y,x
    sec
    sbc py
    clc
    adc #10
    cmp #21
    bcs @r
    lda en_t,x              ; el géiser no mata: calienta
    cmp #GEISER
    bne @mata
    jsr erupcion
    bcc @r
    lda #2
    jmp calienta
@mata:
    lda inv
    bne @r
    lda en_t,x
    cmp #COMPUERTA          ; indestructible
    beq @solo
    lda #0
    sta en_t,x
    lda en_y,x
    tay
    lda en_x,x
    jsr boom
@solo:
    jmp danio
@r: rts
.endproc

.proc calienta              ; calor += A (con apagón). Conserva X
    sta eu
    txa
    pha
    lda apagon
    bne @n
    lda eu
    jsr sube
@n: pla
    tax
    rts
.endproc

.proc boom                  ; A = x, Y = y. Conserva X
    sta eu
    txa
    pha
    lda eu
    jsr fx_grande
    lda #FX_EXP
    jsr snd_play
    pla
    tax
    rts
.endproc

.proc danio                 ; conserva X
    txa
    pha
    jsr jug_danio
    pla
    tax
    rts
.endproc

; --- disparos enemigos --------------------------------------------------------
.proc origen                ; centro del enemigo X (menos media bala)
    lda en_x,x
    clc
    adc #4
    sta ex
    lda en_y,x
    clc
    adc #4
    sta ey
    rts
.endproc

; Dispara desde ex,ey hacia la sonda. La velocidad queda entre 12 y 23
; dieciseisavos en el eje mayor, más 1/8 por cada 5 de amenaza. Conserva X.
.proc apunta
    lda #0
    sta sgx
    sta sgy
    lda px
    clc
    adc #4
    sec
    sbc ex
    bcs @dx
    eor #$FF
    adc #1
    inc sgx
@dx:
    sta vx
    lda py
    clc
    adc #4
    sec
    sbc ey
    bcs @dy
    eor #$FF
    adc #1
    inc sgy
@dy:
    sta vy
@red:
    lda vx
    cmp #24
    bcs @mitad
    lda vy
    cmp #24
    bcc @chico
@mitad:
    lsr vx
    lsr vy
    jmp @red
@chico:
    lda vx                  ; muy cerca: no puede quedarse parada
    ora vy
    cmp #8
    bcs @rap
    lda #12
    sta vy
@rap:
    lda amenaza
    cmp #15
    bcc @sg
    lda vx                  ; x1,5 desde la amenaza 15
    lsr
    clc
    adc vx
    sta vx
    lda vy
    lsr
    clc
    adc vy
    sta vy
@sg:
    lda sgx
    beq @s2
    lda #0
    sec
    sbc vx
    sta vx
@s2:
    lda sgy
    beq dispara
    lda #0
    sec
    sbc vy
    sta vy
.endproc
.proc dispara               ; ex, ey, vx, vy. Conserva X
    ldy #NEB-1
@b: lda eb_on,y
    beq @l
    dey
    bpl @b
    rts
@l: lda #1
    sta eb_on,y
    lda ex
    sta eb_x,y
    lda ey
    sta eb_y,y
    lda vx
    sta eb_vx,y
    lda vy
    sta eb_vy,y
    lda #0
    sta eb_fx,y
    sta eb_fy,y
    sta eb_rb,y
    inc n_disp
    lda #FX_EDISP
    jsr snd_play
    rts
.endproc

.macro AVANZA pos, frac, vel    ; pos += (frac+vel)/16, con signo
    lda frac,x
    clc
    adc vel,x
    pha
    and #$0F
    sta frac,x
    pla
    cmp #$80
    ror
    cmp #$80
    ror
    cmp #$80
    ror
    cmp #$80
    ror
    clc
    adc pos,x
    sta pos,x
.endmacro

.proc balas
    ldx #NEB-1
bucle:
    lda eb_on,x
    bne viva
    jmp sig
quita0:                     ; (quita queda lejos para un salto corto)
    lda #0
    sta eb_on,x
    jmp sig
viva:
    AVANZA eb_x, eb_fx, eb_vx
    AVANZA eb_y, eb_fy, eb_vy
    lda eb_y,x
    cmp #24
    bcc quita0
    cmp #236
    bcs quita0
    lda eb_x,x
    cmp #64
    bcc quita0
    cmp #248
    bcs quita0
    stx ev                  ; contra la roca
    clc
    adc #4
    pha
    lda eb_y,x
    clc
    adc #4
    tay
    pla
    tax
    jsr ter_punto
    ldx ev
    bcc libre
    lda zona                ; en el cristal rebotan una vez
    cmp #2
    bne quita
    lda eb_rb,x
    bne quita
    inc eb_rb,x
    inc n_reb
    lda #0
    sec
    sbc eb_vx,x
    sta eb_vx,x
    AVANZA eb_x, eb_fx, eb_vx   ; sale de la pared
    jmp sig
libre:
    lda est
    bne sig
    lda eb_x,x
    clc
    adc #1                  ; +4 de la bala, -3 de la caja
    sec
    sbc px
    cmp #10
    bcs sig
    lda eb_y,x
    clc
    adc #1
    sec
    sbc py
    cmp #11
    bcs sig
    lda inv
    bne sig
    lda #0
    sta eb_on,x
    jsr danio
    jmp sig
quita:
    lda #0
    sta eb_on,x
sig:
    dex
    bmi fin
    jmp bucle
fin:
    rts
.endproc

; --- balas propias contra enemigos -------------------------------------------
.proc golpes
    ldy #NBALA-1
@b: lda by,y
    beq @sigb
    lda jf_on
    beq @en
    jsr golpe_jefe
    lda by,y
    beq @sigb
@en:
    ldx #NEN-1
@e: lda en_t,x
    beq @sige
    lda bx,y
    clc
    adc #4
    sec
    sbc en_x,x
    cmp #16
    bcs @sige
    lda by,y
    adc #2                  ; C = 0
    sec
    sbc en_y,x
    cmp #16
    bcs @sige
    jsr visible
    bcc @sige
    lda en_t,x
    cmp #GEISER             ; las balas lo atraviesan
    beq @sige
    cmp #COMPUERTA          ; y la compuerta las para
    bne @muere
    lda #FX_CHISPA
    jsr snd_play
    lda #0
    sta by,y
    beq @sigb
@muere:
    jsr mata
    lda perf_t              ; la perforante sigue
    bne @sige
    lda #0
    sta by,y
    beq @sigb
@sige:
    dex
    bpl @e
@sigb:
    dey
    bpl @b
    rts
.endproc

.proc mata                  ; enemigo X. Conserva X e Y
    tya
    pha
    lda en_t,x
    tay
    lda t_pts,y
    sta et
    lda #0
    sta en_t,x
    inc bajas
    lda et
    jsr suma
    lda en_y,x
    tay
    lda en_x,x
    jsr boom
    lda combo               ; hasta x4: uno más cada 5 bajas
    cmp #15
    bcs @m
    inc combo
@m: lda mj_t                ; ¿suelta mejora? 1 de cada 8
    bne @r
    jsr rng
    ldy amenaza             ; 1 de cada 8; desde la 15, 1 de cada 16
    cpy #15
    bcc @md
    and #$3F
    bcs @mc
@md:
    and #$1F
@mc:
    cmp #4
    bcs @r
    adc #1                  ; C = 0: 1-4
    sta mj_t
    lda en_x,x
    clc
    adc #4
    sta mj_x
    lda en_y,x
    sta mj_y
@r: pla
    tay
    rts
.endproc

; puntos += A (BCD) x multiplicador del combo. Conserva X
.proc suma
    sta et
    lda d_mul
    sta s_n
@m: lda combo
    ldy #1
@d: cmp #5
    bcc @s
    sbc #5
    iny
    bne @d
@s: sed
@l: lda puntos
    clc
    adc et
    sta puntos
    lda puntos+1
    adc #0
    sta puntos+1
    lda puntos+2
    adc #0
    sta puntos+2
    dey
    bne @l
    cld
    dec s_n                 ; x multiplicador de la dificultad
    bne @m
    rts
.endproc

.proc suma_chk              ; checkpoint: 100 puntos, por los multiplicadores
    lda #$50
    jsr suma
    lda #$50
    jmp suma
.endproc

.proc en_respiro            ; sin enemigos nuevos durante ~2 s
    lda #16
    sta sp_n
    rts
.endproc

; --- mejoras ------------------------------------------------------------------
.proc mejora
    lda mj_t
    beq @r
    inc mj_y
    lda mj_y
    cmp #236
    bcs @quita
    lda est
    bne @r
    lda mj_x
    sec
    sbc px
    clc
    adc #7
    cmp #23
    bcs @r
    lda mj_y
    sec
    sbc py
    clc
    adc #7
    cmp #23
    bcs @r
    lda #FX_MEJORA
    jsr snd_play
    lda mj_t
    cmp #2
    bcc @doble
    beq @perf
    cmp #3
    beq @esc
    lda #0                  ; 4: refrigerante
    sta calor
    beq @quita
@doble:
    lda #150                ; 10 s (baja cada 4 frames)
    sta doble_t
    bne @quita
@perf:
    lda #150
    sta perf_t
    bne @quita
@esc:
    lda #1
    sta escudo
@quita:
    lda #0
    sta mj_t
@r: rts
.endproc

; --- jefes --------------------------------------------------------------------
.proc jefe
    lda jefe_est
    cmp #1
    beq @hay
    rts
@hay:
    lda jf_on
    bne @vivo
    inc jf_on
    lda zona
    asl
    asl
    adc zona
    adc #20                 ; 20 + 5 por zona
    sta jf_hp
    lda vuelta              ; +50 % por vuelta
    beq @hp
    lda jf_hp
    lsr
    adc jf_hp
    sta jf_hp
@hp:
.ifdef TURBO
    lda #5
    sta jf_hp
.endif
    lda #0
    sta jf_y
    sta jf_a
    sta jf_g
    sta jf_k
    lda #144
    sta jf_x
    lda #90
    sta jf_c
    rts
@vivo:
    lda jf_g
    beq @b
    dec jf_g
@b: lda jf_y
    cmp #44
    bcs @lado
    lda tic
    lsr
    bcc @ataca
    inc jf_y
    jmp @ataca
@lado:
    ldx zona
    lda tic
    and jf_lento,x          ; unos se mueven cada frame y otros cada 2
    bne @ataca
    inc jf_a
    lda jf_a                ; vaivén triangular 72..216
    cmp #144
    bcc @tr
    lda #0
    sta jf_a
@tr:
    cmp #72
    bcc @ida
    lda #144
    sec
    sbc jf_a
@ida:
    asl
    clc
    adc #72
    sta et                  ; se acerca a su sitio sin saltos
    lda jf_x
    cmp et
    beq @ataca
    bcs @iz
    inc jf_x
    bne @ataca
@iz:
    dec jf_x
@ataca:
    jsr jefe_toca
    lda est
    bne @r
    dec jf_c
    bne @r
    ldx zona
    lda amenaza
    sta et
    lda jf_cad,x
    sec
    sbc et
    sta jf_c
    inc jf_k
    lda jf_x
    clc
    adc #12
    sta ex
    lda jf_y
    clc
    adc #24
    sta ey
    lda jf_tipo,x
    beq @abanico
    cmp #1
    beq @apunta
    lda jf_k                ; 2: alterna
    lsr
    bcs @apunta
@abanico:
    lda #16
    sta vy
    lda #$F4
    sta vx
    jsr dispara
    lda #0
    sta vx
    jsr dispara
    lda #12
    sta vx
    jmp dispara
@apunta:
    jmp apunta
@r: rts
.endproc

.proc jefe_toca             ; 32x32 contra la sonda
    lda est
    ora inv
    bne @r
    lda px
    sec
    sbc jf_x
    clc
    adc #11
    cmp #39
    bcs @r
    lda py
    sec
    sbc jf_y
    clc
    adc #11
    cmp #39
    bcs @r
    jmp danio
@r: rts
.endproc

.proc golpe_jefe            ; bala Y
    lda jf_y
    cmp #24
    bcc @r
    lda bx,y
    clc
    adc #4
    sec
    sbc jf_x
    cmp #32
    bcs @r
    lda by,y
    sec
    sbc jf_y
    cmp #32
    bcs @r
    lda #0                  ; ni la perforante lo atraviesa
    sta by,y
    lda #FX_GOLPE
    jsr snd_play
    lda #4
    sta jf_g
    dec jf_hp
    bne @r
    tya
    pha
    lda #0
    sta jf_on
    lda #FX_JEFE
    jsr snd_play
    lda #2
    sta jefe_est
    inc bajas
    lda #$50                ; 500 x combo, en diez sumas de 50
    ldx #10
@p: lda #$50
    jsr suma
    dex
    bne @p
    ldx #3                  ; cuatro explosiones
@x: lda jf_x
    clc
    adc t_ex,x
    pha
    lda jf_y
    clc
    adc t_ey,x
    tay
    pla
    jsr boom
    dex
    bpl @x
    jsr en_limpia_balas
    pla
    tay
@r: rts
.endproc

; --- dibujo -------------------------------------------------------------------
.proc en_dibuja
    ldx #NEN-1
@e: lda en_t,x
    beq @off
    jsr visible
    bcc @off
    lda en_x,x
    sta spr_x+SP_EN,x
    lda en_y,x
    sta spr_y+SP_EN,x
    ldy en_t,x
    lda t_pat,y
    sta spr_t+SP_EN,x
    cpy #GEISER
    bne @flg
    jsr erupcion            ; en erupción, otro dibujo
    bcc @flg
    lda #S_GEIS_B
    sta spr_t+SP_EN,x
@flg:
    lda t_flg,y
    cpy #TORRETA
    bne @f
    ldy en_a,x              ; la del lado derecho, en espejo
    bpl @f
    ora #FLIP_X
@f: sta spr_f+SP_EN,x
    jmp @o
@off:
    lda #SPR_OFF
    sta spr_y+SP_EN,x
@o: dex
    bpl @e

    ldx #NEB-1
@b: lda #SPR_OFF
    ldy eb_on,x
    beq @by
    lda eb_x,x
    sta spr_x+SP_EB,x
    lda #S_EBALA
    sta spr_t+SP_EB,x
    lda #2
    sta spr_f+SP_EB,x
    lda eb_y,x
@by:
    sta spr_y+SP_EB,x
    dex
    bpl @b

    lda #SPR_OFF            ; mejora
    ldx mj_t
    beq @my
    txa
    clc
    adc #S_MEJ_D-1
    sta spr_t+SP_MJ
    lda mj_x
    sta spr_x+SP_MJ
    lda #0
    sta spr_f+SP_MJ
    lda mj_y
    cmp #24
    bcs @my
    lda #SPR_OFF
@my:
    sta spr_y+SP_MJ

    lda #SPR_OFF            ; escudo, detrás de la sonda
    ldx escudo
    beq @ey
    ldx est
    bne @ey
    lda px
    sta spr_x+SP_ES
    lda #S_ESCUDO
    sta spr_t+SP_ES
    lda #SCALE2X
    sta spr_f+SP_ES
    lda py
@ey:
    sta spr_y+SP_ES

    lda jf_on               ; jefe: 4 sprites a 2x
    beq @joff
    lda jf_y
    cmp #24
    bcs @jve
@joff:
    lda #SPR_OFF
    ldx #3
@jo:
    sta spr_y+SP_JF,x
    dex
    bpl @jo
    jmp dib_viento
@jve:
    sta spr_y+SP_JF
    sta spr_y+SP_JF+1
    clc
    adc #16
    sta spr_y+SP_JF+2
    sta spr_y+SP_JF+3
    lda jf_x
    sta spr_x+SP_JF
    sta spr_x+SP_JF+2
    clc
    adc #16
    sta spr_x+SP_JF+1
    sta spr_x+SP_JF+3
    lda zona
    asl
    adc #S_JEFE
    sta spr_t+SP_JF
    sta spr_t+SP_JF+1
    adc #1
    sta spr_t+SP_JF+2
    sta spr_t+SP_JF+3
    lda #SCALE2X|3
    ldx jf_g
    beq @jp
    lda #SCALE2X|1
@jp:
    sta spr_f+SP_JF
    sta spr_f+SP_JF+2
    ora #FLIP_X
    sta spr_f+SP_JF+1
    sta spr_f+SP_JF+3
    rts
.endproc

.rodata
t_pts: .byte 0, $50, $20, $80, $30, 0, 0
t_pat: .byte 0, S_TORRETA, S_ENJ, S_MINA, S_ROCA, S_GEIS_A, S_COMP
t_flg: .byte 0, SCALE2X|3, SCALE2X|3, SCALE2X|2, SCALE2X|2, SCALE2X|1, SCALE2X|0
t_vy:  .byte 46, 92, 138, 190
t_vx:  .byte 0, 100, 40, 160
t_ex:  .byte 0, 16, 0, 16
t_ey:  .byte 0, 0, 16, 16
jf_cad:   .byte 100, 80, 95, 80, 85
jf_tipo:  .byte 0, 1, 0, 1, 2
jf_lento: .byte 1, 0, 1, 0, 0
seno:
    .byte 0,5,9,13,17,20,22,24,24,24,22,20,17,13,9,5
    .byte 0,<-5,<-9,<-13,<-17,<-20,<-22,<-24,<-24,<-24,<-22,<-20,<-17,<-13,<-9,<-5
