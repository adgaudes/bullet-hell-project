# Stato del progetto — leggere per primo

> **Breve per scelta** (audit D-06, 14 ottobre 2026): dove siamo, prossimo passo, cosa aspetta il proprietario. Va aggiornato a ogni avanzamento e tenuto **sotto 8 KB**: quando cresce, il vecchio va in `docs/archive/`. Storia delle sessioni fino al 14 ottobre 2026: `docs/archive/STATUS_LOG_2026-10.md`. Decisioni: `DECISIONS.md`. Piano di prodotto: `PROJECT_ROADMAP.md`. Per trovare un documento: `INDEX.md`.

**Ultimo aggiornamento:** 14 ottobre 2026, notte.

## Dove siamo

- **Engine** Godot 4.7.2 (GDScript). La migrazione da Unreal e chiusa; il codice Unreal sta nel tag `unreal-prototype-final`.
- **Prodotto:** fase 3, prototipo della promessa A. Due livelli giocabili, quartiere e ferrovia, su terreno continuo (Terrain3D), con boss (Demolitore, Trivella), treno, terremoto, giorno e notte con lampioni, estrazione, Officina, campagna, interfaccia "fatta a mano", audio Sonniss. **Il proprietario non ha giocato nulla dal 7 ottobre.**
- **Branch di lavoro:** `feature/arena-run`. Non integrato: `feature/engineer-restyle` (Ingegnere D-088, worktree `../Videogame-engineer`), in attesa del giudizio del proprietario.
- **Gate:** `tools/godot/Invoke-GodotChecks.ps1`: check-only, 37 suite con seme fisso, passo con finestra (Terrain3D e shader), smoke test. Verde.
- **Build:** `LocalBuilds/Prototype01-Godot-Win64/` e `-Linux/` (exe 196 MB).

## Ultimo lavoro: audit e correzioni (14 ottobre 2026)

Audit generale in `docs/REVIEWS/FULL_AUDIT_2026-10-14.md`, con lo stato riga per riga in testa. Fatte, con un test ciascuna:

- **Dati:** salvataggi con `.bak`, `.tmp` conservato, recupero e copia del file illeggibile (S-01..S-03).
- **Gioco:** spinta della Trivella, terremoto sotto giocatore e compagno, annuncio con priorita, Esci con conferma e incasso, pennello dopo Alt-Tab, zainetto, frammenti e corone sul rilievo, mira col mouse sul rilievo, compagno e argini, mappa con barricate, terremoto senza faglia.
- **Prestazioni (PC, i7-13620H e RTX 4050 Laptop, 70 nemici):**
  - frame Alto 6,8 → 4,8 ms; frame Deck 5,4 → 4,1 ms;
  - primitive 2,06 M → 0,76 M (prato a porzioni);
  - ricentro del campo di percorso 51-64 → 0,5-1,4 ms;
  - martello del Demolitore 557 → 18 aggiornamenti del terreno al secondo;
  - primo frame del caricamento circa 3,1 → 2,7 s;
  - exe 246 → 196 MB.
- **Gate:** seme fisso, log delle suite fallite in `output/gate/`, allowlist per suite, passo con finestra.

## Playtest del proprietario (14 ottobre 2026, sera)

Esito **Modifica**: 14 osservazioni (salute, terra senza indicatore, buca senza uscita, sparo dalle spalle, armi, frecce viola, ombre e AO, terreno a quadrati, erba, rovine, impostazioni, menu, Officina, musica). Cause e piano in `docs/PLAYTESTS/OWNER_PLAYTEST_2026-10-14.md`. **Il piano di quel documento viene prima delle voci dell'audit qui sotto.**

## Prossimo passo (agente)

0. **Blocco 2 (grafica) del playtest del 14 ottobre**, poi i blocchi 1, 3, 4 (ordine D-089). Primo passo: cattura delle ombre accese e spente su Massimo (O-07).
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

1. **Ascolto dei suoni** (D-084): `output/audio/sfx_preview.wav` oppure in gioco.
2. **Giudizio sull'Ingegnere** (D-088): catture in `../Videogame-engineer/output/engineer/`. Dopo il si si integra.
3. **Playtest dei due livelli:** primo giro fatto il 14 ottobre (livello 1, tastiera, breve). Restano boss, notte, ferrovia e controller: promemoria in `docs/PLAYTESTS/ARENA_RUN_LEVEL_2026-10-07.md`.
4. **Misura sul Steam Deck** con la build in `LocalBuilds/` e il Debug Menu (F3).
5. **Decisioni:**
   - direttore dei nemici (PF-01): sfera −20 %, 60 Hz −50 %, oppure movimento cinematico;
   - Scorta liv. 2 (P-02);
   - campo visivo su schermi larghi (G-04).
6. **Catture ancora da giudicare** (identita, restyling, passate artistiche): elenco nella roadmap, sezione "Stato operativo".

## Rischi e limiti noti

- **Steam Deck mai misurato.** CPU: il direttore costa 2,6 ms per passo, e a 60 fps i passi sono due per frame. GPU: le stime vanno da 25 a 40 fps senza ulteriori ottimizzazioni.
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
