"""Texture CC0 del terreno (playtest del 14 ottobre 2026, O-08; rosa in docs/ART/ASSET_SHORTLIST_2026-10-14.md).

Scarica da Poly Haven e ambientCG (entrambi CC0) le mappe a 2K (ridotte a 1024: dalla camera si vedono circa 40 px/m) in tools/textures/third_party/
(ignorata da Git) e le impacchetta per Terrain3D in godot/assets/textures/terrain/:
  <strato>_albedo_height.png  RGB albedo, A altezza (displacement)
  <strato>_normal_rough.png   RGB normal OpenGL, A rugosita
Poi in Godot: godot_console --headless --path godot --editor --quit (genera gli .import VRAM).

  python -I tools/textures/fetch_terrain_textures.py [--only nome,...] [--no-download]
"""

import argparse
import http.client
import io
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "tools" / "textures" / "third_party"
DST = ROOT / "godot" / "assets" / "textures" / "terrain"
SIDE = 1024
UA = {"User-Agent": "Dwarmageddon-texture-fetch/1.0"}

# strato -> (fonte, id). L'ordine dei primi cinque e quello di TerrainSurface.LAYERS.
LAYERS = {
    "dirt": ("ambientcg", "Ground037"),
    "slabs": ("ambientcg", "PavingStones149"),
    "asphalt": ("polyhaven", "asphalt_02"),
    "dug_soil": ("ambientcg", "Ground104"),
    "mud": ("polyhaven", "brown_mud_leaves_01"),
    "rubble": ("polyhaven", "concrete_debris"),
    "gravel": ("ambientcg", "Gravel040"),
}


def _get(url: str, attempts: int = 4) -> bytes:
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as r:
                return r.read()
        except (OSError, http.client.HTTPException) as error:
            if attempt == attempts - 1:
                raise
            print(f"RETRY {url} ({error.__class__.__name__})")


def fetch_polyhaven(asset: str, out: Path) -> None:
    files = json.loads(_get(f"https://api.polyhaven.com/files/{asset}"))
    for key, name in (("Diffuse", "color"), ("nor_gl", "normal"), ("Rough", "rough"), ("Displacement", "height")):
        target = out / f"{name}.png"
        if not target.exists():
            target.write_bytes(_get(files[key]["2k"]["png"]["url"]))


def fetch_ambientcg(asset: str, out: Path) -> None:
    data = _get(f"https://ambientcg.com/get?file={asset}_2K-PNG.zip")
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for info in z.infolist():
            low = info.filename.lower()
            for suffix, name in (("_color.png", "color"), ("_normalgl.png", "normal"), ("_roughness.png", "rough"), ("_displacement.png", "height")):
                if low.endswith(suffix):
                    (out / f"{name}.png").write_bytes(z.read(info))


def _load(path: Path, mode: str) -> Image.Image:
    image = Image.open(path)
    if image.mode in ("I;16", "I;16B", "I"):
        image = image.point(lambda v: v / 256.0).convert("L") if mode == "L" else image.convert(mode)
    image = image.convert(mode)
    if image.size != (SIDE, SIDE):
        image = image.resize((SIDE, SIDE), Image.LANCZOS)
    return image


def _normalized(image: Image.Image) -> Image.Image:
    lo, hi = image.getextrema()
    span = max(hi - lo, 1)
    return image.point(lambda v: (v - lo) * 255 // span)


def pack(layer: str, src: Path) -> None:
    color = _load(src / "color.png", "RGB")
    normal = _load(src / "normal.png", "RGB")
    rough = _load(src / "rough.png", "L")
    height = _normalized(_load(src / "height.png", "L"))
    albedo_height = Image.merge("RGBA", (*color.split(), height))
    normal_rough = Image.merge("RGBA", (*normal.split(), rough))
    DST.mkdir(parents=True, exist_ok=True)
    albedo_height.save(DST / f"{layer}_albedo_height.png", optimize=True)
    normal_rough.save(DST / f"{layer}_normal_rough.png", optimize=True)
    print(f"PACKED {layer} <- {src.name}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    parser.add_argument("--no-download", action="store_true")
    args = parser.parse_args()
    only = [n for n in args.only.split(",") if n]
    for layer, (source, asset) in LAYERS.items():
        if only and layer not in only:
            continue
        out = RAW / f"{source}_{asset}"
        out.mkdir(parents=True, exist_ok=True)
        if not args.no_download and not all((out / f"{n}.png").exists() for n in ("color", "normal", "rough", "height")):
            print(f"FETCH {source} {asset}")
            (fetch_polyhaven if source == "polyhaven" else fetch_ambientcg)(asset, out)
        missing = [n for n in ("color", "normal", "rough", "height") if not (out / f"{n}.png").exists()]
        if missing:
            print(f"FAIL {layer} missing={missing}")
            return 1
        pack(layer, out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
