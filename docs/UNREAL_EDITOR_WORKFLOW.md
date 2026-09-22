# Strategia di lavoro diretto in Unreal Editor

## Obiettivo

Permettere a Codex di modificare il progetto con il minimo intervento manuale del proprietario e mostrare i risultati nell'Editor aperto, senza sacrificare ripetibilita, versionamento o stabilita della toolchain Unreal Engine 5.6.1.

## Decisione raccomandata per la fase corrente

Adottare un flusso ibrido, in questo ordine:

1. **file, codice, build e test tramite repository e toolchain locale**;
2. **script Python/Editor Scripting per operazioni Unreal ripetibili**;
3. **Computer Use per osservare e manovrare l'interfaccia visibile**;
4. **Play In Editor e Live Coding per feedback rapido quando compatibili con la modifica**;
5. **MCP Unreal soltanto come spike isolato**, non come dipendenza della produzione su UE 5.6.1.

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

## 2. Automazione strutturata in Unreal 5.6

Per creare o modificare asset, livelli e impostazioni ripetibili, la base consigliata e:

- `Python Editor Script Plugin`;
- `Editor Scripting Utilities`;
- script versionati nel repository;
- esecuzione nell'Editor o tramite `UnrealEditor-Cmd` quando non serve feedback visivo.

Python e disponibile soltanto nell'Editor e non nel gioco in esecuzione. Questo e appropriato per import, disposizione di livelli, gestione asset, convalide e tool interni; il gameplay resta in Blueprint/C++.

L'esecuzione Python remota e disponibile nelle impostazioni dell'Editor, ma va abilitata soltanto per un test locale circoscritto. In alternativa, la Remote Control API espone HTTP/WebSocket e puo invocare funzioni Blueprint-callable su oggetti caricati. Entrambe sono superfici potenti: limitare l'ascolto al computer locale e non esporle alla rete.

Fonti ufficiali Epic:

- https://dev.epicgames.com/documentation/en-us/unreal-engine/scripting-the-unreal-editor-using-python
- https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/EditorPythonScripting?application_version=5.6
- https://dev.epicgames.com/documentation/en-us/unreal-engine/remote-control-for-unreal-engine

## 3. Feedback quasi in tempo reale

- **Blueprint:** compilazione e Play In Editor permettono iterazioni rapide, ma modifiche durante PIE vanno usate con cautela e salvate esplicitamente.
- **C++:** Live Coding puo ricompilare e applicare molte modifiche ai corpi delle funzioni mentre Editor o PIE sono aperti.
- **Limite C++:** cambi strutturali a `UCLASS`, `UPROPERTY`, `UFUNCTION`, costruttori o layout riflessi possono richiedere chiusura dell'Editor e build completa. Non forzare Live Coding quando rischia dati o asset corrotti.
- **Asset/level:** Python o Editor Utility applicano cambiamenti nell'Editor; Computer Use verifica visivamente il risultato e salva soltanto gli asset previsti.

Fonte ufficiale Epic: https://dev.epicgames.com/documentation/en-us/unreal-engine/using-live-coding-to-recompile-unreal-engine-applications-at-runtime

## 4. Unreal MCP

Epic distribuisce un **Unreal MCP** ufficiale che incorpora un server MCP nell'Editor e consente a client compatibili di creare attori, configurare luci, lavorare con materiali, ispezionare Slate ed eseguire test. Tuttavia, la documentazione corrente lo presenta come funzionalita **Experimental** di Unreal Engine 5.8; il progetto e fissato alla 5.6.1.

Esistono plugin MCP della comunita compatibili con UE 5.6, ma aggiungono codice C++, un server esterno e una superficie di controllo non ancora necessaria al micro-prototipo. Possono inoltre diventare incompatibili con una futura migrazione al MCP ufficiale Epic.

Decisione corrente:

- non migrare il progetto a UE 5.8 soltanto per MCP;
- non installare ora un plugin MCP della comunita nel progetto principale;
- rivalutare dopo Terrain Slice A e il round-trip Blender-Unreal;
- se il lavoro nell'Editor diventa un collo di bottiglia, provare un solo candidato in branch/worktree isolato, con licenza, sorgente, permessi, rollback, test UE 5.6.1 e misurazione del risparmio reale.

Fonti:

- Unreal MCP ufficiale Epic: https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-mcp-in-unreal-editor
- configurazione MCP in Codex: https://learn.chatgpt.com/docs/extend/mcp

## Flusso operativo proposto

Per ogni incremento visivo:

1. Codex o Claude modifica file/script su un branch isolato.
2. Codex compila o esegue la validazione automatica pertinente.
3. Unreal Editor viene aperto sul progetto con Computer Use autorizzato.
4. Codex applica lo script o apre gli asset interessati.
5. Il proprietario vede il risultato nella viewport o in Play In Editor.
6. Codex controlla Output Log e comportamento, poi salva soltanto gli asset previsti.
7. Diff, build e test restano obbligatori prima dell'integrazione.

## Primo esperimento consigliato

Dopo il playtest Terrain Slice A:

- abilitare Computer Use nell'app Codex e autorizzare Unreal Editor;
- aprire la build di sviluppo nell'Editor, senza aggiungere MCP;
- far eseguire a Codex un cambiamento innocuo e reversibile, per esempio colore o intensita di un indicatore graybox;
- avviare PIE, verificare insieme il cambiamento e ripristinarlo o conservarlo;
- misurare affidabilita, durata e numero di interventi manuali.

Se il test e affidabile, Computer Use diventa il canale visivo standard. Python Editor Scripting viene aggiunto quando compare il primo task ripetitivo su asset o livelli. MCP viene valutato solo se questa combinazione lascia ancora un problema concreto irrisolto.
