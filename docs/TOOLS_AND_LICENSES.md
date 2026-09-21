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
| Unreal Engine | 5.6, in installazione | Engine e packaging Windows | Approvato |
| Epic Games Launcher | 1.3.193.0 | Installazione e aggiornamento UE | Installato |
| Blender | 5.2.2 registrato; eseguibili 5.1 e 5.2 presenti | Modellazione, UV, rig, animazione, export | Installato; fissare 5.2.2 dopo test pipeline |
| Visual Studio Code | 1.137.0 x64 | Testo, configurazioni e modifiche leggere | Installato; non IDE primario UE C++ |
| Git | 2.55.0 | Versionamento | Installato |
| Git LFS | 3.7.1 | Asset binari | Installato e configurato nel repository |
| Git Credential Manager | 2.9.1 | Autenticazione remota | Installato |
| Visual Studio Community 2022 | 17.14.41, MSVC 14.44.35207, MSBuild 17.14.60 | Compilazione e debugging UE 5.6 C++ | Installato e verificato; IDE/toolchain primaria |
| Visual Studio Community 2026 | 18.10.1 | Nessun uso previsto per UE 5.6 | Candidato alla disinstallazione dopo che lo smoke test conferma VS 2022 e dopo verifica di eventuali altri usi del proprietario |
| GitHub CLI | Non rilevato | Issue, pull request e automazione GitHub | Opzionale |

Spazio libero rilevato sul disco di progetto: circa 620 GB, sufficiente per la fase iniziale. Hardware rilevato: Intel Core i7-13620H, 16 GB RAM, RTX 4050 Laptop con 6 GB VRAM.

## Visual Studio 2022 - verifica completata

Per Unreal Engine 5.6 usare Visual Studio 2022 versione 17.14 o successiva compatibile. Installazione rilevata: Community 2022 17.14.41. UE 5.6 non richiede Visual Studio 2026 e il progetto non deve selezionarlo automaticamente prima di una verifica esplicita.

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

Visual Studio Installer indica l'istanza 2022 come completa, avviabile e senza riavvio richiesto. La verifica definitiva resta la creazione, compilazione e pacchettizzazione di un progetto C++ minimo dopo il completamento dell'installazione di UE 5.6.

Dopo lo smoke test:

1. verificare nei log e nelle impostazioni che UnrealBuildTool abbia selezionato Visual Studio 2022/MSVC 14.44;
2. confermare con il proprietario che Visual Studio 2026 non serva ad altri progetti;
3. se entrambe le condizioni sono soddisfatte, raccomandarne esplicitamente la disinstallazione tramite Visual Studio Installer per recuperare spazio;
4. non rimuovere componenti condivisi o Windows SDK usati dalla toolchain 2022.

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

Licenze, prezzi e compatibilita devono essere ricontrollati prima di acquisti o aggiornamenti maggiori.
