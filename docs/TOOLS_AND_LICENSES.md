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
