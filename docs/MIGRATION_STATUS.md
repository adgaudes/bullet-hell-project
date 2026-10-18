# Stato del progetto — leggere per primo

> **Breve per scelta** (audit D-06, 14 ottobre 2026): dove siamo, prossimo passo, cosa aspetta il proprietario. Va aggiornato a ogni avanzamento e tenuto **sotto 8 KB**: quando cresce, il vecchio va in `docs/archive/`. Storia delle sessioni fino al 14 ottobre 2026: `docs/archive/STATUS_LOG_2026-10.md`. Decisioni: `DECISIONS.md`. Piano di prodotto: `PROJECT_ROADMAP.md`. Per trovare un documento: `INDEX.md`.

**Ultimo aggiornamento:** 18 ottobre 2026 (**piano A della carovana fatto**: task 10 chiuso con bot, benchmark, catture, documenti, export Windows e gate).

## Dove siamo

- **Engine** Godot 4.7.2 (GDScript). La migrazione da Unreal e chiusa; il codice Unreal sta nel tag `unreal-prototype-final`.
- **Prodotto:** fase 3, prototipo della promessa A. Due livelli (quartiere, ferrovia) su Terrain3D, boss, treno, terremoto, notte con lampioni, estrazione, Officina, campagna, carovana di macchine, audio Sonniss. Primo playtest del proprietario il 14 ottobre (vedi sotto).
- **Branch di lavoro:** `feature/arena-run`. Non integrato: `feature/engineer-restyle` (Ingegnere D-088, worktree `../Videogame-engineer`), in attesa del giudizio del proprietario.
- **Gate:** `tools/godot/Invoke-GodotChecks.ps1`: check-only, 58 suite con seme fisso, passo con finestra (Terrain3D e shader), smoke test. Ultimo gate completo verde il 18 ottobre, a fine piano A della carovana (58 suite, nessun rilancio).
- **Build:** Windows esportata il 18 ottobre in `LocalBuilds/Prototype01-Godot-Win64/` (exe 195 MB, avvio con `--autostart` pulito); la Linux in `-Linux/` e del 14 ottobre, senza la carovana.

**Audit del 14 ottobre:** `docs/REVIEWS/FULL_AUDIT_2026-10-14.md`.

## Playtest del proprietario (14 ottobre 2026, sera)

Esito **Modifica**: 16 osservazioni, cause e piano in `docs/PLAYTESTS/OWNER_PLAYTEST_2026-10-14.md` (viene prima dell'audit; ordine D-089: grafica, gioco, armi, audio).

**Fatto e dettagli** (blocchi 1-2, armi D-092, luce D-094, eventi D-097, carovana piano A): `docs/archive/STATUS_LOG_2026-10.md`.

## Prossimo passo (agente)

0. **Piano A della carovana (D-093) fatto il 18 ottobre** (`docs/superpowers/plans/2026-10-16-caravan-machines.md`). Numeri: carovana 0,24 ms per passo sul Deck con sei macchine e 20 robusti sul grappolo (budget 0,5; passo peggiore 6,9 ms quando Trivella, Pala e Sirena scattano insieme), 0,22 ms di notte con sei Faro e 13 luci; bot senza errori; nelle sei run di prova nessuna macchina presa (carte macchina quasi sempre con una carta arma, relitti a 54-114 m), nel seme 8 lo scrapper prende la Trivella da un relitto. Debito del benchmark nel piano: righe `frame`, `run`, `path` misurate a gioco fermo. Catture in `output/caravan/`. **Prossimo:** revisione finale del branch con le correzioni rimandate (elenco nel piano, sotto il task 10), poi i piani B (fusione) e C (colosso, eventi, Meccanico, Officina) dopo il playtest del proprietario. **Inondazione** (richiesta del 15 ottobre): spike di costo dell'acqua sul Deck, poi il design. Dopo: bilanciamento coi bot, playtest, musica scelta da lui. ProtonScatter approvato (D-090), da installare quando si spargono oggetti.
   **Grafica (richieste del 15 ottobre):** strumenti di D-095 uno alla volta con misura e catture (Effekseer solo per i boss, ProtonScatter, post-produzione, AreaLight3D di notte, Material Maker e Ucupaint); **carte degli upgrade da rifare** (D-096: bozze in cattura).
1. **Voci rimaste dell'audit**, nell'ordine della sua sezione 1: `docs/REVIEWS/FULL_AUDIT_2026-10-14.md`.
2. **Dopo la misura sul Deck:** V-02, V-03, V-06, Q-01, Q-03, Q-04 (costo GPU e contenuto del preset Deck).
3. **Dopo le decisioni del proprietario:** PF-01 (metodo del direttore dei nemici) e P-02 (regola di Scorta).

## Cosa aspetta il proprietario

0. **Playtest della carovana** (piano A fatto): Faro, carte Nuova macchina e di livello, colpi alle macchine, guasto, ritirata, riparazione tenendo X o R vicino a una guasta (1,5 s con 2 rottami, 4,5 s gratis con meno), striscia della carovana sopra le armi, Trivella, Pala, Saldatore, Sirena, relitti sepolti (telaio arrugginito e bagliore arancione). Catture da giudicare in `output/caravan/`. Elenco completo in archivio. **Da sapere:** in certe buche larghe una macchina resta incastrata finche non ti allontani di 20 m.
0. **Decidere** se le carte macchina devono battere i livelli delle armi (o se il bot scrapper deve avvicinarsi ai relitti con margine minore): fin li i bot prendono una macchina solo da un'offerta senza carte arma o da un relitto vicino.
0. **Carovana di macchine** (D-093): rileggere la spec (`docs/superpowers/specs/2026-10-15-caravan-machines-design.md`). **Confermare due scelte del piano A**, entrambe gia in gioco: luce di notte solo dai Faro (il carretto di partenza non ha piu il faro da 11 m di D-058) e riparazione gratis ma lenta (4,5 s invece di 1,5) sotto i 2 rottami. Dire se la striscia della carovana si legge e se il tasto Ripara deve tenere sempre il suo posto; se il Meccanico vede troppe carte Nuova macchina. **Scheda Gameplay** (D-097): dire se un evento di serie basta.
0. **Armi e classi** (D-092): provare la scelta della classe in campagna, l'Officina a schede, le casse sepolte e gli effetti del piano 5 (`output/weapons/fx/`); `--class=sapper|mechanic|weeder`. Da confermare: Fortino "al 70%" come cadenza, Polarita inversa che respinge di circa 2 m. Dettaglio in archivio.
1. **Luce (D-094):** giudicare in gioco o sulle catture `output/lighting_lab/`. **Carte degli upgrade (D-096):** scegliere fra le bozze quando arrivano.
1. **Musica:** ascoltare i candidati in `C:\Users\adgau\Desktop\Videogame-assets\music-candidates\` (LEGGIMI.md con licenze) e dire quali tenere (D-089).
2. **Giudizio sull'Ingegnere** (D-088): catture in `../Videogame-engineer/output/engineer/`.
3. **Playtest dei due livelli:** restano boss, notte, ferrovia e controller (`docs/PLAYTESTS/ARENA_RUN_LEVEL_2026-10-07.md`).
4. **Misura sul Steam Deck** con la build in `LocalBuilds/` e il Debug Menu (F3).
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
