# CLAUDE.md — Death Canyon

Leer `PLAN.md` antes de tocar código.

- Plataforma (sólo consulta): `D:\Proyectos\fpga-6502-16k`,
  `D:\Proyectos\monitor_6502_TN-9k_16k`.
- Emulador: `D:\Proyectos\EmuladorFpga6502`.
- Toolchain: `D:\cc65\bin`, `D:\make\bin`; `make` desde Git Bash.
- Comentarios, documentación y respuestas en español.
- Fase a fase, con luz verde explícita del usuario.
- Diagnosticar midiendo (RAM, OAM, tilemap). Todo el estado se inicializa en
  `reset`: la RAM no se borra.
- Vídeo sólo en VBLANK y esperando `VIDEO_READY`; un único módulo escribe VRAM.
- Juego original: ver «Reglas de originalidad» en `PLAN.md`.
