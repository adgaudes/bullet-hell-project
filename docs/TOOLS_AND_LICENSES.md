# Strumenti, dipendenze e licenze

## Scopo

Questo documento registra gli strumenti rilevati, approvati, proposti o rimandati. Le versioni rilevate descrivono il computer di sviluppo al 21 settembre 2026; prima di aggiornare un componente critico verificare la compatibilita con Unreal Engine 5.6.

Stati usati:

- **Installato**: rilevato sul computer.
- **In installazione**: operazione avviata dal proprietario.
- **Da installare**: necessario o raccomandato per la fase corrente.
- **Opzionale**: utile ma non giustificato immediatamente.
- **Rimandato**: da rivalutare a una milestone successiva.

## Inventario rilevato

| Strumento | Versione/stato | Uso previsto | Decisione |
|---|---|---|---|
| Unreal Engine | 5.6.1 | Engine e packaging Windows | Installato; compilazione C++, cook, packaging e avvio build Windows verificati |
| Fab UE plugin | 0.0.9, incluso in UE 5.6.1 | Ricerca e import di asset Fab | Installato e abilitato di default; test in Editor da eseguire |
| Quixel Bridge UE plugin | 2025.0.1, incluso in UE 5.6.1 | Accesso e import dei contenuti Megascans compatibili | Installato e abilitato di default; test in Editor da eseguire |
| Epic Games Launcher | 1.3.193.0 | Installazione e aggiornamento UE | Installato |
| Blender | 5.2.2 registrato; eseguibili 5.1 e 5.2 presenti | Modellazione, UV, rig, animazione, export | Installato; fissare 5.2.2 dopo test pipeline |
| Visual Studio Code | 1.137.0 x64 | Testo, configurazioni e modifiche leggere | Installato; non IDE primario UE C++ |
| Claude Desktop | Installato; versione da rilevare | Confronto, pianificazione e revisione con Claude | Disponibile con piano Claude Pro |
| Claude Code CLI | 2.1.278 | Delega controllata di implementazione, test e documentazione | Installato e autenticato con Claude.ai Pro; `doctor` non rileva problemi. I `ConnectionRefused` del 21 settembre 2026 erano causati dall'esecuzione nel sandbox senza rete: il canale funziona con autorizzazione di rete esplicita. Nessuna API PAYG configurata |
| Google Antigravity | 2.12.2 | Orchestrazione di agenti, task asincroni e browser agent | Installato; canale AI secondario |
| Google Antigravity IDE | 2.5.5 | Editing agentico e task locali sul repository | Installato; non sostituisce Visual Studio per UE C++ |
| Git | 2.55.0 | Versionamento | Installato |
| Git LFS | 3.7.1 | Asset binari | Installato e configurato nel repository |
| Git Credential Manager | 2.9.1 | Autenticazione remota | Installato |
| Visual Studio Community 2022 | 17.14.41, MSVC 14.44.35207, MSBuild 17.14.60 | Compilazione e debugging UE 5.6 C++ | Installato e verificato; IDE/toolchain primaria |
| Visual Studio Community 2026 | 18.10.1, MSVC 14.51.36231 | Compilazione e debugging UE 5.8 C++ | Installato e completo il 22 settembre 2026; workload Game development with C++, strumenti Unreal, debugger Blueprint, test adapter, ASan, profiling, HLSL e Windows SDK verificati. Diventera la toolchain primaria dopo la migrazione validata a UE 5.8.2 |
| IncrediBuild | Installato come componente opzionale di VS 2026 | Accelerazione distribuita di build, shader e cook | Non necessario nella fase corrente con un solo PC e poco codice. Rimuovere durante la pulizia post-migrazione; riproporre solo se tempi misurati di compilazione, shader o packaging diventano un collo di bottiglia |
| GitHub CLI | Non installato/rilevato, verifica del 21 settembre 2026 | Issue, pull request e automazione GitHub | Opzionale; non serve ora perche Git e Git Credential Manager coprono il flusso corrente |

Spazio libero rilevato sul disco di progetto: circa 620 GB, sufficiente per la fase iniziale. Hardware rilevato: Intel Core i7-13620H, 16 GB RAM, RTX 4050 Laptop con 6 GB VRAM.

Audit repository del 21 settembre 2026: Git LFS 3.7.1 configurato e integro; il branch remoto `feature/terrain-grid-slice` al commit `40b7682` e stato clonato in un percorso pulito, inclusa la mappa LFS, quindi compilato e avviato headless con successo. La copia temporanea e stata rimossa dopo la verifica.

