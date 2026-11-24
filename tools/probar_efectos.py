"""Anota que pistas y que efectos (por duracion restante y prioridad) suenan."""
import re, sys, time
import emu
V, SEG = sys.argv[1], float(sys.argv[2])
DBG = {}
for l in open(V + "/dcanyon.dbg"):
    m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
    if l.startswith("sym") and m: DBG[m[1]] = int(m[2], 16)
emu.post_run(V + "/dcanyon.bin"); time.sleep(4)
if "output" == V or "amenaza" in V: emu.joy(["fire"], 100); time.sleep(1)
NOM = {(0,1,65):"disparo",(1,3,129):"explosion",(1,6,129):"muerte",(0,4,33):"apagon",(0,5,17):"mejora",
       (0,6,65):"checkpoint/empezar",(1,2,65):"impacto jefe",(1,1,33):"disparo enemigo",(0,2,17):"menu",
       (0,5,129):"escudo roto",(1,0,129):"chispa",(0,2,65):"alarma",(1,7,129):"jefe vencido",(0,5,33):"fin"}
vis, pistas, lado, t0 = {}, set(), 0, time.time()
while time.time() - t0 < SEG:
    if time.time() - lado > 1.1:
        lado = time.time(); emu.joy_release(); emu.joy([("left", "right")[int(lado) % 2], "fire"], 0)
    M = emu.ram(0x4000, 0x700); a = lambda n, k: M[DBG[n] - 0x4000:][:k]
    pistas.add(a("pista", 1)[0])
    for x in (0, 1):
        if a("v_dur", 2)[x]:
            c = (x, a("v_pri", 2)[x], a("v_ctl", 2)[x]); n = NOM.get(c, c); vis[n] = vis.get(n, 0) + 1
emu.joy_release()
print(V, "pistas", sorted(pistas), vis)
