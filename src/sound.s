; Sonido. Voz 1: efectos de la sonda. Voz 2: acompañamiento, que cede la voz
; a los efectos de enemigos mientras suenan. Voz 3: melodía.
; El SID no tiene volumen por voz: la música se baja cortando el gate en pleno
; ataque, antes de que la envolvente llegue al máximo. MUS_AD fija cuánto tarda
; en subir y MUS_GATE cuántos frames sube: más ataque o menos gate = más bajo.
.include "hardware.s"
.export snd_init, snd_play, snd_frame, snd_pista, snd_vol
SFX_TAM = 10
MUS_AD   = $80              ; ataque 100 ms
MUS_SR   = $F8              ; suelta en 300 ms
MUS_GATE = 3
.bss
snd_vol: .res 1             ; volumen general (0 en pausa)
v_dur:  .res 2              ; frames que le quedan al efecto de cada voz
v_pri:  .res 2
v_fl:   .res 2
v_fh:   .res 2
v_dl:   .res 2              ; cambio de frecuencia por frame
v_dh:   .res 2
v_ctl:  .res 2
pista:  .res 1
m_paso: .res 1
m_tic:  .res 1
s_x:    .res 1
s_y:    .res 1
s_v:    .res 1
.code
.proc snd_init
    lda #0
    ldx #$18
@l: sta SID,x
    dex
    bpl @l
    sta v_dur
    sta v_dur+1
    sta m_paso
    sta m_tic
    lda #$FF
    sta pista
    lda #$0F
    sta snd_vol
    sta SID+$18
    lda #$08                ; pulso al 50 %
    sta SID+3
    sta SID+7+3
    lda #$04                ; melodía al 25 %, más fina
    sta SID+14+3
    lda #MUS_AD
    sta SID+14+5
    lda #MUS_SR
    sta SID+14+6
    rts
.endproc

; A = efecto. Conserva X e Y. Uno más importante no se corta por otro menor.
.proc snd_play
    stx s_x
    sty s_y
    tax
    ldy sfx_off,x
    ldx sfx,y               ; voz
    lda v_dur,x
    beq @si
    lda sfx+1,y
    cmp v_pri,x
    bcc @no
@si:
    lda sfx+1,y
    sta v_pri,x
    lda sfx+2,y
    sta v_ctl,x
    lda sfx+5,y
    sta v_fl,x
    lda sfx+6,y
    sta v_fh,x
    lda sfx+7,y
    sta v_dl,x
    lda sfx+8,y
    sta v_dh,x
    lda sfx+9,y
    sta v_dur,x
    stx s_v
    lda voz_off,x
    tax
    lda #0                  ; cierra el gate y lo vuelve a abrir
    sta SID+4,x
    lda sfx+3,y
    sta SID+5,x
    lda sfx+4,y
    sta SID+6,x
    lda sfx+5,y
    sta SID,x
    lda sfx+6,y
    sta SID+1,x
    ldy s_v
    lda v_ctl,y
    sta SID+4,x
@no:
    ldx s_x
    ldy s_y
    rts
.endproc

; A = pista. Si ya suena, no hace nada.
.proc snd_pista
    cmp pista
    beq @r
    sta pista
    lda #0
    sta m_paso
    lda #1
    sta m_tic
@r: rts
.endproc

.proc snd_frame
    lda snd_vol
    sta SID+$18
    bne @suena
    rts
@suena:
    ldx #1
@v: lda v_dur,x
    beq @sig
    ldy voz_off,x
    dec v_dur,x
    bne @sigue
    lda v_ctl,x             ; fin: suelta la nota
    and #$FE
    sta SID+4,y
    jmp @sig
@sigue:
    lda v_fl,x
    clc
    adc v_dl,x
    sta v_fl,x
    sta SID,y
    lda v_fh,x
    adc v_dh,x
    sta v_fh,x
    sta SID+1,y
@sig:
    dex
    bpl @v
    ldx pista               ; --- música
    bmi @fin
    dec m_tic
    beq @paso
    lda p_tempo,x           ; corta las notas a los MUS_GATE frames
    sec
    sbc #MUS_GATE
    cmp m_tic
    bne @fin
    lda #$40
    sta SID+14+4
    lda v_dur+1             ; la voz 2 puede ser de un efecto
    bne @fin
    lda #$10
    sta SID+7+4
@fin:
    rts
@paso:
    lda p_tempo,x
    sta m_tic
    lda p_mel,x             ; melodía
    asl
    asl
    asl
    asl
    asl
    clc
    adc m_paso
    tay
    lda melodias,y
    bmi @acomp
    clc
    adc p_raiz,x
    clc
    adc p_alto,x
    tay
    lda nota_l,y
    sta SID+14
    lda nota_h,y
    sta SID+14+1
    lda #$40
    sta SID+14+4
    lda #$41
    sta SID+14+4
@acomp:                     ; acompañamiento: un acorde cada 8 pasos
    lda v_dur+1
    bne @avanza
    lda m_paso
    and #7
    tay
    lda a_int,y
    bmi @avanza
    sta s_v                 ; intervalo
    lda p_mel,x             ; acorde = melodía*4 + compás
    asl
    asl
    sta s_x
    lda m_paso
    lsr
    lsr
    lsr
    clc
    adc s_x
    sta s_x
    lda s_v
    cmp #A_TERCERA
    bne @int
    ldy s_x
    lda a_terc,y            ; tercera mayor o menor, en la octava alta
