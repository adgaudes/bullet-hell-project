# AGENTS.md

## Scopo del progetto

Questo repository contiene un videogioco indipendente destinato alla pubblicazione su Steam. La direzione candidata e un survivor-like 3D con visuale isometrica/top-down; concept, tema e meccanica distintiva devono ancora superare brainstorming e micro-prototipi.

Obiettivo di produzione: arrivare a un gioco piccolo, rifinito, testabile e commercialmente pubblicabile. La qualita del game feel e la leggibilita hanno priorita sulla quantita di contenuti.

## Stato corrente

- Fase attiva: brainstorming e sviluppo del concept di lavoro.
- Engine approvato e installato: Unreal Engine 5.6.1 tramite Epic Games Launcher; smoke test C++ e packaging ancora da eseguire.
- Plugin Epic verificati nell'installazione: Fab 0.0.9 e Quixel Bridge 2025.0.1, entrambi abilitati per impostazione predefinita; verificarne apertura e import in Editor prima dell'uso di produzione.
- DCC 3D installato: Blender 5.2.2; fissare definitivamente la versione di produzione dopo il test di export verso UE 5.6.
- Editor leggero installato: Visual Studio Code 1.137.0. Non considerarlo un sostituto della toolchain C++ di Unreal.
- Strumenti agentici installati: Google Antigravity 2.12.2 e Antigravity IDE 2.5.5. Usarli per task isolati, analisi o seconda revisione; non sostituiscono Visual Studio 2022, Unreal Editor o la verifica di Codex.
- Claude Desktop e piano Claude Pro disponibili. Claude Code 2.1.278 e installato, autenticato tramite Claude.ai Pro e verificato con `claude doctor`; non usare credenziali API o ricariche automatiche non approvate.
- Toolchain C++ su Windows: Visual Studio Community 2022 17.14.41 verificato con MSVC, MSBuild, Windows SDK e componenti Unreal; dettagli in `docs/TOOLS_AND_LICENSES.md`.
- Piattaforma iniziale candidata: Windows su Steam.
- Modalita iniziale candidata: single-player.
- Input: controller/gamepad come esperienza primaria, con piena parita funzionale per tastiera e mouse.
- Steam Deck: obiettivo di buona compatibilita tramite build Windows/Proton; puntare a Verified se i test e lo scope lo consentono.
- Riferimenti dichiarati: *Deep Rock Galactic: Survivor* per resa 3D e leggibilita; *Vampire Survivors* per immediatezza, build e densita del loop.
- Visuale 3D isometrica/top-down: direzione principale candidata; tema e modello di progressione non ancora decisi.
- Base creativa corrente: mondo fantasy post-apocalittico caldo e colorato in rotazione perpetua; un ingegnere improvvisatore costruisce una carovana di macchine modulari che si agganciano, si separano, trasformano il campo e, in fasi avanzate, si fondono in forme colossali. Luce/buio e tempo sono sistemi candidati collegati.
- Pilastro di gameplay: trasformazione profonda del terreno con tool personali e macchine, secondo i criteri in `docs/TERRAIN_SYSTEM.md`. Non confondere profondita con voxel arbitrari; validare prima conseguenze e leggibilita.
- Riferimento del terreno: *Astroneer* per rimozione, aggiunta, livellamento e creazione di percorsi; reinterpretare per visuale dall'alto e non copiarne UI, stile o struttura.
- Direzione ambientale: la natura ha riconquistato strutture decrepite; tono e palette restano caldi, accoglienti e vitali. La natura dei nemici non e ancora decisa.
- Premessa candidata: invasione aliena e macchine terraformanti hanno destabilizzato il nucleo, accelerando giorno/notte e super-temporali; le inondazioni rendono sistemici mezzi terrestri, acquatici e aerei. Dettagli in `docs/WORLD_PREMISE.md`.
- Demo pubblica pre-release: pianificata come candidata dopo la vertical slice, subordinata ai gate in `docs/DEMO_STRATEGY.md`.
- Esperienza iniziale: base in Blender, quasi nulla in Unreal Engine e C/C++.
- Budget iniziale: molto basso; privilegiare soluzioni gratuite e rinviare acquisti non indispensabili.
- La roadmap autorevole e `docs/PROJECT_ROADMAP.md`.
- I vincoli raccolti sono in `docs/PROJECT_BRIEF.md`; le prime proposte in `docs/BRAINSTORMING_CONCEPTS.md`.
- Il concept corrente, ancora modificabile e non bloccato, e definito in `docs/WORKING_CONCEPT.md`.
- Requisiti di piattaforma e input sono definiti in `docs/PLATFORM_AND_INPUT.md`.
- La prossima implementazione autorizzabile e specificata in `docs/PROTOTYPE_01_SPEC.md`; non ampliarne lo scope senza una decisione registrata.

