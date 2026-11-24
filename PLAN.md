# Death Canyon — plan

Shooter vertical original para la placa 6502 (Tang Nano 9K), en ca65.
Binario: `DCANYON.BIN`, carga `LOAD DCANYON.BIN 0800` y `R 0800`.

## 1. El juego

Una sonda desciende por un cañón volcánico. El recurso es el **calor**: sube al
disparar y al volar cerca de la lava; baja sin disparar y en las corrientes
frías. Al llegar al tope los sistemas se apagan unos segundos.

Reglas de originalidad: nombre, gráficos, terreno, enemigos, niveles y sonido
son propios. No hay río, combustible, bidones, puentes ni sus equivalentes, y no
se traen gráficos, sonidos, generador ni tablas de juego de ningún otro título.

### Zonas (cada una con su paleta y tiles)

| Zona | Terreno | Peligro propio | Jefe |
|---|---|---|---|
| 1 Ceniza | roca con cornisas | rocas que caen | Excavadora |
| 2 Lava | paredes incandescentes | géiseres que calientan | Salamandra |
| 3 Cristal | columnas en el centro | disparos que rebotan | Prisma |
| 4 Hielo | pasos muy estrechos | viento lateral | Carámbano |
| 5 Ruinas | salas y compuertas | compuertas móviles | El Núcleo |

Al completar la 5 se repite desde la 1 con más dificultad.

### Enemigos y objetos

Torreta de pared, enjambre en formación, mina térmica (persigue si el calor es
alto) y jefe. Mejoras: disparo doble, perforante, escudo y refrigerante. Combo
por bajas seguidas sin recibir daño.

### Dificultad (valores de partida, se afinan jugando)

| | Fácil | Normal | Difícil |
|---|---|---|---|
| Vidas | 5 | 3 | 2 |
| Calor por disparo | 3 | 4 | 6 |
| Apagón (frames) | 60 | 90 | 120 |
| Velocidad de scroll inicial (px/frame) | 0,625 | 0,75 (aprobada) | 1 |
| Cadencia enemiga (frames) | 120 | 80 | 50 |
| Enemigos simultáneos | 4 | 6 | 8 |
| Continuaciones | ilimitadas | 3 | 0 |
| Multiplicador de puntos | ×1 | ×2 | ×3 |

### Checkpoints: la dificultad sube durante la partida

Cada zona tiene 4 tramos. El final de cada tramo es un **checkpoint**: una baliza
en las paredes que se enciende al cruzarla. El cuarto es la derrota del jefe, así
que una vuelta completa son 20 checkpoints.

Al cruzar uno:
1. Sube el **nivel de amenaza** (0-39; ahí se queda). Nunca baja al morir.
2. Se guarda el punto de reaparición. Morir devuelve al último checkpoint y,
   al quedarse sin vidas, continuar también.
3. Premio: puntos y calor a 0. El cuarto da además una vida.
4. Aviso en el HUD, sonido propio y 2 s sin enemigos nuevos.

La dificultad elegida pone la base; la amenaza se suma encima. Qué sube (todo
con tope, para que siempre se pueda esquivar):

| Parámetro | Cada cuánto | Cambio | Tope |
|---|---|---|---|
| Cadencia enemiga | 1 checkpoint | -2 frames | 30 frames |
| Velocidad de scroll | 4 | +1/8 px/frame | 3 px/frame |
| Enemigos simultáneos | 4 | +1 | 10 |
| Velocidad de bala enemiga | 5 | +1/4 px/frame | 3 px/frame |
| Ancho mínimo del cañón | 4 | -1 tile | 10 tiles |
| Aparición de mejoras | 5 | menos frecuente | 1 cada 2 tramos |
| Vida del jefe | vuelta (20) | +50 % | +100 % |

Los tipos de enemigo también entran por checkpoint, no todos de golpe:

| Checkpoints | Aparecen |
|---|---|
| 0-1 | torretas |
| 2-3 | + enjambres |
| 4-7 | + minas térmicas |
| 8-11 | + torretas que apuntan a la sonda |
| 12-19 | + enjambres que disparan |
| 20 o más | todas las variantes rápidas |

Los valores van en una sola tabla (`amenaza_tab`), para equilibrar sin tocar la
lógica. El build admite `make AMENAZA=n` para probar directamente un nivel.

