"""Record real: juega hasta puntuar, muere, y comprueba tabla y SD."""
import re, sys, time
import emu
DIR = sys.argv[1]
DBG = {}
for l in open("output/amenaza14/dcanyon.dbg"):
    m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
    if l.startswith("sym") and m: DBG[m[1]] = int(m[2], 16)
v = lambda n, k=1: int.from_bytes(emu.ram(DBG[n], k), "little")
def carga():
    t = time.time(); emu.post_run("output/amenaza14/dcanyon.bin"); time.sleep(3.5)
def pulsa(t):
    emu.joy_release(); time.sleep(.15); emu.joy([t], 100); time.sleep(.3)
tabla = lambda: [int.from_bytes(emu.ram(DBG["rec"] + 21 + 3 * k, 3), "little") for k in range(3)]
carga(); pulsa("down"); ini = tabla(); print("tabla inicial", ["%06x" % x for x in ini])
hechos = []
for n in range(6):
    pulsa("fire"); time.sleep(.8); lado = 0
    t0 = time.time()
    while v("est") != 3 and time.time() - t0 < 60:
        if time.time() - lado > .5:
            lado = time.time(); emu.joy_release(); emu.joy([("left", "right")[int(lado * 2) % 2], "fire"], 0)
        time.sleep(.05)
    emu.joy_release(); time.sleep(.6)
    hechos.append(v("puntos", 3)); emu.pantalla(DIR + "/fin.png")
    print("partida", n, "%06x" % hechos[-1], "msg", v("msg"), ["%06x" % x for x in tabla()])
    pulsa("fire"); time.sleep(.6)
esperada = sorted([x for x in ini + hechos], reverse=True)[:3]
# iguales no desplazan: la comparacion por valores basta
ok1 = tabla() == esperada
antes = emu.ram(DBG["rec"], 32); carga()
ok2 = emu.ram(DBG["rec"], 32) == antes
emu.pantalla(DIR + "/menu_rec.png")
print("tabla ordenada", ok1, "| sobrevive a recargar", ok2, "| hubo puntos", any(hechos))
sys.exit(not (ok1 and ok2 and any(hechos)))
