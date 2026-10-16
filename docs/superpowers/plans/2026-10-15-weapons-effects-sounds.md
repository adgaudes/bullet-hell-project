# Armi, piano 5: suoni ed effetti — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ogni arma del catalogo D-092 ha un suono suo allo sparo e all'impatto, ogni attiva un telegrafo a terra, ogni arma un effetto leggibile da 15 m di camera; Effekseer provato e adottato o scartato con misura.

**Architecture:** le armi chiedono un suono con un segnale della base `Weapon` (`sound_requested(kind)`); `WeaponLoadout` lo rilancia col proprio id e `RunAudio` suona `w_<arma>_<kind>` se esiste, con ripiego sui suoni di oggi. I campioni nascono dalle ricette di `tools/audio/build_sfx.py` (Sonniss, D-084). Il telegrafo e un nodo unico del loadout (`ActiveTelegraph`). Gli effetti restano nelle armi, con `DebrisBurst`, `CPUParticles3D` e mesh semplici; Effekseer entra solo se la prova lo giustifica.

**Tech Stack:** Godot 4.7.2 GDScript, Python 3 + ffmpeg per i suoni, bundle Sonniss GDC 2024 fuori repo.

**Stato (15 ottobre 2026):** task 1-3 fatti (`e4277c7`, `cd3ee10`, `8e77fe2`); task 4 fatto il 16 ottobre (`02277d4`..: effetti su 12 armi e 6 fusioni, suite `weapon_fx_tests`, catture `capture_weapons.gd -- --fx` in `output/weapons/fx/`, riga `weapons_frame` e `--no-fx` nel benchmark; costo: righe `weapons` entro +0,07 ms, 40 effetti vivi 0,064 ms per frame su desktop, headless); task 5 fatto il 16 ottobre: Effekseer misurato col preset Deck e **non adottato per le armi** (esito sotto il Task 5; branch locale `spike/effekseer`, `58f55fe`, tenuto per i boss); task 6 fatto il 16 ottobre (gate completo verde, review finale con correzioni: priorita del tetto per gli effetti minori, test della Calamita al rilascio, della Ruspa e senza direttore).

**Spec:** `docs/superpowers/specs/2026-10-15-weapons-classes-design.md` (par. "Effetti", "Suoni", ordine dei piani punto 5); D-095 per Effekseer.

## Global Constraints

- Budget armi: 1,0 ms per passo nel caso peggiore sul preset Deck (spec D-092); gli effetti non devono spostare il benchmark per classe oltre +0,15 ms.
- Effetti leggibili da 15 m di camera; colori di classe di `ClassCatalog`.
- Suoni: una ricetta per arma in `tools/audio/build_sfx.py`; sorgenti Sonniss fuori repo, nel repo solo l'OGG finale.
- Frequenti bassi e con intervallo minimo (`RunAudio.SOUND_SETTINGS`), come i suoni di oggi.
- Nessuna dipendenza nuova senza prova, misura, catture prima/dopo e registrazione in `docs/TOOLS_AND_LICENSES.md` (D-095).
- Controller e tastiera equivalenti; Windows e Steam Deck.

## Review Focus

- Molte armi che sparano insieme (cinque slot pieni): i suoni non devono coprire nemici e allarmi → limite di voci per id e priorita degli allarmi (`PROTECTED_IDS`); test in Task 1.
- Arma senza campione (fusione nuova, id mancante): nessun errore, ripiego sul suono generico → test in Task 1.
- Mira manuale col mouse fuori portata o cursore fuori dal terreno: il telegrafo resta al limite della portata, mai sotto i piedi → test in Task 3.
- Pausa e level-up: nessun suono ne telegrafo con l'albero in pausa → test in Task 3.
- Effekseer non compatibile con 4.7 o con l'export Linux: il gioco deve restare identico senza → Task 5 lavora su un branch e non tocca le armi finche non e deciso.

---

### Task 1: aggancio sonoro delle armi

