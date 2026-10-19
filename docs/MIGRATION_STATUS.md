# Stato del progetto — leggere per primo

> **Breve per scelta** (audit D-06, 14 ottobre 2026): dove siamo, prossimo passo, cosa aspetta il proprietario. Va aggiornato a ogni avanzamento e tenuto **sotto 8 KB**: quando cresce, il vecchio va in `docs/archive/`. Storia delle sessioni fino al 14 ottobre 2026: `docs/archive/STATUS_LOG_2026-10.md`. Decisioni: `DECISIONS.md`. Piano di prodotto: `PROJECT_ROADMAP.md`. Per trovare un documento: `INDEX.md`.

**Ultimo aggiornamento:** 19 ottobre 2026 (**piano B della carovana fatto e rivisto**: fusione delle macchine, revisione finale del branch; gate verde con 59 suite, export Windows).

## Dove siamo

- **Engine** Godot 4.7.2 (GDScript). La migrazione da Unreal e chiusa; il codice Unreal sta nel tag `unreal-prototype-final`.
- **Prodotto:** fase 3, prototipo della promessa A. Due livelli (quartiere, ferrovia) su Terrain3D, boss, treno, terremoto, notte con lampioni, estrazione, Officina, campagna, carovana di macchine, audio Sonniss. Playtest del proprietario il 14 ottobre (sotto).
- **Branch di lavoro:** `feature/arena-run`. Non integrato: `feature/engineer-restyle` (Ingegnere D-088, worktree `../Videogame-engineer`), in attesa del giudizio del proprietario.
- **Gate:** `tools/godot/Invoke-GodotChecks.ps1`: check-only, 59 suite con seme fisso, passo con finestra (Terrain3D e shader), smoke test. Ultimo gate completo verde il 19 ottobre, revisione finale del piano B (59 suite, nessun rilancio).
- **Build:** Windows riesportata il 19 ottobre dopo la revisione finale del piano B, in `LocalBuilds/Prototype01-Godot-Win64/` (exe 195 MB, avvio con `--autostart` pulito); la Linux in `-Linux/` e del 14 ottobre, senza carovana.

**Audit del 14 ottobre:** `docs/REVIEWS/FULL_AUDIT_2026-10-14.md`.

## Playtest del proprietario (14 ottobre 2026, sera)

Esito **Modifica**: 16 osservazioni, cause e piano in `docs/PLAYTESTS/OWNER_PLAYTEST_2026-10-14.md` (viene prima dell'audit; ordine D-089: grafica, gioco, armi, audio).

**Fatto e dettagli** (blocchi 1-2, armi D-092, luce D-094, eventi D-097, carovana piano A): `docs/archive/STATUS_LOG_2026-10.md`.

## Prossimo passo (agente)

0. **Carovana (D-093): piano A fatto il 18 ottobre, piano B (fusione) fatto e rivisto il 19** (`docs/superpowers/plans/2026-10-18-caravan-fusion.md`): pedana a meta della chiamata del boss, banco in pausa, taglie fino al Colosso, travolgere, sei combinazioni, profilo v3. Deck: carovana 0,26 ms per passo con sei macchine, 0,11 col Colosso (budget 0,5). Revisione finale del branch: nessun critico; chiusa la cura gratuita sgancia-e-rifondi (la sganciata conserva la frazione di vita), pedana che ricontrolla il piano all'arrivo, pretesa fantasma del secondo Cassone e le minori del registro; esito e debito in D-093 (benchmark della Ruspa in moto, chiave dei dettagli dell'Officina). Bot: fondono solo con pedana a 150 s, scrapper con Calamita e Officina `cargo:3,stock:2` (`GODOT_WORKFLOW.md`). **Prossimo:** playtest della carovana e della fusione del proprietario, poi il piano C (colosso pilotato, eventi, Meccanico, Officina). **Inondazione** (15 ottobre): spike di costo dell'acqua sul Deck, poi il design. Dopo: bilanciamento, playtest, musica. ProtonScatter approvato (D-090), da installare quando servira.
   **Grafica (richieste del 15 ottobre):** strumenti di D-095 uno alla volta con misura e catture (Effekseer solo per i boss, ProtonScatter, post-produzione, AreaLight3D di notte, Material Maker e Ucupaint); **carte degli upgrade da rifare** (D-096: bozze in cattura).
1. **Voci rimaste dell'audit**, nell'ordine della sua sezione 1: `docs/REVIEWS/FULL_AUDIT_2026-10-14.md`.
2. **Dopo la misura sul Deck:** V-02, V-03, V-06, Q-01, Q-03, Q-04 (costo GPU e contenuto del preset Deck).
3. **Dopo le decisioni del proprietario:** PF-01 (metodo del direttore dei nemici) e P-02 (regola di Scorta).

## Cosa aspetta il proprietario

0. **Piano B fatto: 7 scelte eseguite coi default**, da confermare o ribaltare (pedana 6 m, prima la base poi l'assorbita, Riflettore anche di giorno, Ruspa gratis, doppi danni x4, Cassone con raggio invece di capienza, luce della pedana solo visiva), **piu la scelta della revisione finale: la macchina sganciata conserva la frazione di vita** invece di nascere piena (sgancia-e-rifondi curava a 2 rottami il giro). Catture nuove in `output/caravan/`: `fusion_pad`, `fusion_pad_night`, `fusion_bench`, `fused_machine` (nel banco la scheda inattiva e piu chiara dell'attiva: dire se confonde). **Da sapere:** fossato e argine della Ruspa arrivano a circa il 75% di 0,4 e 0,6 m col pennello attuale da 0,5 m; il pannello dell'Officina e piu alto su ogni scheda.
0. **Playtest della carovana e della fusione**: piano A (Faro, carte, colpi, guasto, ritirata, riparazione con X o R, striscia, quattro moduli nuovi, relitti) e piano B (pedana a meta della chiamata del boss, banco con X o R sulla pedana, taglie, combinazioni); elenco completo e conferme ancora aperte (D-092, D-093) in `docs/archive/STATUS_LOG_2026-10.md`, sezioni del 18 e 19 ottobre. **Da sapere:** una macchina caduta in una buca da cui non risale torna al suo posto dopo 3 s.
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