@int:
    ldy s_x
    clc
    adc a_raiz,y
    clc
    adc p_raiz,x
    clc
    adc #12
    tay
    lda #MUS_AD
    sta SID+7+5
    lda #MUS_SR
    sta SID+7+6
    lda nota_l,y
    sta SID+7
    lda nota_h,y
    sta SID+7+1
    lda #$10
    sta SID+7+4
    lda #$11                ; triángulo: más suave que la melodía
    sta SID+7+4
@avanza:
    inc m_paso
    lda m_paso
    and #31
    sta m_paso
    rts
.endproc

.rodata
voz_off: .byte 0, 7
sfx_off:
.repeat 16, I
    .byte I*SFX_TAM
.endrepeat
.macro FX voz, pri, ctl, ad, sr, frec, delta, dur
    .byte voz, pri, ctl, ad, sr
    .word frec, (delta) & $FFFF
    .byte dur
.endmacro
sfx:                        ; en el orden de FX_* (hardware.s)
    FX 0, 1, $41, $08, $00, $2800, -$0280,  8   ; disparo
    FX 1, 3, $81, $09, $00, $1400, -$00C0, 18   ; explosión
    FX 1, 6, $81, $0B, $A0, $1800, -$0050, 50   ; muerte de la sonda
    FX 0, 4, $21, $09, $90, $1C00, -$0048, 60   ; apagón
    FX 0, 5, $11, $09, $A0, $1800,  $0180, 18   ; mejora
    FX 0, 6, $41, $0A, $A0, $1000,  $0120, 34   ; checkpoint
    FX 1, 2, $41, $06, $00, $0900, -$0060,  5   ; impacto en el jefe
    FX 1, 1, $21, $07, $00, $1600, -$0140,  9   ; disparo enemigo
    FX 0, 2, $11, $06, $00, $2200,  $0000,  5   ; mover en el menú
    FX 0, 6, $41, $0A, $80, $0C00,  $0200, 20   ; empezar
    FX 0, 5, $81, $08, $60, $3800, -$0180, 20   ; escudo roto
    FX 1, 0, $81, $04, $00, $5000,  $0000,  3   ; chispa en la roca
    FX 0, 2, $41, $06, $50, $2C00,  $0000,  7   ; alarma de calor
    FX 1, 7, $81, $0C, $C0, $2000, -$0048, 90   ; jefe vencido
    FX 0, 5, $21, $0A, $A0, $1400, -$0060, 45   ; fin de partida
    FX 1, 4, $81, $C9, $80, $0600,  $0010,110   ; viento
; Pistas: 0-4 zonas, 5 jefe, 6 título. Frames por paso, raíz y melodía.
p_tempo: .byte 11, 10, 11, 12, 10,  7, 12
p_raiz:  .byte  0,  2,  5,  7,  3,  1,  0
p_mel:   .byte  0,  1,  2,  2,  0,  3,  4
p_alto:  .byte 24, 24, 12, 12, 24, 24, 12
; Acompañamiento: intervalo de cada paso, y 4 acordes por melodía
A_TERCERA = 100
a_int:   .byte 0,$80,7,$80, 12,7,A_TERCERA,$80
a_raiz:  .byte 0,5,0,7,  0,0,0,1,  0,8,5,7,  0,0,0,1,  0,3,8,7
a_terc:  .byte 15,15,15,15, 15,15,15,16, 15,16,15,16, 15,15,15,16, 15,16,16,16
melodias:
    ; grave y espaciada
    .byte 0,$80,0,7, 3,$80,0,$80, 5,$80,5,12, 8,$80,5,$80
    .byte 0,$80,0,7, 3,$80,10,$80, 8,$80,7,$80, 5,3,2,$80
    ; inquieta
    .byte 0,0,12,0, 1,1,13,1, 0,0,12,0, 6,$80,5,$80
    .byte 0,0,12,0, 3,3,15,3, 1,1,13,1, 0,$80,$80,$80
    ; arpegio abierto
    .byte 0,7,12,14, 15,14,12,7, 8,12,15,17, 19,17,15,12
    .byte 5,12,17,19, 20,19,17,12, 7,11,14,17, 19,17,14,11
    ; jefe
    .byte 0,0,1,0, 0,0,6,5, 0,0,1,0, 3,1,0,$80
    .byte 0,0,1,0, 0,0,8,7, 6,6,5,5, 3,3,1,1
    ; título
    .byte 12,$80,15,$80, 19,$80,17,15, 14,$80,10,$80, 7,$80,$80,$80
    .byte 8,$80,12,$80, 15,$80,14,12, 11,$80,14,$80, 19,$80,$80,$80
; Desde La de 55 Hz, por semitonos, con el SID a 964.286 Hz
nota_l: .byte <957,<1014,<1074,<1138,<1206,<1277,<1353,<1434,<1519,<1609,<1705,<1806,<1914,<2028,<2148,<2276,<2411,<2555,<2707,<2868,<3038,<3219,<3410,<3613,<3828,<4055,<4296,<4552,<4823,<5109,<5413,<5735,<6076,<6437,<6820,<7226,<7655,<8111,<8593,<9104,<9645,<10219,<10826,<11470,<12152,<12875,<13640,<14451
nota_h: .byte >957,>1014,>1074,>1138,>1206,>1277,>1353,>1434,>1519,>1609,>1705,>1806,>1914,>2028,>2148,>2276,>2411,>2555,>2707,>2868,>3038,>3219,>3410,>3613,>3828,>4055,>4296,>4552,>4823,>5109,>5413,>5735,>6076,>6437,>6820,>7226,>7655,>8111,>8593,>9104,>9645,>10219,>10826,>11470,>12152,>12875,>13640,>14451
