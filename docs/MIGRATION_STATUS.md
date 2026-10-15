# Stato del progetto — leggere per primo

> **Breve per scelta** (audit D-06, 14 ottobre 2026): dove siamo, prossimo passo, cosa aspetta il proprietario. Va aggiornato a ogni avanzamento e tenuto **sotto 8 KB**: quando cresce, il vecchio va in `docs/archive/`. Storia delle sessioni fino al 14 ottobre 2026: `docs/archive/STATUS_LOG_2026-10.md`. Decisioni: `DECISIONS.md`. Piano di prodotto: `PROJECT_ROADMAP.md`. Per trovare un documento: `INDEX.md`.

**Ultimo aggiornamento:** 15 ottobre 2026 (eventi del mondo casuali e scheda Gameplay, D-097; carovana: Sezioni 1-5 approvate).

## Dove siamo

- **Engine** Godot 4.7.2 (GDScript). La migrazione da Unreal e chiusa; il codice Unreal sta nel tag `unreal-prototype-final`.
- **Prodotto:** fase 3, prototipo della promessa A. Due livelli giocabili, quartiere e ferrovia, su terreno continuo (Terrain3D), con boss (Demolitore, Trivella), treno, terremoto, giorno e notte con lampioni, estrazione, Officina, campagna, interfaccia "fatta a mano", audio Sonniss. Primo playtest del proprietario il 14 ottobre (vedi sotto).
- **Branch di lavoro:** `feature/arena-run`. Non integrato: `feature/engineer-restyle` (Ingegnere D-088, worktree `../Videogame-engineer`), in attesa del giudizio del proprietario.
- **Gate:** `tools/godot/Invoke-GodotChecks.ps1`: check-only, 45 suite con seme fisso, passo con finestra (Terrain3D e shader), smoke test. Verde.
- **Build:** `LocalBuilds/Prototype01-Godot-Win64/` e `-Linux/` (exe 196 MB).

**Audit del 14 ottobre:** `docs/REVIEWS/FULL_AUDIT_2026-10-14.md` (70 nemici: Alto 4,8 ms, Deck 4,1 ms).

## Playtest del proprietario (14 ottobre 2026, sera)

Esito **Modifica**: 14 osservazioni, piu O-15 e O-16 del 15 ottobre. Cause e piano in `docs/PLAYTESTS/OWNER_PLAYTEST_2026-10-14.md`. **Il piano di quel documento viene prima delle voci dell'audit.** Ordine scelto (D-089): grafica, gioco, armi, audio.

**Blocchi 1 e 2 (14 ottobre, D-090, D-091):** luce, terreno CC0, prato a particelle, rovine a moduli, menu 3D, Officina a carte, vita 10, terra nel HUD, rampa d'uscita, mira commutabile, impostazioni a schede (catture `output/lighting/`).

**Blocco 3, armi e classi (D-092), 15 ottobre:** design approvato a voce (spec `docs/superpowers/specs/2026-10-15-weapons-classes-design.md`), piani 1-4 fatti (dettagli in `DECISIONS.md`). Deck per classe 0,18-0,65 ms per passo (budget 1,0). Catture `output/weapons/`.

**Eventi del mondo, 15 ottobre (D-097):** niente orari fissi; quanti eventi per livello (1-5, di serie 1), quali e quando li sceglie a caso `WorldEventScheduler` prima della chiamata del boss. Nuova scheda **Gameplay** nelle Impostazioni: eventi per livello, Terremoto, Treno, Notte, mira manuale. Suite `world_event_tests`.

**Luce, 15 ottobre (D-094):** il proprietario la giudicava piatta. Sole in controluce laterale, ombre blu, AgX, `FillLight`, `CloudShadows`, notte lunare; banco di prova `tests/tools/lighting_lab.gd` (varianti JSON, notte e tramonto veri). Costo PC +0,1-0,2 ms; catture `output/lighting_lab/`.

## Prossimo passo (agente)

0. Blocchi 1-2 del playtest e piani 1-4 delle armi fatti (sopra). **In corso: progettazione della carovana di macchine e della fusione (D-093)** col proprietario: bozza `docs/superpowers/specs/2026-10-15-caravan-machines-design.md`; Sezioni 1-5 approvate, ripartire dalla Sezione 6 (HUD, comandi, prestazioni), poi la 7 e la spec. **Non implementare prima.** **Inondazione** (richiesta del 15 ottobre): proporre uno spike di costo dell'acqua simulata sul Deck, poi il design. Dopo: piano 5 armi (effetti e suoni), bilanciamento coi bot, playtest. Poi la musica scelta da lui (candidati in `Videogame-assets/music-candidates/`). ProtonScatter approvato (D-090) ma non installato: serve quando si spargono oggetti.
   **Grafica (richieste del proprietario del 15 ottobre):** strumenti di D-095 uno alla volta con misura e catture (Effekseer col piano 5, ProtonScatter, post-produzione, AreaLight3D di notte, Material Maker e Ucupaint per nemici e boss); **carte degli upgrade da rifare** (D-096: font e layout, prima bozze in cattura).
1. **Voci rimaste dell'audit**, nell'ordine della sua sezione 1 (PF-03, T-01/T-02, I-02, K-07/K-08, L-01, D-05, H-01, X-01/X-03, voci B): elenco in `docs/REVIEWS/FULL_AUDIT_2026-10-14.md`.
2. **Dopo la misura sul Deck:** V-02, V-03, V-06, Q-01, Q-03, Q-04 (costo GPU e contenuto del preset Deck).
3. **Dopo le decisioni del proprietario:** PF-01 (metodo del direttore dei nemici) e P-02 (regola di Scorta).

## Cosa aspetta il proprietario

0. **Carovana di macchine** (D-093): Sezioni 6 e 7 da approvare. **Scheda Gameplay** (D-097): provarla; dire se un evento di serie basta. 0. **Armi e classi** (D-092): da provare a mano la scelta della classe in campagna, l'Officina a schede e le casse sepolte (luccichio sui cumuli).  Spec da rileggere quando vuoi; catture in `output/weapons/` (effetti ancora discreti: arrivano col piano 5). Da provare a mano: `--class=sapper|mechanic|weeder`. Scelte da confermare (D-092): Fortino "al 70%" come cadenza, Polarita inversa che respinge di circa 2 m.
1. **Luce (D-094):** giudicare in gioco o sulle catture `output/lighting_lab/`. **Carte degli upgrade (D-096):** scegliere fra le bozze quando arrivano.
1. **Musica:** ascoltare i candidati in `C:\Users\adgau\Desktop\Videogame-assets\music-candidates\` (LEGGIMI.md con licenze) e dire quali tenere (D-089).
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
