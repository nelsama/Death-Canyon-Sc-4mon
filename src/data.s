.include "hardware.s"
.include "gfx.inc"
.export gfx_tabla, pal_tabla, zona_gfx, zona_pal, zona_par
.macro COLOR n, c
    .byte n, <(c), >(c)
.endmacro
.rodata
gfx_tabla: GFX_TABLA
zona_gfx:  ZONA_GFX
pal_tabla:                  ; lo que no cambia con la zona
    COLOR 9,  $000          ; texto
    COLOR 10, $E50
    COLOR 11, $FFD
    COLOR 13, $136          ; corriente fría
    COLOR 14, $27A
    COLOR 17, $245          ; sonda
    COLOR 18, $5AB
    COLOR 19, $DFF
    COLOR 21, $A20          ; balas y fuego
    COLOR 22, $F82
    COLOR 23, $FE8
    COLOR 25, $511          ; sonda apagada
    COLOR 26, $A33
    COLOR 27, $F86
    COLOR 29, $426          ; enemigos
    COLOR 30, $C3A
    COLOR 31, $FBE
    .byte $FF
; Por zona: roca (3 colores), material caliente o isla (3) y fondo.
zona_pal:
    .word $433,$754,$A86, $543,$875,$BA8, $112
    .word $411,$622,$933, $900,$E50,$FC4, $201
    .word $325,$537,$86B, $348,$6AD,$CFF, $013
    .word $468,$8AC,$DEF, $579,$9BD,$FFF, $023
    .word $332,$564,$986, $431,$873,$DB5, $111
; Por zona: ancho mínimo, ancho máximo, estilo, filas por tramo.
; Estilo: 1 bordes de lava, 2 islas, 4 salas, 8 cornisas.
zona_par:
    .byte 14, 20, 8, 8
    .byte 12, 18, 1, 8
    .byte 18, 22, 2, 10
    .byte 10, 13, 0, 8
    .byte 10, 22, 4, 10
