# AGENTS.md

## Scopo del progetto

Questo repository contiene un videogioco indipendente destinato alla pubblicazione su Steam. La direzione candidata e un survivor-like 3D con visuale isometrica/top-down; concept, tema e meccanica distintiva devono ancora superare brainstorming e micro-prototipi.

Obiettivo di produzione: arrivare a un gioco piccolo, rifinito, testabile e commercialmente pubblicabile. La qualita del game feel e la leggibilita hanno priorita sulla quantita di contenuti.

## Stato corrente

- Fase attiva: brainstorming e sviluppo del concept di lavoro.
- Engine approvato: Unreal Engine 5.6, installazione tramite Epic Games Launcher.
- DCC 3D installato: Blender 5.2.2; fissare definitivamente la versione di produzione dopo il test di export verso UE 5.6.
- Editor leggero installato: Visual Studio Code 1.137.0. Non considerarlo un sostituto della toolchain C++ di Unreal.
- Toolchain C++ prevista su Windows: Visual Studio 2022 17.14 o successivo compatibile con UE 5.6; componenti da verificare in `docs/TOOLS_AND_LICENSES.md`.
- Piattaforma iniziale candidata: Windows su Steam.
- Modalita iniziale candidata: single-player.
- Riferimenti dichiarati: *Deep Rock Galactic: Survivor* per resa 3D e leggibilita; *Vampire Survivors* per immediatezza, build e densita del loop.
- Visuale 3D isometrica/top-down: direzione principale candidata; tema e modello di progressione non ancora decisi.
- Base creativa corrente: ingegnere improvvisatore che costruisce macchine durante le missioni; le macchine trasformano il campo con vantaggi e conseguenze, mentre la manipolazione temporale e una meccanica secondaria candidata.
- Esperienza iniziale: base in Blender, quasi nulla in Unreal Engine e C/C++.
- Budget iniziale: molto basso; privilegiare soluzioni gratuite e rinviare acquisti non indispensabili.
- La roadmap autorevole e `docs/PROJECT_ROADMAP.md`.
- I vincoli raccolti sono in `docs/PROJECT_BRIEF.md`; le prime proposte in `docs/BRAINSTORMING_CONCEPTS.md`.
- Il concept corrente, ancora modificabile e non bloccato, e definito in `docs/WORKING_CONCEPT.md`.

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

Il progetto puo utilizzare Claude e altre AI per produrre codice, documentazione, test o proposte tecniche. Codex opera come supervisore tecnico e integratore, salvo diversa indicazione esplicita del proprietario.

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

## Regole Unreal Engine

- Usare convenzioni di denominazione coerenti per gli asset. Convenzione iniziale: prefissi espliciti come `BP_`, `WBP_`, `BPI_`, `DA_`, `DT_`, `M_`, `MI_`, `T_`, `SM_`, `SK_`, `A_`, `S_`, `NS_`.
- Organizzare gli asset per dominio o feature; evitare cartelle generiche permanenti come `Misc` e `NewFolder`.
- Non modificare manualmente i file binari `.uasset` e `.umap`.
- Usare Blueprint per iterazione e prototipazione. Introdurre C++ quando serve per prestazioni, infrastruttura stabile, testabilita o API non esposte; documentare il motivo.
- Evitare logica critica in Level Blueprint quando puo vivere in componenti, subsystem o classi riutilizzabili.
- Esporre parametri di bilanciamento tramite Data Asset, Data Table, Curve o configurazione equivalente.
- Definire budget misurabili per frame time, numero di proiettili, VFX, memoria e tempi di caricamento prima della vertical slice.
- Profilare prima di ottimizzare. Usare Unreal Insights e gli strumenti di profiling dell'engine per attribuire i colli di bottiglia.
- Verificare regolarmente una build Development pacchettizzata; per una release candidate verificare anche Shipping su una macchina pulita.

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
