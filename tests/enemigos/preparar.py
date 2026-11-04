#!/usr/bin/env python3
"""Activa o restaura el nivel de diagnóstico; no cambia las rutinas de IA."""
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
if len(sys.argv) != 2 or sys.argv[1] not in ('activar', 'restaurar'):
    sys.exit('Uso: python3 tests/enemigos/preparar.py activar|restaurar')
active = sys.argv[1] == 'activar'
source = HERE / ('mapa-test.txt' if active else 'nivel1-original.txt')
target = ROOT / 'levels/nivel1.txt'
# Evita sobrescribir ediciones posteriores del nivel sin advertirlo.
known = [(HERE / name).read_bytes() for name in ('mapa-test.txt', 'nivel1-original.txt')]
if target.read_bytes() not in known:
    sys.exit('nivel1.txt contiene cambios propios. Guárdalos antes de activar o restaurar.')
spec = importlib.util.spec_from_file_location('map2asm_test', ROOT / 'tools/map2asm.py')
converter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(converter)
# Validar el mapa antes de sustituir el nivel.
converter.convert(str(source), 1)
if active:
    converter.AI[0] = (1, 1)  # Los dos grupos persiguen; el generador original no se edita.
target.write_bytes(source.read_bytes())
converter.main()
print('TEST DE ENEMIGOS ACTIVO' if active else 'NIVEL ORIGINAL RESTAURADO')
print('Ejecuta make clean y luego make para reconstruir la ROM.')
