#!/usr/bin/env python3
"""emu.py - Arranca y controla el emulador EmuladorFpga6502 para las pruebas.

El emulador vive en otro repositorio y expone un servidor HTTP de depuracion
(puerto 8080) con la pantalla, la VRAM, la OAM, la RAM y los ciclos de CPU.

IMPORTANTE: el emulador necesita ventana (SDL2) y red local, asi que hay que
lanzarlo FUERA del sandbox y desacoplado del shell.

Uso desde linea de comandos:
    python tools/emu.py start        arranca y espera a que responda
    python tools/emu.py status       ¿esta vivo?
    python tools/emu.py stop         lo cierra
    python tools/emu.py run BIN      reinicia, carga en 0800 y ejecuta
    python tools/emu.py shot F.png   captura la pantalla
    python tools/emu.py state        volcado de /state.txt

Tambien se usa como modulo desde probar.py.
"""

import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

# Ruta del emulador (otro repositorio, no se versiona aqui).
EMU_DIR = os.environ.get("EMU_DIR", r"D:\Proyectos\EmuladorFpga6502")
EXE = os.path.join(EMU_DIR, "emulador.exe")
ROM = os.path.join(EMU_DIR, "rom", "monitor.bin")
SD = os.path.join(EMU_DIR, "tarjeta.img")
DEBUG_PORT = int(os.environ.get("EMU_DEBUG_PORT", "8080"))
UART_PORT = int(os.environ.get("EMU_UART_PORT", "4000"))

# Nombre 8.3 en la tarjeta SD.
# OJO: el emulador recorta a 8 caracteres de BASE (sin contar la extensión).
SD_NAME = "DCANYON.BIN"
LOAD_ADDR = 0x0800


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------
def http(path, timeout=5.0):
    url = "http://localhost:%d%s" % (DEBUG_PORT, path)
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return r.read()


def post_run(bin_path, name=SD_NAME, addr=LOAD_ADDR, timeout=20.0):
    """POST /run: reinicia, escribe el binario en la SD, LOAD y R en un paso."""
    url = "http://localhost:%d/run?name=%s&addr=%04X" % (DEBUG_PORT, name, addr)
    with open(bin_path, "rb") as f:
        data = f.read()
    req = urllib.request.Request(url, data=data, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def estado():
    """Devuelve el texto de /state.txt."""
    return http("/state.txt").decode("utf-8", "replace")


def joy(teclas=(), hold_ms=200):
    """Pulsa botones del joystick por HTTP (puerto 1).

    teclas: iterable de "up", "down", "left", "right", "fire".
    Con hold_ms=0 el boton queda apretado hasta joy_release().
    Devuelve el texto de respuesta del emulador.
    """
    if not teclas:
        return joy_release()
    lista = ",".join(teclas)
    ruta = "/joy?press=%s" % lista
    if hold_ms:
        ruta += "&hold=%d" % int(hold_ms)
    return http(ruta).decode("utf-8", "replace")


def joy_release():
    """Suelta todos los botones del joystick."""
    return http("/joy?release=1").decode("utf-8", "replace")


def ciclos():
    """Ciclos de CPU transcurridos desde el arranque del emulador."""
    for linea in estado().splitlines():
        if "ciclos:" in linea:
            return int(linea.split("ciclos:")[1].split()[0])
    return None


def ram(start, length):
    """Bytes de RAM crudos."""
    return http("/ram.bin?start=%d&len=%d" % (start, length), timeout=10.0)


def vram():
    """Tilemap, atributos y sprites en JSON."""
    import json
    return json.loads(http("/vram.json", timeout=10.0).decode("utf-8"))


def pantalla(png_path=None):
    """Captura PNG de la salida de video (320x240)."""
    data = http("/screen.png?scale=1", timeout=10.0)
    if png_path:
        with open(png_path, "wb") as f:
            f.write(data)
    return data


# ---------------------------------------------------------------------------
# Proceso
# ---------------------------------------------------------------------------
def _pids():
    if os.name != "nt":
        r = subprocess.run(["pgrep", "-f", "emulador"], capture_output=True, text=True)
        return r.stdout.split()
    r = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq emulador.exe", "/FO", "CSV", "/NH"],
        capture_output=True, text=True)
    out = []
    for linea in r.stdout.splitlines():
        partes = linea.split('","')
        if len(partes) > 1 and "emulador.exe" in partes[0]:
            out.append(partes[1].strip('"'))
    return out


def vivo():
    try:
        http("/state.txt", timeout=2.0)
        return True
    except Exception:
        return False


def start(timeout=20.0):
    """Lanza el emulador desacoplado y espera a que el HTTP responda."""
    if vivo():
        return True
    if not os.path.exists(EXE):
        raise RuntimeError("no encuentro el emulador en %s" % EXE)
    if _pids():
        # Proceso vivo pero HTTP sin responder: puede estar arrancando.
        return esperar(timeout)

    logdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build")
    os.makedirs(logdir, exist_ok=True)
    out_log = os.path.join(logdir, "emu.out.log")
    err_log = os.path.join(logdir, "emu.err.log")

    if os.name == "nt":
        # Start-Process + redirecciones: sin ellas el pipe se llena y bloquea.
        ps = (
            "Start-Process -FilePath '%s' -ArgumentList '%s','%d','%s','--debug=%d' "
            "-WorkingDirectory '%s' "
            "-RedirectStandardOutput '%s' -RedirectStandardError '%s' -WindowStyle Normal"
            % (EXE, ROM, UART_PORT, SD, DEBUG_PORT, EMU_DIR, out_log, err_log)
        )
        subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=False)
    else:
        subprocess.Popen([EXE, ROM, str(UART_PORT), SD, "--debug=%d" % DEBUG_PORT],
                         cwd=EMU_DIR, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    return esperar(timeout)


def esperar(timeout=20.0):
    fin = time.time() + timeout
    while time.time() < fin:
        if vivo():
            return True
        time.sleep(0.25)
    return False


def stop():
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/IM", "emulador.exe"],
                       capture_output=True, check=False)
    else:
        subprocess.run(["pkill", "-f", "emulador"], check=False)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]

    if cmd == "start":
        print("OK" if start() else "NO RESPONDE")
        return 0 if vivo() else 1
    if cmd == "stop":
        stop()
        print("parado")
        return 0
    if cmd == "status":
        print("vivo" if vivo() else "parado")
        return 0 if vivo() else 1
    if cmd == "run":
        if len(argv) < 3:
            print("falta el binario")
            return 2
        print(post_run(argv[2]).strip())
        return 0
    if cmd == "shot":
        pantalla(argv[2] if len(argv) > 2 else None)
        print("captura hecha")
        return 0
    if cmd == "state":
        print(estado())
        return 0

    print("comando desconocido: %s" % cmd)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
