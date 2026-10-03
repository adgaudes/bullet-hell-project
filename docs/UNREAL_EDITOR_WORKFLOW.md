# Strategia di lavoro diretto in Unreal Editor

> **ARCHIVIO STORICO — NON PIU AUTOREVOLE.**
> Superato il 3 ottobre 2026 dalla decisione D-019 (migrazione a Godot 4.7.2).
> Il flusso di lavoro corrente e in `docs/GODOT_WORKFLOW.md`.
> Questo documento resta solo come traccia delle verifiche svolte sulla toolchain Unreal.

## Obiettivo

Permettere a Codex di modificare il progetto con il minimo intervento manuale del proprietario e mostrare i risultati nell'Editor aperto, senza sacrificare ripetibilita, versionamento o stabilita della toolchain Unreal Engine 5.8.2.

## Decisione raccomandata per la fase corrente

Adottare un flusso ibrido, in questo ordine:

1. **file, codice, build e test tramite repository e toolchain locale**;
2. **script Python/Editor Scripting per operazioni Unreal ripetibili**;
3. **Computer Use per osservare e manovrare l'interfaccia visibile**;
4. **Play In Editor e Live Coding per feedback rapido quando compatibili con la modifica**;
5. **MCP ufficiale Epic in una prova isolata e misurata**, iniziando da ispezione e operazioni reversibili;
6. **Aura valutato task per task** quando le sue funzioni specializzate possono ridurre lavoro o migliorare la verifica, senza duplicare l'autore attivo.

Questa combinazione permette di vedere le modifiche mentre vengono applicate, ma conserva file e script revisionabili come fonte di verita. I clic nell'Editor non devono essere l'unico modo per ricostruire una feature.

## 1. Controllo visivo dell'Editor

Codex Computer Use puo leggere e operare interfacce Windows autorizzate, quindi puo:

- aprire pannelli, selezionare attori e modificare proprieta esposte;
- avviare e fermare Play In Editor;
- osservare viewport, Output Log, finestre di import e risultati visivi;
- riprodurre flussi e bug che non risultano dai soli log;
- mostrare al proprietario le modifiche nella stessa sessione.

Limite importante: su Windows il controllo avviene sul desktop attivo e in primo piano. Durante l'operazione il proprietario vede mouse e tastiera muoversi e non puo usare contemporaneamente la stessa sessione in modo affidabile. Il PC deve restare sbloccato e Unreal visibile.

Nella verifica del 22 settembre 2026 il canale Computer Use era disponibile, ma non risultavano finestre di applicazioni Windows aperte o collegate. Prima dell'uso reale bisogna aprire Unreal Editor e verificare che venga rilevato; se l'app richiede di abilitare il plugin **Computer Use** o autorizzare `UnrealEditor.exe`, quel passaggio richiede conferma del proprietario.

Fonte ufficiale OpenAI: https://learn.chatgpt.com/docs/computer-use

## 2. Automazione strutturata in Unreal 5.8

Per creare o modificare asset, livelli e impostazioni ripetibili, la base consigliata e:

- `Python Editor Script Plugin`;
- `Editor Scripting Utilities`;
- script versionati nel repository;
- esecuzione nell'Editor o tramite `UnrealEditor-Cmd` quando non serve feedback visivo.

Python e disponibile soltanto nell'Editor e non nel gioco in esecuzione. Questo e appropriato per import, disposizione di livelli, gestione asset, convalide e tool interni; il gameplay resta in Blueprint/C++.

L'esecuzione Python remota e disponibile nelle impostazioni dell'Editor, ma va abilitata soltanto per un test locale circoscritto. In alternativa, la Remote Control API espone HTTP/WebSocket e puo invocare funzioni Blueprint-callable su oggetti caricati. Entrambe sono superfici potenti: limitare l'ascolto al computer locale e non esporle alla rete.

Fonti ufficiali Epic:

