"""Effetti sonori del gioco dal bundle Sonniss GDC 2024 (D-084).

Per ogni id di SfxLibrary una ricetta di strati: file sorgente (cercato per
nome dentro gli zip del bundle), taglio, intonazione, filtri, guadagno e
ritardo. Lo script estrae dai zip solo i file usati (cache fuori repo), mescola
gli strati con ffmpeg, porta il suono a un volume di riferimento (RMS con tetto
sul picco), applica le dissolvenze e scrive OGG mono 44,1 kHz in
godot/assets/audio/sfx/<id>.ogg. Riproducibile: stesse ricette, stessi file.

Uso:
    python -I tools/audio/build_sfx.py [--only id1,id2] [--preview]

--preview scrive anche output/audio/sfx_preview.wav: tutti i suoni in fila,
separati da mezzo secondo di silenzio, nell'ordine di RECIPES.

Licenza Sonniss: uso nel gioco libero, vietato ridistribuire i suoni come
suoni; i sorgenti restano fuori repo, nel repo solo il mix finale.
"""

import array
import math
import os
import subprocess
import sys
import wave
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BUNDLE_DIR = os.path.abspath(os.path.join(ROOT, "..", "Videogame-assets", "sonniss-gdc2024"))
CACHE_DIR = os.path.abspath(os.path.join(ROOT, "..", "Videogame-assets", "sonniss-cache"))
OUT_DIR = os.path.join(ROOT, "godot", "assets", "audio", "sfx")
PREVIEW_PATH = os.path.join(ROOT, "output", "audio", "sfx_preview.wav")

RATE = 44100
PEAK_CEILING_DB = -1.0
FADE_IN_S = 0.003
TAIL_FADE_S = 0.02
# Volume di riferimento: RMS sulla parte udibile. I suoni sintetizzati avevano
# picco 0,85 e RMS fra -9 e -13 dBFS; i volumi di RunAudio sono tarati su quelli.
DEFAULT_RMS_DB = -13.0


def L(src, start=0.0, dur=None, gain=0.0, pitch=0.0, delay=0.0, hp=None, lp=None, fade_in=None):
    """Uno strato. start: secondi, oppure "onset" (primo punto sopra -20 dB dal
    picco) o "peak" (finestra centrata sul punto piu forte, richiede dur).
    pitch in semitoni (cambia anche la durata, come un nastro)."""
    return {"src": src, "start": start, "dur": dur, "gain": gain, "pitch": pitch,
            "delay": delay, "hp": hp, "lp": lp, "fade_in": fade_in}


