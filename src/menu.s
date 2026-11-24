; Pantalla de título, elección de dificultad y récords.
; La tabla (3 por dificultad) se guarda en DCREC.DAT: se crea una sola vez y
; después se reescribe en su sitio, porque MicroFS no recupera lo borrado.
.include "hardware.s"
.include "gfx.inc"
.import vid_init, vid_frame, vid_flush, spr_prepara, vid_celda, vq_put
.import vid_banda, pq_put
.import input_read, ter_zona, jug_init, jug_dibuja
.import puntos, snd_play, snd_frame, snd_pista, snd_init
.importzp joy_new, v_lo, v_hi, px, py, inv, frames
.export menu, dif_carga, rec_carga, rec_inserta
.export dif, d_vidas, d_cal, d_apag, d_vlo, d_vhi, d_cad, d_nen, d_cont, d_mul
.export rec_sd, rec
R_SDREADY = $BF78
R_MOUNT   = $BF03
R_OPEN    = $BF06
R_READ    = $BF09
R_CLOSE   = $BF0C
R_CREATE  = $BF3C
R_WRITE   = $BF3F
R_MAGIC   = $BF87
REC_TAM   = 32
.zeropage
mp:   .res 2
.bss
dif:    .res 1              ; 0 fácil, 1 normal, 2 difícil
d_vidas: .res 1             ; copia de la fila de dif_tab
d_cal:  .res 1
d_apag: .res 1
d_vlo:  .res 1
d_vhi:  .res 1
d_cad:  .res 1
d_nen:  .res 1
d_cont: .res 1
d_mul:  .res 1
msel:   .res 1              ; opción: 0-2 dificultad, 3 salir
mt:     .res 1
mu:     .res 1
mfil:   .res 1
mbits:  .res 1
mref:   .res 1              ; celdas de récords por redibujar
rec_sd: .res 1              ; 1 = la SD responde
rec:    .res REC_TAM        ; "DC", versión, 27 de datos, suma, 0
.code
; dif_carga: copia la fila de la dificultad elegida.
.proc dif_carga
    lda dif
    asl
    asl
    asl
    adc dif                 ; *9
    tax
    ldy #0
@l: lda dif_tab,x
    sta d_vidas,y
    inx
    iny
    cpy #9
    bne @l
    rts
.endproc

; v_lo/v_hi = celda (A = fila, X = columna)
.proc donde
    stx v_lo
    pha
    lsr
    lsr
    sta v_hi
    pla
    and #3
    lsr
    ror
    ror
    ora v_lo
    sta v_lo
    rts
.endproc

; Escribe la cadena mp (hasta 0) desde v_lo/v_hi.
.proc texto
    ldy #0
@l: lda (mp),y
    beq @f
    jsr vid_celda
    inc v_lo
    iny
    bne @l
@f: rts
.endproc

.macro TEXTO cad, f, c
    lda #<cad
    sta mp
    lda #>cad
    sta mp+1
    lda #f
    ldx #c
    jsr donde
    jsr texto
.endmacro

; Palabra grande: cada píxel de la letra es un tile. X = índice en palabras,
; mfil = fila, mu = columna inicial.
.proc logo
    lda palabras,x
    beq @fin                ; 0 = fin de palabra
    stx mt
    tay                     ; desplazamiento+1 en letras
    lda #5
    sta mref
@f: lda letras-1,y
    sta mbits
    tya
    pha
    lda mfil
    ldx mu
    jsr donde
    ldy #5
@b: asl mbits
    bcc @no
    lda #T_ISLA
    jsr vid_celda
    lda v_hi
    ora #AREA_ATTR
    sta v_hi
    lda #PAL_LAVA
    jsr vid_celda
    lda v_hi
    and #7
    sta v_hi
@no:
    inc v_lo
    dey
    bne @b
    inc mfil
    pla
    tay
    iny
    dec mref
    bne @f
    lda mfil
    sec
    sbc #5
    sta mfil
    lda mu
    clc
    adc #6
    sta mu
    ldx mt
    inx
    bne logo
@fin:
    rts
.endproc

.proc menu
    jsr vid_init
    lda #$FF
    jsr vid_banda           ; pantalla entera, sin HUD
    lda #0                  ; 2048 celdas: espacio y paleta de texto
    sta v_lo
    sta v_hi
