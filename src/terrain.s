; Generador del cañón por zonas, y colisión por perfil en RAM.
; Cada fila del mapa guarda sus dos paredes (columnas sólidas) y una isla.
; Una fila tarda dos frames en entrar: atributos y después tiles. Se genera
; 3 filas por encima de lo visible (el mapa tiene 4 de margen).
.include "hardware.s"
.include "gfx.inc"
.import zona_gfx, zona_pal, zona_par
.import vq_put, vid_vuelca, pq_put
.importzp sc_y, sc_frac, v_lo, v_hi, vq_n, amenaza, frames
.export ter_init, ter_frame, ter_choca
.export w_izq, w_der, w_isi, w_isd, w_tip, w_fri, ter_punto, ter_fila, rng
.export tr, ter_desde, ter_zona, ter_chk, w_chk, chk_z, chk_t, chk_v
.exportzp zona, dist, gen_fila, rnd, zfila, vuelta, filas_n, jefe_est
.zeropage
gen_fila: .res 1            ; última fila generada (0-31)
fase:     .res 1            ; 1 = faltan los tiles de gen_fila
zona:     .res 1
zfila:    .res 1            ; filas dentro de la zona (255 = jefe)
vuelta:   .res 1            ; vueltas completas (máx. 2)
filas_n:  .res 1            ; filas generadas (contador libre)
jefe_est: .res 1            ; 0 no hay, 1 pelea, 2 vencido
dist:     .res 2            ; filas recorridas, BCD
rnd:      .res 2
p_izq:    .res 1            ; paredes actuales
p_der:    .res 1
o_izq:    .res 1            ; objetivo
o_der:    .res 1
seg_n:    .res 1            ; filas hasta elegir objetivo
isla_n:   .res 1            ; >0: filas de isla; <0: filas de descanso
corn_n:   .res 1            ; filas de cornisa
fri_n:    .res 1            ; filas de corriente fría que quedan
fri_c:    .res 1            ; su columna
corn_l:   .res 1            ; lado: 0 izquierda, $80 derecha
e_izq:    .res 1            ; paredes de la fila, con cornisa
e_der:    .res 1
e_isi:    .res 1            ; isla de la fila (isi > isd = no hay)
e_isd:    .res 1
e_fri:    .res 1
ancho:    .res 1
zc_n:     .res 1            ; patrones de zona pendientes
zp_n:     .res 1            ; colores de zona pendientes
zptr:     .res 2
cx0:      .res 1
cx1:      .res 1
cfil:     .res 1
cult:     .res 1
tt:       .res 1
FIL_JEFE  = 200
EST_LAVA  = $01
EST_ISLA  = $02
EST_SALA  = $04
EST_CORN  = $08
.bss
w_izq: .res 32
w_der: .res 32
w_isi: .res 32
w_isd: .res 32
w_chk: .res 32              ; 0, o tramo+1 si la fila es checkpoint
tr:    .res 1               ; etapa del cambio de zona (0 = no hay)
zp_z:  .res 1               ; zona de los colores que se escriben
zp_k:  .res 1               ; oscurecido: cada canal >> k
zp_h:  .res 1
chk_z: .res 1               ; último checkpoint: zona, tramo y vuelta
chk_t: .res 1
chk_v: .res 1
d_sal: .res 2               ; distancia al reaparecer
w_tip: .res 32              ; zona de la fila
w_fri: .res 32              ; primera columna fría ($FF = no hay)
fb_t:  .res 24
fb_a:  .res 24
.code
.proc rng                   ; A = byte aleatorio. Conserva X e Y
    txa
    pha
    ldx #8
@l: lsr rnd+1
    ror rnd
    bcc @n
    lda rnd+1
    eor #$B4
    sta rnd+1
@n: dex
    bne @l
    pla
    tax
    lda rnd
    rts
.endproc

.proc ter_init              ; partida nueva
    lda frames
    eor #$5C
    sta rnd
    lda #$A7                ; nunca 0: el LFSR se quedaría parado
    sta rnd+1
    lda #0
    sta filas_n
    sta dist
    sta dist+1