**Files:**
- Modify: `godot/scripts/combat/weapon.gd` (segnale e helper)
- Modify: `godot/scripts/combat/weapon_loadout.gd` (rilancio con l'id)
- Modify: `godot/scripts/audio/run_audio.gd` (collegamento, ripiego, impostazioni)
- Modify: le 11 armi in `godot/scripts/combat/weapons/*.gd` e `auto_weapon.gd` (chiamate `_sound`)
- Test: `godot/tests/audio_tests.gd`

**Interfaces:**
- Produces: `Weapon.sound_requested(kind: StringName)` con `kind` in `&"fire"`, `&"hit"`; `Weapon._sound(kind)`; `WeaponLoadout.weapon_sound(id: StringName, kind: StringName)`; `RunAudio.weapon_sound_id(id, kind) -> StringName` (id del campione suonato, ripiego compreso).

- [x] **Step 1: test che falliscono** in `audio_tests.gd`, nuova `_test_weapon_sounds()`: per ogni arma non fusione del catalogo la si aggiunge al loadout, si emette `sound_requested(&"fire")` e si controlla che `RunAudio.play_count(weapon_sound_id(id, &"fire")) ` cresca; un id inesistente (`&"nobody"`) ripiega su `nail_shot` per `fire` e `terrain_raise` per `hit` senza errori; con l'albero in pausa nessun suono.
- [x] **Step 2:** eseguire `godot_console --headless --path godot --fixed-fps 60 --script res://tests/audio_tests.gd`: FAIL (segnale inesistente).
- [x] **Step 3: implementazione.**

```gdscript
# weapon.gd
## Suono chiesto dall'arma (piano 5): `&"fire"` allo sparo, `&"hit"` all'impatto.
signal sound_requested(kind: StringName)

func _sound(kind: StringName) -> void:
	sound_requested.emit(kind)
```

```gdscript
# weapon_loadout.gd, in add() dopo give_services(w):
	if not w.sound_requested.is_connected(_on_weapon_sound):
		w.sound_requested.connect(_on_weapon_sound.bind(w))

signal weapon_sound(id: StringName, kind: StringName)

func _on_weapon_sound(kind: StringName, w: Weapon) -> void:
	weapon_sound.emit(w.weapon_id, kind)
```

```gdscript
# run_audio.gd
const WEAPON_FALLBACK := {&"fire": &"nail_shot", &"hit": &"terrain_raise"}

static func weapon_sound_id(id: StringName, kind: StringName) -> StringName:
	var wanted := StringName("w_%s_%s" % [id, kind])
	return wanted if SfxLibrary.IDS.has(wanted) else WEAPON_FALLBACK.get(kind, &"nail_shot")

func _on_loadout_weapon_sound(id: StringName, kind: StringName) -> void:
	if get_tree().paused:
		return
	play(weapon_sound_id(id, kind))
```

  Collegare `loadout.weapon_sound` in `_connect_run` accanto a `weapon.fired`; la chiodatrice continua a suonare da `fired`. Nelle armi: `_sound(&"fire")` dove parte il colpo (in `_fire` delle attive, nel punto di sparo delle automatiche), `_sound(&"hit")` all'impatto o all'esplosione.
- [x] **Step 4:** audio_tests PASS; `--check-only` sui file toccati.
- [x] **Step 5:** commit "Armi, piano 5: aggancio sonoro".

### Task 2: ricette dei suoni delle armi

**Files:**
- Modify: `tools/audio/build_sfx.py` (ricette `w_<arma>_fire`, `w_<arma>_hit`)
- Modify: `godot/scripts/audio/sfx_library.gd` (`IDS`), `godot/scripts/audio/run_audio.gd` (`SOUND_SETTINGS`: volume, variazione d'intonazione, intervallo minimo)
- Create: `godot/assets/audio/sfx/w_*.ogg` (+ `.import` dopo `--editor --quit`)
- Test: `godot/tests/audio_tests.gd`

Armi: `seismic_stake`, `scrap_launcher`, `dig_charge`, `welder`, `crane_magnet`, `scythe`, `bramble`, `site_blade`, `jackhammer`, `ram`, `cement_mixer`; la chiodatrice resta `nail_shot`; le fusioni vivono dentro la loro automatica e ne usano i suoni. Carattere: Picchetto colpo sordo e anello che rimbomba; Lanciarottami tonfo pneumatico e lamiera che cade; Carica fuse corta e scoppio di terra; Saldatrice ronzio e scintille; Calamita ronzio grave e clangore; Falce fruscio d'erba tagliata; Roveto rami che scricchiolano; Lama strisciata metallica; Martello colpo pneumatico; Ariete spinta e urto; Betoniera tamburo e colata.

- [x] **Step 1: test che fallisce:** in `_test_library()` ogni arma non fusione del catalogo ha `w_<id>_fire` in `SfxLibrary.IDS` con campione (`has_sample`), durata fra 0,05 e 1,2 s, picco non nullo.
- [x] **Step 2:** FAIL.
- [x] **Step 3:** elencare i candidati del bundle con uno script nello scratchpad (nomi dei file negli zip per parola chiave: impact, metal, electric, swish, grass, crack, pneumatic, explosion), scrivere le ricette con `L(...)`, costruire con `python -I tools/audio/build_sfx.py --only <ids> --preview`, importare con `godot_console --headless --path godot --editor --quit`.
- [x] **Step 4:** audio_tests PASS; ascolto non possibile all'agente: dichiararlo e lasciare `output/audio/sfx_preview.wav` al proprietario.
- [x] **Step 5:** commit "Armi, piano 5: suoni delle armi".

### Task 3: telegrafo delle attive

**Files:**
- Create: `godot/scripts/combat/active_telegraph.gd`
- Modify: `godot/scripts/combat/weapon_loadout.gd` (crea il telegrafo, lo aggiorna)
- Test: `godot/tests/weapons_tests.gd`

**Interfaces:**
- Produces: `ActiveTelegraph.show_aim(at: Vector3, radius: float, color: Color)`, `flash(at, radius, color)`, `hide_aim()`; `WeaponLoadout.telegraph: ActiveTelegraph`.

Comportamento: con la mira manuale un anello piatto (mesh `TorusMesh` schiacciata, materiale unshaded, colore di classe al 70%) segue `aim_point()` della prima attiva carica, raggio = `stat(&"radius")` se esiste, altrimenti 1,5 m; alla partenza di un'attiva, in entrambe le mire, un lampo dell'anello di 0,35 s al punto colpito. Nessun anello con l'albero in pausa o senza attive.

- [x] **Step 1: test che falliscono:** con mira manuale e cursore finto oltre la portata l'anello sta entro `aim_range` dal giocatore; trigger → anello visibile per circa 0,35 s poi nascosto; in pausa nascosto; senza attive nessun nodo visibile.
- [x] **Step 2:** FAIL.
- [x] **Step 3:** implementare `ActiveTelegraph` (un `MeshInstance3D` per l'anello di mira e uno per il lampo; `_process` legge il loadout) e collegarlo in `WeaponLoadout._ready`.
- [x] **Step 4:** weapons_tests PASS.
- [x] **Step 5:** commit "Armi, piano 5: telegrafo delle attive".

### Task 4: effetti leggibili, arma per arma

**Files:** le armi in `godot/scripts/combat/weapons/*.gd`, `godot/scripts/combat/auto_weapon.gd`, `godot/scripts/fx/debris_burst.gd` se serve un parametro in piu. Test: `godot/tests/weapons_tests.gd` (ogni effetto nasce e si libera da solo), benchmark e catture.

Obiettivi dalla spec: rottami in parabola con scia (Lanciarottami); dischi che rotolano e lasciano polvere (Ruspa a dischi); anello d'onda a terra (Picchetto); archi elettrici spezzati (Saldatrice, Bobina di Tesla); falci con scia (Falce); anelli di argine che salgono con polvere (Betoniera, Fortino); crateri con detriti (Carica, Mortaio); cemento grigio che si opacizza (Betoniera); rovi a cespuglio (Roveto). Regola: ogni effetto e un `CPUParticles3D` one-shot o una mesh che si libera da sola, al piu 32 particelle, mai una luce dinamica per colpo.

- [x] **Step 1: test che fallisce:** per ogni arma, dopo uno sparo con nemici davanti, nella scena compare almeno un nodo d'effetto nel gruppo `weapon_fx` e dopo 2 s non ce n'e piu nessuno.
- [x] **Step 2:** FAIL per le armi senza effetto.
- [x] **Step 3:** un'arma alla volta: aggiungere l'effetto, mettere il nodo nel gruppo `weapon_fx`, catturare con `capture_weapons.gd -- --class=<id>` in `output/weapons/fx/`, guardare la cattura, correggere.
- [x] **Step 4:** weapons_tests PASS; `benchmark_arena.gd -- --class=<id>` per le quattro classi: righe `weapons` e `weapons_fused` entro +0,15 ms da oggi (0,18-0,65 ms).
- [x] **Step 5:** commit per gruppo (comune, Guastatore, Meccanico, Erbacciaia, Ingegnere).

### Task 5: prova di Effekseer (D-095)

**Files:** branch `spike/effekseer` (worktree proprio). Nessun file delle armi su `feature/arena-run` finche la prova non decide.

- [x] **Step 1:** controllare versione del plugin Godot 4 di Effekseer, compatibilita con 4.7.2 (GDExtension), export Windows e Linux, licenza MIT; se incompatibile annotare "valutato, non adottato" in `TOOLS_AND_LICENSES.md` e chiudere il task.
- [x] **Step 2:** se compatibile: un effetto (scoppio della Carica da scavo) in Effekseer accanto a quello in `CPUParticles3D`, catture affiancate, costo per 20 scoppi contemporanei col preset Deck.
- [x] **Step 3:** decisione: adottare (registrazione in `TOOLS_AND_LICENSES.md`, nota in `DECISIONS.md` D-095, trappole in `GODOT_WORKFLOW.md`) o scartare con le misure.
- [x] **Step 4:** commit della decisione sul branch di lavoro.

**Esito (16 ottobre 2026):** valutato, non adottato per le armi; misure in `TOOLS_AND_LICENSES.md` (Tool radar), nota in D-095. Il branch `spike/effekseer` resta locale per una prova futura sulle esplosioni dei boss.

### Task 6: chiusura

- [x] gate completo `tools/godot/Invoke-GodotChecks.ps1` verde;
- [x] catture finali in `output/weapons/fx/`, anteprima audio in `output/audio/sfx_preview.wav`;
- [x] `DECISIONS.md` (D-092: piano 5 fatto), `MIGRATION_STATUS.md`, roadmap, `INDEX.md` se nascono documenti;
- [x] commit.
