"""Autoverifica di sculpt.py (D-088). Eseguire:
    blender -b --factory-startup --python tools/blender/selftest_sculpt.py
Stampa `SCULPT_SELFTEST PASS|FAIL failures=N` ed esce con 1 se fallisce."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)

import sculpt  # noqa: E402

failures = 0


def check(condition, label):
    global failures
    if condition:
        print("  ok   %s" % label)
    else:
        failures += 1
        print("  FAIL %s" % label)


# Corpo da grafo: tre nodi in fila con un ramo, chiuso e a quadrilateri.
body = sculpt.skin_body("Body", [((0, 0, 0.5), 0.2), ((0, 0, 1.0), 0.25), ((0, 0, 1.4), 0.15), ((0.4, 0, 1.0), 0.08)],
                        [(0, 1), (1, 2), (1, 3)])
stats = sculpt.mesh_stats(body)
check(stats["boundary_edges"] == 0, "skin_body: mesh chiusa (%d bordi aperti)" % stats["boundary_edges"])
check(all(len(p.vertices) == 4 for p in body.data.polygons), "skin_body: solo quadrilateri")
zs = [v.co.z for v in body.data.vertices]
check(min(zs) < 0.55 and max(zs) > 1.3, "skin_body: copre i nodi (z %.2f..%.2f)" % (min(zs), max(zs)))

# Loft: 4 anelli da 8 lati con le due chiusure = 3*8 quadrilateri + 2*8 triangoli.
rings = [sculpt.Ring((0, 0, z), 0.1, 0.1, sides=8) for z in (0.0, 0.1, 0.2, 0.3)]
tube = sculpt.loft("Tube", rings)
check(len(tube.data.polygons) == 3 * 8 + 2 * 8, "loft: %d facce (attese 40)" % len(tube.data.polygons))
check(sculpt.mesh_stats(tube)["boundary_edges"] == 0, "loft: chiuso")
side = sculpt.loft("Side", [sculpt.Ring((x, 0, 0), 0.05, 0.08, axis="x", sides=8) for x in (0.0, 0.2)])
ys = [v.co.y for v in side.data.vertices]
zs = [v.co.z for v in side.data.vertices]
check(abs(max(ys) - 0.05) < 1e-4 and abs(max(zs) - 0.08) < 1e-4, "Ring asse x: rx lungo Y, ry lungo Z")

# Anello perpendicolare a una direzione qualsiasi (tubi lungo un percorso curvo).
slant = sculpt.Ring((0, 0, 0), 0.1, 0.1, axis=(1.0, 1.0, 0.0), sides=8)
direction = Vector((1.0, 1.0, 0.0)).normalized()
check(all(abs((p - slant.center).dot(direction)) < 1e-6 and abs((p - slant.center).length - 0.1) < 1e-6
          for p in slant.points()), "Ring su asse obliquo: punti sul piano perpendicolare, a distanza r")
path = sculpt.tube("Path", [(0, 0, 0), (0.2, 0, 0.1), (0.4, 0.1, 0.1)], [0.03, 0.04, 0.02], sides=8)
check(sculpt.mesh_stats(path)["boundary_edges"] == 0 and len(path.data.polygons) == 2 * 8 + 2 * 8,
      "tube: tubo chiuso lungo un percorso (%d facce)" % len(path.data.polygons))

# Suddivisione: quadruplica i quadrilateri a ogni livello.
before = len(body.data.polygons)
sculpt.subdivide(body, 1)
check(len(body.data.polygons) == before * 4, "subdivide: %d -> %d facce" % (before, len(body.data.polygons)))

# Pennelli: muovono solo dentro il raggio, in modo deterministico.
far_before = {v.index: v.co.copy() for v in body.data.vertices if (v.co - Vector((0, 0, 1.0))).length > 0.5}
front_before = min(v.co.y for v in body.data.vertices)
sculpt.grab(body, (0, 0, 1.0), 0.5, (0, -0.1, 0))
moved_far = sum(1 for i, co in far_before.items() if (body.data.vertices[i].co - co).length > 1e-6)
check(moved_far == 0, "grab: nessun vertice fuori raggio spostato (%d)" % moved_far)
front = min(v.co.y for v in body.data.vertices)
check(front < front_before - 0.05, "grab: la pancia esce davanti (y min %.3f -> %.3f)" % (front_before, front))
copy_a = sculpt.loft("A", rings)
copy_b = sculpt.loft("B", rings)
sculpt.fold_noise(copy_a, lambda p: True, 0.01, 8.0, seed=3)
sculpt.fold_noise(copy_b, lambda p: True, 0.01, 8.0, seed=3)
check(all((a.co - b.co).length < 1e-9 for a, b in zip(copy_a.data.vertices, copy_b.data.vertices)),
      "fold_noise: deterministico a parita di seme")
check(any(True for a, r in zip(copy_a.data.vertices, sculpt.loft("C", rings).data.vertices) if (a.co - r.co).length > 1e-5),
      "fold_noise: sposta davvero i vertici")
radius_before = max(Vector((v.co.x, v.co.y)).length for v in tube.data.vertices if abs(v.co.z - 0.1) < 1e-4)
sculpt.inflate(tube, (0.1, 0, 0.1), 0.06, 0.02)
radius_after = max(Vector((v.co.x, v.co.y)).length for v in tube.data.vertices if abs(v.co.z - 0.1) < 0.01)
check(radius_after > radius_before + 0.015, "inflate: l'anello si allarga (%.3f -> %.3f)" % (radius_before, radius_after))
line = sculpt.loft("Line", [sculpt.Ring((0, 0, z), 0.1, 0.1, sides=16) for z in (0.0, 0.05, 0.1, 0.15, 0.2)])
sculpt.crease_line(line, [(0.1, 0, 0.0), (0.1, 0, 0.2)], 0.03, 0.01)
check(min(v.co.x for v in line.data.vertices if abs(v.co.y) < 0.01 and v.co.x > 0) < 0.095,
      "crease_line: il solco rientra lungo la linea")

# Suole: i vertici sotto il terreno salgono sul piano, quelli sopra non si muovono.
sole = sculpt.loft("Sole", [sculpt.Ring((0, 0, z), 0.1, 0.1, sides=8) for z in (-0.05, 0.05, 0.15)])
above = {v.index: v.co.copy() for v in sole.data.vertices if v.co.z >= 0.0}
sculpt.flatten_below(sole, 0.0)
check(min(v.co.z for v in sole.data.vertices) >= -1e-6, "flatten_below: niente sotto il piano")
check(all((sole.data.vertices[i].co - co).length < 1e-9 for i, co in above.items()), "flatten_below: il resto non si muove")

# Abiti estratti: solo le facce scelte, spessore vero.
shell = sculpt.extract_shell(body, "Shirt", lambda p: 0.8 < p.z < 1.2, 0.01, 0.01)
zs = [v.co.z for v in shell.data.vertices]
check(min(zs) > 0.7 and max(zs) < 1.3, "extract_shell: solo la fascia scelta (z %.2f..%.2f)" % (min(zs), max(zs)))
check(sculpt.mesh_stats(shell)["boundary_edges"] == 0, "extract_shell: lo spessore chiude il guscio")

# Colore per angolo: set_color riempie, tint scalda solo vicino al centro.
sculpt.set_color(tube, (0.2, 0.3, 0.8))
sculpt.tint(tube, (0.1, 0, 0.3), 0.05, (1.0, 0.0, 0.0), 1.0)
cols = tube.data.color_attributes["Col"].data
reds = [c.color[0] for c in cols]
check(min(reds) < 0.21 and max(reds) > 0.9, "tint: rosso solo vicino al centro (%.2f..%.2f)" % (min(reds), max(reds)))

# Grafo vero dell'Ingegnere (regressione): lo Skin lasciava 4 buchi attorno alla pancia.
# In fondo: Skeleton() cancella gli oggetti della scena.
from build_engineer import ENGINEER_PROPORTIONS, Skeleton, _body_graph  # noqa: E402

skeleton = Skeleton(ENGINEER_PROPORTIONS)
real = sculpt.skin_body("RealBody", *_body_graph(skeleton))
check(sculpt.mesh_stats(real)["boundary_edges"] == 0, "skin_body: corpo dell'Ingegnere chiuso (%d bordi aperti)"
      % sculpt.mesh_stats(real)["boundary_edges"])

print("SCULPT_SELFTEST %s failures=%d" % ("PASS" if failures == 0 else "FAIL", failures))
sys.exit(1 if failures else 0)
