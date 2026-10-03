# Analisi di migrazione a Godot

Data: 3 ottobre 2026. Stato: analisi completata, migrazione approvata, implementazione non iniziata.

Documento di riferimento per la Fase 1 ("Analisi del software esistente") del piano di migrazione. Descrive cosa viene ereditato dal prototipo Unreal e come viene trasferito.

## 1. Quadro generale

Il progetto ereditato e un micro-prototipo Unreal Engine 5.8.2 in C++ puro, fermo alla Fase 3 della roadmap. Non e un gioco: e un graybox tecnico che verifica una sola domanda di design, se modificare il terreno a celle da visuale isometrica sia leggibile e preciso con controller e mouse.

- **Codice:** 7 classi C++, circa 1.350 righe, in `Source/Prototype01/` (rimosso da `main` il 3 ottobre 2026, consultabile nel tag Git `unreal-prototype-final` (`git show unreal-prototype-final:Source/Prototype01/<file>`)).
- **Contenuto:** **un solo asset binario**, `Content/Maps/SmokeTest.umap`. Nessuna mesh, texture, materiale, audio, font, Blueprint o widget di progetto.
- **Documentazione:** 24 documenti in `docs/`, circa 4.000 righe. E l'asset piu prezioso del progetto e **non dipende dall'engine**: sopravvive integralmente.
- **Resto del repository:** circa 9,5 GB fra `Binaries/`, `DerivedDataCache/`, `Intermediate/`, `Saved/`, `LocalBuilds/`, tutto rigenerabile e gia escluso da Git.

La superficie realmente migrabile e quindi molto piccola. Il rischio della migrazione non e tecnico, e strategico.

## 2. Funzionalita esistenti

Implementate e verificate (fonte: codice e playtest Terrain Slice A, esito `Continua`).

**Personaggio** — movimento planare analogico a 600 u/s con accelerazione e frenata a 2048; orientamento indipendente dal movimento in stile twin-stick, con stick destro (dead zone 0.2, sensibilita e interpolazione configurabili) oppure mouse per deproiezione sul piano del personaggio; **commutazione automatica del dispositivo** basata su soglia di movimento, senza menu ne conferme; dash a 3000 u/s per 0,18 s con cooldown di 1,2 s misurato dall'attivazione, nella direzione dell'ultimo input valido; feedback dash esclusivamente visivo (corpo ingrandito 1,15x e ciano durante il dash, grigio in cooldown, arancione quando pronto); mesh a cubo con indicatore frontale ciano che risolve l'ambiguita del corpo simmetrico.

**Camera** — isometrica fissa, braccio 1500, pitch -55 gradi, rotazione assoluta non ereditata dal personaggio, nessuna collisione, nessuna rotazione libera.

**Terreno a celle** — griglia 7x7, cella 240, gap 12, dimensioni forzate dispari per garantire un centro esatto; tre stati per cella (`Lowered` 4, `Normal` 12, `Raised` 120) con colori distinti e **collisione solo su `Raised`**; tool a due modalita `Dig`/`Raise` che avanzano di **un passo per volta**, non un toggle; anteprima sulla cella bersaglio, ciano per Scava, gialla per Solleva, **rossa per comando impossibile**; bersaglio calcolato a 480 unita davanti al personaggio e **non sul cursore**, scelta che rende il targeting identico con mouse e controller ed e la ragione per cui il gate di parita input passa; cella protetta non modificabile; rifiuto del sollevamento quando la nuova geometria intersecherebbe il giocatore; penalita del 50% di velocita sulle celle `Lowered`.

**Hazard** — sfera che percorre una corsia rettilinea a 350 u/s, **fermata dalle celle `Raised`**, riavviata dopo 1 s riusando lo stesso attore; ignora il Pawn.

