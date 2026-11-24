# Death Canyon

Shooter vertical original en ensamblador 6502 (ca65) para un computador 6502
sobre FPGA Tang Nano 9K, con vídeo por tiles y sprites y sonido SID.

Pilota una sonda por un cañón volcánico vigilando el **calor**: disparar y
acercarse a la lava lo suben; si llega al tope, los sistemas se apagan.

- 5 zonas (ceniza, lava, cristal, hielo y ruinas), cada una con su peligro y jefe.
- 3 dificultades; además, la dificultad sube con cada checkpoint.
- Mejoras, combos, continuaciones y récords guardados en la SD.

## Requisitos

- Hardware con **32 KB de RAM** y monitor **v2.8.0** o posterior.
- Para compilar: cc65 (`ca65`, `ld65`), GNU Make y Python 3 en el PATH.

## Compilar

```sh
make                    # output/dcanyon.bin
make CC65_HOME=/ruta    # si cc65 no está en D:/cc65
```

## Ejecutar

Copiar `output/dcanyon.bin` a la SD como `DCANYON.BIN` y, en el monitor:

```
LOAD DCANYON.BIN 0800
R 0800
```

## Controles

| Control | Acción |
|---|---|
| Joystick | mover / elegir en el menú |
| Fuego o pulsador A | disparar / aceptar |
| Pulsador B | pausa |

SALIR vuelve al monitor, que ejecuta `BOOT.INI` si existe.

## Estado

Probado en el emulador; pendiente de probar en la placa. El diseño y los
presupuestos están en [PLAN.md](PLAN.md), y las pruebas en `tools/probar_*.py`
(la ruta del emulador se indica con la variable `EMU_DIR`).
