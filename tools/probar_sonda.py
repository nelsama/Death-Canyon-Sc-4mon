"""Fase 4: calor, disparos, apagón, vidas, fin y reinicio."""
import re
import sys
import time
import emu
DBG = {}
def carga(dire):
    DBG.clear()
    for l in open(dire + "/dcanyon.dbg"):
        m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
        if l.startswith("sym") and m:
            DBG[m[1]] = int(m[2], 16)
    emu.post_run(dire + "/dcanyon.bin")
    time.sleep(3.5)
v = lambda n, k=1: int.from_bytes(emu.ram(DBG[n], k), "little")
DIR = sys.argv[1] if len(sys.argv) > 1 else None
foto = lambda n: DIR and emu.pantalla(DIR + "/" + n + ".png")
def espera(f, s):
    fin = time.time() + s
    while time.time() < fin:
        if f():
            return True
        time.sleep(0.03)
    return False
bien = True
def dice(n, c, d=""):
    global bien
    bien &= bool(c)
    print("OK   " if c else "FALLO", n, d)
emu.joy_release()
carga("output/inmortal")
dice("empieza con 3 vidas y sin calor", v("vidas") == 3 and v("calor") == 0)
emu.joy(["fire"], 0); time.sleep(0.5); foto("disparo")
dice("disparar calienta", v("calor") > 0 and v("disp") > 2, (v("calor"), v("disp")))
t = time.time()
dice("llega el apagon", espera(lambda: v("apagon") > 0, 14), "%.1f s" % (time.time() - t + 0.5)); foto("apagon")
d = v("disp"); time.sleep(0.8)
dice("apagada no dispara", v("disp") == d and v("apagon") > 0)
dice("se recupera y vuelve a disparar", espera(lambda: v("disp") != d, 3))
espera(lambda: v("calor") > 40, 8); emu.joy_release(); time.sleep(0.2); c = v("calor"); time.sleep(0.7)
dice("sin disparar se enfria", v("calor") < c, (c, v("calor")))
carga("output")
emu.joy(["fire"], 120); time.sleep(1.5)   # sale del menú
emu.joy(["left"], 0)
dice("chocar mata", espera(lambda: v("est") == 1, 8)); time.sleep(.15); foto("muerte")
dice("resta vida y reaparece", espera(lambda: v("vidas") == 2 and v("est") == 0, 4), v("vidas"))
dice("sin vidas ofrece continuar", espera(lambda: v("est") == 2, 30), v("vidas")); time.sleep(.6); foto("continuar")
emu.joy_release(); time.sleep(.2); emu.joy(["fire"], 120)
dice("continua con 3 vidas", espera(lambda: v("est") == 0 and v("vidas") == 3, 3)); time.sleep(1)
dice("video en VBLANK", v("tarde") == 0, v("tarde"))
sys.exit(not bien)
