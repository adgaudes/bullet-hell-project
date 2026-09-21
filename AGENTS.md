# AGENTS.md

## Scopo del progetto

Questo repository contiene un videogioco indipendente destinato alla pubblicazione su Steam. Il concept iniziale e un bullet hell, con prospettiva ancora da scegliere tra isometrica dall'alto e scorrimento laterale.

Obiettivo di produzione: arrivare a un gioco piccolo, rifinito, testabile e commercialmente pubblicabile. La qualita del game feel e la leggibilita hanno priorita sulla quantita di contenuti.

## Stato corrente

- Fase attiva: fondazione del progetto e brainstorming.
- Engine previsto: Unreal Engine 5, versione da fissare prima di creare il progetto.
- DCC 3D previsto: Blender, versione LTS/stabile da fissare prima della produzione degli asset.
- Piattaforma iniziale candidata: Windows su Steam.
- Modalita iniziale candidata: single-player.
- Prospettiva, stile, tema e modello di progressione: non ancora decisi.
- La roadmap autorevole e `docs/PROJECT_ROADMAP.md`.

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

