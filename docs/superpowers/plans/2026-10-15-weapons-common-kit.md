# Armi e classi, piano 2: kit comune e fusioni — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le quattro armi comuni della spec D-092 (Lama da cantiere, Martello pneumatico, Ariete, Betoniera), ciascuna coi suoi quattro bivi, il sistema di fusione (carta Leggendaria, `WeaponLoadout.fuse`) e le due fusioni comuni (Ruspa a dischi, Costipatore).

**Architecture:** ogni arma e uno script in `scripts/combat/weapons/` su `Weapon` o `ActiveWeapon` (piano 1), con i valori in `WeaponCatalog`. Due servizi nuovi e piccoli: lo stordimento dei nemici (`Enemy.stun`, letto dal direttore) e la carica del giocatore (`PlayerCharacter.start_charge`). Una fusione non crea un nodo nuovo: l'automatica resta, riceve `fusion_id` e aggiunge il suo effetto; l'attiva compagna esce dagli slot.

**Tech Stack:** Godot 4.7.2, GDScript, suite headless, gate `tools/godot/Invoke-GodotChecks.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-15-weapons-classes-design.md` (par. 4.5, regole di fusione del par. 3, carta fusione del par. 6.3). Piano precedente: `docs/superpowers/plans/2026-10-15-weapons-foundation.md`.

## Global Constraints