.ifdef AMENAZA_INI
    lda #(AMENAZA_INI / 4) .mod 5
    sta chk_z
    lda #AMENAZA_INI .mod 4
    sta chk_t
    lda #AMENAZA_INI / 20
    sta chk_v
.else
    sta chk_z
    sta chk_t
    sta chk_v
.endif
.endproc
.proc ter_desde             ; monta el cañón en el último checkpoint
    jsr vid_vuelca
    lda dist
    sta d_sal
    lda dist+1
    sta d_sal+1
    lda chk_v
    sta vuelta
    lda #0
    sta sc_y
    sta sc_frac
    sta zfila
    sta jefe_est
    sta isla_n
    sta corn_n
    sta fri_n
    lda #11
    sta p_izq
    sta o_izq
    lda #28
    sta p_der
    sta o_der
    lda #20                 ; salida recta
    sta seg_n
    lda chk_z
    jsr ter_zona
    lda #0                  ; filas 31, 30 ... 0
    sta gen_fila
    ldx #32
@f: txa
    pha
    jsr genera
    jsr encola_atr
    jsr vid_vuelca
    jsr encola_til
    jsr vid_vuelca
    pla
    tax
    dex
    bne @f
    ; gen_fila = 0, justo lo que pide ter_frame con sc_y = 0
    stx fase
    lda chk_t               ; zfila = tramo*64
    lsr
    ror
    ror
    sta zfila
    lda d_sal
    sta dist
    lda d_sal+1
    sta dist+1
    rts
.endproc

; A = zona: carga ya sus tiles y colores.
.proc ter_zona
    sta zona
    jsr zona_carga
@z: jsr zona_frame
    jsr vid_vuelca
    lda zc_n
    ora zp_n
    bne @z
    rts
.endproc

; A = y de pantalla de la sonda. C = 1 si acaba de cruzar un checkpoint, con
; A = tramo (0 = empieza zona, es decir, jefe vencido).
.proc ter_chk
    jsr ter_fila
    lda w_chk,x
    beq @no
    pha
    lda #0
    sta w_chk,x
    lda w_tip,x
    sta chk_z
    lda vuelta
    sta chk_v
    pla
    sec
    sbc #1
    sta chk_t
    sec
    rts
@no:
    clc
    rts
.endproc

; Trabajo de cada frame (lógica). Encola como mucho 24 celdas de terreno.
.proc ter_frame
    lda fase
    beq @nueva
    jsr encola_til
    lda #0
    sta fase
    jmp zona_frame
@nueva:
    lda sc_y
    clc
    adc #24
    lsr
    lsr
    lsr
    sec
    sbc #3                  ; (visible - 3) fila que tiene que estar generada
    and #31
    cmp gen_fila
    beq @no
    jsr genera
    jsr encola_atr
    lda #1
    sta fase
@no:
    jmp zona_frame
.endproc

; --- cambio de zona ---------------------------------------------------------
.proc zona_carga
    lda #4
    sta zc_n
    lda #7
    sta zp_n
    lda zona
    sta zp_z
    lda #0
    sta zp_k
    sta tr
    rts
.endproc

; Cambio en vuelo: oscurece lo viejo, cambia los tiles a oscuras y aclara.
; Etapas: 1 y 2 viejos >>1 y >>2, 3 tiles, 4-6 nuevos >>2, >>1 y enteros.
.proc transicion
    lda tr
    beq @r
    lda zp_n
    ora zc_n
    bne @r
    inc tr
    ldx tr
    cpx #7
    bne @et
    lda #0
    sta tr
@r: rts
@et:
    cpx #3
    bne @col
    lda #4
    sta zc_n
    rts
@col:
    lda t_tr-2,x
    sta zp_k
    cpx #4
    bcc @n
    lda zona
    sta zp_z
@n: lda #7
    sta zp_n
    rts
.endproc

; Un patrón (16 escrituras) y un color por frame, si caben.
.proc zona_frame
    jsr transicion
    lda zp_n
    beq @pat
    dec zp_n
    lda zp_z                ; fila de 14 bytes: 7 colores
    asl
    sta tt
    asl
    asl
    asl
    sec
    sbc tt                  ; zona*14
    sta tt
    lda zp_n
    asl
    clc
    adc tt
    tax
    ldy zp_n
    lda pal_ent,y
    tay                     ; entrada
    lda zona_pal+1,x
    sta zp_h
    lda zona_pal,x
    ldx zp_k
    beq @entero