**Arena** — pavimento 6000x6000 con materiale a griglia, quattro pilastri angolari di colore diverso per l'orientamento, landmark direzionale sul lato +Y, luce direzionale calda, sky light con cattura real-time, atmosfera procedurale. Nessun asset esterno: tutto da primitive e materiali engine.

**Non implementato**, benche previsto dalla specifica: punti vita, morte, restart, invulnerabilita, arma automatica, nemici, macchina Terraformer, energia, annullamento, HUD, timer, audio, pausa, menu, impostazioni, rimappatura.

## 3. Architettura attuale

Flusso di avvio: la configurazione apre `/Game/Maps/SmokeTest` con `SmokeTestGameMode`, che disattiva l'eye adaptation, individua il pawn, **cerca gli attori gia piazzati in mappa** e li usa, spawnandoli solo come fallback d'emergenza; infine collega la griglia al personaggio e configura la corsia dell'hazard.

Pattern rilevanti:

- **tutto procedurale, zero asset**: ogni mesh e un cubo o una sfera engine scalata, ogni colore un material instance dinamico con parametro `Color`. E la caratteristica che rende la migrazione quasi indolore;
- **stato logico separato dalla presentazione** nella griglia: l'array degli stati e la verita, le mesh sono derivate;
- **parita Editor/PIE** ottenuta facendo passare entrambi per lo stesso codice di costruzione, con ricostruzione idempotente che impedisce la duplicazione dei componenti;
- **riferimento iniettato** invece di ricerca globale per frame;
- **Enhanced Input** con azioni e mapping creati in C++ a runtime, non come data asset.

## 4. Dati e persistenza

**Non esiste persistenza.** Verificato su tutto `Source/`: nessun salvataggio, nessun JSON, nessun file locale, nessun database, nessuna configurazione scritta a runtime.

Conseguenza: **nessun dato utente da migrare, nessun formato da preservare, nessuna compatibilita da mantenere.** Lo stato del terreno e volutamente transitorio e vive solo nella sessione.

Gli unici dati sono circa 25 parametri di tuning esposti come proprieta editabili sugli attori, che in Godot diventano `@export` con mappatura diretta, e la configurazione engine, interamente specifica di Unreal e banalmente riproducibile.

## 5. Integrazioni esterne

**Nessuna integrazione runtime**: niente API, rete, servizi web, Steamworks o analytics. Le dipendenze del modulo sono solo `Core`, `CoreUObject`, `Engine`, `InputCore`, `EnhancedInput`.

**Nessuna credenziale o segreto presente nel repository.**

Esistono solo integrazioni di tooling, che la migrazione rende obsolete: MCP Epic, Python Editor Scripting, plugin Aura. L'handoff Claude/Codex (`tools/ai/`) e indipendente dall'engine e sopravvive.

## 6. Struttura UI

**Non esiste UI**: nessun widget, menu, schermata o font. Tutto il feedback e diegetico, nel mondo 3D: direzione dall'indicatore frontale, stato del dash dal colore del corpo, bersaglio dalla placca di anteprima, modalita dal colore dell'anteprima, rifiuto dal rosso, stato delle celle da altezza e colore, orientamento dai pilastri colorati.

Questa scelta — informazione nel mondo invece che in overlay — e coerente con il vincolo di leggibilita a 1280x800 e **va preservata deliberatamente**. Non e una lacuna da riempire con un HUD durante la migrazione.

## 7. Problemi e debito tecnico

**Da risolvere prima di iniziare**

1. **Lavoro non committato**: gli attori della griglia e dell'hazard (circa 700 righe, Terrain Slice B) sono untracked e 13 file risultano modificati, inclusa la mappa binaria. Finche questo lavoro non e committato, il progetto originale non esiste in forma recuperabile.

**Debito architetturale**

