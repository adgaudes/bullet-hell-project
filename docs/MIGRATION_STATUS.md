# Stato del progetto — leggere per primo

> **Breve per scelta** (audit D-06, 14 ottobre 2026): dove siamo, prossimo passo, cosa aspetta il proprietario. Va aggiornato a ogni avanzamento e tenuto **sotto 8 KB**: quando cresce, il vecchio va in `docs/archive/`. Storia delle sessioni fino al 14 ottobre 2026: `docs/archive/STATUS_LOG_2026-10.md`. Decisioni: `DECISIONS.md`. Piano di prodotto: `PROJECT_ROADMAP.md`. Per trovare un documento: `INDEX.md`.

**Ultimo aggiornamento:** 15 ottobre 2026 (armi e classi: design e piano 1, impianto).

## Dove siamo

- **Engine** Godot 4.7.2 (GDScript). La migrazione da Unreal e chiusa; il codice Unreal sta nel tag `unreal-prototype-final`.
- **Prodotto:** fase 3, prototipo della promessa A. Due livelli giocabili, quartiere e ferrovia, su terreno continuo (Terrain3D), con boss (Demolitore, Trivella), treno, terremoto, giorno e notte con lampioni, estrazione, Officina, campagna, interfaccia "fatta a mano", audio Sonniss. Primo playtest del proprietario il 14 ottobre (vedi sotto).
- **Branch di lavoro:** `feature/arena-run`. Non integrato: `feature/engineer-restyle` (Ingegnere D-088, worktree `../Videogame-engineer`), in attesa del giudizio del proprietario.
- **Gate:** `tools/godot/Invoke-GodotChecks.ps1`: check-only, 43 suite con seme fisso, passo con finestra (Terrain3D e shader), smoke test. Verde.
- **Build:** `LocalBuilds/Prototype01-Godot-Win64/` e `-Linux/` (exe 196 MB).

## Audit (14 ottobre 2026)

`docs/REVIEWS/FULL_AUDIT_2026-10-14.md`; riepilogo di cosa e stato corretto in `docs/archive/STATUS_LOG_2026-10.md`. Frame di riferimento prima del blocco grafica (RTX 4050, 70 nemici): Alto 4,8 ms, Deck 4,1 ms.

## Playtest del proprietario (14 ottobre 2026, sera)

Esito **Modifica**: 14 osservazioni (salute, terra senza indicatore, buca senza uscita, sparo dalle spalle, armi, frecce viola, ombre e AO, terreno a quadrati, erba, rovine, impostazioni, menu, Officina, musica). Cause e piano in `docs/PLAYTESTS/OWNER_PLAYTEST_2026-10-14.md`. **Il piano di quel documento viene prima delle voci dell'audit.** Ordine scelto (D-089): grafica, gioco, armi, audio.

**Blocco grafica, fatto il 14 ottobre (D-090, catture in `output/lighting/`):** luce (nebbia del Massimo 0,003, ambiente 0,4, AO di contatto), terreno con texture CC0 a 1024 e bordi sfumati, prato a particelle (`GrassField`, +0,7 ms Deck), rovine a moduli (`RuinModules`), frecce viola spente.

**Blocco 3, armi e classi (D-092), 15 ottobre:** design approvato a voce (spec `docs/superpowers/specs/2026-10-15-weapons-classes-design.md`: quattro classi giocabili, 6 automatiche, 6 attive, 6 fusioni, bivi al 3 e al 5, casse sepolte, Officina a sezioni). **Piano 1, impianto, fatto** (`docs/superpowers/plans/2026-10-15-weapons-foundation.md`): catalogo e classi, chiodatrice coi quattro bivi, Picchetto sismico, `WeaponLoadout`, comandi E/F e LT/RB, carte arma e schermata della trasformazione, mazzi di classe, striscia nel HUD, `--class=`. Armi 0,09 ms per passo, 0,84 ms mentre un anello sale (budget 1,0). Catture `output/weapons/`.