# id -> (strati, durata massima in secondi, dissolvenza finale in secondi, RMS di riferimento o None)
RECIPES = {
    # Interfaccia (D-081): brevi, metallici, mai oltre 0,25 s.
    "ui_move": ([L("tiny_gears_small_mechanism_click_003", 0.0, 0.05, pitch=2.0)], 0.06, 0.015, -16.0),
    "ui_confirm": ([L("UIClick_UI Click 33", 0.0, 0.08),
                    L("Metallic Bell_ 22", "onset", 0.16, gain=-9.0, pitch=12.0, delay=0.02)], 0.18, 0.08, -15.0),
    "ui_back": ([L("computer_button_013", 0.0, 0.11, pitch=-3.0)], 0.12, 0.04, -15.0),
    "ui_open": ([L("SlideMetal_02_CLOSED", 0.5, 0.4, pitch=7.0)], 0.24, 0.08, -15.0),
    # Combattimento.
    "nail_shot": ([L("Staple Gun", 0.12, 0.14),
                   L("Steam Release Short 03", 0.02, 0.09, gain=-9.0, hp=1500)], 0.13, 0.05, -12.0),
    "enemy_death": ([L("Drop Fall Metal Rattle Scrap Debris", 0.02, 0.15),
                     L("Big Cardboard Box Impact", 0.02, 0.13, gain=-3.0, lp=1800)], 0.14, 0.06, -13.0),
    "player_hurt": ([L("Noise_Punch_006", 0.08, 0.26),
                     L("Metal Shield Block Hits", 0.0, 0.26, gain=-5.0)], 0.26, 0.1, -11.0),
    "player_death": ([L("Drop Fall Metal Rattle Scrap Debris", 0.0, 0.75),
                      L("heavy_impact_011", 0.0, 0.5, gain=-3.0, delay=0.18),
                      L("HairDryerOnOff04", 14.0, 1.85, gain=-4.0, delay=0.1, lp=6000)], 1.95, 0.6, -13.0),
    "dash": ([L("Airy-Whoosh Wind Gust 11", "peak", 0.5, pitch=7.0)], 0.3, 0.12, -14.0),
    # Terreno: suonano ogni 0,25 s mentre si scolpisce.
    "terrain_dig": ([L("Skiing On Soft Snow 01", "peak", 0.26, pitch=-4.0, lp=5000),
                     L("Medium Rock Dropping 011", 0.0, 0.18, gain=-8.0)], 0.24, 0.08, -14.0),
    "terrain_raise": ([L("Big Cardboard Box Impact", 0.02, 0.2, lp=1500),
                       L("Flesh Drops on Floor 03", 0.0, 0.16, gain=-5.0, lp=3000),
                       L("Medium Rock Dropping 011", 0.0, 0.18, gain=-10.0, delay=0.03)], 0.28, 0.1, -13.0),
    "tool_reject": ([L("UI_Noisy_Impact_09", "onset", 0.25, pitch=-3.0)], 0.2, 0.07, -14.0),
    # Raccolta e spesa.
    "xp_pickup": ([L("Metallic Bell_ 22", "onset", 0.12, pitch=7.0)], 0.1, 0.06, -16.0),
    "scrap_pickup": ([L("stone_impact_steel_bar_01_010", 0.0, 0.13, pitch=2.0)], 0.13, 0.05, -13.0),
    "scrap_spend": ([L("tiny_gears_small_mechanism_click_complex_011", 0.0, 0.17)], 0.16, 0.04, -14.0),
    "carrier_pickup": ([L("TRS Cable Plug In Solid Metal Thump", 0.0, 0.26)], 0.25, 0.08, -13.0),
    # Progressione.
    "level_up": ([L("Feedback 36 up", 0.0, 0.5),
                  L("Metallic Bell_ 22", "onset", 0.9, gain=-6.0, delay=0.12)], 0.95, 0.4, -12.0),
    "upgrade_chosen": ([L("industrial_lever_switch_small_003", 0.0, 0.3)], 0.28, 0.08, -13.0),
    # Boss, eventi del livello.
    "boss_warning": ([L("Cinematic Horn_MWSFX_CF 05", 0.25, 2.0, fade_in=0.05)], 1.95, 0.7, -10.0),
    "boss_spawn": ([L("Haunted Metal Vol 1_60", 0.2, 1.6),
                    L("Heavy Mechanical Footsteps 03", 0.0, 0.8, gain=-2.0)], 1.6, 0.6, -10.0),
    "boss_demolish": ([L("heavy_impact_011", 0.0, 0.5),
                       L("Wood Crash And Debris 13", 0.0, 0.6, gain=-4.0)], 0.6, 0.25, -11.0),
    "boss_barricade": ([L("stone_impact_hammer_015", 0.0, 0.16),
                        L("Metal Impact-03", 0.06, 0.45, gain=-3.0),
                        L("Woodstove, Door, Iron, Close", 1.3, 0.2, gain=-4.0)], 0.5, 0.2, -11.0),
    "victory": ([L("Metallic Bell_ 22", "onset", 1.0, gain=-3.0),
                 L("80,TheGong", 0.08, 1.9, delay=0.05)], 1.95, 0.8, -11.0),
    "dusk": ([L("Tense Metallic Tone", 2.6, 1.8, fade_in=0.35, lp=4000)], 1.8, 0.7, -14.0),
    # Il primo richiamo pulito dell'allocco e a 7,3 s (fascia 400-800 Hz); il resto e vento.
    "nightfall": ([L("Many Tawny Owls", 7.3, 1.15, hp=250, lp=3000)], 1.15, 0.35, -13.0),
    "train_horn": ([L("Man Lions Coach - VAR SFX - Horn", 5.1, 0.85, pitch=-5.0)], 1.15, 0.25, -10.0),
    "driller_charge": ([L("Drill Burst, Rev, Mechanical Tool, Electric,_Jake Fielding_Drill_09", 0.15, 1.2, pitch=-4.0)], 1.45, 0.3, -11.0),
    # Armi (piano 5 di D-092): `w_<arma>_fire` allo sparo, `w_<arma>_hit` all'impatto.
    "w_seismic_stake_fire": ([L("Solid Metal Thump", "onset", 0.35, pitch=-5.0)], 0.3, 0.12, -12.0),
    "w_seismic_stake_hit": ([L("stone_impact_hammer_015", "onset", 0.35, pitch=-4.0),
                             L("Cabinet_Metal_Rumble", "peak", 0.6, gain=-6.0, lp=1500)], 0.55, 0.25, -11.0),
    "w_scrap_launcher_fire": ([L("pneumatic_chemical_weapon_black_smoke_001", "onset", 0.3, pitch=3.0, lp=6000)], 0.25, 0.1, -13.0),
    "w_scrap_launcher_hit": ([L("Metal Impact-03", "onset", 0.3),
                              L("Medium Rock Dropping 011", 0.0, 0.2, gain=-8.0)], 0.3, 0.12, -13.0),
    "w_dig_charge_fire": ([L("Cock Uncock Hammer", "onset", 0.15),
                           L("Steam Release Short 03", 0.02, 0.2, gain=-8.0, hp=1200)], 0.22, 0.08, -14.0),
    "w_dig_charge_hit": ([L("Medium Realistic Explosion 15", "onset", 0.9, lp=3500),
                          L("Medium Rock Dropping 011", 0.0, 0.25, gain=-6.0, delay=0.05)], 0.85, 0.35, -10.0),
    "w_welder_fire": ([L("electricity_surge_discharge_electrical_arc_crackling_002_01", "peak", 0.3)], 0.25, 0.1, -15.0),
    "w_crane_magnet_fire": ([L("Electromagnetic05", "onset", 0.6, pitch=-5.0, lp=3000)], 0.55, 0.25, -13.0),
    "w_crane_magnet_hit": ([L("Haunted Metal Vol 1_02", "onset", 0.4, lp=5000)], 0.4, 0.18, -12.0),
    "w_scythe_hit": ([L("Shears Slide Open Close", "onset", 0.18, pitch=3.0),
                      L("Dry Tree Branches Contact 024", "onset", 0.18, gain=-6.0, hp=800)], 0.18, 0.07, -15.0),
    "w_bramble_fire": ([L("Airy-Whoosh Wind Gust 11", "peak", 0.35, pitch=-4.0)], 0.3, 0.12, -15.0),
    "w_bramble_hit": ([L("WOODBrk_Snap09", "onset", 0.3),
                       L("Dry Tree Branches Contact 024", "onset", 0.4, gain=-4.0, delay=0.05)], 0.45, 0.18, -13.0),
    "w_site_blade_fire": ([L("Weapon 03 Slow Scrapes", "peak", 0.3, pitch=5.0, hp=600)], 0.25, 0.1, -15.0),
    "w_site_blade_hit": ([L("stone_impact_041", "onset", 0.2, pitch=4.0)], 0.18, 0.07, -15.0),
    "w_jackhammer_fire": ([L("Drill_22", "onset", 0.25, pitch=-6.0),
                           L("heavy_impact_011", "onset", 0.3, gain=-3.0)], 0.3, 0.12, -12.0),
    "w_ram_fire": ([L("WHOOSH PASS SF LOW", "peak", 0.5)], 0.45, 0.2, -13.0),
    "w_ram_hit": ([L("Cinematic Hit_MWSFX", "onset", 0.5, lp=4000)], 0.45, 0.2, -11.0),
    "w_cement_mixer_fire": ([L("texture_organic_liquid_005", "onset", 0.5, pitch=-3.0, lp=3000),
                             L("Big Cardboard Box Slide", "onset", 0.4, gain=-6.0, lp=2000)], 0.5, 0.2, -13.0),
    "w_cement_mixer_hit": ([L("stone_impact_015", "onset", 0.3, pitch=-2.0)], 0.3, 0.12, -13.0),
    "quake_rumble": ([L("Metal_Rails_Pack_Rumble", 2.2, 2.0, fade_in=0.15),
                      L("rock_collapse_earthquake_rumble_large_005", 0.19, 2.0, gain=-3.0, lp=2500)], 1.95, 0.7, -10.0),
}