@c: lda #' '
    jsr vid_celda
    lda v_hi
    ora #AREA_ATTR
    sta v_hi
    lda #PAL_TEXTO
    jsr vid_celda
    lda v_hi
    and #7
    sta v_hi
    inc v_lo
    bne @c
    inc v_hi
    lda v_hi
    cmp #8
    bne @c
    lda #1
    jsr ter_zona            ; colores y tiles de lava para el logo
    lda #3
    sta mfil
    lda #5
    sta mu
    ldx #0
    jsr logo
    lda #9
    sta mfil
    lda #2
    sta mu
    ldx #6
    jsr logo
    TEXTO t_fac, 15, 18
    TEXTO t_nor, 17, 18
    TEXTO t_dif, 19, 18
    TEXTO t_sal, 21, 18
    lda dif
    sta msel
    TEXTO t_rec, 23, 16
    TEXTO t_jug, 28, 7
    lda #PISTA_TIT
    jsr snd_pista
    jsr jug_init
    lda #0
    sta inv
    lda #120
    sta px
    lda #0
    sta mref
@bucle:
    lda msel
    asl
    asl
    asl
    asl
    clc
    adc #116
    sta py
    jsr jug_dibuja
    jsr spr_prepara
    jsr vid_frame
    jsr vid_flush
    inc frames
    bne @lee
    inc frames+1
@lee:
    jsr input_read
    lda joy_new
    and #J_UP
    beq @ab
    lda msel
    beq @ab
    dec msel
    jsr elige
@ab:
    lda joy_new
    and #J_DOWN
    beq @fu
    lda msel
    cmp #3
    beq @fu
    inc msel
    jsr elige
@fu:
    jsr pinta_rec
    jsr late
    jsr snd_frame
    lda joy_new
    and #J_FIRE
    bne @sale
    jmp @bucle
@sale:
    lda msel
    cmp #3
    beq salir
    lda #FX_INICIO
    jsr snd_play
    rts
.endproc

.proc elige                 ; sobre SALIR se conserva la última dificultad
    lda #FX_MENU
    jsr snd_play
    lda msel
    cmp #3
    bcs @r
    sta dif
    lda #0
    sta mref
@r: rts
.endproc

; Vuelve al monitor: sin sonido, pantalla limpia y reset con autoarranque (launcher).
.proc salir
    jsr snd_init            ; calla las tres voces
    lda #0
    sta SID+$18
    jsr vid_init            ; borra tilemap y apaga sprites
    lda #$FF
    jsr vid_banda
    lda #0                  ; 0 = el monitor ejecuta BOOT.INI (launcher)
    sta SYSFLAGS
    jmp (RESET_VEC)
.endproc

; El logo late: el color medio de la lava cambia cada 8 frames.
.proc late
    lda frames
    and #7
    bne @r
    lda frames
    lsr
    lsr
    and #6
    tay
    ldx t_late,y
    lda t_late+1,y
    ldy #6
    jmp pq_put
@r: rts
.endproc

; Récords de la dificultad elegida, una línea por frame (6 cifras).
.proc pinta_rec
    lda mref
    cmp #3
    bcs @r
    tay                     ; línea
    clc
    adc #24
    ldx #17
    jsr donde
    lda dif
    asl
    asl
    asl
    adc dif                 ; *9
    sta mt
    tya
    asl
    adc mref                ; + línea*3
    adc mt
    tax
    lda #3
    sta mu
@b: lda rec+3+2,x           ; byte alto primero
    pha
    lsr
    lsr
    lsr
    lsr
    ora #'0'
    jsr vq_put
    inc v_lo
    pla
    and #$0F
    ora #'0'
    jsr vq_put
    inc v_lo
    dex
    dec mu
    bne @b
    inc mref
@r: rts
.endproc

; --- récords -----------------------------------------------------------------
.proc suma_rec              ; A = suma de control
    ldx #29
    lda #$5A
@l: clc
    adc rec,x
    dex
    bpl @l
    rts
.endproc

.proc rec_cero
    ldx #REC_TAM-1
    lda #0
@l: sta rec,x
    dex
    bpl @l
    lda #'D'
    sta rec
    lda #'C'
    sta rec+1
    lda #1
    sta rec+2
    jsr suma_rec
    sta rec+30
    rts
.endproc

.macro PTR zpd, dir
    lda #<(dir)
    sta zpd
    lda #>(dir)
    sta zpd+1
.endmacro

; Al arrancar: monta la SD y lee el fichero. Sin SD o sin fichero, a cero.
.proc rec_carga
    lda #0
    sta rec_sd
    jsr rec_cero
    ldx #5                  ; ¿está la ROM API?
