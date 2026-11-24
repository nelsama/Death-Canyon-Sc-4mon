"""Fase 7: peligro de cada zona, fundido y sprites por linea (INMORTAL+AMENAZA)."""
import re
import sys
import time
import emu
DIR = sys.argv[1]
DBG = {}
v = lambda n, k=1: int.from_bytes(emu.ram(DBG[n], k), "little")
NOMBRE = {0: "rocas", 1: "geiseres", 2: "rebotes", 3: "viento", 4: "compuertas"}
TIPO = {0: 4, 1: 5, 4: 6}
bien = True


def dice(n, c, d=""):
    global bien
    bien &= bool(c)
    print("OK   " if c else "FALLO", n, d, flush=True)


def carga(vdir):
    DBG.clear()
    for l in open(vdir + "/dcanyon.dbg"):
        m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
        if l.startswith("sym") and m:
            DBG[m[1]] = int(m[2], 16)
    emu.joy_release()
    emu.post_run(vdir + "/dcanyon.bin")
    time.sleep(4)


peor_linea = 0


def por_linea(M):
    """Sprites que cruzan la linea mas cargada (cuentan 16 px si van a 2x)."""
    a = lambda n: M[DBG[n]:DBG[n] + 32]
    Y, F = a("spr_y"), a("spr_f")
    c = [0] * 270
    for y, f in zip(Y, F):
        if y < 240:
            for l in range(y, min(y + (16 if f & 0x10 else 8), 270)):
                c[l] += 1
    return max(c)


for z in range(5):
    carga("output/inmortalamenaza%d" % (z * 4 + 1))
    visto, foto, t0, cal, pxs, reb = 0, False, time.time(), 0, set(), 0
    emp, est_x = [], set()
    dice("zona %d arranca" % (z + 1), v("zona") == z)
    lado = 0
    while time.time() - t0 < 32 and v("jefe_est") == 0:
        if z != 3 and time.time() - lado > 1.2:
            lado = time.time()
            emu.joy_release()
            emu.joy([("left", "right")[int(lado) % 2]] + (["fire"] if z != 1 else []), 0)
        M = emu.ram(0, 0x4B00)
        peor_linea = max(peor_linea, por_linea(M))
        T = M[DBG["en_t"]:DBG["en_t"] + 8]
        if max(T) > 6:
            dice("tipo valido", False, list(T))
        if z in TIPO and TIPO[z] in T:
            i = T.index(TIPO[z])
            visto += 1
            est_x.add(M[DBG["en_x"] + i])
            if not foto and 90 < M[DBG["en_y"] + i] < 170:
                foto = True
                emu.pantalla("%s/pel%d.png" % (DIR, z))
        if z == 3:
            if M[DBG["vi_t"]] >= 165:
                emp.append(M[DBG["px"]])
                if not foto and M[DBG["vi_t"]] > 170:
                    foto = True
                    emu.pantalla("%s/pel3.png" % DIR)
        time.sleep(0.03)
    if z in TIPO:
        dice(NOMBRE[z], visto > 5, "lecturas %d, x distintas %d" % (visto, len(est_x)))
        if z == 4:
            dice("la compuerta se mueve", len(est_x) > 10, len(est_x))
    if z == 2:
        dice("rebotes", v("n_reb") > 0, v("n_reb"))
    if z == 3:
        dice("el viento empuja", emp and max(emp) - min(emp) > 10,
             (min(emp), max(emp)) if emp else "")
    dice("video en VBLANK", v("tarde") == 0, v("tarde"))
emu.joy_release()
print("peor linea de sprites:", peor_linea, "(limite 12)")

# geiser: quieta encima de uno en erupcion, el calor sube (sin disparar)
carga("output/inmortalamenaza5")
t0, sube = time.time(), 0
ult = v("calor")
while time.time() - t0 < 40 and not sube:
    M = emu.ram(0, 0x4B00)
    T = M[DBG["en_t"]:DBG["en_t"] + 8]
    g = [i for i in range(8) if T[i] == 5 and 60 < M[DBG["en_y"] + i] < 225]
    if g:
        i = max(g, key=lambda k: M[DBG["en_y"] + k])
        gx, gy = M[DBG["en_x"] + i], M[DBG["en_y"] + i]
        x, y = M[DBG["px"]], M[DBG["py"]]
        t = (["left"] if x > gx + 2 else ["right"] if x < gx - 2 else []) + \
            (["up"] if y > gy + 2 else ["down"] if y < gy - 2 else [])
        emu.joy_release()
        if t:
            emu.joy(t, 60)
        if abs(x - gx) < 10 and abs(y - gy) < 10 and (M[DBG["en_a"] + i] & 127) >= 72:
            c0 = v("calor")
            time.sleep(0.2)
            sube = v("calor") - c0 >= 8 or v("apagon") > 0
    time.sleep(0.02)
dice("el geiser calienta", sube, v("calor"))
emu.joy_release()

# fundido: en el cambio de zona pasa por las etapas y acaba en 0
carga("output/turbo")
etapas, t0, lado = [], time.time(), 0
while time.time() - t0 < 60 and not (etapas and v("tr") == 0):
    if time.time() - lado > 1.1:
        lado = time.time()
        emu.joy_release()
        emu.joy([("left", "right")[int(lado) % 2], "fire"], 0)
    t = v("tr")
    if t and t not in etapas:
        etapas.append(t)
        if t == 2 or t == 3:
            emu.pantalla(DIR + "/fundido.png")
    time.sleep(0.01)
emu.joy_release()
dice("fundido", len(etapas) >= 4 and etapas == sorted(etapas) and v("tr") == 0, etapas)
time.sleep(1)
emu.pantalla(DIR + "/tras_fundido.png")
sys.exit(not bien)
