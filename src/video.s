; Única puerta a la VRAM. La lógica encola (spr_*, vq_put) y vid_flush vuelca
; las colas dentro del VBLANK: ahí sólo se copia, no se decide nada.
.include "hardware.s"
.include "gfx.inc"
.import gfx_tabla, pal_tabla
.export vid_init, vid_frame, vid_flush, spr_prepara, vq_put, vid_celda, vid_banda, vid_vuelca, pq_put
.export spr_x, spr_y, spr_t, spr_f
.exportzp sc_y, sc_frac, tarde, v_lo, v_hi, vq_n
.zeropage
ptr:     .res 2
sc_y:    .res 1
sc_frac: .res 1
tarde:   .res 1             ; frames con el vídeo fuera del VBLANK
v_lo:    .res 1
v_hi:    .res 1
v_a:     .res 1
oq_n:    .res 1             ; bytes de OAM pendientes (máx. 128)
vq_n:    .res 1             ; celdas pendientes (máx. VQ_MAX)
pq_n:    .res 1             ; colores pendientes
t0:      .res 1
.bss
spr_x: .res NSPR            ; lo que la lógica quiere ver
spr_y: .res NSPR
spr_t: .res NSPR
spr_f: .res NSPR
c_x:   .res NSPR            ; lo que hay en el OAM
c_y:   .res NSPR
c_t:   .res NSPR
c_f:   .res NSPR
oq_a:  .res 128
oq_d:  .res 128
vq_lo: .res VQ_MAX
vq_hi: .res VQ_MAX
vq_d:  .res VQ_MAX
pq_e:  .res PQ_MAX
pq_l:  .res PQ_MAX
pq_h:  .res PQ_MAX
.code
; Escribe A en la celda v_lo/v_hi ahora mismo (arranque, no en el frame).
.proc vid_celda
    sta v_a
    lda v_lo
    sta VID_ADDR_LO
    lda v_hi
    sta VID_ADDR_HI
    lda v_a
    sta VID_DATA
    rts
.endproc

; Encola A para la celda v_lo/v_hi. Destruye Y. Con la cola llena, descarta.
.proc vq_put
    ldy vq_n
    cpy #VQ_MAX
    bcs @fin
    sta vq_d,y
    lda v_lo
    sta vq_lo,y
    lda v_hi
    sta vq_hi,y
    inc vq_n
@fin:
    rts
.endproc

; Encola un color: Y = entrada, X = byte bajo, A = byte alto.
.proc pq_put
    sta v_a
    tya
    ldy pq_n
    cpy #PQ_MAX
    bcs @fin
    sta pq_e,y
    txa
    sta pq_l,y
    lda v_a
    sta pq_h,y
    inc pq_n
@fin:
    rts
.endproc

.proc vid_init
@r: lda VID_STATUS
    and #ST_READY
    beq @r
    lda #3
    sta VID_FONT
    sta VID_SETUP
@b: lda VID_SETUP_ST
    and #$01
    bne @b
@s: lda VID_STATUS
    and #ST_READY
    beq @s
    ldx #0
@pal:
    lda pal_tabla,x
    cmp #$FF
    beq @gfx
    sta VID_PAL_PTR
    lda pal_tabla+1,x
    sta VID_PAL_LO
    lda pal_tabla+2,x
    sta VID_PAL_HI
    inx
    inx
    inx
    bne @pal
@gfx:
    lda #<gfx_tabla
    sta ptr
    lda #>gfx_tabla
    sta ptr+1
@pat:
    ldy #0
    lda (ptr),y             ; 0 fondo, 1 sprite, $FF fin
    bmi @oam
    beq @fondo
    lda #$48
@fondo:
    ora #$80                ; $80 fondo, $C8 sprite
    sta t0
    iny
    lda (ptr),y
    pha
    asl
    asl
    asl
    sta v_lo                ; indice*8
    pla
    lsr
    lsr
    lsr
    lsr
    lsr
    ora t0
    sta v_hi
    ldx #8
