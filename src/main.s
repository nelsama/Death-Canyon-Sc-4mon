; Death Canyon - arranque, bucle de frame y control de la partida.
.include "hardware.s"
.include "gfx.inc"
.import vid_init, vid_frame, vid_flush, spr_prepara, vid_celda, vid_vuelca
.import input_init, input_read
.import ter_init, ter_desde, ter_frame
.import jug_init, jug_sale, jug_frame, jug_dibuja
.import hud_init, hud_frame
.import en_init, en_limpia, en_frame, en_dibuja
.import menu, dif_carga, rec_carga, rec_inserta
.import dif, d_vidas, d_vlo, d_vhi, d_cont, msg, cuenta, chk_aviso
.import puntos
.import snd_init, snd_play, snd_frame, snd_pista, snd_vol
.importzp zona, jefe_est
.importzp joy, joy_new, sc_y, sc_frac, v_lo, v_hi, est, vidas, amenaza
.exportzp dsc, frames
.zeropage
frames: .res 2
vel_lo: .res 1              ; velocidad de scroll 8.8
vel_hi: .res 1
pausa:  .res 1
dsc:    .res 1              ; píxeles de scroll de este frame
fila:   .res 1
col:    .res 1
.bss
cuen_f: .res 1
conts:  .res 1              ; continuaciones que quedan (255 = sin límite)
.code
reset:
    sei
    cld
    ldx #$FF
    txs
    jsr snd_init
    jsr vid_init
    lda #$A5                ; ¿hay RAM alta? (hardware de 32 KB)
    sta $5FFF
    cmp $5FFF
    bne sin_ram
    lda #$5A
    sta $5FFF
    cmp $5FFF
    beq con_ram
sin_ram:
    ldx #0
aviso:
    txa
    clc
    adc #<(5*64+8)
    sta v_lo
    lda #>(5*64+8)
    sta v_hi
    lda txt_ram,x
    beq parado
    jsr vid_celda
    inx
    bne aviso
parado:
    jmp parado
con_ram:
    jsr input_init
    lda #0
    sta frames
    sta frames+1
    lda #1
    sta dif
    jsr rec_carga
titulo:
.if .not (.defined(TURBO) .or .defined(INMORTAL))
    jsr menu
.endif
partida:
    jsr dif_carga
    lda d_cont
    sta conts
    lda d_vidas
    sta vidas
    jsr vid_init            ; pantalla y colas limpias
    jsr marco
    jsr hud_init
    jsr ter_init
    jsr jug_init
    jsr en_init
    lda #0
    sta pausa
    jsr jug_dibuja
bucle:
    jsr spr_prepara
    jsr vid_frame
    jsr vid_flush
    inc frames
    bne lee
    inc frames+1
lee:
    jsr input_read
    lda est
    cmp #EST_CONT
    bcc jugando
    jsr control             ; fin, continuar, reaparecer
    bcs titulo
    jmp dibuja
jugando:
    lda joy_new
    and #J_PAUSE
    beq no_pausa
    lda pausa
    eor #1
    sta pausa
    beq quita
    lda #0
    sta snd_vol
    lda #MSG_PAUSA
    bne pon
quita:
    lda #$0F
    sta snd_vol
    lda #MSG_NADA
pon:
    sta msg
no_pausa:
    lda pausa
    bne dibuja
    lda #0
    sta dsc
    lda est                 ; el terreno se para al morir
    bne quieto
    jsr scroll
quieto:
    jsr ter_frame
    jsr jug_frame
    jsr en_frame
dibuja:
    jsr jug_dibuja
    jsr en_dibuja
    jsr hud_frame
    lda zona                ; música de la zona o del jefe
    ldx jefe_est
    cpx #1
    bne pista
    lda #PISTA_JEFE
pista:
    jsr snd_pista
    jsr snd_frame
    jmp bucle

; Estados fuera del juego. C = 1: volver al título.
.proc control
    lda est
    cmp #EST_REAP
    beq @reap
    cmp #EST_SINV
    beq @sinv
    cmp #EST_CONT
    beq @cont
    lda joy_new             ; EST_FIN
    and #J_FIRE
    beq @no
    sec
    rts
@reap:
    jsr reinicia
@no:
    clc
    rts
@sinv:                      ; sin vidas: ¿quedan continuaciones?
    lda conts
    beq @fin
    lda #EST_CONT
    sta est
    lda #MSG_CONT
    sta msg
    lda #9
    sta cuenta
    lda #60
    sta cuen_f
    bne @no
@cont:
    lda joy_new
    and #J_FIRE
    bne @sigue
    dec cuen_f
    bne @no
    lda #60
    sta cuen_f
    dec cuenta
    bpl @no
@fin:
    lda #EST_FIN
    sta est
    lda #FX_FIN
    jsr snd_play
    jsr rec_inserta
    lda #MSG_FIN
    bcc @m
    lda #MSG_REC
@m: sta msg
    clc
    rts
@sigue:
    lda conts
    cmp #255
    beq @sin_lim
    dec conts
@sin_lim:
    lda d_vidas
    sta vidas
    lda #0                  ; continuar cuesta los puntos
    sta puntos
    sta puntos+1
    sta puntos+2
    jsr reinicia
    clc
    rts
.endproc

; Vuelve al último checkpoint.
.proc reinicia
    jsr ter_desde
    jsr jug_sale
    jsr en_limpia
    lda #MSG_NADA
    sta msg
    rts
.endproc

; Restar: el terreno baja. La velocidad sube 1/8 px cada 4 checkpoints.
.proc scroll
.ifdef TURBO
    lda #$80
    sta vel_lo
    lda #2
    sta vel_hi
.else
    lda #0
    sta vel_hi
    lda amenaza
    and #$FC
    asl
    rol vel_hi
    asl
    rol vel_hi
    asl
    rol vel_hi
    clc
    adc d_vlo
    sta vel_lo
    lda vel_hi
    adc d_vhi
    sta vel_hi
.endif
    lda sc_frac
    sec
    sbc vel_lo
    sta sc_frac
    lda sc_y
    tax
    sbc vel_hi
    sta sc_y
    stx dsc
    lda dsc
    sec
    sbc sc_y
    sta dsc
    rts
.endproc

; Columnas fijas: roca a los lados y hueco del HUD, en las 32 filas.
.proc marco
    lda #0
    sta fila
@f: lda #0
    sta col
@c: lda fila
    lsr
    lsr
    sta v_hi
    lda fila
    and #3
    lsr
    ror
    ror
    ora col
    sta v_lo
    lda col
    cmp #40
    bcs @hud
    lda #T_ROCA
    jsr vid_celda
    lda #PAL_ROCA
    beq @atr
@hud:
    lda #' '
    jsr vid_celda
    lda #PAL_TEXTO
@atr:
    pha
    lda v_hi
    ora #AREA_ATTR
    sta v_hi
    pla
    jsr vid_celda
    inc col
    lda col
    cmp #64
    bne @c
    inc fila
    lda fila
    cmp #32
    bne @f
    rts
.endproc

.rodata
txt_ram: .byte "NECESITA 32 KB DE RAM",0