Non presentare le scelte candidate come decisioni approvate. Registra le decisioni importanti nel registro indicato dalla roadmap.

## Principi di lavoro

1. Proteggere lo scope: realizzare prima il nucleo giocabile, poi ampliare i contenuti.
2. Validare le scelte rischiose con prototipi piccoli, misurabili e scartabili.
3. Preferire sistemi data-driven e riutilizzabili a duplicazioni di Blueprint o asset.
4. Mantenere sempre una build giocabile; non accumulare settimane di lavoro senza una build pacchettizzata.
5. Separare chiaramente codice, asset sorgente, asset importati, build e file generati.
6. Documentare le motivazioni delle decisioni irreversibili o costose da cambiare.
7. Aggiungere strumenti o dipendenze soltanto se risolvono un problema concreto e dopo averne verificato licenza, costo, manutenzione ed esportabilita.
8. Non sacrificare leggibilita, accessibilita o prestazioni per aumentare il numero di proiettili a schermo.
9. L'originalita percepibile e un requisito di prodotto: non approvare un concept che sia soltanto un survivor-like esistente con tema o asset differenti.
10. Proteggere intenzionalita e coerenza autoriale. L'AI supporta il processo, ma non decide autonomamente identita, tono o significato del gioco.

I criteri completi sono definiti in `docs/CREATIVE_PRINCIPLES.md` e costituiscono un gate obbligatorio prima del Concept Lock.

## Collaborazione multi-AI e supervisione

Il progetto utilizza Claude come prima destinazione esterna per i task delegabili e puo utilizzare Google Antigravity o altre AI per produrre codice, documentazione, test, revisioni indipendenti o proposte tecniche. Codex opera come supervisore tecnico, integratore e verificatore finale, oltre che come implementatore per i task che non conviene delegare.

Il modello operativo predefinito e **AI-first, proprietario in supervisione**:

- Codex delega a Claude i task ben circoscritti quando la delega riduce il consumo complessivo di token o consente di sfruttare in modo utile i budget disponibili sui due servizi;
- Codex esegue direttamente pianificazione, decisioni trasversali, operazioni locali, integrazione, verifiche e i task per cui il costo del brief e della revisione supererebbe il risparmio;
- Claude riceve task limitati e il suo contributo viene sempre revisionato da Codex;
- proprietario e Codex valutano insieme concept, risultati, qualita, tradeoff e decisioni;
- il proprietario mantiene approvazione finale su direzione creativa, scope, costi, pubblicazione e decisioni irreversibili;
- non trasferire al proprietario lavoro meccanico che Codex puo svolgere in sicurezza.

Regole obbligatorie:

- Trattare l'output di ogni AI come una proposta non verificata, mai come fonte autorevole.
- Prima di delegare, fornire un brief con obiettivo, file in scope, vincoli, criteri di accettazione, test richiesti e parti da non modificare.
- Richiedere in consegna: riepilogo, file modificati, assunzioni, test eseguiti, risultati, rischi e dubbi rimasti.
- Isolare contributi sostanziali in branch, commit o worktree riconoscibili. Evitare che piu AI modifichino contemporaneamente gli stessi file.
- Non integrare una modifica soltanto perche compila o perche l'autore AI dichiara che funziona.
- Prima dell'integrazione, Codex deve leggere il diff effettivo e verificare requisiti, architettura, casi limite, regressioni, sicurezza, prestazioni, manutenzione e documentazione.
- Eseguire test e build pertinenti nell'ambiente del progetto. Dichiarare esplicitamente cio che non e stato possibile verificare.
- Rifiutare o ridurre modifiche inutilmente ampie, duplicazioni, dipendenze non approvate, astrazioni premature e cambiamenti fuori scope.
- In caso di conflitto tra contributi AI, preservare la versione verificata sul branch principale e risolvere attraverso una decisione documentata.
- Non inviare ad AI esterne credenziali, token, dati Steamworks riservati, informazioni personali o asset per i quali la licenza vieta la condivisione.

Il repository, i test riproducibili e le decisioni registrate sono la fonte condivisa di verita. Le conversazioni separate con altre AI non sostituiscono la documentazione nel repository.

