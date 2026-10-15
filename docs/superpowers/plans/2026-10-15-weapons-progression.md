# Armi e classi, piano 4: casse, Officina, classe, profilo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** come si ottengono le armi fuori dal level-up (spec D-092, par. 6): profilo versione 2, Officina a sezioni con lo sblocco delle armi comuni, gli upgrade di classe e il ricettario delle fusioni, scelta della classe nella campagna, casse sepolte che si aprono scavando.

**Architecture:** tutto cio che si compra in Officina resta una voce di `PermanentCatalog` (lo sblocco di un'arma e una voce `unlock_<arma>` a un livello, generata da `WeaponCatalog.unlock_cost`), quindi profilo, salvataggio e pannello trattano un solo tipo di acquisto. Il profilo aggiunge le fusioni scoperte (`[recipes]`) e l'ultima classe (`last_class`). Gli upgrade permanenti di classe valgono solo giocando quella classe. Le casse sono un nodo nuovo (`BuriedCaches`) che segue lo scavo come le vene di `ScrapField`; l'apertura riusa `LevelUpMenu`.

**Tech Stack:** Godot 4.7.2, GDScript, suite headless, gate `tools/godot/Invoke-GodotChecks.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-15-weapons-classes-design.md` (par. 6.1, 6.2, 6.3 "Casse sepolte", 6.4, 7 "Officina" e "Campagna", 8 `PlayerProfileService` e `BuriedCaches`). Piani precedenti: `2026-10-15-weapons-foundation.md`, `-common-kit.md`, `-classes.md`.

## Global Constraints

- Costi provvisori della spec (par. 6.2); testi italiani senza accenti tipografici.
- Un profilo versione 1 si carica coi valori di default per le novita e mantiene rottami, livelli dei permanenti, livelli sbloccati e completati; le chiavi sconosciute restano conservate (come oggi).
- Controller e tastiera/mouse equivalenti, controller prioritario: schede dell'Officina con LB/RB e PagSu/PagGiu (come le Impostazioni, D-091); A conferma, B torna.
- Nessuna scena `.tscn` modificata (i pannelli si costruiscono da codice come oggi).
- Script che si riferiscono al proprio `class_name` vietati (trappola del piano 3: perdite all'uscita).
- Suite una alla volta; `--check-only` sugli script toccati; `--editor --quit` dopo ogni `class_name` nuova, poi `git checkout godot/project.godot`.

## Scelte di questo piano (da registrare in D-092)

- **Sblocchi come permanenti:** la spec chiede una sezione `[weapons]` del profilo; qui lo sblocco e la voce `unlock_<arma>` in `[upgrades]` (livello 1 = sbloccata). Un solo meccanismo di acquisto, salvataggio e recupero.
- **Classi e permanenti:** gli upgrade di una classe si applicano solo giocando quella classe; la Torretta fissa passa al Meccanico (spec), quindi un Ingegnere che l'aveva comprata non la monta piu.
- **Cassa senza carte possibili:** se nessuna carta arma e possibile (slot pieni e tutto al 5), la cassa da 2 rottami al compagno (o li lascia a terra) e un avviso.
- **Cassa e scavo:** la cassa sta alla quota di base sotto un cumulo (vene di rottami) o un vagone; esce quando il suolo nel suo punto scende entro 0,1 m dalla base, come l'estrazione delle vene.

## Review Focus

1. Cassa aperta mentre e gia aperto un level-up (o il contrario, o due casse nello stesso passo): nessuna carta persa, nessun conteggio sbagliato; il gioco riparte solo quando non c'e piu niente da scegliere.
2. Bivio scelto da una cassa: la seconda schermata (trasformazioni) consuma la cassa, non un level-up.
3. Profilo versione 1 con la Torretta fissa comprata: si carica, la voce resta, il Meccanico la monta.
4. Mappa della campagna col controller: dopo la scelta del livello si arriva alle quattro classi, B torna ai livelli (non al menu), A avvia; l'ultima classe resta preselezionata alla volta dopo.
5. Officina: lo sblocco di un'arma comprato compare subito nelle carte della run successiva; una classe non vede negli slot armi di un'altra classe anche se sbloccate.

---

### Task 1: profilo versione 2 e catalogo dell'Officina

**Files:** Modify `godot/scripts/progression/permanent_catalog.gd`, `godot/scripts/services/player_profile.gd`, `godot/scripts/ui/ui_icon.gd` (`for_permanent` per le voci nuove). Create `godot/tests/profile_v2_tests.gd`. Modify `godot/tests/workshop_tests.gd` dove si contano i gruppi.

**Interfaces — Produces:**
- `PermanentCatalog.GROUPS`: `[[&"common", "Comune"], [&"engineer", "Ingegnere"], [&"sapper", "Guastatore"], [&"mechanic", "Meccanico"], [&"weeder", "Erbacciaia"]]`. Le voci di oggi del gruppo `engineer` e `companion` diventano `common` (stessi `id`), tranne `fixed_turret` che va a `mechanic`. Voci nuove: `toolbox` (engineer, `[8, 16]`, Cassetta degli attrezzi), `spare_stakes` (engineer, `[10]`, Picchetti di scorta), `dry_powder` (sapper, `[8, 16]`, Polvere asciutta), `charge_pack` (sapper, `[12]`, Zaino di cariche), `good_oil` (mechanic, `[8]`, Olio buono), `good_seeds` (weeder, `[8, 16]`, Semi buoni), `green_thumb` (weeder, `[12]`, Pollice verde). Testi dalla spec par. 6.2.
- Voci di sblocco generate: per ogni arma di `WeaponCatalog` con `unlock_cost > 0`, `{id = StringName("unlock_%s" % arma), group = &"common", weapon = arma, name = "Sblocca: <nome>", costs = [unlock_cost], text = <testo dell'arma>}`. `PermanentCatalog.unlock_id(weapon_id) -> StringName`, `PermanentCatalog.weapon_of(id) -> StringName` (&"" se non e uno sblocco). Il catalogo si costruisce una volta (static var, come `WeaponCatalog`).
- `PermanentCatalog.RECIPES: Array[StringName] = [&"fort", &"mortar", &"tesla_coil", &"scythe_bramble", &"disc_dozer", &"compactor"]`.
- `PlayerProfileService.VERSION = 2`; `last_class: StringName` (default `ClassCatalog.DEFAULT`, chiave `last_class` in `[profile]`, valida solo se `ClassCatalog.find` la conosce); `recipes: PackedStringArray` (sezione `[recipes]`, chiavi = id, valore true); `set_last_class(id)`, `discover_recipe(id) -> bool` (vero la prima volta; salva), `has_recipe(id) -> bool`, `unlocked_weapons() -> Array[StringName]` (armi con `unlock_<arma>` a livello >= 1). `KNOWN_PROFILE_KEYS` comprende `last_class`; `[recipes]` non finisce piu fra le sezioni sconosciute.

- [ ] Test (`profile_v2_tests.gd`, profilo con percorso `user://profile_v2_test_*.cfg` ripulito alla fine): un file versione 1 scritto a mano (rottami 17, `tool_reach = 2`, `fixed_turret = 1`, `levels_unlocked = 2`, una sezione `[mystery]`) si carica con rottami, livelli e sblocchi intatti, `last_class == &"engineer"`, nessuna ricetta, nessuna arma sbloccata; salvato e ricaricato e versione 2 e `[mystery]` c'e ancora; `set_last_class(&"weeder")`, `discover_recipe(&"mortar")` (vero, poi falso), `buy(&"unlock_site_blade")` con 20 rottami: ricaricando restano; `last_class` sconosciuta nel file torna a `engineer`; ogni voce di `GROUPS` ha almeno due voci; `unlock_ram` costa 20; `weapon_of(&"unlock_jackhammer") == &"jackhammer"`.
- [ ] `workshop_tests.gd` e `campaign_tests.gd` verdi (aggiornare i conteggi dei gruppi se servono).
- [ ] Commit `Armi (D-092): profilo versione 2 (ultima classe, ricette) e catalogo dell'Officina per sezioni, sblocco delle armi comuni e upgrade di classe; test`.

### Task 2: classe dal profilo, permanenti di classe, armi sbloccate, ricette

**Files:** Modify `godot/scripts/run/arena_run.gd` (`_setup_loadout`: classe da `--class=`, altrimenti `profile.last_class`; `_unlocked_weapons()` dal profilo; `_apply_permanent_upgrades` solo voci `common` e della classe; ricetta scoperta alla fusione), `godot/scripts/combat/weapon.gd` (`extra_mods`), `godot/scripts/combat/weapon_catalog.gd` (`apply_mods` pubblica), `godot/scripts/combat/weapon_loadout.gd` (`set_weapon_mods`, segnale `fused(fusion_id)`), `godot/scripts/progression/class_perks.gd` (`boost_companion_speed(fraction)`, condiviso con Motore truccato). Test: `godot/tests/workshop_tests.gd`, `godot/tests/loadout_tests.gd`.

**Interfaces — Produces:**
- `Weapon.extra_mods: Dictionary` (chiavi come i `mods` dei bivi: `damage_add`, `cooldown_mul`, `hedge_seconds_add`); `stat()` applica `WeaponCatalog.apply_mods(value, key, extra_mods)` dopo il catalogo.
- `WeaponLoadout.set_weapon_mods(id: StringName, mods: Dictionary)`: vale per l'arma presente (riapplica i valori) e per quella aggiunta dopo. `signal fused(fusion_id: StringName)` emesso da `fuse`.
- Effetti (spec par. 6.2): `toolbox` liv. 1 chiodatrice al livello 2, liv. 2 anche il picchetto; `spare_stakes` picchetto `cooldown_mul 0.9`; `dry_powder` carica `damage_add = livello`; `charge_pack` Scavo esplosivo al livello 1; `fixed_turret` come oggi ma solo Meccanico; `good_oil` compagno +15% velocita; `good_seeds` roveto `hedge_seconds_add = 3 * livello`; `green_thumb` Erba alta al livello 2.
- `ArenaRun._unlocked_weapons()` restituisce `profile.unlocked_weapons()` (senza profilo: nessuna). Il rimando provvisorio del piano 2 sparisce.

- [ ] Test (`workshop_tests.gd`): con `last_class = &"mechanic"` e `fixed_turret = 1` la run monta la torretta; con `last_class = &"engineer"` e `fixed_turret = 1` no; `toolbox = 2` da Ingegnere: chiodatrice e picchetto al livello 2; `dry_powder = 2` da Guastatore: la carica fa 6 danni (`stat(&"damage")`); `green_thumb` da Erbacciaia: `tall_grass` al livello 2; `good_oil` da Meccanico: velocita massima del compagno x1,15; senza `unlock_site_blade` nessuna carta della Lama nelle offerte, con lo sblocco si (`WeaponOffers.cards(run.loadout, run.class_id, run._unlocked_weapons())`); `--class=` vince su `last_class`; una fusione fatta nella run (`loadout.fuse`) chiama `discover_recipe` (profilo con la ricetta).
- [ ] Test (`loadout_tests.gd`): `set_weapon_mods(&"seismic_stake", {cooldown_mul = 0.9})` porta la ricarica a 13,5; un'arma aggiunta dopo i mods li ha; `fused` emesso con l'id della fusione.
- [ ] Suite toccate e `classes_tests.gd` verdi. Commit `Armi (D-092): classe dal profilo, upgrade permanenti di classe, armi comuni sbloccate in Officina, ricette scoperte alla fusione; test`.

### Task 3: Officina a schede e ricettario

**Files:** Modify `godot/scripts/ui/workshop_panel.gd`. Test: `godot/tests/workshop_tests.gd`.

**Interfaces — Consumes:** `PermanentCatalog.GROUPS`, `RECIPES`, `weapon_of`; `PlayerProfileService.has_recipe`; `WeaponCatalog.find` (nome, icona, `parts`, testo). **Produces:** `WorkshopPanel.show_tab(index)`, `current_tab`, `TAB_NAMES` (le cinque sezioni piu "Ricettario"), `recipe_text(id) -> String` (per i test), `press(id)` invariato.

Comportamento: una barra di sei schede (stile delle Impostazioni: `MainButton` a interruttore, LB/RB e PagSu/PagGiu cambiano scheda e mettono il fuoco sulla prima carta); ogni scheda mostra solo le carte del suo gruppo; le carte di sblocco usano l'icona dell'arma (`WeaponCatalog.find(weapon).icon`), le altre `UiIcon.for_permanent`. La scheda Ricettario mostra sei carte non comprabili (focus si, acquisto no): fusione scoperta = icona, nome, "Chiodatrice + Picchetto sismico", testo; non scoperta = icona `lock`, nome "???", indizio "<prima parte> + ?". Il dettaglio a destra segue la carta col fuoco. All'apertura la scheda e quella della classe di `profile.last_class`.

- [ ] Test: sei schede; LB/RB (evento `InputEventJoypadButton`) passa alla scheda successiva e il fuoco va su una carta visibile; la scheda Comune contiene `unlock_site_blade` e `tool_reach`, non `fixed_turret`; la scheda Meccanico contiene `fixed_turret`; comprare `unlock_site_blade` con 15 rottami lo porta a 1/1; ricettario: `recipe_text(&"mortar")` contiene "?" e "Lanciarottami" prima di `discover_recipe`, il nome "Mortaio a crateri" dopo; il flusso di oggi (comprare, rifiutare, B torna) resta verde.
- [ ] Commit `Armi (D-092): Officina a schede (Comune e classi) con lo sblocco delle armi e il ricettario delle fusioni; test`.

### Task 4: scelta della classe nella campagna

**Files:** Modify `godot/scripts/ui/campaign_map_panel.gd`. Test: `godot/tests/campaign_tests.gd`.

**Interfaces — Consumes:** `ClassCatalog.all()` (nome, colore, kit, testo), `WeaponCatalog.find` (nomi e icone del kit), `PlayerProfileService.last_class/set_last_class`. **Produces:** `CampaignMapPanel.choosing_class: bool`, `press_class(id)`, `class_card(id) -> Button`, segnale `level_chosen(id)` invariato (emesso dopo la classe).

Comportamento: A su un livello non avvia piu: la riga dei livelli lascia il posto a quattro carte di classe (bordo nel colore di classe, ritratto = icone delle due armi del kit, nome, riga del ruolo, nomi delle armi). Fuoco sull'ultima classe scelta. A su una classe: `set_last_class`, poi `level_chosen` col livello scelto. B dalle classi torna ai livelli col fuoco sul livello di prima; B dai livelli chiude come oggi. Avvio diretto (`--class=`, `--autostart`) invariato.

- [ ] Test: premere un livello apre le classi (`choosing_class` vero, `level_chosen` non ancora emesso); quattro carte; il fuoco e sulla classe di `last_class`; `press_class(&"sapper")` emette `level_chosen(&"district")` e salva `last_class = &"sapper"`; `ui_cancel` dalle classi torna ai livelli e non chiude il pannello; un secondo `ui_cancel` chiude.
- [ ] Commit `Armi (D-092): scelta della classe nella mappa della campagna, ricordata nel profilo; test`.

### Task 5: casse sepolte

**Files:** Create `godot/scripts/run/buried_caches.gd` (`class_name BuriedCaches extends Node3D`), `godot/tests/buried_caches_tests.gd`. Modify `godot/scripts/run/arena_run.gd` (posa dopo le pennellate, cassa in coda al menu), `godot/scripts/progression/run_progression.gd` (`roll_weapon_offer(cards: Array[Dictionary], count := 3) -> Array[Dictionary]`).

**Interfaces — Produces:**
- `BuriedCaches`: `terrain_field`, `player: Node3D`; `place(points: Array[Vector3])` (quota di base in ogni punto); `count() -> int`, `closed_count() -> int`; `signal cache_opened(at: Vector3)`; luccichio (piccola mesh emissiva che pulsa, visibile solo col giocatore entro `GLINT_RANGE = 3.0` m) e, all'apertura, una cassa che sale in 0,6 s e sparisce. Controllo dell'apertura su `TerrainField.player_sculpted` e `region_changed` (anche il Demolitore e le armi scavano): aperta quando `height_at(p) <= base + 0.1`.
- `BuriedCaches.pick_points(district_strokes: Array, rng: RandomNumberGenerator, count: int) -> Array[Vector3]` statico: fra le pennellate con `scrap > 0` (cumuli e vagoni), a meta raggio dal centro in direzione casuale; se non bastano, nessun punto in piu.
- `ArenaRun`: 3 o 4 casse per livello (seme della run), `_pending_caches` e `_cache_menu` (la scelta in corso viene da una cassa); il menu si apre a fine passo come il level-up, titolo "CASSA SEPOLTA", sottotitolo "scegli un'arma", tre carte da `progression.roll_weapon_offer(WeaponOffers.cards(...))`; una carta di bivio apre le trasformazioni e la trasformazione chiude la cassa; senza carte possibili: 2 rottami al compagno, avviso nel HUD, nessun menu.

- [ ] Test (`buried_caches_tests.gd`): con un campo 40x40, un cumulo alzato e una cassa al centro: niente apertura finche il centro e sopra la base + 0,1; scavando (`field.sculpt` e `player_sculpted.emit`) fino alla base `cache_opened` arriva una volta sola; il luccichio e visibile col giocatore a 2 m e nascosto a 5 m; `pick_points` su tre pennellate (due con rottami) restituisce al massimo due punti, entro il raggio. In una run (`arena_run.tscn`): le casse posate sono 3 o 4; aprire una cassa (`_on_cache_opened`) apre il menu col titolo "CASSA SEPOLTA" e solo carte arma; scegliere una carta "nuova arma" la aggiunge e non tocca `_pending_level_ups`; cassa aperta con un level-up in coda: si scelgono entrambi, poi il gioco riparte; bivio da cassa: dopo la trasformazione `_pending_caches == 0`; slot pieni e tutto al 5: niente menu e 2 rottami in piu al compagno.
- [ ] Commit `Armi (D-092): casse sepolte nei cumuli e nei vagoni: luccichio, uscita allo scavo, scelta fra tre armi; test`.

### Task 6: catture, gate, documenti

**Files:** `godot/tests/tools/capture_weapons.gd` (`--shots=progression`: Officina su ogni scheda, ricettario, classi della campagna, cassa che luccica e menu della cassa), documenti (`MIGRATION_STATUS`, roadmap, `DECISIONS` D-092, `INDEX`, `GODOT_WORKFLOW`).

- [ ] Catture lette una per una; gate completo verde; commit `Armi (D-092): piano 4 chiuso; catture di Officina, classi e casse; documenti`.

---

## Esecuzione

Task 1 e 2 in sequenza (profilo e catalogo servono a tutti). Poi 3 (`workshop_panel.gd`), 4 (`campaign_map_panel.gd`) e 5 (`buried_caches.gd`, `arena_run.gd`, `run_progression.gd`) toccano file disgiunti e possono andare in parallelo, uno per worktree; integrazione e verifica qui. Poi 6.
