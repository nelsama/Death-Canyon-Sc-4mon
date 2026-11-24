"""Graba el SID a WAV y mide nivel por tramos; comprueba que cada efecto suena."""
import os, re, struct, sys, time, wave
WAV = sys.argv[1]
os.environ["EMU_WAV"] = WAV
import emu
DBG = {}
for l in open("output/inmortal/dcanyon.dbg"):
    m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
    if l.startswith("sym") and m: DBG[m[1]] = int(m[2], 16)
emu.stop(); time.sleep(1.5); print("emulador", emu.start())
t0 = time.time()
def tramo(n, seg):
    a = time.time() - t0; time.sleep(seg); marcas.append((n, a, time.time() - t0))
marcas = []
emu.post_run("output/dcanyon.bin"); time.sleep(3.5)
tramo("menu (musica)", 6)
emu.joy(["down"], 100); tramo("mover menu", .4)
emu.joy(["fire"], 100); time.sleep(1.5)
tramo("juego sin tocar", 3)
emu.joy(["fire"], 0); tramo("disparando", 2.5)
emu.joy_release(); emu.joy(["left"], 0); tramo("choque y muerte", 3)
emu.joy_release()
emu.post_run("output/inmortal/dcanyon.bin"); time.sleep(3.5)
emu.joy(["fire"], 0); tramo("hasta el apagon", 9); emu.joy_release()
v = lambda n, k=1: int.from_bytes(emu.ram(DBG[n], k), "little")
pos0 = v("frames", 2); c0 = emu.ciclos(); time.sleep(4)
print("ciclos/frame %.0f tarde %d" % ((emu.ciclos() - c0) / ((v("frames", 2) - pos0) & 0xFFFF), v("tarde")))
fin = time.time() - t0
time.sleep(1); emu.stop(); time.sleep(1)
d = open(WAV, "rb").read()
i = d.index(b"fmt ")
can, hz = struct.unpack("<HI", d[i + 10:i + 16])
raw = d[d.index(b"data") + 8:]; raw = raw[:len(raw) // 2 * 2]
S = struct.unpack("<%dh" % (len(raw) // 2), raw)[::can]
print("wav", hz, "Hz,", "%.1f s, sesion %.1f s" % (len(S) / hz, fin))
desf = len(S) / hz - fin - 1
for n, a, b in marcas:
    x = S[max(0, int((a + desf) * hz)):int((b + desf) * hz)]
    if not x: print(n, "SIN DATOS"); continue
    med = sum(x) / len(x)
    rms = (sum((y - med) ** 2 for y in x) / len(x)) ** .5
    print("%-18s rms %6.0f  pico %6d" % (n, rms, max(abs(y - med) for y in x)))