- https://dev.epicgames.com/documentation/en-us/unreal-engine/scripting-the-unreal-editor-using-python
- https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/EditorPythonScripting?application_version=5.8
- https://dev.epicgames.com/documentation/en-us/unreal-engine/remote-control-for-unreal-engine

## 3. Feedback quasi in tempo reale

- **Blueprint:** compilazione e Play In Editor permettono iterazioni rapide, ma modifiche durante PIE vanno usate con cautela e salvate esplicitamente.
- **C++:** Live Coding puo ricompilare e applicare molte modifiche ai corpi delle funzioni mentre Editor o PIE sono aperti.
- **Limite C++:** cambi strutturali a `UCLASS`, `UPROPERTY`, `UFUNCTION`, costruttori o layout riflessi possono richiedere chiusura dell'Editor e build completa. Non forzare Live Coding quando rischia dati o asset corrotti.
- **Asset/level:** Python o Editor Utility applicano cambiamenti nell'Editor; Computer Use verifica visivamente il risultato e salva soltanto gli asset previsti.

Fonte ufficiale Epic: https://dev.epicgames.com/documentation/en-us/unreal-engine/using-live-coding-to-recompile-unreal-engine-applications-at-runtime

## 4. Unreal MCP

Il video analizzato il 22 settembre 2026, *Build a Playable Unreal Engine 5 Level with AI (MCP + Claude Code)*, mostra il flusso reale del nuovo **Unreal MCP** incluso in Unreal Engine 5.8. Non e un plugin Marketplace di terze parti: e un plugin sperimentale Epic distribuito con l'engine. Nel video vengono abilitati il plugin Unreal MCP e i toolset, poi avviato il server e generata la configurazione per Claude Code.

Epic documenta un server MCP incorporato nell'Editor, accessibile localmente via HTTP e compatibile con client quali Claude Code. I tool ufficiali possono creare attori, configurare luci e materiali, ispezionare Slate ed eseguire test. Il plugin principale e `ModelContextProtocol`; i tool predefiniti richiedono anche i toolset. La funzione e **Experimental**, ma i plugin `ModelContextProtocol` e `AllToolsets` sono presenti nell'installazione UE 5.8.2 verificata.

I plugin MCP della comunita non sono candidati correnti: aggiungono codice, manutenzione e una superficie di controllo senza un vantaggio dimostrato rispetto al server ufficiale gia disponibile.

Decisione corrente:

- non installare un plugin MCP della comunita nel progetto principale;
- MCP Epic e abilitato nel progetto e configurato per avviarsi con l'Editor su `127.0.0.1:8000/mcp`;
- Codex usa una configurazione locale al repository, non obbligatoria quando l'Editor e chiuso, con approvazione per gli strumenti di scrittura;
- Claude Code usa lo stesso endpoint tramite `.mcp.json` con scope progetto, dopo login e consenso personale una tantum;
- durante ogni incarico un solo agente puo modificare l'Editor: Claude implementa e verifica il proprio task, poi termina la sessione MCP prima della revisione e integrazione di Codex;
- validazione iniziale completata: ispezione, lettura e una modifica reversibile con controllo dello stato;
- usarlo come canale strutturato standard quando l'Editor e aperto, mantenendo log, diff e rollback per le modifiche persistenti.

Verifica del 22 settembre 2026: il target Editor compila con entrambi i plugin; in avvio headless il server parte automaticamente, accetta l'handshake MCP `2025-06-18`, crea una sessione ed espone i tre strumenti di discovery. `list_toolsets` ha enumerato correttamente i toolset installati, inclusi Editor, log, test, attori, asset, Blueprint, scene, materiali, UMG, Niagara e Slate. Anche una scrittura reversibile e riuscita: lettura di stato PIE inattivo, avvio PIE, verifica dello stato attivo, arresto e verifica del ritorno allo stato inattivo. Nessun asset e stato salvato o modificato.