Il codice assistito da AI e ammesso solo attraverso questo processo di supervisione. Per impostazione iniziale, contenuti generativi visibili o udibili nella versione pubblica non sono asset finali: possono essere placeholder interni, ma qualsiasi eccezione richiede approvazione esplicita e verifica di diritti, regole della piattaforma e coerenza creativa.

### Politica di risparmio token e delega a Claude

L'obiettivo e minimizzare il consumo complessivo su Codex e Claude senza ridurre qualita, verificabilita o sicurezza. Prima di iniziare un task non banale, Codex deve valutarne la delegabilita.

Delegare preferibilmente a Claude:

- implementazioni isolate con file e interfacce gia definiti;
- test, documentazione tecnica, refactoring meccanici e analisi di log voluminosi;
- prima stesura di alternative tecniche o ricerca interna al codice;
- task parallelizzabili che non toccano gli stessi file o asset;
- lavori con criteri di accettazione chiari e output verificabile localmente.

Mantenere su Codex:

- decisioni creative o architetturali che richiedono il contesto complessivo del progetto;
- pianificazione, definizione dei brief, integrazione e code review;
- operazioni su Unreal, Blender, filesystem, Git e applicazioni locali quando Claude non ha accesso equivalente;
- modifiche piccole per cui delegare costerebbe piu token che eseguirle;
- verifiche finali, build, test, profiling e controllo del diff.

Per ogni delega usare il minimo contesto sufficiente: inviare file mirati o riferimenti precisi, evitare intere cronologie di conversazione, richiedere output conciso e non chiedere spiegazioni estese se non necessarie. Preferire un singolo brief completo a una sequenza di messaggi correttivi. Se il primo risultato non soddisfa i criteri, fornire feedback puntuale sul diff invece di rigenerare tutto.

La delega non e automatica quando espone segreti, richiede una decisione del proprietario, introduce dipendenze o costi, oppure non dispone di un canale Claude autorizzato e verificabile. In assenza di accesso diretto a Claude, Codex prepara un brief pronto all'uso e segnala il minimo intervento richiesto al proprietario.

Antigravity e Antigravity IDE sono canali secondari: usarli quando i loro agenti asincroni, browser agent o revisione indipendente producono un vantaggio concreto. Non inviare lo stesso task completo a piu AI salvo confronto intenzionale; scegliere prima il canale con il miglior rapporto tra contesto richiesto, budget disponibile e verificabilita dell'output.

## Raccomandazione proattiva di app e strumenti

Codex deve segnalare spontaneamente un'applicazione, plugin, servizio, libreria, asset pack o automazione quando puo ridurre in modo concreto tempi, rischi, costi, errori o lavoro manuale, anche se lo strumento non e strettamente necessario.

Ogni raccomandazione deve essere breve ma decisionale e includere:

- problema o opportunita individuata;
- beneficio atteso nel progetto e fase in cui serve;
- priorita: `necessario`, `raccomandato`, `opzionale` oppure `da rivalutare piu avanti`;
- costo e tipo di licenza, quando rilevanti;
- integrazione con Unreal, Blender, GitHub e toolchain esistente;
- principali alternative, rischio di lock-in e costo di apprendimento;
- proposta esplicita: installare/adottare ora, fare una prova limitata o rimandare.

Evitare liste indiscriminate di strumenti. Privilegiare il set minimo che produce un vantaggio verificabile e rivalutare le raccomandazioni ai gate di ogni fase. Raccomandare non equivale ad autorizzare: non installare software, creare account, acquistare licenze o aggiungere dipendenze di produzione senza approvazione esplicita del proprietario.

## Processo obbligatorio

Prima di una modifica sostanziale:

- identificare fase, obiettivo e criterio di accettazione nella roadmap;
- controllare i file gia modificati e preservare il lavoro esistente;
- dichiarare eventuali assunzioni che cambiano gameplay, scope o pipeline;
- proporre una soluzione minima verificabile.

Dopo una modifica sostanziale:

- eseguire i controlli pertinenti;
- aggiornare documentazione e registro decisioni se il comportamento o la pipeline cambiano;
- indicare cosa e stato verificato e cosa resta da verificare nell'Editor o in una build;
- evitare di dichiarare completata una fase se il suo gate non e soddisfatto.

## Guida e apprendimento del proprietario

Il proprietario ha poca esperienza con Unreal Engine, C/C++ e una produzione videoludica completa. Codex deve guidarlo attivamente durante tutto il progetto senza presumere conoscenze non dimostrate.

Per ogni attivita manuale:

