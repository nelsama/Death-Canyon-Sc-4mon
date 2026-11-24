"""Las explosiones no se mueven respecto al terreno (fx_y + sc_y constante)."""
import re, sys, time
import emu
DBG = {}
for l in open("output/turbo/dcanyon.dbg"):
    m = re.search(r'name="(\w+)".*val=0x([0-9A-F]+).*type=lab', l)
    if l.startswith("sym") and m:
        DBG[m[1]] = int(m[2], 16)
emu.post_run("output/turbo/dcanyon.bin"); time.sleep(4)
emu.joy(["fire"], 0); lado = 0
H = {}
pares, peor, mov, ant, t0 = 0, 0, 0, None, time.time()
while time.time() - t0 < 40:
    if time.time() - lado > 1.1:
        lado = time.time(); emu.joy_release(); emu.joy([("left", "right")[int(lado) % 2], "fire"], 0)
    M = emu.ram(0, 0x4800)                  # una sola lectura: coherente
    s0 = M[DBG["sc_y"]]
    f = [M[DBG[n]:DBG[n] + 4] for n in ("fx_x", "fx_y", "fx_n", "fx_g")]
    if ant:
        for i in range(4):
            n0, n1 = ant[1][2][i], f[2][i]
            if n0 > n1 > 0 and ant[1][0][i] == f[0][i] and f[3][i]:
                d = ((f[1][i] + s0) - (ant[1][1][i] + ant[0]) + 128) % 256 - 128
                H[d] = H.get(d, 0) + 1; pares += 1; peor = max(peor, abs(d)); mov += f[1][i] != ant[1][1][i]
    ant = (s0, f)
emu.joy_release()
print(sorted(H.items()))
print("comparaciones", pares, "con scroll", mov, "desvio maximo", peor, "px")
sys.exit(not (mov and H.get(0, 0) > 0.8 * pares and abs(sum(k * n for k, n in H.items())) <= 0.05 * pares))