`AllToolsets` carica anche gli strumenti Game Features. Per questo UE richiede la registrazione di `GameFeatureData` nell'Asset Manager anche se il gioco non usa ancora plugin di gameplay modulari. La voce ufficiale con regola `AlwaysCook` e stata aggiunta tramite le impostazioni dell'Editor; non implica l'adozione architetturale del sistema Game Features.

Fonti:

- video esaminato: https://www.youtube.com/watch?v=Pwqujpu4548
- Unreal MCP ufficiale Epic: https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-mcp-in-unreal-editor
- configurazione MCP in Codex: https://learn.chatgpt.com/docs/extend/mcp

## 5. Valutazione Aura

Esistono piu prodotti chiamati Aura. Quello pertinente a questo flusso e **Aura di Ramen VR** su `tryaura.dev`, un plugin commerciale per Unreal e Unity. La documentazione dichiara supporto Windows per UE 5.4-5.8, quindi include UE 5.8.2.

Aura installa a livello engine un plugin che puo essere usato come app separata o pannello nell'Editor. Espone inoltre due server MCP `stdio` a client esterni:

- `unreal_inspector`, orientato a ispezione e pianificazione senza modifiche;
- `unreal_editor`, capace di modificare Blueprint, C++, materiali, Niagara, Behavior Tree, Data Table, UMG ed Enhanced Input e di controllare Play In Editor, screenshot e profiling.

Il vantaggio concreto rispetto al solo controllo visivo e l'accesso strutturato agli asset binari e ai sistemi dell'Editor. Aura dichiara anche compilazione/Live Coding, verifica automatica in PIE con registrazione video e recupero dai crash. Queste sono capacita del fornitore da convalidare sperimentalmente, non risultati gia verificati sul nostro progetto.

### Costi e dati verificati il 22 settembre 2026

- prova gratuita di due settimane senza carta, con Auto Mode illimitata e 10 USD di credito premium;
- piano Indie: 20 USD/mese oppure 120 USD/anno; include MCP esterno illimitato e 15 USD di credito premium;
- piano Pro: 40 USD/mese oppure 360 USD/anno;
- l'integrazione MCP con Claude Code/Codex e indicata come **Alpha** e richiede una prova attiva o un piano a pagamento;
- Aura dichiara che puo usare conversazioni e contesto forniti esplicitamente per addestramento; l'opzione puo essere disattivata, ma Auto Mode illimitata richiede che sia attiva;
- i sotto-agenti specializzati di Aura consumano il credito Aura; l'uso da un IDE puo anche aumentare il consumo del servizio AI esterno.

Non assumere quindi che Aura permetta di usare gratuitamente o soltanto con il piano Claude Pro tutte le sue funzioni. Nessun acquisto, overage o API a consumo deve essere attivato automaticamente.

### Decisione corrente

Priorita: **installato, candidato operativo da valutare per ogni task**. Aura 1.0.6 e presente a livello engine e puo aggiungere capacita utili per Blueprint, livelli e verifiche PIE, ma introduce un plugin proprietario, un secondo budget AI e condizioni sui dati. Prima di un lavoro nell'Editor, confrontare il suo vantaggio con MCP ufficiale, Claude Code e automazioni locali. Mantenere sempre un solo autore di modifiche.

Procedura operativa:

1. verificare prima del task piano attivo, costo, impostazioni dati e capacita necessarie;
2. preferire un canale diretto da Codex ad Aura quando disponibile e verificabile;
3. se il canale diretto non e disponibile, Codex prepara un unico prompt circoscritto che il proprietario deve soltanto incollare nel pannello Aura;
4. iniziare con ispezione o task reversibile, quindi misurare qualita, consumo e affidabilita;
5. terminare la sessione dell'altro agente prima di consentire ad Aura di scrivere nell'Editor;
6. revisionare log, asset modificati, diff e risultato in PIE prima dell'integrazione.

Il Filesystem Sandbox di Aura e dichiarato sperimentale anche su UE 5.8; non sostituisce branch/copia isolata, Git LFS e backup degli asset binari.

