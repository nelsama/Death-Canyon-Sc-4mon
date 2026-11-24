"""Cada torreta apoya sus dos filas en la pared: ni flota ni se hunde."""
import re, sys, time
import emu
DBG = {}
for l in open("output/turbo/dcanyon.dbg"):
    m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
    if l.startswith("sym") and m:
        DBG[m[1]] = int(m[2], 16)
emu.post_run("output/turbo/dcanyon.bin"); time.sleep(4)
emu.joy(["fire"], 0)
vistas, mal, medio, zonas, t0 = 0, 0, 0, {}, time.time()
while time.time() - t0 < 90:
    M = emu.ram(0, 0x4800)
    a = lambda n, k: M[DBG[n]:DBG[n] + k]
    sc = M[DBG["sc_y"]]
    T, X, Y, A = (a(n, 8) for n in ("en_t", "en_x", "en_y", "en_a"))
    L, R = a("w_izq", 32), a("w_der", 32)
    for i in range(8):
        if T[i] != 1 or not 24 <= Y[i] < 220:
            continue
        y = (Y[i] + sc) & 255
        if y & 7:                   # lectura a mitad de frame
            medio += 1
            continue
        vistas += 1
        f = [(y >> 3), ((y >> 3) + 1) % 32]
        bien = all((R[k] * 8 == X[i] + 16) if A[i] & 0x80 else
                   ((L[k] + 1) * 8 == X[i]) for k in f)
        mal += not bien
        z = M[DBG["zona"]]
        zonas[z] = zonas.get(z, 0) + 1
    time.sleep(0.03)
emu.joy_release()
print("torretas miradas", vistas, "mal apoyadas", mal, "a mitad de frame", medio,
      "por zona", zonas)
sys.exit(not vistas or mal > 0 or medio > vistas // 4)
