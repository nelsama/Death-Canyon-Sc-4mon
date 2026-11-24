"""Fase 3: recorre las zonas (build TURBO) y comprueba el terreno.
- paso libre mínimo y solape entre filas seguidas
- el tilemap coincide con el perfil de colisión
- ningún frame con el vídeo fuera del VBLANK
"""
import re
import sys
import time
import emu
DBG = {}
for l in open("output/turbo/dcanyon.dbg"):
    m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
    if l.startswith("sym") and m:
        DBG[m[1]] = int(m[2], 16)
v = lambda n, k=1: int.from_bytes(emu.ram(DBG[n], k), "little")
VISTA = int(sys.argv[1]) if len(sys.argv) > 1 else 85
zonas, minimo, malas, cortes, t0 = set(), {}, 0, 0, time.time()
f0, c0 = v("frames", 2), emu.ciclos()
while time.time() - t0 < VISTA:
    z = v("zona")
    if z not in zonas and time.time() - t0 > 1:
        zonas.add(z)
    W = emu.ram(DBG["w_izq"], 256)          # una sola lectura: coherente
    g = v("gen_fila")
    filas = [(W[i], W[32 + i], W[64 + i], W[96 + i], W[DBG["w_tip"] - DBG["w_izq"] + i])
             for i in ((g + 3 + k) % 32 for k in range(24))]
    def tramos(f):
        l, r, a, b, _ = f
        return [(l + 1, a - 1), (b + 1, r - 1)] if a <= b else [(l + 1, r - 1)]
    for f in filas:
        m = min(b - a + 1 for a, b in tramos(f))
        minimo[f[4]] = min(minimo.get(f[4], 99), m)
    for f, h in zip(filas, filas[1:]):
        if max(min(b, d) - max(a, c) + 1 for a, b in tramos(f)
               for c, d in tramos(h)) < 4:
            cortes += 1
    time.sleep(0.15)
f1, c1 = v("frames", 2), emu.ciclos()
emu.joy_release()
emu.joy(["down"], 0); time.sleep(0.4); emu.joy_release()
# pausa no disponible por joystick: se compara evitando las filas en curso
time.sleep(0.3)
for _ in range(8):
    g = v("gen_fila"); W = emu.ram(DBG["w_izq"], 128); tm = emu.vram()["tilemap"]
    if g != v("gen_fila"):
        continue
    for k in range(3, 26):
        i = (g + k) % 32
        for c in range(8, 32):
            sol = c <= W[i] or c >= W[32 + i] or W[64 + i] <= c <= W[96 + i]
            malas += (tm[i][c] in (128, 129, 130, 131, 134)) != sol
print("zonas vistas", sorted(zonas), "paso minimo por zona", minimo)
print("cortes", cortes, "celdas que no casan", malas, "tarde", v("tarde"),
      "ciclos/frame %.0f" % ((c1 - c0) / max(1, (f1 - f0) & 0xFFFF)))