@osc:                       ; cada canal (4 bits) a la mitad
    lsr
    and #$77
    lsr zp_h
    dex
    bne @osc
@entero:
    tax
    lda zp_h
    jsr pq_put              ; Y entrada, X lo, A hi
@pat:
    lda zc_n
    bne @hay
@ret:
    rts
@hay:
    lda vq_n
    cmp #VQ_MAX-15
    bcs @ret
    dec zc_n
    lda #0
    sta zptr+1
    lda zona                ; zona*64 + k*16
    asl
    asl
    asl
    asl
    asl
    asl
    rol zptr+1
    sta zptr
    lda zc_n
    asl
    asl
    asl
    asl
    ora zptr
    clc
    adc #<zona_gfx
    sta zptr
    lda zptr+1
    adc #>zona_gfx
    sta zptr+1
    lda zc_n
    asl
    asl
    asl
    sta v_lo
    ldx #8
    ldy #0
@f: lda #$84                ; patrón 128+k = dirección $400 + k*8
    sta v_hi
    tya
    pha
    lda (zptr),y
    jsr vq_put              ; plano 0 antes que el 1 (la cola es FIFO)
    lda #$A4
    sta v_hi
    pla
    pha
    clc
    adc #8
    tay
    lda (zptr),y
    jsr vq_put
    inc v_lo
    pla
    tay
    iny
    dex
    bne @f
    rts
.endproc

; --- generación de una fila -------------------------------------------------
.macro PASO p, o             ; p se acerca 1 a o
    .local menos, fin
    lda p
    cmp o
    beq fin
    bcs menos
    inc p
    bne fin
menos:
    dec p
fin:
.endmacro

.proc genera
    ldx gen_fila
    dex
    txa
    and #31
    sta gen_fila
    sed
    lda dist
    clc
    adc #1
    sta dist
    lda dist+1
    adc #0
    sta dist+1
    cld
    inc filas_n
    lda zfila
    cmp #255                ; final de zona: espera a vencer al jefe
    bne g_avanza
    lda jefe_est
    cmp #2
    beq g_vencido
    lda #1
    sta jefe_est
    jmp g_misma
g_vencido:
    lda #0
    sta jefe_est
g_avanza:
    inc zfila
    bne g_misma
    ldx zona
    inx
    cpx #5
    bne g_z
    ldx vuelta
    cpx #2
    bcs g_v
    inc vuelta
g_v:
    ldx #0
g_z:     lda zona
    sta zp_z
    stx zona
    lda #1                  ; empieza el fundido
    sta tr
    sta zp_k
    lda #7
    sta zp_n
    lda #0
    sta seg_n
g_misma:
    lda zona
    asl
    asl
    tax                     ; X = fila de zona_par (4 bytes)
    lda seg_n
    bne g_sigue
    jsr objetivo
g_sigue:
    dec seg_n
    PASO p_izq, o_izq
    PASO p_der, o_der
    lda zona_par+2,x
    and #EST_SALA           ; ruinas: paredes abruptas
    beq g_paredes
    PASO p_izq, o_izq
    PASO p_der, o_der
g_paredes:
    lda p_izq
    sta e_izq
    lda p_der
    sta e_der
    sec
    sbc p_izq
    sta ancho               ; columnas abiertas + 1
    lda zfila               ; el tramo del jefe es ancho y liso
    cmp #FIL_JEFE
    bcs g_sin_corn
    lda zona_par+2,x
    and #EST_CORN
    beq g_sin_corn
    lda corn_n
    bne g_corn
    jsr rng
    cmp #24
    bcs g_sin_corn
    jsr rng
    and #$80
    sta corn_l
    lda #3
    sta corn_n
g_corn:
    dec corn_n
    lda ancho
    cmp #14
    bcc g_sin_corn
    lda corn_l
    bmi g_cd
    inc e_izq
    inc e_izq
    bne g_sin_corn
g_cd:
    dec e_der
    dec e_der