- Valori di partenza dal par. 4.5 della spec, in `WeaponCatalog`; testi a schermo in italiano senza accenti tipografici.
- Scritture sul terreno solo da `TerrainWriteQueue`; una nuova arma va anche in `WeaponLoadout.script_for`.
- Nessuna scena `.tscn` modificata.
- Suite una alla volta; `--check-only` su ogni script toccato; `godot_console --headless --path godot --editor --quit` dopo ogni `class_name` nuova (e poi `git checkout godot/project.godot`, che l'editor riordina).
- Budget del par. 9: tutte le armi al massimo 1,0 ms per passo (benchmark Deck, riga `weapons`).
- Controller e tastiera equivalenti (le attive restano su E/F e LT/RB).

## Review Focus

1. Ariete contro un argine alto o un muro: la carica si ferma senza attraversarlo e senza restare incastrata; l'intoccabilita finisce comunque.
2. Ariete durante uno scatto o con la vita a zero: niente carica sovrapposta, niente carica da morto.
3. Stordimento e blocco sui boss (`self_driven`): nessun errore; i boss non si fermano.
4. Fusione con l'attiva compagna nello slot 1 e un'altra attiva nello slot 2: dopo la fusione la rimasta passa allo slot 1 e il tasto E la usa.
5. Lama e Betoniera fuori campo o su zona protetta: nessuna scrittura, nessun errore.

---

### Task 1: servizi — stordimento dei nemici e carica del giocatore

**Files:** Modify `godot/scripts/enemies/enemy.gd`, `godot/scripts/enemies/enemy_director.gd`, `godot/scripts/player/player_character.gd`. Test: `godot/tests/weapons_tests.gd` (casi nuovi), `godot/tests/player_tests.gd` (casi nuovi).

**Interfaces — Produces:**
- `Enemy.stun(seconds: float)`, `Enemy.stun_left: float` (il direttore moltiplica la velocita per 0 finche `stun_left > 0`; scala in `tick_visuals`; i `self_driven` lo ignorano).
- `PlayerCharacter.start_charge(direction: Vector3, distance: float, seconds: float) -> bool` (falso se morto, gia in carica o in scatto), `is_charging() -> bool`, segnale `charge_finished`, `grant_invulnerability(seconds: float)`; durante la carica `take_damage` non toglie vita.

- [ ] Test: un nemico stordito 0,5 s col giocatore vicino non si muove per 0,5 s e poi riparte; un boss (`self_driven`) chiamato `stun` non da errori.
- [ ] Test: `start_charge(FORWARD, 8, 0.5)` porta il giocatore circa 8 m avanti in 0,5 s su terreno piano, `is_charging()` vero durante e falso dopo, un colpo durante la carica non toglie vita, una seconda `start_charge` durante la prima restituisce falso; contro un muro la carica finisce entro il suo tempo.
- [ ] Eseguire: falliscono. Implementare. Eseguire: passano. Commit `Armi (D-092): stordimento dei nemici e carica del giocatore; test`.

### Task 2: catalogo del kit comune e sblocco provvisorio

**Files:** Modify `godot/scripts/combat/weapon_catalog.gd` (quattro voci, valori del par. 4.5; due voci `slot = &"fusion"` per Ruspa a dischi e Costipatore con `parts`), `godot/scripts/run/arena_run.gd` (`_unlocked_weapons()`), `godot/tests/weapon_catalog_tests.gd`.

- [ ] Test: ogni arma comune ha due bivi al 3 e al 5 e `unlock_cost > 0`; `WeaponCatalog.fusion_of(&"site_blade") == &"disc_dozer"`, `fusion_of(&"jackhammer") == &"compactor"`; le fusioni non compaiono fra le armi offribili (`slot == &"fusion"`).
- [ ] Sblocco provvisorio: finche l'Officina non le vende (piano 4), `ArenaRun._unlocked_weapons()` restituisce tutte le armi con `unlock_cost > 0`, cosi il kit comune si prova in partita. Commento con rimando al piano 4.
- [ ] Commit `Armi (D-092): catalogo del kit comune e delle fusioni comuni; sblocco provvisorio; test`.

### Task 3: Lama da cantiere

**Files:** Create `godot/scripts/combat/weapons/site_blade.gd`. Modify `weapon_loadout.gd` (`script_for`). Test: `weapons_tests.gd`.

Comportamento (par. 4.5): ogni `fire_interval` lancia un disco verso il nemico piu vicino entro `weapon_range` (in manuale dove guarda); il disco rotola a `projectile_speed`, segue la quota del terreno, accelera in discesa (fino a +50%), gira verso la discesa piu ripida; entrato in un fossato (delta < -0,5) ci resta fino a 3 s seguendo il fondo; colpisce ogni nemico una volta per disco. Bivi: Due lame (due dischi a ±15°), Lama dentata (raggio ×1,6, velocita ×0,7), Rimbalzo (sugli argini, fino a 3), Solco (`push_level` ogni 0,8 m verso quota -0,25, raggio 0,5). Dischi in `MultiMesh`.

- [ ] Test: liv. 1 un nemico a 5 m prende 2 danni; tre nemici in fila li prende tutti; su una pendenza il disco che scende arriva piu lontano di quello in piano nello stesso tempo; in un fossato scavato il disco resta dentro piu di 1 s; Due lame: due dischi per lancio; Rimbalzo: un disco contro un argine torna indietro; Solco: dopo il passaggio la quota sul percorso e scesa.
- [ ] Commit `Armi (D-092): Lama da cantiere coi bivi; test`.

### Task 4: Martello pneumatico

**Files:** Create `godot/scripts/combat/weapons/jackhammer.gd`. Modify `weapon_loadout.gd`. Test: `weapons_tests.gd`.

Comportamento: ogni `fire_interval` un'onda di raggio `wave_radius` attorno a chi spara: `damage` a ogni nemico, spinta di 6 m/s (`EnemyDirector.shove_from`); un nemico con un argine entro 1 m nella direzione della spinta (quota +0,6 m) prende danno doppio. Bivi: Onda larga (raggio 5), Stordente (stun 0,8 s), Crepe (tre crateri da 0,3 m, raggio 1, a 2 m), Eco nei fossati (colpisce anche i nemici entro 8 m che stanno in basso, delta < -0,4). Anello visivo che si allarga in 0,25 s.

- [ ] Test: nemici a 2 m prendono 1 danno e si allontanano; uno con un muro dietro prende 2; Onda larga colpisce a 4,5 m; Stordente ferma; Crepe abbassa il terreno attorno; Eco colpisce un nemico a 7 m dentro un fossato e non uno a 7 m in piano.
- [ ] Commit `Armi (D-092): Martello pneumatico coi bivi; test`.

### Task 5: Ariete

**Files:** Create `godot/scripts/combat/weapons/ram.gd`. Modify `weapon_loadout.gd`. Test: `weapons_tests.gd` (con un `PlayerCharacter` della scena di smoke test).

Comportamento: `trigger` avvia `start_charge` verso il punto di mira (`charge_distance` in 0,5 s); a ogni passo della carica i nemici entro 1,2 m non ancora colpiti prendono `damage` e sono spinti di lato; ogni metro mette in coda una spianata verso la base (raggio 1,2, forza 0,6). Bivi: Rincorsa (12 m), Scudo (1,5 s intoccabile all'arrivo), Trincea (scava a -0,6 invece di spianare), Botto (onda di raggio 3 all'arrivo, 3 danni). Senza giocatore capace di caricare (`start_charge` assente o falso) la ricarica non si consuma.

- [ ] Test: la carica sposta il giocatore e colpisce i nemici sul percorso (3 danni); spiana un dosso sul percorso; Trincea lascia il percorso sotto la base; Botto colpisce all'arrivo; Scudo rende intoccabile dopo l'arrivo; con lo scatto in corso non parte e non consuma la ricarica.
- [ ] Commit `Armi (D-092): Ariete coi bivi; test`.

### Task 6: Betoniera

**Files:** Create `godot/scripts/combat/weapons/cement_mixer.gd`. Modify `weapon_loadout.gd`. Test: `weapons_tests.gd`.

Comportamento: pozza di raggio `pool_radius` nel punto di mira; per `block_seconds` ogni nemico dentro e stordito (rinnovato a ogni passo, chi entra resta fermo); poi indurisce: dosso di `bump_height` (coda di scritture) e strato lastricato (`TerrainField.paint_layer`, `LAYER_SLABS`). Bivi: Doppia colata (due pozze affiancate), Muro di getto (dosso 1,2 m), Presa rapida (3 danni ai bloccati all'indurimento), Pavimento (spiana alla base invece del dosso). Disco grigio che si opacizza.

- [ ] Test: un nemico nella pozza resta fermo 3 s; dopo l'indurimento il centro e piu alto di 0,3 m; Muro di getto oltre 1,0 m; Pavimento riporta un dosso alla base; Presa rapida toglie 3 PV; Doppia colata due pozze.
- [ ] Commit `Armi (D-092): Betoniera coi bivi; test`.

### Task 7: fusioni — carta, `WeaponLoadout.fuse`, Ruspa a dischi, Costipatore

**Files:** Modify `weapon_loadout.gd` (`can_fuse`, `fuse`), `weapon.gd` (`fusion_id`, `fusion_stat`), `weapon_offers.gd` (carta `w:fusion:<auto>` Leggendaria), `run_progression.gd` (la fusione vince sempre il posto arma), `arena_run.gd` (scelta della carta, voce del HUD), `site_blade.gd` (effetto della Ruspa), `jackhammer.gd` (effetto del Costipatore). Test: `loadout_tests.gd`, `weapon_offers_tests.gd`, `weapons_tests.gd`, `run_progression_tests.gd`.

- [ ] Test: `can_fuse` vero solo con automatica e compagna al 5; `fuse` toglie l'attiva dagli slot (la seconda attiva passa allo slot 1), lascia l'automatica coi suoi bivi e `fusion_id`; la carta fusione e Leggendaria e quando c'e e sempre la prima; Ruspa: dischi di raggio doppio che spianano e un disco enorme ogni 10 s; Costipatore: ogni onda stordisce 0,6 s e ogni terza lascia un anello di cemento.
- [ ] Commit `Armi (D-092): fusioni (carta Leggendaria, WeaponLoadout.fuse), Ruspa a dischi e Costipatore; test`.

### Task 8: icone, benchmark, catture, documenti

**Files:** `ui_icon.gd` (sei icone: `blade`, `hammer`, `ram`, `mixer`, `dozer`, `compactor`), `benchmark_arena.gd` (caso peggiore con quattro armi comuni al 5 e una fusione), `capture_weapons.gd` (una cattura per arma e fusione), `simulate_runs.gd` (i bot accettano le fusioni), documenti (`MIGRATION_STATUS`, roadmap, `DECISIONS` D-092, `INDEX`, `GODOT_WORKFLOW`).

- [ ] Gate completo verde; benchmark sotto 1,0 ms; catture lette; documenti; commit `Armi (D-092): piano 2 chiuso; icone, benchmark, catture, documenti`.