@m: lda R_MAGIC,x
    cmp t_magic,x
    bne @fin
    dex
    bpl @m
    jsr R_SDREADY
    cmp #0
    beq @fin
    jsr R_MOUNT
    cmp #0
    bne @fin
    inc rec_sd
    PTR $F4, t_fich
    jsr R_OPEN
    cmp #0
    bne @fin                ; aún no existe
    PTR $F0, rec
    PTR $F2, REC_TAM
    jsr R_READ
    jsr R_CLOSE
    lda rec                 ; ¿válido?
    cmp #'D'
    bne @malo
    lda rec+1
    cmp #'C'
    bne @malo
    lda rec+2
    cmp #1
    bne @malo
    jsr suma_rec
    cmp rec+30
    beq @fin
@malo:
    jmp rec_cero
@fin:
    rts
.endproc

.proc rec_guarda
    lda rec_sd
    beq @fin
    jsr suma_rec
    sta rec+30
    PTR $F4, t_fich
    jsr R_OPEN
    cmp #0
    beq @escribe
    PTR $F4, t_fich
    PTR $F6, REC_TAM
    jsr R_CREATE
    cmp #0
    bne @fin
@escribe:
    PTR $F4, rec
    PTR $F6, REC_TAM
    jsr R_WRITE
    jmp R_CLOSE
@fin:
    rts
.endproc

; Inserta `puntos` en la tabla de la dificultad. C = 1 si entra (y la guarda).
.proc rec_inserta
    lda dif
    asl
    asl
    asl
    adc dif
    sta mt                  ; primera entrada
    lda #0
    sta mu
@l: ldx mt                  ; ¿puntos > entrada?
    lda rec+3,x
    cmp puntos
    lda rec+4,x
    sbc puntos+1
    lda rec+5,x
    sbc puntos+2
    bcc @entra
    lda mt
    clc
    adc #3
    sta mt
    inc mu
    lda mu
    cmp #3
    bne @l
    clc
    rts
@entra:                     ; baja las siguientes: 2 - mu desplazamientos
    lda dif
    asl
    asl
    asl
    adc dif
    adc #8                  ; último byte de la tercera
    tax
@b: lda mu
    cmp #2
    beq @pon
    lda rec+3-3,x
    sta rec+3,x
    lda rec+3-4,x
    sta rec+3-1,x
    lda rec+3-5,x
    sta rec+3-2,x
    dex
    dex
    dex
    inc mu
    bne @b
@pon:
    ldx mt
    lda puntos
    sta rec+3,x
    lda puntos+1
    sta rec+4,x
    lda puntos+2
    sta rec+5,x
    jsr rec_guarda
    sec
    rts
.endproc

.rodata
; vidas, calor por disparo, apagón, scroll lo/hi, cadencia, enemigos,
; continuaciones (255 = sin límite), multiplicador de puntos
dif_tab:
    .byte 5, 3,  60, $A0,0, 120, 4, 255, 1
    .byte 3, 4,  90, $C0,0,  80, 6,   3, 2
    .byte 2, 6, 120, $00,1,  50, 8,   0, 3
t_fac:  .byte "FACIL",0
t_nor:  .byte "NORMAL",0
t_dif:  .byte "DIFICIL",0
t_sal:  .byte "SALIR",0
t_rec:  .byte "RECORDS",0
t_jug:  .byte "ELIGE CON ARRIBA/ABAJO - FUEGO",0
t_fich: .byte "DCREC.DAT",0
t_magic: .byte "ROMAPI"
t_late: .word $E50, $F72, $E50, $B30
; Desplazamiento+1 de cada letra en `letras`
palabras:
    .byte 1,6,11,16,21,0            ; D E A T H
    .byte 26,11,31,36,41,31,0       ; C A N Y O N
letras:
    .byte $F0,$88,$88,$88,$F0       ; D
    .byte $F8,$80,$F0,$80,$F8       ; E
    .byte $70,$88,$F8,$88,$88       ; A
    .byte $F8,$20,$20,$20,$20       ; T
    .byte $88,$88,$F8,$88,$88       ; H
    .byte $78,$80,$80,$80,$78       ; C
    .byte $88,$C8,$A8,$98,$88       ; N
    .byte $88,$50,$20,$20,$20       ; Y
    .byte $70,$88,$88,$88,$70       ; O
