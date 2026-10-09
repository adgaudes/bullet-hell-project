# Strumenti, dipendenze e licenze

## Scopo

Questo documento registra gli strumenti rilevati, approvati, proposti o rimandati. Le versioni rilevate descrivono il computer di sviluppo al 22 settembre 2026; prima di aggiornare un componente critico verificare la compatibilita con l'engine. **Dal 3 ottobre 2026 l'engine e Godot 4.7.2 (D-019)**: il codice Unreal e stato rimosso da `main` (tag `unreal-prototype-final`), Unreal Engine resta installato e Visual Studio e stato disinstallato (D-027).

Stati usati:

- **Installato**: rilevato sul computer.
- **In installazione**: operazione avviata dal proprietario.
- **Da installare**: necessario o raccomandato per la fase corrente.
- **Opzionale**: utile ma non giustificato immediatamente.
- **Rimandato**: da rivalutare a una milestone successiva.

## Inventario rilevato

| Strumento | Versione/stato | Uso previsto | Decisione |
|---|---|---|---|
| Godot Engine | 4.7.2 stable, standard/GDScript, via winget | Engine, editor, test headless, export Windows e Linux | Installato e verificato il 3 ottobre 2026; export template Windows/Linux x86_64 installati. Licenza MIT, nessun costo. Vedi `GODOT_WORKFLOW.md` |
| Unreal Engine | 5.8.2 | Riferimento del prototipo migrato | Installato; compilazione Editor/Game C++, caricamento mappa, cook, packaging e avvio build Windows verificati il 22 settembre 2026 |
| Fab UE plugin | Incluso in UE 5.8.2 | Ricerca e import di asset Fab | Installato; apertura e import in Editor da verificare |
| Quixel Bridge UE plugin | Incluso in UE 5.8.2 | Accesso e import dei contenuti Megascans compatibili | Installato; apertura e import in Editor da verificare |
| Epic Games Launcher | 1.3.193.0 | Installazione e aggiornamento UE | Installato |
| Blender | 5.2.2 LTS (`C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`) | Asset statici generati da script (`tools/blender/`), export `.glb` | In uso dal 4 ottobre 2026 (D-037); GPL, gli asset prodotti sono nostri |
| Universal Animation Library (Quaternius) | Standard 1.0, variante Godot, dal Godot Asset Store (6 ottobre 2026) | Scheletro umanoide e animazioni dei personaggi (`tools/blender/build_character_assets.py`, D-060) | In uso; **CC0 1.0**, nessun costo, nessuna attribuzione dovuta (autore: Quaternius, https://quaternius.com). Sorgente in `tools/blender/third_party/quaternius_ual/` con `License.txt`; non e un addon: nelle build entrano solo le animazioni dentro i `.glb`. La versione Pro (a pagamento, 120+ animazioni, corsa in 8 direzioni) non e acquistata |
| MCP for Blender (`ahujasid/blender-mcp`, pacchetto `mcp-for-blender`) | Addon 1.8 in `%APPDATA%/Blender Foundation/Blender/5.2/scripts/addons/blender_mcp.py`, abilitato; server registrato in Claude Code per questo progetto (`claude mcp get blender`: connesso) | Pilotare un Blender aperto da Claude Code: modellare vedendo il viewport, ispezionare scene (D-061) | Installato il 6 ottobre 2026 su richiesta del proprietario. **MIT**, nessun costo, uso commerciale libero. Solo strumento di sviluppo: non entra nel gioco ne nelle build. Telemetria spenta del tutto (`DISABLE_TELEMETRY=true` nella configurazione del server; consenso dell'addon non dato). Esegue codice arbitrario dentro Blender: usarlo solo su file del progetto. Uso in `GODOT_WORKFLOW.md` |
| Rigify | Incluso in Blender 5.2.2, abilitato nelle preferenze il 6 ottobre 2026 | Scheletri con controlli per animare a mano; scheletri non umanoidi (D-061) | GPL come Blender, nessun costo; gli asset prodotti sono nostri. Non ancora usato: lo scheletro in uso viene dalla libreria Quaternius, che deriva gia da Rigify (ossa `DEF-*`) |
| Visual Studio Code | 1.137.0 x64 | Testo, configurazioni e modifiche leggere | Installato; non IDE primario UE C++ |
| Claude Desktop | Installato; versione da rilevare | Confronto, pianificazione e revisione con Claude | Disponibile con piano Claude Pro |
| Claude Code CLI | 2.1.278 | Delega controllata di implementazione, test e documentazione | Installato e autenticato con Claude.ai Pro; `doctor` non rileva problemi. I `ConnectionRefused` del 21 settembre 2026 erano causati dall'esecuzione nel sandbox senza rete: il canale funziona con autorizzazione di rete esplicita. Nessuna API PAYG configurata |
| Google Antigravity | 2.12.2 | Orchestrazione di agenti, task asincroni e browser agent | Installato; canale AI secondario |
| Google Antigravity IDE | 2.5.5 | Editing agentico e task locali sul repository | Installato; non sostituisce Visual Studio per UE C++ |
| Git | 2.55.0 | Versionamento | Installato |
| Git LFS | 3.7.1 | Asset binari | Installato e configurato nel repository |
| Git Credential Manager | 2.9.1 | Autenticazione remota | Installato |
| Visual Studio Community 2022 | Rimossa il 22 settembre 2026 | Precedente toolchain UE 5.6 | Non piu necessaria; rimozione verificata con `vswhere` e build successiva |
| Visual Studio Community 2026 | Disinstallato il 3 ottobre 2026 su richiesta del proprietario | Toolchain C++ del prototipo Unreal | Non serve al progetto Godot. Verificato: `vswhere` non rileva istanze, cartella di installazione assente. Senza Visual Studio il codice C++ Unreal (tag `unreal-prototype-final`) non e piu compilabile su questo PC; Unreal Engine resta installato |
| IncrediBuild | Rimosso il 22 settembre 2026 | Accelerazione distribuita di build, shader e cook | Non necessario nella fase corrente con un solo PC e poco codice; riproporre solo se tempi misurati diventano un collo di bottiglia |
| GitHub CLI | Non installato/rilevato, verifica del 21 settembre 2026 | Issue, pull request e automazione GitHub | Opzionale; non serve ora perche Git e Git Credential Manager coprono il flusso corrente |

Spazio libero rilevato sul disco di progetto: circa 620 GB, sufficiente per la fase iniziale. Hardware rilevato: Intel Core i7-13620H, 16 GB RAM, RTX 4050 Laptop con 6 GB VRAM.

Audit repository del 21 settembre 2026: Git LFS 3.7.1 configurato e integro; il branch remoto `feature/terrain-grid-slice` al commit `40b7682` e stato clonato in un percorso pulito, inclusa la mappa LFS, quindi compilato e avviato headless con successo. La copia temporanea e stata rimossa dopo la verifica.

## Addon Godot installati (`godot/addons/`)

Installati il 6 ottobre 2026 su richiesta del proprietario (D-057). Tutti gratuiti, licenza MIT, sorgente pubblico; copiati nel repository, nessun download a runtime. Verifica: import in Godot 4.7.2, suite `godot/tests/addons_tests.gd`, catture con finestra, export Windows e Linux, smoke test della build Windows. **Steam Deck non verificato.**

| Addon | Versione | Fonte | Licenza | Stato | A cosa serve |
|---|---|---|---|---|---|
| Debug Menu (Calinou) | 1.2.0, commit `ff12461` del 19 novembre 2025 | <https://github.com/godot-extended-libraries/godot-debug-menu> | MIT | **Attivo** (autoload `DebugMenu`) | Overlay con fps, frametime, grafici CPU/GPU e hardware; **F3** cicla nascosto / compatto / dettagliato. Serve alla misura su Steam Deck |
| Controller Icons (rsubtil) | 3.1.8 del 28 luglio 2026 | <https://github.com/rsubtil/controller_icons> | MIT; per le icone vedi `godot/addons/controller_icons/LICENSE` | **Attivo** (autoload `ControllerIcons`), usato da `ButtonPrompts` in menu e HUD (D-059) | Glifi dei tasti che seguono il dispositivo in uso (Xbox, PlayStation, Switch, Steam Deck, tastiera e mouse) |
| Debug Draw 3D (DmitriySalnikov) | 1.7.3 del 4 aprile 2026 | <https://github.com/DmitriySalnikov/godot_debug_draw_3d> | MIT | **Attivo** (GDExtension, si carica da sola), non ancora usato dal gioco | Linee, scatole, sfere e testo di debug in 3D (`DebugDraw3D.draw_*`). Nelle build release la libreria e uno stub che non disegna nulla |
| SimpleGrassTextured (IcterusGames) | 2.1.0 del 3 aprile 2026 | <https://github.com/IcterusGames/SimpleGrassTextured> | MIT | **Installato, plugin non attivo**, escluso dagli export | Erba dipinta nell'editor. **Valutato il 9 ottobre 2026 per la seconda passata artistica (D-068) e non adottato**: si dipinge a mano nell'editor e l'arena e procedurale dal seme; l'erba a lame e fatta in casa (`grass_blades.gdshader`, texture generata da codice, stesso MultiMesh). Da rivalutare per scene fisse (menu, livelli disegnati a mano) o per l'interazione erba-giocatore che l'addon offre. Attivarlo aggiunge un autoload, uniformi globali e un layer di rendering: misurarne il costo |

Scostamenti dai pacchetti originali: di Debug Draw 3D sono incluse solo le librerie Windows e Linux x86_64 (niente macOS, Android, iOS, web, arm64, ne `native_api`); esempi e demo non copiati. Le librerie native (`*.dll`, `*.so`) sono in Git LFS.

Aggiornare un addon: scaricare la release in una cartella temporanea, sostituire la cartella in `godot/addons/`, rieseguire `--editor --quit` e il gate, aggiornare questa tabella.

### Regola: cercare addon utili e proporli

A ogni nuovo task l'agente controlla se nell'Asset Library o nell'Asset Store di Godot (o su GitHub) esiste un addon o un asset che farebbe meglio o prima, e **lo propone al proprietario quando pensa che convenga scaricarlo**: beneficio concreto, licenza, costo (solo gratuiti; quelli a pagamento si propongono e basta), manutenzione, compatibilita con Godot 4.7.x, Windows, Linux e Steam Deck. Si scarica dopo il suo si. Anche "valutato, non serve" va annotato quando la domanda e ricorrente.

Valutati e non adottati il 7 ottobre 2026 per il ciclo giorno/notte (D-058, `docs/DAY_NIGHT_PLAN.md`; giudizio dell'agente dai repository e dall'Asset Library, senza prova pratica, Godot non disponibile):

- **Sky3D** (TokisanGames, MIT con attribuzione per la mappa stellare, v2.1.0 del 19 maggio 2025, "Godot 4.3+", Forward+, Mobile e Compatibility; <https://github.com/TokisanGames/Sky3D>): il candidato serio se servisse un cielo vero. Sostituisce il `WorldEnvironment` (va rimosso) con cupola, sole, luna, stelle, nuvole, nebbia e orologio propri. **Non adottato**: la camera isometrica vede pochissimo cielo; l'ambiente del quartiere (nebbia di profondita, SSAO, glow, tonemap, cielo procedurale) e costruito da `OvergrownArena` e andrebbe rifatto dentro Sky3D; il suo orologio astronomico duplica `ArenaRun.elapsed` per una sola notte a livello; costo del cielo dinamico non misurato su Steam Deck. Il piano prevede un `DayNightCycle` di circa 100 righe che interpola i nodi gia esistenti. **Da rivalutare** se la campagna chiede cieli, nuvole o meteo visibili (`WORLD_PREMISE.md` parla di meteo) o livelli con piu cicli.
- **Day & Night Cycle** (maetzemax, MIT, ultimo commit 6 ottobre 2025, Asset Library per Godot 4.5; <https://github.com/maetzemax/day-and-night-cycle>): modula un `WorldEnvironment` con `ProceduralSkyMaterial` e una `DirectionalLight3D` esistenti con preset giorno/notte. E vicino a cio che serve, ma fa meno del piano (niente fase a soglia, niente `night_factor` da esporre, niente nebbia) e aggiungerebbe una dipendenza per il lavoro di un pomeriggio. **Non adottato.**
- **Dynamic Day Night Cycles**, **Day Night Cycle & Season System**, **TimeTick** (Asset Library): simulazioni di calendario, stagioni ed equazione del tempo o orologi generici; fuori misura per una notte per livello guidata dal tempo di `ArenaRun`. **Non adottati.**

Valutati e non adottati il 6 ottobre 2026 (giudizio dell'agente, senza prova pratica): GUT e gdUnit4 (le suite proprie e il gate bastano), Terrain3D (heightmap, incompatibile con la griglia discreta), Phantom Camera e Dialogue Manager (nessun bisogno attuale), Godot Jolt (gia integrato nell'engine). Da rivalutare piu avanti: GodotSteam (all'apertura della pagina Steam), LimboAI (se boss e compagno superano il codice attuale), Voxel Tools di Zylann (voce "terrain voxel" del radar).

## Migrazione UE 5.8.2 e Visual Studio 2026 (storico)

Sezione storica: il progetto Godot non richiede Visual Studio ne MSVC.

La precedente combinazione Unreal Engine 5.6.1 e Visual Studio 2022 e stata sostituita il 22 settembre 2026 da Unreal Engine 5.8.2 e Visual Studio Community 2026. I target `Prototype01` e `Prototype01Editor` fissano `VisualStudio2026` e la famiglia MSVC `14.51.36231`, evitando selezioni silenziose della toolchain precedente.

Selezionare il workload:

- **Game development with C++**.

Verificare i componenti:

- MSVC v143 C++ build tools per x64/x86;
- Windows 11 SDK 10.0.22621.0 o successivo compatibile;
- Visual Studio Tools for Unreal Engine;
- Visual Studio debugger tools for Unreal Engine Blueprints;
- Unreal Engine Test Adapter;
- C++ profiling tools;
- C++ AddressSanitizer.

Non selezionare per ora:

- workload Unity;
- SDK Android, iOS o console;
- MAUI e sviluppo mobile;
- Incredibuild;
- un secondo installer di Unreal Engine dentro Visual Studio;
- componenti cloud non richiesti dal progetto.

Componenti verificati il 21 settembre 2026:

- workload Game development with C++;
- MSVC x64/x86 14.44.35207, compilatore 19.44.35229;
- linker x64 14.44.35229;
- MSBuild 17.14.60;
- Windows 11 SDK 10.0.26100;
- Visual Studio Tools for Unreal Engine;
- Blueprint debugger tools;
- Unreal Engine Test Adapter;
- C++ AddressSanitizer;
- C++ diagnostic/profiling tools;
- HLSL tools.

Visual Studio 2022 resta documentato come toolchain precedentemente validata; non e piu richiesto dal progetto dopo i test UE 5.8.2 riportati in `SMOKE_TEST_UE58_2026-09-22.md`.

Visual Studio Community 2026 e stato inizialmente disinstallato il 21 settembre 2026 perche UE 5.6 non lo supportava, poi reinstallato il 22 settembre 2026 in preparazione alla migrazione a UE 5.8.2. L'istanza 18.10.1 risulta completa, avviabile e senza riavvio richiesto. Sono verificati workload Game development with C++, MSVC 14.51.36231, Windows 11 SDK 10.0.22621/26100/28000, strumenti Unreal, debugger Blueprint, Unreal Engine Test Adapter, AddressSanitizer, diagnostica/profiling e HLSL. In Visual Studio 2026 l'identificatore interno del test adapter e `Microsoft.VisualStudio.Component.Unreal.TestAdapter`.

Visual Studio 2022 e stato rimosso il 22 settembre 2026. `vswhere` rileva soltanto Visual Studio Community 2026, completo, avviabile e senza riavvio richiesto. Dopo la rimozione sono riusciti build incrementale, cook, packaging e avvio headless; AutomationTool usa `Visual Studio\18\Community\MSBuild`.

IncrediBuild, installato inizialmente come componente opzionale, e stato rimosso il 22 settembre 2026. Registro applicazioni, componente Visual Studio e cartella di installazione risultano assenti. Rivalutarlo in futuro soltanto sulla base di profiling dei tempi e di un vantaggio concreto rispetto a Unreal Build Accelerator, build incrementali, Live Coding e cache locali.

## Dipendenze da non installare separatamente ora

- Redistributable e prerequisiti runtime UE: l'installazione da Epic Games Launcher include normalmente i prerequisiti necessari.
- .NET SDK: Unreal include o gestisce le dipendenze necessarie alla propria toolchain; installarne uno separato solo in risposta a un requisito verificato.
- CMake o Ninja: non necessari al normale progetto UE, che usa UnrealBuildTool.
- Python separato: Blender include il proprio runtime Python; Unreal fornisce il proprio ambiente per gli strumenti editor quando il plugin Python e abilitato.
- Plugin Blender-Unreal: rimandare fino al test manuale FBX/glTF, per evitare incompatibilita con Blender 5.2.2.

## Tool radar

| Strumento | Priorita | Quando rivalutarlo | Motivo |
|---|---|---|---|
| PureRef 2.x Small Business | Rimandato, a pagamento | Quando una moodboard dedicata giustifica il costo | La licenza Personal e solo per uso personale; il progetto Steam richiede uso commerciale |
| GitHub CLI | Opzionale | Primo flusso branch/PR con Claude | Automatizzare issue, PR e review |
| Krita | Opzionale | Se scegliamo sprite o concept paint 2D | Produzione e modifica raster |
| MCP Godot (`tugcantopaloglu/godot-mcp`) | Rimandato | Trigger in `GODOT_WORKFLOW.md` | Ispezione di un gioco in esecuzione; non necessario oggi |
| Mixamo (Adobe) | In uso dal 6 ottobre 2026: cinque animazioni scaricate dal proprietario | Animazioni umanoidi che la libreria Quaternius gratuita non ha (D-062) | Servizio web gratuito anche per uso commerciale, con l'account Adobe del proprietario: l'agente non gestisce account ne credenziali. **Vietato ridistribuire i file grezzi**: gli FBX in `tools/blender/third_party/mixamo/` vanno tolti dal repository prima di renderlo pubblico. Flusso: il proprietario scarica in FBX Binary, Without Skin, 30 fps, In Place; l'agente aggiunge il file a `MIXAMO_CLIPS` in `build_character_assets.py` |
| Generatori 3D AI (Tripo, Meshy) | Rimandato, a pagamento per uso commerciale | Se i pezzi rigidi non bastano per volti e forme organiche | Licenze dei piani gratuiti da verificare; il modello generato va comunque ripulito e riggato |
| Substance 3D Painter | Rimandato | Dopo art direction 3D approvata | Texturing avanzato, costo ricorrente |
| Reaper/Audacity | Rimandato | Primi file audio veri (il primo audio, D-048, e sintetizzato nel codice e non ha asset) | Editing audio |
| FMOD/Wwise | Rimandato | Solo con requisito audio non coperto da Godot | Evitare middleware prematuro |
| OBS Studio | Rimandato | Playtest registrati e materiale store | Cattura gameplay |
| DaVinci Resolve | Rimandato | Trailer e marketing | Montaggio video |
| Perforce | Rimandato | Solo se Git LFS/locking diventa insufficiente | Gestione di grandi volumi binari |
| Steam Deck LCD | Disponibile; capacita da rilevare | Dalla prima build Windows pacchettizzata | Dispositivo di riferimento per test reali di Proton, prestazioni, input, UI e sospensione |
| SteamOS Devkit Client | Rimandato, gratuito | Prima distribuzione frequente sullo Steam Deck disponibile | Distribuzione e debug della build dal PC Windows al dispositivo |
| Soluzione terrain voxel/runtime | Da ricercare, non installare ora | Dopo il prototipo discreto e prima della vertical slice | Confronto build-vs-buy per deformazione continua; verificare Godot 4.x, sorgente, licenza, Windows, Linux/Proton e Steam Deck |
| Aura di Ramen VR (`tryaura.dev`) | 1.0.6 installato a livello engine Unreal | Obsoleto con il passaggio a Godot | Plugin commerciale con funzioni aggiuntive, costo, lock-in e superficie dati maggiori. I suoi MCP restano scollegati; nessun acquisto o piano approvato |
| Unreal MCP ufficiale Epic | Configurato e validato in passato | Obsoleto con il passaggio a Godot (D-020) | Plugin sperimentali `ModelContextProtocol` e `AllToolsets` abilitati nel progetto; build, auto-start, handshake MCP `2025-06-18`, scoperta toolset e ciclo reversibile Start/Stop PIE verificati il 22 settembre 2026 su `http://127.0.0.1:8000/mcp`; Codex richiede approvazione per le scritture |

## Librerie di asset esterni

Le librerie di asset gratuiti possono essere valutate quando risolvono un bisogno concreto di prototipo o produzione. Prima dell'importazione stabile registrare:

- URL, autore e data di acquisizione;
- testo o identificatore della licenza e conferma dell'uso commerciale;
- requisiti di attribuzione e limiti alla redistribuzione dei sorgenti;
- versione e formati disponibili;
- modifiche necessarie per stile, scala, materiali, collisioni e prestazioni;
- decisione condivisa: placeholder, adottato, da modificare o rifiutato.

Evitare download massivi preventivi. Cercare un asset soltanto dopo aver definito il problema, confrontare poche alternative e provarlo in una scena isolata prima di inserirlo nel progetto principale.

## Fonti ufficiali

- [Epic Games - Visual Studio per progetti C++ Unreal](https://dev.epicgames.com/documentation/unreal-engine/setting-up-visual-studio-development-environment-for-cplusplus-projects-in-unreal-engine)
- [Microsoft - Visual Studio Tools for Unreal Engine](https://learn.microsoft.com/en-us/visualstudio/gamedev/unreal/get-started/vs-tools-unreal-overview)
- [Microsoft - Installare Visual Studio Tools for Unreal Engine](https://learn.microsoft.com/en-us/visualstudio/gamedev/unreal/get-started/vs-tools-unreal-install)
- [Epic Games - Versioni Visual Studio supportate per Unreal Engine](https://dev.epicgames.com/documentation/unreal-engine/setting-up-visual-studio-development-environment-for-cplusplus-projects-in-unreal-engine)

Licenze, prezzi e compatibilita devono essere ricontrollati prima di acquisti o aggiornamenti maggiori.
