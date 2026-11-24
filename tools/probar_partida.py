"""Fase 6: menu, dificultades, checkpoints, fin y records en la SD."""
import re, sys, time
import emu
DIR = sys.argv[1]
DBG = {}
def carga(dire):
    DBG.clear()
    for l in open(dire + "/dcanyon.dbg"):
        m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
        if l.startswith("sym") and m:
            DBG[m[1]] = int(m[2], 16)
    emu.post_run(dire + "/dcanyon.bin")
    time.sleep(2.5)
v = lambda n, k=1: int.from_bytes(emu.ram(DBG[n], k), "little")
foto = lambda n: emu.pantalla("%s/%s.png" % (DIR, n))
bien = True
def dice(n, c, d=""):
    global bien
    bien &= bool(c)
    print("OK   " if c else "FALLO", n, d)
def espera(f, s):
    fin = time.time() + s
    while time.time() < fin:
        if f(): return True
        time.sleep(0.03)
    return False
def pulsa(t):
    emu.joy_release(); time.sleep(.15); emu.joy([t], 100); time.sleep(.3)
emu.joy_release()
carga("output"); foto("menu")
dice("la SD responde", v("rec_sd") == 1)
dice("empieza en normal", v("dif") == 1)
for tecla, d, esp in (("up", 0, (5, 3, 60)), ("down", 1, (3, 4, 90)), ("down", 2, (2, 6, 120))):
    pulsa(tecla); dice("menu dificultad %d" % d, v("dif") == d)
foto("menu_dificil")
pulsa("fire"); time.sleep(1)
dice("dificil: 2 vidas, calor 6, x3", (v("d_vidas"), v("d_cal"), v("d_mul"), v("vidas")) == (2, 6, 3, 2))
dice("dificil va a 1 px", (v("vel_lo"), v("vel_hi")) == (0, 1))
emu.joy(["fire"], 0)
ok = espera(lambda: v("est") == 3, 60)
emu.joy_release(); time.sleep(.6); foto("fin")
p = v("puntos", 3); r = emu.ram(DBG["rec"], 32)
dice("sin continuaciones acaba", ok, "puntos %06x" % p)
mejor = int.from_bytes(r[21:24], "little")
dice("el record entra en la tabla", p == 0 or p in [int.from_bytes(r[21 + 3 * k:24 + 3 * k], "little") for k in range(3)], "%06x" % mejor)
pulsa("fire"); time.sleep(1)
carga("output")
dice("el record sobrevive a recargar", emu.ram(DBG["rec"], 32) == r)
# checkpoints, en la variante rapida e inmortal
carga("output/turbo")
emu.joy(["fire"], 0)
a0 = v("amenaza")
dice("cruza el primero", espera(lambda: v("chk_t") == 1, 30), v("chk_t"))
espera(lambda: v("h_fin") == 22, 1); foto("checkpoint")
dice("avisa y respira", v("msg") == 3 and v("sp_n") > 0)
dice("la amenaza sube", v("amenaza") > a0, v("amenaza"))
vid = v("vidas")
lado, t0 = 0, time.time()
def zona2():
    global lado
    if time.time() - lado > 1.1:
        lado = time.time(); emu.joy_release(); emu.joy([("left", "right")[int(lado) % 2], "fire"], 0)
    return v("chk_z") == 1
dice("jefe vencido = checkpoint y vida", espera(zona2, 60) and v("vidas") == vid + 1, (v("chk_z"), v("chk_t"), v("vidas")))
emu.joy_release()
dice("video en VBLANK", v("tarde") == 0, v("tarde"))
# morir vuelve al checkpoint, en una amenaza alta (zona 4, tramo 2)
carga("output/amenaza14"); pulsa("fire"); time.sleep(1.2)
dice("empieza en zona 4 tramo 2", (v("zona"), v("zfila") >> 6) == (3, 2), (v("zona"), v("zfila")))
emu.joy(["left"], 0)
dice("muere", espera(lambda: v("est") == 1, 12)); emu.joy_release()
dice("vuelve al checkpoint", espera(lambda: v("est") == 0, 4) and (v("zona"), v("zfila") >> 6) == (3, 2) and v("vidas") == 2,
     (v("zona"), v("zfila"), v("vidas")))
dice("y va mas rapido (0,75+3/8)", (v("vel_hi"), v("vel_lo")) == (1, 0x20), (v("vel_hi"), v("vel_lo")))
time.sleep(1); foto("hielo")
sys.exit(not bien)