## 2. Plataforma

Fuentes: manual de vídeo 3.1 y monitor v2.8.0 (2026-11-24).

| Novedad | Uso en el juego |
|---|---|
| RAM de 32 KB | código en el bloque bajo, variables y búferes en el alto |
| 12 sprites por línea (antes 8) | enjambres y jefes compuestos |
| Transparencia entre sprites | escudo, humo y explosiones superpuestos |
| `$D818`, color de la fuente | título y HUD |
| Pulsadores en `$C005` | entrada auxiliar (activos en bajo, sin antirrebote) |
| ROM API | carga de datos y récords |
| Rutinas de vídeo en ROM (`$BE40`) | sólo código frío (menús) |

Las rutinas de vídeo en ROM destruyen A, X, Y y `$16-$1F`, y no son reentrantes.
En el frame se usan primitivas propias.

## 3. Presupuestos

### Memoria

| Rango | Uso |
|---|---|
| `$0020-$007F` | zero page del juego (96 B) |
| `$0100-$01FF` | pila del 6502 |
| `$0200-$07FF` | monitor: no tocar |
| `$0800-$3DFF` | código y constantes (13.824 B; objetivo ≤ 12 KB) |
| `$3E00-$3FFF` | pila del monitor: no tocar, la ROM API la usa |
| `$4000-$5FFF` | variables y búferes (8 KB) |
| `$6000-$7FFF` | datos cargados de la SD si hacen falta (8 KB) |

Sólo se usa el bloque alto con hardware de 32 KB. Al arrancar se comprueba que
`$4000` es RAM y, si no, se avisa. `BOOT.INI` carga en `$0800`, así que el juego
puede arrancar solo.

### Vídeo

- VBLANK: 45 líneas, unos 4.826 ciclos (medido en un proyecto anterior; se mide
  de nuevo en la fase 2). Objetivo: peor frame ≤ 4.300.
- Bucle: vídeo primero, lógica después. OAM con caché, sólo lo que cambia.
- Filas 0 y 29 sin contenido crítico.

### Sprites (32 en OAM, 12 por línea)

| Slots | Uso |
|---|---|
| 0-3 | sonda 16×16 |
| 4-7 | balas propias |
| 8-19 | enemigos y jefe (máx. 12) |
| 20-25 | balas enemigas |
| 26-27 | mejoras |
| 28-31 | explosiones y efectos |

El HUD va con tiles en una banda de raster, no con sprites. Peor línea prevista:
2 (sonda) + 4 + 2 + 4 = 12; la lógica limita a 4 enemigos por línea.

## 4. Fases

1. **Plan y presupuestos** (este documento).
2. **Motor**: arranque, vídeo, scroll, banda del HUD, entrada, medición de VBLANK.
3. **Cañón**: generador de terreno por zonas y colisión.
4. **Sonda**: control, calor, disparos, vidas.
5. **Enemigos**: torretas, enjambres, minas, mejoras y jefes.
6. **Partida**: menú, dificultad, zonas, checkpoints y amenaza, continuación, pausa, récords.
7. **Acabado**: sonido, efectos, equilibrado.

Cada fase termina con una prueba en el emulador y la luz verde del usuario.

## 5. Por comprobar

- **Récords:** en MicroFS borrar no libera espacio. Antes de la fase 6 hay que
  ver si se puede reescribir un fichero en su sitio; si no, se guarda en RAM.
- **Emulador:** `emulador.exe` es de las 00:22 y el cambio a 32 KB se confirmó a
  las 00:24 del mismo día. Parece incluirlo, pero se verifica en la fase 2.

## 6. Estado (2026-11-24)

Fases 1 a 7 hechas y probadas en el emulador; falta la placa real. Binario:
10.334 de 13.824 bytes. Pruebas en `tools/probar_*.py`; variantes de compilación
(`TURBO`, `INMORTAL`, `AMENAZA=n`) en el `Makefile`.

- Los récords van en `DCREC.DAT`: se crea una vez y se reescribe en su sitio.
- Zero page del juego: `$28-$8F` (la ROM API usa `$02-$27` y `$F0-$F7`).
- SALIR escribe 0 en `$C004`: el monitor ejecuta `BOOT.INI` (launcher).
- La pausa sólo está en el pulsador B de la placa.
