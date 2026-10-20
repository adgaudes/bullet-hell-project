# Stato del progetto — leggere per primo

> **Breve per scelta** (audit D-06, 14 ottobre 2026): dove siamo, prossimo passo, cosa aspetta il proprietario. Va aggiornato a ogni avanzamento e tenuto **sotto 8 KB**: quando cresce, il vecchio va in `docs/archive/`. Storia delle sessioni fino al 14 ottobre 2026: `docs/archive/STATUS_LOG_2026-10.md`. Decisioni: `DECISIONS.md`. Piano di prodotto: `PROJECT_ROADMAP.md`. Per trovare un documento: `INDEX.md`.

**Ultimo aggiornamento:** 20 ottobre 2026 (**piano C della carovana scritto, task 1-4 fatti e rivisti**: basi, relitti dei moduli, eventi che staccano moduli; fermato dal proprietario dopo il task 4; gate verde con 60 suite).

## Dove siamo

- **Engine** Godot 4.7.2 (GDScript). La migrazione da Unreal e chiusa; il codice Unreal sta nel tag `unreal-prototype-final`.
- **Prodotto:** fase 3, prototipo della promessa A. Due livelli (quartiere, ferrovia) su Terrain3D, boss, treno, terremoto, notte con lampioni, estrazione, Officina, campagna, carovana di macchine, audio Sonniss. Playtest del proprietario il 14 ottobre (sotto).
- **Branch di lavoro:** `feature/arena-run`. Non integrato: `feature/engineer-restyle` (Ingegnere D-088, worktree `../Videogame-engineer`), in attesa del giudizio del proprietario.
- **Gate:** `tools/godot/Invoke-GodotChecks.ps1`: check-only, 60 suite con seme fisso (nuova `colossus_tests`), passo con finestra (Terrain3D e shader), smoke test. Ultimo gate completo verde il 20 ottobre dopo il task 3 del piano C; dopo il task 4 rilanciate a mano le 15 suite pertinenti, verdi.
- **Build:** Windows del 19 ottobre (piano B) in `LocalBuilds/Prototype01-Godot-Win64/` (exe 195 MB); **senza il piano C** (riesportare alla chiusura del task 8); la Linux in `-Linux/` e del 14 ottobre, senza carovana.

**Audit del 14 ottobre:** `docs/REVIEWS/FULL_AUDIT_2026-10-14.md`.

## Playtest del proprietario (14 ottobre 2026, sera)