**Secondo giro (14 ottobre, notte):** menu 3D, Officina a carte; blocco di gioco D-091 (vita 10, terra nel HUD, rampa d'uscita, mira commutabile, impostazioni a schede).

## Prossimo passo (agente)

0. **Blocchi 1 e 2 del playtest fatti** (grafica, menu, Officina, salute, terra, buca, mira, impostazioni; D-090, D-091). **Blocco 3, armi (O-05): design approvato a voce il 15 ottobre** (D-092): quattro classi giocabili, 6 automatiche, 6 attive su tasto, 6 fusioni, bivi, casse sepolte; spec `docs/superpowers/specs/2026-10-15-weapons-classes-design.md`. Piano 1 (impianto) fatto. Prossimo: **piano 2, kit comune** (Lama, Martello, Ariete, Betoniera e le due fusioni comuni), poi le tre classi (piani 3, anche in parallelo con Codex), casse/Officina/scelta della classe (4), effetti (5), bilanciamento coi bot (6). Poi la musica scelta da lui (candidati in `Videogame-assets/music-candidates/`). ProtonScatter approvato (D-090) ma non installato: serve quando si spargono oggetti.
1. **Voci rimaste dell'audit**, nell'ordine della sua sezione 1:
   - PF-03, caricamento: prato sul rilievo 850 ms, pittura del terreno 460 ms;
   - T-01 e T-02: collisione copiata dal campo, ferrovia allineata;
   - I-02: cursore nascosto o confinato;
   - K-07 e K-08: soglie a tempo reale e controlli deboli nei test;
   - L-01: exit code di Blender;
   - D-05: stati di DECISIONS;
   - H-01: binari Terrain3D non bersaglio;
   - X-01 e X-03: Debug Menu e nome dell'exe;
   - le voci B.
2. **Dopo la misura sul Deck:** V-02, V-03, V-06, Q-01, Q-03, Q-04 (costo GPU e contenuto del preset Deck).
3. **Dopo le decisioni del proprietario:** PF-01 (metodo del direttore dei nemici) e P-02 (regola di Scorta).

## Cosa aspetta il proprietario

0. **Armi e classi** (D-092): la spec e da rileggere quando vuoi (si procede intanto, come chiesto); catture dell'impianto in `output/weapons/` (l'anello del picchetto dalla camera alta e ancora discreto: polvere e tinta arrivano col piano 5).
1. **Musica:** ascoltare i candidati in `C:\Users\adgau\Desktop\Videogame-assets\music-candidates\` (LEGGIMI.md con licenze) e dire quali tenere (D-089). **Grafica:** giudicare il blocco grafica nella nuova build (catture in `output/lighting/`).
2. **Giudizio sull'Ingegnere** (D-088): catture in `../Videogame-engineer/output/engineer/`. Dopo il si si integra.
3. **Playtest dei due livelli:** primo giro fatto il 14 ottobre (livello 1, tastiera, breve). Restano boss, notte, ferrovia e controller: promemoria in `docs/PLAYTESTS/ARENA_RUN_LEVEL_2026-10-07.md`.
4. **Misura sul Steam Deck** con la build in `LocalBuilds/` e il Debug Menu (F3).
5. **Decisioni:**
   - direttore dei nemici (PF-01): sfera −20 %, 60 Hz −50 %, oppure movimento cinematico;
   - Scorta liv. 2 (P-02);
   - campo visivo su schermi larghi (G-04).
6. **Catture ancora da giudicare** (identita, restyling, passate artistiche): elenco nella roadmap, sezione "Stato operativo".

## Rischi e limiti noti

- **Gate, 14 ottobre notte:** `run_progression_tests` ha passato i controlli ma il processo non si e chiuso entro 300 s (exit 124) una volta su quattro; da sola esce sempre in 1 s. Blocco intermittente all'uscita di Godot, da tenere d'occhio.
- **Steam Deck mai misurato.** CPU: il direttore costa 2,6 ms per passo (due passi per frame a 60 fps), un anello del picchetto che sale 0,75 ms per passo; GPU stimata 25-40 fps; prato a particelle e menu 3D non misurati.
- **Registro minori di D-088** in `.superpowers/` (ignorato da Git): va portato in `docs/` all'integrazione (D-03).
- **Bundle Sonniss:** lo zip 6 di 9 e in parte illeggibile; va riscaricato se servono quei suoni.

## Comandi essenziali

```bash
# gate completo; -Executable <exe> verifica una build, -Seed N cambia il seme, -NoWindow salta il passo con finestra
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
# una suite, o uno script senza eseguirlo
godot_console --headless --path godot --fixed-fps 60 --script res://tests/<suite>.gd
godot_console --headless --path godot --check-only --script res://<percorso>.gd
# benchmark (frame, draw call, direttore, pennellata, corsa con ricentro)
godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70 --preset=deck
# export
godot_console --headless --path godot --export-release "Windows Desktop" ../LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe
```

Altri comandi, catture e trappole: `GODOT_WORKFLOW.md`.

## Da non dimenticare

- **Unreal:** non estendere il progetto e non ripristinarlo nel working tree; si legge dal tag.
- **Comandi Godot:** sempre `godot_console` con `--quit-after`. Le suite una alla volta: processi godot rimasti scrivono sullo stesso log.
- **Seme:** un rosso del gate si riproduce con lo stesso seme, il log sta in `output/gate/`.
- **Scene aperte:** prima di modificare una scena, dirlo al proprietario; puo averla aperta nell'editor.
- **Playtest:** non cancellare `Artifacts/Playtests/`, unica evidenza del playtest Slice A.
