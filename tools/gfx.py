"""Convierte dibujos ASCII (. = 0, 1, 2, 3) en patrones de 2 planos.

Formato: 'b NOMBRE indice' (fondo), 's NOMBRE indice' (sprite) o
'z ROCA|BORDE|ISLA zona' (tiles de zona), seguido de 8 filas.
"""
import sys

T = "T_ROCA T_BORDE_I T_BORDE_D T_ISLA".split()
out = ["%s = %d" % (n, 128 + i) for i, n in enumerate(T)]
tabla, zonas = [], {}


def planos(filas):
    return [sum(((int(c) >> p) & 1) << (7 - k) for k, c in enumerate(f))
            for p in (0, 1) for f in filas]


lineas = [l.strip() for l in open(sys.argv[1], encoding="utf-8")]
lineas = [l for l in lineas if l and not l.startswith("#")]
for i in range(0, len(lineas), 9):
    tipo, nombre, idx = lineas[i].split()
    filas = [f.replace(".", "0") for f in lineas[i + 1:i + 9]]
    assert tipo in "bsz" and all(
        len(f) == 8 and set(f) <= set("0123") for f in filas), nombre
    if tipo == "z":
        z = zonas.setdefault(int(idx), {})
        z[nombre] = planos(filas)
        if nombre == "BORDE":
            z["BORDE_D"] = planos([f[::-1] for f in filas])
    else:
        out.append("%s = %s" % (nombre, idx))
        tabla.append((0 if tipo == "b" else 1, int(idx), planos(filas)))

# barra de calor: 0 a 8 píxeles encendidos (color 2) sobre color 1
out.append("T_BARRA = 136")
for n in range(9):
    f = "2" * n + "1" * (8 - n)
    tabla.append((0, 136 + n, planos(["00000000"] + [f] * 6 + ["00000000"])))

with open(sys.argv[2], "w") as f:
    f.write("\n".join(out) + "\n.macro GFX_TABLA\n")
    for t, n, d in tabla:
        f.write("  .byte %d,%d,%s\n" % (t, n, ",".join(map(str, d))))
    f.write("  .byte $FF\n.endmacro\n.macro ZONA_GFX\n")
    for z in sorted(zonas):
        for n in ("ROCA", "BORDE", "BORDE_D", "ISLA"):
            f.write("  .byte %s\n" % ",".join(map(str, zonas[z][n])))
    f.write(".endmacro\n")