def _index():
    entries = []
    for name in sorted(os.listdir(BUNDLE_DIR)):
        if not name.endswith(".zip"):
            continue
        with zipfile.ZipFile(os.path.join(BUNDLE_DIR, name)) as z:
            for info in z.infolist():
                if not info.is_dir() and info.filename.lower().endswith(".wav"):
                    entries.append((name, info.filename))
    return entries


_INDEX = None


def source_path(needle):
    """File sorgente in cache, estratto dal bundle alla prima richiesta."""
    global _INDEX
    os.makedirs(CACHE_DIR, exist_ok=True)
    cached = [f for f in os.listdir(CACHE_DIR) if needle.lower() in f.lower() and not f.endswith(".part")]
    if len(cached) == 1:
        return os.path.join(CACHE_DIR, cached[0])
    if _INDEX is None:
        _INDEX = _index()
    hits = [(z, n) for z, n in _INDEX if needle.lower() in os.path.basename(n).lower()]
    if len(hits) != 1:
        raise SystemExit(f"sorgente '{needle}': {len(hits)} corrispondenze nel bundle, ne serve una")
    zip_name, member = hits[0]
    dst = os.path.join(CACHE_DIR, os.path.basename(member))
    with zipfile.ZipFile(os.path.join(BUNDLE_DIR, zip_name)) as z, z.open(member) as src, open(dst + ".part", "wb") as out:
        out.write(src.read())
    os.replace(dst + ".part", dst)
    return dst


