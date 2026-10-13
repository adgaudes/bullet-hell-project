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
import painter  # noqa: E402

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

# Stili sovrascrivibili per costruttore (D-088): con il fango solo in fondo un cubo rosso
# alto 1 m resta piu rosso (il fango e bruno) e senza macchie piu uniforme.
def mean_red(overrides):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = StaticBuilder(bake_size=128, bake_normal=False, bake_orm=False, style_overrides=overrides)
    b.box((1.0, 1.0, 1.0), (0.0, 0.0, 0.5), (0.8, 0.1, 0.1), paint=True)
    b.to_object("Style")
    px = bpy.data.images["Style_albedo"].pixels[:]
    reds = [r for r, a in zip(px[0::4], px[3::4]) if a > 0.5]
    return sum(reds) / max(1, len(reds))


default_red = mean_red(None)
clean_red = mean_red({"paint": {"mud_top": 0.06, "stain_floor": (1.0, 1.0, 1.0), "wear_amount": 0.0}})
check(clean_red > default_red + 0.03, "stili sovrascritti: meno fango e macchie (rosso %.3f -> %.3f)" % (default_red, clean_red))

# Normal dalla versione alta con gusci vicini (D-088): un tubo e un guscio spesso a 12 mm
# (cotti tutti insieme: 22 % di normali rovesciate dalla faccia interna del guscio). Ogni
# pezzo basso va cotto solo contro il suo alto, altrimenti i raggi colpiscono il guscio
# sbagliato e la normal esce rovesciata (blu < 0,5).
import sculpt  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)
lows, pairs = [], {}
def thicken(obj):
    """Spessore vero come gli abiti estratti: la faccia interna guarda il pezzo sotto."""
    modifier = obj.modifiers.new("Solidify", "SOLIDIFY")
    modifier.thickness = 0.01
    modifier.offset = 1.0
    sculpt._apply(obj, modifier)


for part, radius in enumerate((0.1, 0.112)):
    rings = [sculpt.Ring((0, 0, z), radius, radius, sides=10) for z in (0.0, 0.1, 0.2, 0.3)]
    low_part = sculpt.subdivide(sculpt.loft("Low%d" % part, rings, False, False), 1)
    high_part = sculpt.subdivide(sculpt.loft("High%d" % part, rings, False, False), 3)
    if part == 1:
        thicken(low_part)
        thicken(high_part)
    sculpt.fold_noise(high_part, lambda p: True, 0.002, 40.0, seed=part)
    lows.append(low_part)
    pairs[part] = [high_part]
mat = bpy.data.materials.new("pairs")
mat.use_nodes = True
for part, obj in enumerate(lows):
    sculpt.assign_material(obj, mat)
    painter.tag_part(obj, part)
bpy.ops.object.select_all(action="DESELECT")
for obj in lows:
    obj.select_set(True)
bpy.context.view_layer.objects.active = lows[0]
bpy.ops.object.join()
joined = bpy.context.view_layer.objects.active
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(island_margin=0.01)
bpy.ops.object.mode_set(mode="OBJECT")
normal_image = painter.new_normal_image("Pairs_normal", 256)
bake_settings = bpy.context.scene.render.bake
bake_settings.margin, bake_settings.cage_extrusion, bake_settings.max_ray_distance = 12, 0.0, 0.0
painter.bake_normal_pairs(joined, pairs, normal_image)
# Le cotture successive (albedo, ORM) devono ritrovare le impostazioni di prima: un margine
# rimasto a 3 px lasciava cuciture scure nelle mip dell'Ingegnere.
check((bake_settings.margin, bake_settings.cage_extrusion, bake_settings.max_ray_distance) == (12, 0.0, 0.0),
      "bake_normal_pairs rimette margine, estrusione e raggio (%d, %.2f, %.2f)"
      % (bake_settings.margin, bake_settings.cage_extrusion, bake_settings.max_ray_distance))
px = normal_image.pixels[:]
blues = [b for r, g, b in zip(px[0::4], px[1::4], px[2::4]) if not (abs(r - 0.5) < 0.01 and abs(g - 0.5) < 0.01)]
flipped = sum(1 for b in blues if b < 0.5)
check(len(blues) > 100 and flipped <= 0.02 * len(blues), "normal per coppie: rovesciati %d su %d" % (flipped, len(blues)))

print("PAINTER_SELFTEST %s failures=%d" % ("PASS" if failures == 0 else "FAIL", failures))
sys.exit(1 if failures else 0)