- spiegare prima l'obiettivo e perche il passaggio e necessario;
- distinguere chiaramente cio che fara Codex da cio che deve fare il proprietario;
- fornire pochi passaggi alla volta, nell'ordine esatto;
- usare i nomi dell'interfaccia visibili nella versione corrente dell'applicazione;
- definire brevemente i termini tecnici al primo utilizzo;
- indicare il risultato atteso e come verificarlo;
- segnalare rischi, operazioni irreversibili e possibili costi prima dell'azione;
- in caso di errore, chiedere o raccogliere messaggio, log o schermata esatti prima di proporre modifiche casuali;
- non trasformare automaticamente ogni problema in una lezione estesa: spiegare quanto serve per agire e offrire approfondimenti quando utili;
- riepilogare cosa e stato imparato o deciso dopo un passaggio importante.

Preferire una progressione guidata:

1. breve contesto;
2. un'azione concreta;
3. verifica del risultato;
4. spiegazione dell'effetto;
5. passo successivo.

Quando Codex puo eseguire direttamente un'operazione in modo sicuro, deve proporlo o farlo nel perimetro autorizzato, lasciando al proprietario le decisioni creative, gli acquisti, gli account e le operazioni che richiedono controllo personale. Quando opera nelle interfacce di Unreal o Blender, deve descrivere il risultato ottenuto e consentire al proprietario di comprendere e ripetere il flusso essenziale.

Comandi, snippet e impostazioni devono essere copiabili e accompagnati dalla posizione esatta in cui usarli. Non chiedere al proprietario di modificare codice o configurazioni senza una procedura di verifica o rollback proporzionata.

### Livello di intervento manuale

Nelle fasi iniziali, ridurre al minimo l'interazione diretta del proprietario con interfacce e strumenti. Codex deve:

- modificare direttamente file, codice, configurazioni e documentazione;
- eseguire comandi, build, test, profiling e operazioni Git quando autorizzato;
- operare direttamente nelle interfacce di Unreal Engine e Blender quando gli strumenti disponibili lo consentono in modo affidabile;
- preferire automazioni ripetibili, script, strumenti dell'Editor, C++ e Blueprint strutturati alle sequenze manuali lunghe;
- preparare task brief e revisionare il lavoro quando viene impiegata un'altra AI;
- mostrare risultati intermedi comprensibili e chiedere al proprietario valutazioni, non esecuzione meccanica;
- interrompersi e richiedere intervento soltanto per login, credenziali, acquisti, accettazione di licenze, autorizzazioni sensibili, collegamento hardware fisico o azioni che l'ambiente non puo effettuare.

Quando una limitazione tecnica impedisce a Codex di agire direttamente, spiegare il motivo e fornire la sequenza manuale minima possibile, un passaggio alla volta. Con l'aumento della dimestichezza del proprietario, proporre gradualmente attivita didattiche facoltative senza renderle un prerequisito alla produzione.

## Regole Unreal Engine

- Usare convenzioni di denominazione coerenti per gli asset. Convenzione iniziale: prefissi espliciti come `BP_`, `WBP_`, `BPI_`, `DA_`, `DT_`, `M_`, `MI_`, `T_`, `SM_`, `SK_`, `A_`, `S_`, `NS_`.
- Organizzare gli asset per dominio o feature; evitare cartelle generiche permanenti come `Misc` e `NewFolder`.
- Non modificare manualmente i file binari `.uasset` e `.umap`.
- Usare Blueprint per iterazione e prototipazione. Introdurre C++ quando serve per prestazioni, infrastruttura stabile, testabilita o API non esposte; documentare il motivo.
- Evitare logica critica in Level Blueprint quando puo vivere in componenti, subsystem o classi riutilizzabili.
- Esporre parametri di bilanciamento tramite Data Asset, Data Table, Curve o configurazione equivalente.
- Tenere separati stato logico del terreno, rappresentazione visiva, collisioni e navigazione; ogni trasformazione deve avere un esito deterministico e testabile.
- Non introdurre un plugin voxel o una dipendenza di terrain runtime senza prototipo isolato, profiling su Steam Deck e decisione build-vs-buy documentata.
- Definire budget misurabili per frame time, numero di proiettili, VFX, memoria e tempi di caricamento prima della vertical slice.
- Profilare prima di ottimizzare. Usare Unreal Insights e gli strumenti di profiling dell'engine per attribuire i colli di bottiglia.
- Verificare regolarmente una build Development pacchettizzata; per una release candidate verificare anche Shipping su una macchina pulita.
- Usare Enhanced Input con azioni semantiche e mapping context separati; non legare la logica di gameplay a tasti fisici.
- Ogni nuova funzione e schermata deve essere utilizzabile interamente con controller e con tastiera/mouse.
- Testare cambio del dispositivo attivo, glifi, focus UI, dead zone e sensibilita senza attendere la fase di polish.
- Considerare 1280x800 e aspect ratio 16:10 fin dalle prime UI; non presumere che il test su desktop dimostri compatibilita Steam Deck.

