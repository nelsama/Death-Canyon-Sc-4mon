import re, sys, time
import emu
D = {}
for l in open("output/dcanyon.dbg"):
    m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
    if l.startswith("sym") and m: D[m[1]] = int(m[2], 16)
v = lambda n: emu.ram(D[n], 1)[0]
def pulsa(t):
    emu.joy_release(); time.sleep(.15); emu.joy([t], 100); time.sleep(.3)
emu.joy_release(); emu.post_run("output/dcanyon.bin"); time.sleep(4)
r = [v("msel")]
for t in "down down down up up up up".split():
    pulsa(t); r.append((v("msel"), v("dif")))
print("recorrido", r)
for _ in range(3): pulsa("down")
emu.pantalla(sys.argv[1] + "/salir.png")
print("en SALIR", v("msel"), "dif", v("dif"))
pulsa("fire"); time.sleep(2.5)
e = emu.estado()
pc = int(re.search(r"PC=(\w+)", e)[1], 16)
print("PC %04X (ROM: %s)" % (pc, 0x8000 <= pc < 0xC000))
print([l.strip() for l in e.splitlines() if "C004" in l or "voz" in l or "volumen" in l])
print(emu.http("/console.txt").decode("utf8", "replace")[-900:])
emu.pantalla(sys.argv[1] + "/monitor.png")