def decode(path, start=0.0, dur=None, filters=""):
    cmd = ["ffmpeg", "-v", "error", "-ss", f"{start:.4f}"]
    if dur is not None:
        cmd += ["-t", f"{dur:.4f}"]
    cmd += ["-i", path, "-ac", "1", "-ar", str(RATE)]
    if filters:
        cmd += ["-af", filters]
    cmd += ["-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    samples = array.array("f")
    samples.frombytes(raw[: len(raw) // 4 * 4])
    return samples


def envelope(samples, win=0.01):
    n = max(int(RATE * win), 1)
    return [math.sqrt(sum(v * v for v in samples[i:i + n]) / n) for i in range(0, max(len(samples) - n, 1), n)]


def find_start(path, mode, dur):
    env = envelope(decode(path))
    peak = max(env) or 1e-9
    if mode == "onset":
        for i, v in enumerate(env):
            if v > peak * 0.1:
                return max(i * 0.01 - 0.005, 0.0)
        return 0.0
    # "peak": finestra di durata dur centrata sul punto piu forte.
    i = env.index(peak)
    return max(i * 0.01 - dur / 2.0, 0.0)


def render_layer(layer):
    path = source_path(layer["src"])
    pitch = layer["pitch"]
    ratio = 2.0 ** (pitch / 12.0)
    start = layer["start"]
    if isinstance(start, str):
        start = find_start(path, start, (layer["dur"] or 0.5) * ratio)
    # Il taglio e espresso nel tempo del sorgente: con l'intonazione alzata si legge di piu.
    src_dur = None if layer["dur"] is None else layer["dur"] * ratio
    filters = []
    if pitch:
        filters.append(f"asetrate={RATE * ratio:.3f},aresample={RATE}")
    if layer["hp"]:
        filters.append(f"highpass=f={layer['hp']}")
    if layer["lp"]:
        filters.append(f"lowpass=f={layer['lp']}")
    samples = decode(path, start, src_dur, ",".join(filters))
    fade_in = layer["fade_in"] or FADE_IN_S
    _fade(samples, fade_in, 0.0)
    g = 10.0 ** (layer["gain"] / 20.0)
    pad = int(layer["delay"] * RATE)
    out = array.array("f", [0.0] * pad)
    out.extend(v * g for v in samples)
    return out


def _fade(samples, fade_in, fade_out):
    n_in = min(int(fade_in * RATE), len(samples))
    for i in range(n_in):
        samples[i] *= i / n_in
    n_out = min(int(fade_out * RATE), len(samples))
    for i in range(n_out):
        # Dissolvenza a coseno: la coda arriva a zero senza scatto.
        samples[len(samples) - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / n_out)


def build(sound_id):
    layers, max_dur, fade_out, rms_db = RECIPES[sound_id]
    rendered = [render_layer(l) for l in layers]
    length = min(max(len(r) for r in rendered), int(max_dur * RATE))
    mix = array.array("f", [0.0] * length)
    for r in rendered:
        for i in range(min(len(r), length)):
            mix[i] += r[i]
    _fade(mix, FADE_IN_S, max(fade_out, TAIL_FADE_S))
    peak = max(abs(v) for v in mix) or 1e-9
    loud = [v for v in mix if abs(v) > peak * 0.05] or list(mix)
    rms = math.sqrt(sum(v * v for v in loud) / len(loud)) or 1e-9
    target = rms_db if rms_db is not None else DEFAULT_RMS_DB
    gain = min(10.0 ** (target / 20.0) / rms, 10.0 ** (PEAK_CEILING_DB / 20.0) / peak)
    pcm = array.array("h", (int(max(-1.0, min(1.0, v * gain)) * 32767) for v in mix))
    stats = {
        "seconds": len(pcm) / RATE,
        "peak_db": 20 * math.log10(peak * gain),
        "rms_db": 20 * math.log10(rms * gain),
        "tail": abs(pcm[-1]),
    }
    return pcm, stats


def write_wav(path, pcm):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def write_ogg(path, pcm):
    tmp = path + ".tmp.wav"
    write_wav(tmp, pcm)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6",
                    "-map_metadata", "-1", path], check=True)
    os.remove(tmp)


def main(argv):
    only = None
    preview = "--preview" in argv
    for a in argv:
        if a.startswith("--only="):
            only = a.split("=", 1)[1].split(",")
    ids = [i for i in RECIPES if only is None or i in only]
    os.makedirs(OUT_DIR, exist_ok=True)
    gap = array.array("h", [0] * (RATE // 2))
    reel = array.array("h")
    failures = 0
    for sound_id in ids:
        pcm, s = build(sound_id)
        write_ogg(os.path.join(OUT_DIR, sound_id + ".ogg"), pcm)
        ok = 0.03 <= s["seconds"] <= 2.0 and s["peak_db"] <= PEAK_CEILING_DB + 0.05 and s["tail"] < 400
        failures += 0 if ok else 1
        print(f"{'ok  ' if ok else 'FAIL'} {sound_id:15s} {s['seconds']:.2f} s  picco {s['peak_db']:6.1f} dB  rms {s['rms_db']:6.1f} dB  coda {s['tail']}")
        reel.extend(pcm)
        reel.extend(gap)
    if preview:
        write_wav(PREVIEW_PATH, reel)
        print("anteprima:", PREVIEW_PATH)
    print(f"SFX_BUILD {'PASS' if failures == 0 else 'FAIL'} sounds={len(ids)} failures={failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
