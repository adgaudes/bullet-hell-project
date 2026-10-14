"""Texture CC0 dei muri delle rovine (playtest del 14 ottobre 2026, O-10; D-090).

Scarica da Poly Haven (CC0) le mappe a 2K in tools/textures/third_party/ (ignorata da Git) e
scrive i fogli verticali degli array di godot/assets/textures/surfaces/ (strati da 1024,
lo strato 0 in alto), usati in triplanare da resources/materials/ruin_overgrown.gdshader:
  walls_albedo.png  RGB albedo
  walls_normal.png  RGB normal OpenGL
  walls_orm.png     R occlusione, G rugosita, B metallo (dalla mappa "arm" di Poly Haven)
Strati: 0 intonaco con mattoni a vista, 1 muschio, 2 mattoni grezzi, 3 calcestruzzo dei solai.
Sostituisce i fogli `walls` cotti da tools/blender/build_surface_tiles.py (che non va piu
rilanciato per `walls`). Poi: godot_console --headless --path godot --editor --quit.

  python -I tools/textures/fetch_wall_textures.py [--no-download]
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fetch_terrain_textures import RAW, ROOT, _get  # noqa: E402

import json  # noqa: E402

DST = ROOT / "godot" / "assets" / "textures" / "surfaces"
SIDE = 1024
LAYERS = ["damaged_plaster", "concrete_moss", "red_brick_plaster_patch_02", "concrete_floor_damaged_01"]
MAPS = {"color": "Diffuse", "normal": "nor_gl", "arm": "arm"}


def fetch(asset: str, out: Path) -> None:
    files = json.loads(_get(f"https://api.polyhaven.com/files/{asset}"))
    for name, key in MAPS.items():
        target = out / f"{name}.png"
        if not target.exists():
            target.write_bytes(_get(files[key]["2k"]["png"]["url"]))


def _load(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGB")
    return image.resize((SIDE, SIDE), Image.LANCZOS) if image.size != (SIDE, SIDE) else image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-download", action="store_true")
    args = parser.parse_args()
    sheets = {name: Image.new("RGB", (SIDE, SIDE * len(LAYERS))) for name in MAPS}
    for i, asset in enumerate(LAYERS):
        out = RAW / f"polyhaven_{asset}"
        out.mkdir(parents=True, exist_ok=True)
        if not args.no_download and not all((out / f"{n}.png").exists() for n in MAPS):
            print(f"FETCH polyhaven {asset}")
            fetch(asset, out)
        for name in MAPS:
            sheets[name].paste(_load(out / f"{name}.png"), (0, i * SIDE))
    sheets["color"].save(DST / "walls_albedo.png", optimize=True)
    sheets["normal"].save(DST / "walls_normal.png", optimize=True)
    sheets["arm"].save(DST / "walls_orm.png", optimize=True)
    print(f"PACKED walls layers={len(LAYERS)} side={SIDE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
