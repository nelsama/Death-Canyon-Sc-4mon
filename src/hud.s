; HUD: filas 1 y 2 de la banda fija. Pocas celdas por frame.
.include "hardware.s"
.include "gfx.inc"
.import vq_put, vid_celda, pq_put
.importzp v_lo, v_hi, dist, zona, vidas, calor, apagon, est, combo
.import puntos
.export hud_init, hud_frame, msg, cuenta
F1 = 64 + HUD_COL + 1
F2 = 128 + HUD_COL + 1
.zeropage
h_i:   .res 1               ; dato que toca
h_b:   .res 1               ; celda de la barra
h_t:   .res 1
h_fin: .res 1               ; letras del mensaje final escritas
.bss
msg:     .res 1             ; mensaje pedido (MSG_*)
msg_act: .res 1             ; el que se está escribiendo
cuenta:  .res 1             ; segundos para continuar
.code
.proc hud_init              ; textos fijos (arranque)
    lda #0
    sta h_i
    sta h_b
    sta msg
    sta msg_act
    sta v_hi
    lda #22
    sta h_fin
    lda #0
    tax
@a: txa
    clc
    adc #F1
    sta v_lo
    lda txt_1,x
    jsr vid_celda
    txa
    clc
    adc #F2
    sta v_lo
    lda txt_2,x
    jsr vid_celda
    inx
    cpx #22
    bne @a
    rts
.endproc

.proc hud_frame
    lda #0
    sta v_hi
    inc h_i
    lda h_i
    cmp #12
    bcc @d
    lda #0
    sta h_i
@d: tax
    lda t_pos,x
    sta v_lo
    lda dist+1
    cpx #2
    bcc @nib
    lda dist
    cpx #4
    bcc @nib
    lda puntos+2
    cpx #6
    bcc @nib
    lda puntos+1
    cpx #8
    bcc @nib
    lda puntos
    cpx #10
    bcc @nib
    lda vidas
    cpx #11
    beq @num
    ldx zona
    inx
    txa
@num:
    and #$0F
    jmp @pon
@nib:
    pha
    txa
    lsr
    pla
    bcs @bajo
    lsr
    lsr
    lsr
    lsr
@bajo:
    and #$0F
@pon:
    ora #'0'
    jsr vq_put
    lda msg
    cmp msg_act
    beq @mismo
    sta msg_act
    lda #0
    sta h_fin
@mismo:
    lda h_fin
    cmp #22
    bcs @escrito
    jmp mensaje
@escrito:
    lda msg_act
    beq @normal
    cmp #MSG_CONT           ; cuenta atrás
    bne @ret
    lda #F2+19
    sta v_lo
    lda cuenta
    bpl @cu
    lda #0
@cu:
    ora #'0'
    jmp vq_put
@ret:
    rts
@normal:
    jsr barra
    jsr barra
    ; estado a la derecha de la barra, una letra por frame
    ldx #0
    lda combo               ; sin avisos: multiplicador del combo
@mul:
    inx
    cmp #5
    bcc @fm
    sbc #5
    bcs @mul
@fm:
    stx h_t
    ldx #0
    lda apagon
    beq @sin
    ldx #8
    bne @est
@sin:
    lda calor
    cmp #CAL_ALTO
    bcc @est
    ldx #4
@est:
    lda h_i
    and #3
    tay
    clc
    adc #F2+18
    sta v_lo
    cpx #0
    bne @letra
    cpy #1
    bne @letra
    lda h_t
    ora #'0'
    jmp vq_put
@letra:
    sty h_t
    txa
    clc
    adc h_t
    tay
    lda t_est,y
    jmp vq_put
.endproc

.proc barra                 ; una de las 12 celdas
    inc h_b
    lda h_b
    cmp #12
    bcc @ok
    lda #0
    sta h_b
@ok:
    asl
    asl
    asl
    sta h_t
    lda calor
    sec
    sbc h_t
    bcs @pos
    lda #0
@pos:
    cmp #8
    bcc @n
    lda #8
@n: clc
    adc #T_BARRA
    pha
    lda h_b
    clc
    adc #F2+6
    sta v_lo
    pla
    jmp vq_put
.endproc

.proc mensaje               ; fila 2 entera: dos letras por frame
    jsr @una
@una:
    ldx h_fin
    cpx #22
    bcs @r
    txa
    clc
    adc #F2
    sta v_lo
    lda msg_act             ; msg*22 + letra
    asl
    sta h_t
    asl
    asl
    clc
    adc msg_act
    clc
    adc h_t                 ; *11
    asl
    clc
    adc h_fin
    tax
    lda txt_msg,x
    inc h_fin
    jmp vq_put
@r: rts
.endproc

.rodata
txt_1:   .byte "V3  Z1  D0000  P000000"
txt_2:
txt_msg:                    ; 22 letras cada uno, en el orden de MSG_*
    .byte "CALOR                 "
    .byte "FIN - FUEGO: MENU     "
    .byte "NUEVO RECORD! - FUEGO "
    .byte "     CHECKPOINT       "
    .byte "       PAUSA          "
    .byte "CONTINUAR? FUEGO      "
t_est:   .byte "X   ALTOOFF!"
t_pos:   .byte F1+9,F1+10,F1+11,F1+12, F1+16,F1+17,F1+18,F1+19,F1+20,F1+21, F1+5, F1+1