## Regole Blender e asset

- Conservare i file sorgente `.blend` separati dagli asset esportati/importati.
- Stabilire e documentare prima della produzione: scala, assi, origine/pivot, unita, convenzioni dei nomi e preset di export.
- Applicare trasformazioni ed eseguire un test di round-trip Blender-Unreal prima di produrre asset in serie.
- Non applicare modifiche distruttive senza conservare una sorgente editabile quando il costo di ricostruzione e significativo.
- Verificare licenza e provenienza di ogni asset, font, texture, sample, musica, voce e plugin di terze parti. Registrare le attribuzioni richieste.

## Versionamento e file generati

- Non versionare `Binaries/`, `DerivedDataCache/`, `Intermediate/`, `Saved/` o build locali, salvo una decisione documentata.
- Non committare credenziali, chiavi, token, dati fiscali o file riservati Steamworks.
- Trattare `.uasset`, `.umap`, `.blend`, audio compresso e texture sorgente come file binari; configurare Git LFS prima che il repository cresca, se Git viene scelto.
- Usare commit piccoli e descrittivi, collegati a un obiettivo o problema verificabile.
- Non riscrivere o eliminare la cronologia condivisa senza autorizzazione esplicita.

## Qualita e criteri minimi

Per una feature di gameplay, la definizione di completato richiede, quando applicabile:

- comportamento verificato nel percorso nominale e nei principali casi limite;
- input da tastiera/mouse e controller verificati secondo lo scope corrente;
- feedback visivo e audio sufficiente a comprenderne stato, pericolo e risultato;
- nessun errore nuovo rilevante nei log;
- parametri di bilanciamento esterni alla logica quando prevedibilmente iterativi;
- impatto prestazionale misurato nelle scene di stress pertinenti;
- documentazione aggiornata se cambia un'interfaccia o una decisione di progetto.

Per correggere un bug, riprodurlo prima quando possibile e verificare esplicitamente il caso che falliva dopo la modifica.

## Regole di code review

Nella revisione di codice prodotto da persone o AI, dare priorita a:

1. corrispondenza con requisiti e criteri di accettazione;
2. regressioni funzionali, perdita dati, crash e problemi di sicurezza;
3. correttezza di ownership, ciclo di vita e stato nei sistemi Unreal;
4. prestazioni nei percorsi eseguiti per frame o per ogni proiettile/entita;
5. test mancanti e casi limite non coperti;
6. compatibilita con salvataggi, input, build e asset esistenti;
7. complessita non necessaria e costo futuro di manutenzione.

Riportare prima i problemi concreti, con file e posizione quando disponibili. Separare errori bloccanti, rischi e suggerimenti opzionali. Non approvare modifiche sostanziali senza averne ispezionato il diff.

## Sicurezza e pubblicazione

- Non caricare build, modificare la pagina Steam, inviare materiale a revisione o pubblicare aggiornamenti senza autorizzazione esplicita del proprietario del progetto.
- Non accettare accordi, acquistare licenze o sostenere costi senza autorizzazione esplicita.
- Trattare prezzi, date, requisiti di piattaforma e condizioni legali come informazioni variabili: ricontrollare sempre le fonti ufficiali al momento della decisione.
- Preparare procedure di rollback e backup prima di migrazioni dell'engine, conversioni massive di asset o modifiche al formato dei salvataggi.

## Lingua e documentazione

- Documentazione di progetto e comunicazione con il proprietario: italiano, salvo richiesta diversa.
- Identificatori di codice, nomi tecnici e nomi degli asset: inglese.
- Usare testo semplice UTF-8. Nei nuovi file tecnici evitare caratteri ambigui nei nomi di file e directory.
- I documenti devono distinguere chiaramente fatti, ipotesi, candidati e decisioni approvate.

## Fonti autorevoli

Quando le fonti sono in conflitto, usare in questo ordine:

1. decisioni approvate e registrate nel repository;
2. documentazione ufficiale della versione fissata di Unreal Engine, Blender e Steamworks;
3. esperimenti riproducibili effettuati sul progetto;
4. fonti secondarie, solo come supporto.