g_sin_corn:
    lda #$FF                ; sin isla: isi = 255, isd = 0
    sta e_isi
    lda #0
    sta e_isd
    lda zfila
    cmp #FIL_JEFE
    bcs g_guarda
    lda zona_par+2,x
    and #EST_ISLA
    beq g_guarda
    lda isla_n
    bmi g_descanso
    beq g_empieza
    dec isla_n
    bne g_pon
    lda #$F8                ; 8 filas libres
    sta isla_n
    bne g_guarda
g_descanso:
    inc isla_n
    jmp g_guarda
g_empieza:
    jsr rng
    and #3
    clc
    adc #4                  ; 4-7 filas
    sta isla_n
g_pon:
    lda ancho
    cmp #17
    bcc g_guarda
    lsr
    clc
    adc p_izq
    sta e_isi
    dec e_isi
    adc #1                  ; (C = 0 aquí) centro ± 1
    sta e_isd
g_guarda:
    ldx gen_fila
    lda e_izq
    sta w_izq,x
    lda e_der
    sta w_der,x
    lda e_isi
    sta w_isi,x
    lda e_isd
    sta w_isd,x
    lda zona
    sta w_tip,x
    lda #0
    sta w_chk,x
    lda zfila               ; ¿checkpoint? cada 64 filas
    and #63
    bne g_sin_chk
    lda zfila
    rol
    rol
    rol
    and #3
    clc
    adc #1
    sta w_chk,x
g_sin_chk:
    ; corriente fría: 8 filas de 4 columnas, 1 de cada ~40 filas
    lda fri_n
    bne g_fri
    jsr rng
    cmp #6
    bcs g_no_fri
    jsr rng
    and #7
    clc
    adc p_izq
    adc #2
    sta fri_c
    lda #8
    sta fri_n
g_fri:
    dec fri_n
    lda fri_c
    bne g_pon_fri
g_no_fri:
    lda #$FF
g_pon_fri:
    sta w_fri,x
    sta e_fri
    ; --- fila a dibujar ---
    ldx #23
g_c: txa
    clc
    adc #CAN_IZQ
    cmp e_izq
    beq g_bi
    bcc g_roca
    cmp e_der
    beq g_bd
    bcs g_roca
    cmp e_isi
    bcc g_vacio
    cmp e_isd
    beq g_isla
    bcs g_vacio
g_isla:
    lda #T_ISLA
    ldy #PAL_LAVA
    bne g_pon_c
g_vacio:
    txa                     ; ¿dentro de la corriente?
    clc
    adc #CAN_IZQ
    sec
    sbc e_fri
    bcc g_nada
    cmp #4
    bcs g_nada
    lda #T_FRIO
    ldy #PAL_FRIO
    bne g_pon_c
g_nada:
    lda #' '
    ldy #PAL_ROCA
    beq g_pon_c
g_roca:
    lda #T_ROCA
    ldy #PAL_ROCA
    beq g_pon_c
g_bi:
    lda #T_BORDE_I
    bne g_borde
g_bd:
    lda #T_BORDE_D
g_borde:
    ldy zona
    cpy #1                  ; en la zona de lava los bordes queman
    beq g_pon_l
    ldy #PAL_ROCA
    beq g_pon_c
g_pon_l:
    ldy #PAL_LAVA
g_pon_c:
    sta fb_t,x
    tya
    sta fb_a,x
    dex
    bpl g_c
    ldx gen_fila
    lda w_chk,x
    beq g_mota
    ldx #23                 ; línea de meta y balizas en las paredes
g_l:
    lda fb_t,x
    cmp #T_BORDE_I
    beq g_bal
    cmp #T_BORDE_D
    beq g_bal
    cmp #' '
    bne g_nl
    lda #T_META
    bne g_pl
g_bal:
    lda #T_BALIZA
g_pl:
    sta fb_t,x
    lda #PAL_TEXTO
    sta fb_a,x
g_nl:
    dex
    bpl g_l
    rts
g_mota:
    jsr rng                 ; una mota por fila: se nota el movimiento
    and #15
    tax
    lda fb_t+4,x
    cmp #' '
    bne g_fin
    lda #T_MOTA
    sta fb_t+4,x
g_fin:
    rts
