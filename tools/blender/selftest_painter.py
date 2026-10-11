"""Selftest del pittore (Task 1 del restyling): cuoce un cubo e un cilindro a 256 px e
controlla che esistano le tre immagini (albedo, normal, ORM), che non siano nere, che la
roughness dell'ORM sia in un intervallo sensato e che il Principled finale legga ORM e normal.

    blender -b --factory-startup --python tools/blender/selftest_painter.py

Esce con 1 se fallisce. Stampa `PAINTER_SELFTEST PASS|FAIL failures=N`.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)

from refined import StaticBuilder  # noqa: E402

failures = 0


def check(condition, label):
    global failures
    if condition:
        print("  ok   %s" % label)
    else:
        failures += 1
        print("  FAIL %s" % label)


builder = StaticBuilder(bake_size=256, bake_normal=True, bake_orm=True)
builder.box((1.0, 1.0, 1.0), (0.0, 0.0, 0.5), (0.8, 0.3, 0.2), paint=True)
builder.cyl(0.2, 0.6, (0.0, 0.0, 1.3), (0.5, 0.5, 0.5))
builder.sphere(0.12, (0.0, 0.0, 1.75), (1.0, 0.9, 0.6), emit=True)
obj = builder.to_object("SelfTest")

for suffix, colorspace in (("_albedo", "sRGB"), ("_normal", "Non-Color"), ("_orm", "Non-Color")):
    image = bpy.data.images.get("SelfTest" + suffix)
    check(image is not None, "esiste l'immagine %s" % suffix)
    if image is None:
        continue
    check(image.size[0] == 256 and image.size[1] == 256, "%s e 256x256" % suffix)
    check(image.colorspace_settings.name == colorspace, "%s in spazio colore %s" % (suffix, colorspace))
    pixels = image.pixels[:]
    check(max(pixels) > 0.0, "%s non e nera" % suffix)

orm = bpy.data.images.get("SelfTest_orm")
if orm is not None:
    px = orm.pixels[:]
    greens = px[1::4]
    alphas = px[3::4]
    covered = [g for g, a in zip(greens, alphas) if a > 0.5]
    mean_rough = sum(covered) / max(1, len(covered))
    check(0.3 < mean_rough < 0.95, "roughness media dell'ORM sensata (%.2f)" % mean_rough)

for mat_name, kind in (("paint", "paint"), ("gear", "gear")):
    mat = bpy.data.materials[mat_name]
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    check(bsdf is not None, "%s ha un Principled finale" % mat_name)
    if bsdf is not None:
        check(bsdf.inputs["Roughness"].is_linked, "%s: Roughness collegata all'ORM" % mat_name)
        check(bsdf.inputs["Metallic"].is_linked, "%s: Metallic collegata all'ORM" % mat_name)
        check(bsdf.inputs["Normal"].is_linked, "%s: Normal collegata alla normal map" % mat_name)
        check(bsdf.inputs["Base Color"].is_linked, "%s: Base Color collegata all'albedo" % mat_name)

lamp = bpy.data.materials["lamp"]
lamp_bsdf = next((n for n in lamp.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
check(lamp_bsdf is not None and lamp_bsdf.inputs["Emission Color"].is_linked, "lamp: emissiva dalla texture")

check(obj is not None and len(obj.data.polygons) > 0, "l'oggetto unito ha facce")

print("PAINTER_SELFTEST %s failures=%d" % ("PASS" if failures == 0 else "FAIL", failures))
sys.exit(1 if failures else 0)
