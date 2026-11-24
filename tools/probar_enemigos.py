"""Fase 5 (build TURBO): barre la pantalla disparando y anota lo que aparece."""
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
SEG = int(sys.argv[1]); DIR = sys.argv[2]
emu.post_run("output/turbo/dcanyon.bin"); time.sleep(4)
tipos, mejoras, jefes, fotos, lado = {}, set(), [], set(), "left"
f0, c0, t0, t_lado, ant = v("frames", 2), emu.ciclos(), time.time(), 0, 0
fr = lambda: v("frames", 2)
while time.time() - t0 < SEG:
    if time.time() - t_lado > 1.1:
        lado = "right" if lado == "left" else "left"
        emu.joy_release(); emu.joy([lado, "fire"], 0); t_lado = time.time()
    z, je = v("zona"), v("jefe_est")
    for t in emu.ram(DBG["en_t"], 8):
        if t:
            tipos.setdefault(t, set()).add(z)
            if t > 6: print("TIPO INVALIDO", t)
    if v("mj_t"): mejoras.add(v("mj_t"))
    if je == 1 and ant != 1: jefes.append([z, time.time(), 0])
    if je != 1 and ant == 1: jefes[-1][2] = time.time()
    if je == 1 and time.time() - jefes[-1][1] > 2.2 and z not in fotos:
        fotos.add(z); emu.pantalla("%s/jefe%d.png" % (DIR, z))
    ant = je
    time.sleep(0.05)
f1, c1 = fr(), emu.ciclos()
emu.joy_release()
print("tipos por zona", {k: sorted(x) for k, x in tipos.items()})
print("mejoras", sorted(mejoras), "bajas", v("bajas"), "disparos enemigos", v("n_disp"))
print("jefes", [(z, round(b - a, 1) if b else "sigue") for z, a, b in jefes])
print("vuelta", v("vuelta"), "zona", v("zona"), "amenaza", v("amenaza"),
      "puntos %06x" % v("puntos", 3), "tarde", v("tarde"))
print("ciclos/frame %.0f" % ((c1 - c0) / max(1, (f1 - f0) & 0xFFFF)))
