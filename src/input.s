; Joystick + pulsadores de la placa. joy = estado, joy_new = flancos.
.include "hardware.s"
.export input_init, input_read
.exportzp joy, joy_new
.zeropage
joy:     .res 1
joy_new: .res 1
joy_ant: .res 1
bot:     .res 1
bot_ant: .res 1
.code
.proc input_init
    lda JOY_CFG
    and #$07                ; no tocar los bits del TM1638
    ora #$F8
    sta JOY_CFG
    lda #0
    sta joy
    sta joy_new
    sta bot_ant
    rts
.endproc

.proc input_read
    lda joy
    sta joy_ant
    lda JOY_PORT
    eor #$FF
    lsr
    lsr
    lsr
    tax                     ; bits: 0 der, 1 izq, 2 abajo, 3 arriba, 4 fuego
    lda joy_map,x
    sta joy
    lda BOTONES             ; antirrebote: dos frames seguidos pulsado
    eor #$FF
    and #$03
    tax
    and bot_ant
    stx bot_ant
    sta bot
    and #$01                ; A = fuego
    beq @b
    lda joy
    ora #J_FIRE
    sta joy
@b: lda bot
    and #$02                ; B = pausa
    beq @fl
    lda joy
    ora #J_PAUSE
    sta joy
@fl:
    lda joy_ant
    eor #$FF
    and joy
    sta joy_new
    rts
.endproc

.rodata
joy_map:
.repeat 32, I
    .byte ((I & 1) << 1) | ((I >> 1) & 1) | ((I & 4) << 1) | ((I & 8) >> 1) | (I & 16)
.endrepeat