## Visual Studio 2022 - verifica completata

Per Unreal Engine 5.6 usare Visual Studio 2022. La matrice ufficiale Epic indica 17.8 come minimo e 17.14 come versione raccomandata/predefinita; Visual Studio 2026 e indicato come non supportato per UE 5.6. Installazione rilevata: Community 2022 17.14.41, quindi perfettamente allineata alla raccomandazione.

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

Visual Studio Installer indica l'istanza 2022 come completa, avviabile e senza riavvio richiesto. La verifica definitiva e stata completata il 21 settembre 2026 con compilazione Editor e Game, cook, packaging Windows Development e avvio della build; risultati in `SMOKE_TEST_2026-09-21.md`.

Visual Studio Community 2026 e stato inizialmente disinstallato il 21 settembre 2026 perche UE 5.6 non lo supportava, poi reinstallato il 22 settembre 2026 in preparazione alla migrazione a UE 5.8.2. L'istanza 18.10.1 risulta completa, avviabile e senza riavvio richiesto. Sono verificati workload Game development with C++, MSVC 14.51.36231, Windows 11 SDK 10.0.22621/26100/28000, strumenti Unreal, debugger Blueprint, Unreal Engine Test Adapter, AddressSanitizer, diagnostica/profiling e HLSL. In Visual Studio 2026 l'identificatore interno del test adapter e `Microsoft.VisualStudio.Component.Unreal.TestAdapter`.

Visual Studio 2022 resta temporaneamente installato perche il progetto autorevole e ancora associato a UE 5.6.1, che non supporta VS 2026. Rimuoverlo soltanto dopo installazione UE 5.8.2, conversione su copia/branch, compilazione, cook, packaging e avvio riusciti con la nuova toolchain.

IncrediBuild e stato installato come componente opzionale insieme a VS 2026, ma non e adottato dal progetto. Il proprietario ne ha approvato la rimozione durante la stessa pulizia post-migrazione. Rivalutarlo in futuro soltanto sulla base di profiling dei tempi e di un vantaggio concreto rispetto a build incrementali, Live Coding e cache locali.

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
| JetBrains Rider | Rimandato | Se Visual Studio rallenta il flusso C++ | Alternativa UE a pagamento |
| Substance 3D Painter | Rimandato | Dopo art direction 3D approvata | Texturing avanzato, costo ricorrente |
| Reaper/Audacity | Rimandato | Primo audio pass | Editing audio |
| FMOD/Wwise | Rimandato | Solo con requisito audio non coperto da UE | Evitare middleware prematuro |
| OBS Studio | Rimandato | Playtest registrati e materiale store | Cattura gameplay |
| DaVinci Resolve | Rimandato | Trailer e marketing | Montaggio video |
| Perforce | Rimandato | Solo se Git LFS/locking diventa insufficiente | Gestione di grandi volumi binari |
| Steam Deck LCD | Disponibile; capacita da rilevare | Dalla prima build Windows pacchettizzata | Dispositivo di riferimento per test reali di Proton, prestazioni, input, UI e sospensione |
| SteamOS Devkit Client | Rimandato, gratuito | Prima distribuzione frequente sullo Steam Deck disponibile | Distribuzione e debug della build dal PC Windows al dispositivo |
| Soluzione terrain voxel/runtime | Da ricercare, non installare ora | Dopo il prototipo discreto e prima della vertical slice | Confronto build-vs-buy per deformazione continua; verificare UE 5.6, sorgente, licenza, Windows, Proton e Steam Deck |
| Aura di Ramen VR (`tryaura.dev`) | Opzionale; prova limitata, non installare ora | Dopo il playtest Terrain Slice A, se l'Editor resta un collo di bottiglia | Plugin/MCP per controllo strutturato di UE 5.6.1 da Claude/Codex. Trial 2 settimane; Indie 20 USD/mese o 120 USD/anno al 22 settembre 2026. Auto Mode illimitata richiede consenso all'uso dei dati per training; valutazione completa in `UNREAL_EDITOR_WORKFLOW.md` |
| Unreal MCP ufficiale Epic | Rimandato | Gate di eventuale migrazione a UE 5.8+ | Integrato ma sperimentale da UE 5.8; non disponibile nella versione 5.6.1 fissata e non giustifica da solo una migrazione |

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