Esito **Modifica**: 16 osservazioni, cause e piano in `docs/PLAYTESTS/OWNER_PLAYTEST_2026-10-14.md` (viene prima dell'audit; ordine D-089: grafica, gioco, armi, audio).

**Fatto e dettagli** (blocchi 1-2, armi D-092, luce D-094, eventi D-097, carovana piano A): `docs/archive/STATUS_LOG_2026-10.md`.

## Prossimo passo (agente)

0. **Carovana (D-093): piani A e B fatti (18-19 ottobre); piano C scritto il 20 ottobre, task 1-4 fatti e rivisti** (`docs/superpowers/plans/2026-10-20-caravan-colossus.md`, decisioni e debito in "Stato dell'esecuzione" e in D-093): valori del pilotaggio nel tuning, `module_limit` coi posti in piu, `detach_random`, `break_down`, `force_retreat`, relitti dei moduli (`ModuleRelics`, tasto Riprendi, smistatore di Interagisci), terremoto e treno che staccano moduli dalle macchine fuse. **Prossimo: riprendere il piano C dal task 5** (colosso pilotato: `ColossusPilot`, Machine guidata, giocatore a bordo senza armi), poi 6 (Meccanico), 7 (scheda Macchine dell'Officina), 8 (bot, benchmark `caravan_colossus_piloted`, catture, documenti, export); registro locale `.superpowers/sdd/2026-10-20-caravan-colossus/progress.md`, BASE del task 5 = `3d4c066`. Dopo: playtest del proprietario della carovana completa, bilanciamento coi bot. **Inondazione** (15 ottobre): spike di costo dell'acqua sul Deck, poi il design. Poi musica. ProtonScatter approvato (D-090), da installare quando servira.
   **Grafica (richieste del 15 ottobre):** strumenti di D-095 uno alla volta con misura e catture (Effekseer solo per i boss, ProtonScatter, post-produzione, AreaLight3D di notte, Material Maker e Ucupaint); **carte degli upgrade da rifare** (D-096: bozze in cattura).
1. **Voci rimaste dell'audit**, nell'ordine della sua sezione 1: `docs/REVIEWS/FULL_AUDIT_2026-10-14.md`.
2. **Dopo la misura sul Deck:** V-02, V-03, V-06, Q-01, Q-03, Q-04 (costo GPU e contenuto del preset Deck).
3. **Dopo le decisioni del proprietario:** PF-01 (metodo del direttore dei nemici) e P-02 (regola di Scorta).

## Cosa aspetta il proprietario

0. **Piano B: 7 scelte eseguite coi default e la vita conservata dalla sganciata** da confermare o ribaltare; **playtest della carovana e della fusione** (piani A e B; catture in `output/caravan/`): elenco completo in `docs/archive/STATUS_LOG_2026-10.md`, sezione del 20 ottobre.
0. **Piano C, domande di design** (D-093): il relitto di un modulo scagliato dal treno cade dal lato che la spinta preferisce, senza controllo di percorribilita; i rottami di un Cassone staccato dal treno restano sulla fascia e il treno li porta via. Dire se va bene cosi.
0. **Decidere** se le carte macchina devono battere i livelli delle armi (o se il bot scrapper deve avvicinarsi ai relitti con margine minore): fin li i bot prendono una macchina solo da un'offerta senza carte arma o da un relitto vicino.
1. **Luce (D-094):** giudicare in gioco o sulle catture `output/lighting_lab/`. **Carte degli upgrade (D-096):** scegliere fra le bozze quando arrivano.
1. **Musica:** ascoltare i candidati in `C:\Users\adgau\Desktop\Videogame-assets\music-candidates\` (LEGGIMI.md con licenze) e dire quali tenere (D-089).
2. **Giudizio sull'Ingegnere** (D-088): catture in `../Videogame-engineer/output/engineer/`.
3. **Playtest dei due livelli:** restano boss, notte, ferrovia e controller (`docs/PLAYTESTS/ARENA_RUN_LEVEL_2026-10-07.md`).
4. **Misura sul Steam Deck** con la build in `LocalBuilds/` e il Debug Menu (F3); anche una corsa di notte con piu Faro (723 draw call contro 490 di giorno).
5. **Decisioni:**
   - direttore dei nemici (PF-01): sfera −20 %, 60 Hz −50 %, oppure movimento cinematico;
   - Scorta liv. 2 (P-02);
   - campo visivo su schermi larghi (G-04).
6. **Catture ancora da giudicare**: elenco nella roadmap, "Stato operativo".

## Rischi e limiti noti

- **Gate, blocco all'uscita di Godot:** una suite stampa PASS ma il processo non si chiude entro 300 s (exit 124), circa 1 volta su 10; il gate la rilancia una volta (`output/gate/<suite>.exit-hang.log`; dettagli in `GODOT_WORKFLOW.md`).
- **Steam Deck mai misurato.** CPU: il direttore costa 2,6 ms per passo (due passi per frame a 60 fps), un anello del picchetto che sale 0,75 ms per passo; GPU stimata 25-40 fps; prato a particelle e menu 3D non misurati.
- **Registri minori** (D-088 e carovana) in `.superpowers/` (ignorato da Git): in `docs/` all'integrazione (D-03).
- **Bundle Sonniss:** zip 6 di 9 in parte illeggibile; da riscaricare se servono quei suoni.

## Comandi essenziali

```bash
# gate completo; -Executable <exe> verifica una build, -Seed N cambia il seme, -NoWindow salta il passo con finestra
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
# una suite, o uno script senza eseguirlo
godot_console --headless --path godot --fixed-fps 60 --script res://tests/<suite>.gd
godot_console --headless --path godot --check-only --script res://<percorso>.gd
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