.endproc

; Elige nuevas paredes. X = fila de zona_par (se conserva).
.proc objetivo
    lda zfila
    cmp #FIL_JEFE
    bcc @normal
    lda #CAN_IZQ
    sta o_izq
    lda #CAN_DER
    sta o_der
    lda #4
    sta seg_n
    rts
@normal:
    lda amenaza             ; el mínimo baja 1 cada 4 de amenaza, hasta 10
    lsr
    lsr
    sta tt
    lda zona_par,x
    sec
    sbc tt
    cmp #10
    bcs @min
    lda #10
@min:
    sta tt
    jsr rng
    and #7
    clc
    adc tt                  ; + 0..7
    cmp zona_par+1,x
    bcc @w
    lda zona_par+1,x
@w: sta ancho
    lda #23
    sec
    sbc ancho
    sta tt                  ; posiciones posibles
    lda zona_par+2,x
    and #EST_SALA
    beq @azar
    lda tt                  ; ruinas: centrado
    lsr
    jmp @fija
@azar:
    jsr rng
    and #15
@m: cmp tt
    bcc @fija
    sbc tt
    bcs @m
@fija:
    clc
    adc #CAN_IZQ
    sta o_izq
    sec                     ; + ancho + 1
    adc ancho
    sta o_der
    lda zona_par+3,x
    sta seg_n
    jsr rng
    and #7
    clc
    adc seg_n
    sta seg_n
    rts
.endproc

.proc dir_fila              ; v_lo/v_hi = gen_fila*64 + CAN_IZQ
    lda gen_fila
    lsr
    lsr
    sta v_hi
    lda gen_fila
    and #3
    lsr
    ror
    ror
    ora #CAN_IZQ
    sta v_lo
    rts
.endproc

.proc encola_til
    jsr dir_fila
    ldx #0
@l: lda fb_t,x
    jsr vq_put
    inc v_lo
    inx
    cpx #24
    bne @l
    rts
.endproc

.proc encola_atr
    jsr dir_fila
    lda v_hi
    ora #AREA_ATTR
    sta v_hi
    ldx #0
@l: lda fb_a,x
    jsr vq_put
    inc v_lo
    inx
    cpx #24
    bne @l
    rts
.endproc

; A = y de pantalla -> X = fila del mapa. Conserva Y.
.proc ter_fila
    clc
    adc sc_y
    lsr
    lsr
    lsr
    tax
    rts
.endproc

; Punto X, Y (píxeles de pantalla): C = 1 si es roca.
.proc ter_punto
    txa
    lsr
    lsr
    lsr
    sta cx0
    tya
    jsr ter_fila
    lda w_izq,x
    cmp cx0
    bcs @si
    lda cx0
    cmp w_der,x
    bcs @si
    cmp w_isi,x
    bcc @si                 ; C = 0: libre
    lda w_isd,x
    cmp cx0
@si:
    rts
.endproc

; --- colisión ----------------------------------------------------------------
; Caja 10x11 en píxeles de pantalla: X = izquierda, Y = arriba.
; C = 1 si toca roca.
.proc ter_choca
    txa
    lsr
    lsr
    lsr
    sta cx0
    txa
    clc
    adc #9
    lsr
    lsr
    lsr
    sta cx1
    tya
    clc
    adc sc_y
    lsr
    lsr
    lsr
    sta cfil
    tya
    clc
    adc #10
    clc
    adc sc_y
    lsr
    lsr
    lsr
    sta cult
@l: ldx cfil
    lda w_izq,x
    cmp cx0
    bcs @si                 ; pared >= columna izquierda
    lda cx1
    cmp w_der,x
    bcs @si
    cmp w_isi,x             ; cx1 >= isi y cx0 <= isd
    bcc @otra
    lda w_isd,x
    cmp cx0
    bcs @si
@otra:
    lda cfil
    cmp cult
    beq @no
    clc
    adc #1
    and #31
    sta cfil
    jmp @l
@no:
    clc
@si:
    rts
.endproc

.rodata
t_tr:    .byte 2, 0, 2, 1, 0      ; oscurecido de las etapas 2-6
pal_ent: .byte 1,2,3,5,6,7,15