2. **Input cablato in C++**: azioni e mapping costruiti a runtime con tasti letterali. Rimappatura, sensibilita, inversione assi e dead zone non sono previste nell'architettura, come invece richiesto. In Godot la mappatura input e una risorsa di progetto: **la migrazione risolve il debito per costruzione**.
3. **Il personaggio fa troppo** (501 righe): input, movimento, camera, dash, mira, targeting e modificatore di velocita in una sola classe.
4. **La GameMode compone il livello in codice**, mescolando regole di gioco e authoring di scena.
5. **Manca l'interfaccia condivisa tool/macchina** prevista dalla specifica: quando arrivera il Terraformer, duplichera la logica del tool.

**Bug e fragilita**

6. Cella protetta cablata a (0,0), non configurabile.
7. Residui di movimento Flying in un personaggio che cammina: codice morto fuorviante.
8. Fine dash brusca, con velocita azzerata di colpo invece che decelerata. Scelta di feel non documentata, da confermare e non da replicare ciecamente.
9. Stato del terreno azzerato al ridimensionamento della griglia, intenzionale ma non documentato.
10. L'hazard si dichiara `Pawn` ma ignora i Pawn, espediente fragile appena arriveranno nemici veri.
11. Numeri magici di gameplay sepolti in costanti locali della GameMode.
12. **Nessun test automatico** in tutto il progetto.
13. Discrepanza da chiarire fra l'ultimo commit, che annuncia una preview editoriale nella mappa, e il contenuto attuale del file.

## 8. Architettura Godot proposta

Principio guida: **replicare il comportamento, non la struttura Unreal.** Una traduzione uno a uno produrrebbe un progetto Godot scritto in dialetto Unreal.

```
res://
  scenes/
    main/      smoke_test.tscn, game_root.tscn
    actors/    player.tscn, terrain_grid.tscn, terrain_hazard.tscn, arena.tscn
    ui/        (vuoto: nessuna UI esistente)
  scripts/
    player/    player_controller, planar_movement, aim_controller,
               dash_ability, terrain_tool
    terrain/   terrain_grid, terrain_state, terrain_presentation,
               terrain_preview, terrain_modifier
    services/  input_device_tracker, game_log
  resources/
    tuning/    .tres di movimento, dash, griglia, hazard
    materials/ materiali graybox
  assets/      (vuoto: il progetto non ha asset)
```

La scomposizione del personaggio in componenti e della griglia in stato/presentazione/anteprima risolve i punti 3 e 5 del debito e realizza finalmente la separazione gia richiesta dalla specifica del prototipo.

### Mappature tecniche non ovvie

| Unreal | Godot | Nota |
|---|---|---|
| `ACharacter` + CharacterMovement | `CharacterBody3D` + `move_and_slide()` | del componente Unreal si usa una frazione: nessuna perdita |
| **centimetri, Z-up, X-forward** | **metri, Y-up, -Z-forward** | `1 uu = 0.01 m` e rimappatura assi: **principale fonte di errore della migrazione**, da centralizzare e verificare subito |
| Enhanced Input in C++ | mappa input di progetto + `Input.get_vector()` | risolve il debito 2: dead zone per azione e rimappatura native |
| SpringArm con rotazione assoluta | `Node3D` pivot con `top_level = true` + `Camera3D` | niente `SpringArm3D`: il collision test e disattivato |
| deproiezione del mouse | `Camera3D.project_ray_*` + `Plane.intersects_ray()` | equivalente diretto |
| material instance dinamico | `set_instance_shader_parameter()` | evita di duplicare materiali per cella |
| luce + sky light + atmosfera | `DirectionalLight3D` + `WorldEnvironment` | resa simile, non identica; auto-esposizione disattivata |
| costruzione condivisa Editor/PIE | `@tool` + `_ready()` | **conserva la parita editor/gioco** |
| timer | `Timer` o `create_timer()` | |
| spostamento con sweep | `move_and_collide()` | per l'hazard |
| primitive engine | `BoxMesh`, `SphereMesh` | nessuna dipendenza da contenuto engine: miglioramento |
| `.umap` binario | `.tscn` testuale | diffabile e modificabile direttamente |