@fila:
    iny                     ; plano 0: bytes 2..9
    lda (ptr),y
    jsr vid_celda
    lda v_hi
    ora #$20
    sta v_hi
    tya
    clc
    adc #8                  ; plano 1: bytes 10..17
    tay
    lda (ptr),y
    jsr vid_celda
    tya
    sec
    sbc #8
    tay
    lda v_hi
    and #$DF
    sta v_hi
    inc v_lo
    dex
    bne @fila
    lda ptr
    clc
    adc #18
    sta ptr
    bcc @pat
    inc ptr+1
    bne @pat
@oam:
    ldx #NSPR-1             ; sprites apagados: deseado y caché iguales
@c: lda #0
    sta spr_x,x
    sta spr_t,x
    sta spr_f,x
    sta c_x,x
    sta c_t,x
    sta c_f,x
    lda #SPR_OFF
    sta spr_y,x
    sta c_y,x
    dex
    bpl @c
    lda #AREA_OAM
    sta VID_ADDR_HI
    ldy #0
@o: ldx #0
@campo:
    sty VID_ADDR_LO
    lda #0
    cpx #1
    bne @w
    lda #SPR_OFF
@w: sta VID_DATA
    iny
    inx
    cpx #5
    bne @campo
    cpy #NSPR*5
    bne @o
    lda #0
    sta oq_n
    sta vq_n
    sta pq_n
    sta tarde
    sta sc_y
    sta sc_frac
    sta VID_SX_LO
    sta VID_SX_HI
    sta VID_SY_LO
    sta VID_SY_HI
    sta VID_B2X_LO
    sta VID_B2Y_LO
    sta VID_B2Y_HI
    lda #1                  ; banda superior desplazada 256 px
    sta VID_B2X_HI
    lda #24
    sta VID_LINE0
    lda #$FF
    sta VID_LINE1
    rts
.endproc

; Compara lo deseado con el OAM y encola las diferencias. Fuera del VBLANK.
.macro CAMPO quiero, cache, despl
    .local igual
    lda quiero,x
    cmp cache,x
    beq igual
    sta cache,x
    sta oq_d,y
    lda t0
    .if despl > 0
    clc
    adc #despl
    .endif
    sta oq_a,y
    iny
igual:
.endmacro
.proc spr_prepara
    ldx #0
    stx t0
    ldy #0
bucle:
    CAMPO spr_x, c_x, 0
    CAMPO spr_y, c_y, 1
    CAMPO spr_t, c_t, 2
    CAMPO spr_f, c_f, 3
    lda t0
    clc
    adc #5
    sta t0
    inx
    cpx #NSPR
    bne bucle
    sty oq_n
    rts
.endproc

; A = fin de la banda del HUD ($FF = sin banda).
.proc vid_banda
    sta VID_LINE0
    rts
.endproc

; Espera el comienzo de un VBLANK (si ya se está dentro, el siguiente).
.proc vid_frame
@f: bit VID_STATUS
    bmi @f
@i: bit VID_STATUS
    bpl @i
    rts
.endproc

.proc vid_flush
    lda #0                  ; scroll primero: es lo que más se nota tarde
    sta VID_SY_HI
    lda sc_y
    sta VID_SY_LO
    ldx oq_n
    beq @celdas
    lda #AREA_OAM
    sta VID_ADDR_HI
@o: lda oq_a-1,x
    sta VID_ADDR_LO
    lda oq_d-1,x
    sta VID_DATA
    dex
    bne @o
    stx oq_n
@celdas:
    jsr vid_vuelca
    bit VID_STATUS
    bmi @ok
    inc tarde
@ok:
    rts
.endproc

; Vuelca colores y celdas en orden (el plano 0 va antes que el 1).
.proc vid_vuelca
    ldx pq_n
    beq @celdas
@p: lda pq_e-1,x
    sta VID_PAL_PTR
    lda pq_l-1,x
    sta VID_PAL_LO
    lda pq_h-1,x
    sta VID_PAL_HI
    dex
    bne @p
    stx pq_n
@celdas:
    ldx #0
@c: cpx vq_n
    beq @fin
    lda vq_lo,x
    sta VID_ADDR_LO
    lda vq_hi,x
    sta VID_ADDR_HI
    lda vq_d,x
    sta VID_DATA
    inx
    bne @c
@fin:
    lda #0
    sta vq_n
    rts
.endproc