Fonti ufficiali Aura:

- prezzi e trattamento dei dati: https://www.tryaura.dev/about/
- installazione e funzioni: https://www.tryaura.dev/documentation/
- integrazione MCP/Claude Code: https://www.tryaura.dev/documentation/aura-ide-mcp/
- Verification Agent: https://www.tryaura.dev/documentation/verification-agent/
- Filesystem Sandbox: https://www.tryaura.dev/documentation/filesystem-sandbox/

## Flusso operativo proposto

Vincolo del proprietario: mantenere Unreal Editor aperto quando l'attivita lo consente. Viewport e Play In Editor devono condividere Actor, geometria, materiali, illuminazione, dati e stato iniziale persistente, senza preview manuali parallele. La corrispondenza non e richiesta per stati temporanei, procedurali o prodotti dal gameplay, come combattimento, terreno gia trasformato, eventi, inondazioni o avanzamento del ciclo giorno/notte: questi vengono verificati nel PIE pertinente. Una rappresentazione editoriale di un sistema dinamico va mantenuta soltanto quando riduce concretamente tempi o rischi e deve riusare la stessa logica o gli stessi dati del runtime. Icone, gizmo, overlay e debug propri dell'Editor restano esclusi dal confronto. Questo e il ciclo di iterazione predefinito; non generare una build pacchettizzata dopo ogni piccolo cambiamento.

Per ogni incremento visivo:

1. Codex o Claude modifica file/script su un branch isolato.
2. Codex compila o esegue la validazione automatica pertinente.
3. Unreal Editor viene aperto sul progetto con Computer Use autorizzato.
4. Codex applica lo script o apre gli asset interessati.
5. Codex confronta in Lit, Game View e PIE lo stato iniziale persistente e verifica che non esistano Actor o rappresentazioni manuali duplicate; gli stati dinamici vengono controllati nel PIE pertinente senza imporre una copia editoriale.
6. Il proprietario vede il risultato nella Viewport e in Play In Editor.
7. Codex controlla Output Log e comportamento, poi salva soltanto gli asset previsti.
8. Diff, build e test restano obbligatori prima dell'integrazione.

### Cadenza delle verifiche

- **A ogni modifica pertinente:** compilazione Blueprint, Live Coding oppure build del solo target Editor, poi verifica in viewport o Play In Editor.
- **A ogni incremento coerente o prima dell'integrazione:** chiusura dell'Editor se richiesta, compilazione pulita del codice interessato e controllo dei log.
- **Alle milestone e dopo cambiamenti a packaging, configurazione, plugin, caricamento o piattaforma:** cook e build Windows Development pacchettizzata.
- **Prima di demo e release:** build Shipping e test su macchina pulita e Steam Deck.

Play In Editor accelera il controllo del gameplay ma non sostituisce completamente una build: packaging, dipendenze mancanti, configurazioni Shipping, percorsi dei file, avvio standalone, Proton e prestazioni possono comportarsi diversamente. La build pacchettizzata e quindi periodica e basata sul rischio, non eliminata.

## Primo esperimento consigliato

Dopo il playtest Terrain Slice A:

- abilitare Computer Use nell'app Codex e autorizzare Unreal Editor;
- aprire la build di sviluppo nell'Editor e verificare prima il normale flusso PIE;
- far eseguire a Codex un cambiamento innocuo e reversibile, per esempio colore o intensita di un indicatore graybox;
- avviare PIE, verificare insieme il cambiamento e ripristinarlo o conservarlo;
- misurare affidabilita, durata e numero di interventi manuali.

Se il test e affidabile, Computer Use diventa il canale visivo standard. Python Editor Scripting viene aggiunto quando compare il primo task ripetitivo su asset o livelli. Il MCP ufficiale viene poi provato in isolamento per valutarne affidabilita e risparmio manuale rispetto a questa base.