**GDScript**, non C#: il progetto non ha un solo percorso misurato come critico.

## 9. Piano di migrazione

Incrementale, ogni fase verificabile. Il progetto Unreal resta **intatto per tutta la durata**; il progetto Godot vive in `godot/` nello stesso repository.

| Fase | Contenuto | Verifica di uscita |
|---|---|---|
| 0 | Mettere in sicurezza il lavoro non committato; registrare le decisioni; installare la toolchain | working tree pulito, Slice B in `git log`, Godot verificato |
| 1 | Analisi | questo documento |
| 2 | Architettura: conversione unita e assi, struttura, formato delle risorse di tuning | nota breve approvata |
| 3 | Scheletro: progetto, mappa input completa, autoload, scena avviabile | il progetto parte senza errori, le azioni rispondono |
| 4 | Arena, illuminazione, camera isometrica | screenshot confrontabile con la build Unreal |
| 5 | Personaggio: movimento, mira, commutazione dispositivo, dash | **parita di feel** verificata dal proprietario con entrambi gli schemi |
| 6 | Griglia: stato, presentazione, collisione, cella protetta | 49 celle, 3 stati, nessun duplicato |
| 7 | Tool e anteprima | si ripercorre invariato il Test A del protocollo di playtest Slice A |
| 8 | Slice B: penalita velocita, hazard, blocco su `Raised` | l'hazard si ferma su un terrapieno alzato dal giocatore |
| 9 | Verifica, export template, build, smoke test Steam Deck | nessuna funzione della sezione 2 risulta mancante |
| 10 | Pulizia documentale e decisione sull'archiviazione del progetto Unreal | nessun riferimento orfano |

**Migra direttamente:** stato logico e regole di transizione della griglia, cella protetta, colori e soglie, parametri di tuning, logica di anteprima, corsia dell'hazard, composizione dell'arena, camera, mira per deproiezione, logica del dash.

**Richiede implementazione diversa:** sistema di input (da codice a dati, piu semplice), materiali per istanza, cielo e illuminazione (resa simile, non identica), parita editor/gioco, composizione della scena, sweep dell'hazard.

**Da ricostruire o abbandonare:** l'automazione editor basata su MCP Epic, Aura e script Python.

## 10. Rischi e decisioni

| ID | Rischio | Gravita | Nota |
|---|---|---|---|
| R-G1 | **Resa grafica** senza Lumen e Nanite rispetto al riferimento dichiarato in `ART_DIRECTION.md` | **alta** | raggiungibile con illuminazione progettata e bake, ma con lavoro diverso e piu manuale. Invisibile in graybox, si manifestera alla vertical slice. **E il rischio principale della migrazione** |
| R-G2 | Perdita dell'automazione editor | media | compensata ampiamente dalle scene testuali, direttamente modificabili e revisionabili |
| R-G3 | Lavoro Slice B non committato | media, immediata | da risolvere per primo |
| R-G4 | Deriva del feel del personaggio | media | l'unica cosa validata da un playtest; la parita non e automatica e va playtestata, non dichiarata |
| R-G5 | Documentazione contraddittoria | media | affrontata dalla revisione del 3 ottobre 2026 |
| R-G6 | Conversione unita e assi | media | mitigabile centralizzando la conversione in Fase 2 |
| R-G7 | Curva di apprendimento | bassa | GDScript e piu accessibile di C++/Unreal per il profilo del proprietario: e un vantaggio |

Decisioni gia prese: migrazione approvata, Godot 4.7.2 standard, GDScript, stesso repository, MCP rimandato con trigger definito (vedi `DECISIONS.md` e `GODOT_WORKFLOW.md`).

Decisioni ancora aperte: destino del progetto Unreal dopo la Fase 9; build Linux nativa invece di Proton per Steam Deck, resa possibile dall'export nativo di Godot e da valutare contro `PLATFORM_AND_INPUT.md`.
