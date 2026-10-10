# Review indipendente: ferrovia, Trivella, treno e campagna (10 ottobre 2026)

**Fonte:** Codex (gpt-6-sol) in un worktree di sola lettura su `feature/arena-run` (commit 5c51fc2), review statica: nessuna suite eseguita dal revisore. Riletta e verificata dall'agente principale: stato riga per riga nella colonna "Stato".


**Esito:** 0 rilievi A, 5 M, 2 B. La review è statica: `godot_console` non è disponibile nel PATH di questa sessione, quindi **non ho eseguito suite, playtest o misure prestazionali**. I casi che richiedono una riproduzione sono indicati come ipotesi. Nessun file è stato modificato o committato.

| ID | Gravità | File:righe | Problema | Come riprodurre | Proposta |
|---|---|---|---|---|---|
| F-01 | M | `train_event.gd:258`, `terrain_grid.gd:357` | **Ipotesi:** la spinta del treno assegna sempre `z = ±4,4 m`, senza verificare la cella di arrivo. Una cella Raised nella riga adiacente può ricevere il giocatore, il compagno o la Trivella al proprio interno. | Alzare una cella centrata a `z = 4,8 m`, attendere il treno sulla fascia e osservare la spinta verso sud. I test controllano solo che il personaggio sia fuori dalla fascia. | Cercare una posizione libera e percorribile sul lato scelto; aggiungere un test con muro e ostacolo statico al punto di arrivo. |
| F-02 | M | `driller.gd:241`, `driller.gd:299` | **Ipotesi:** la mira controlla rovine soltanto a 3, 6 e 9 m. Una rovina più avanti sulla linea annunciata porta a una carica che termina contro l’edificio; la striscia continua invece a promettere 30 m. Il test esistente verifica una rovina vicina, non questo caso. | Porre una rovina sulla linea fra Trivella e giocatore a circa 12–20 m dalla Trivella; osservare mira e motivo di fine carica. | Sondare l’intera linea annunciata con una query fisica e accorciare la striscia, oppure scegliere prima una direzione percorribile. |
| F-03 | M | `player_profile.gd:95`, `arena_run.gd:514` | `bank_run()` ignora l’esito di `save_profile()`; `_bank()` restituisce comunque il nuovo saldo in memoria. Se il salvataggio fallisce, la vittoria sembra aver sbloccato il livello ma lo sblocco sparisce al riavvio. | Forzare un errore di scrittura sul percorso di un profilo di test, vincere il quartiere, riavviare e rileggere il profilo. | Propagare l’errore alla schermata finale e consentire un nuovo tentativo; testare esplicitamente il fallimento di scrittura. |
| F-04 | M | `arena_run.gd:451` | **Ipotesi di regressione:** alla vittoria `build_run_map()` precede `_bank()`, nonostante il commento prometta l’incasso prima della mappa. Un errore nella generazione della mappa può interrompere la chiusura prima del salvataggio della vittoria. | Provocare un errore controllato in `build_run_map()` durante `_end_level(true)` e verificare se il profilo è stato aggiornato. | Calcolare e salvare l’esito prima della mappa; isolare il fallimento della mappa dal completamento del livello. |
| F-05 | M | `train_event.gd:239`, `driller.gd:171` | Il treno passa i 30 danni previsti a `take_damage()`, che li raddoppia se la Trivella è stordita. La specifica indica **30 danni dal treno**; il test del treno contro il boss lo mette espressamente a riposo. | Far colpire dal treno una Trivella in fase `STUN`: perderà 60 punti vita con il moltiplicatore attuale. | Decidere se il treno debba beneficiare dello stordimento; se il valore fissato è 30, separare danno ambientale e danno delle armi e testare entrambe le fasi. |
| F-06 | B | `player_profile.gd:121`, `player_profile.gd:149` | La versione letta viene registrata, ma ogni salvataggio riscrive `VERSION = 1`. Di un profilo futuro conserva gli upgrade sconosciuti, mentre scarta eventuali altre chiavi o sezioni sconosciute. | Caricare un profilo di test con versione 2 e una nuova chiave in `profile`, poi salvarlo: versione e chiave vengono perse. | Per versioni maggiori, preservare il `ConfigFile` originale o impedire la riscrittura automatica finché non esiste una migrazione esplicita. |
| F-07 | B | `railway_district.gd:158`, `train_event.gd:208`, `terrain_grid.gd:388` | Il treno riporta i vagoni a Normal, ma non cancella la loro tinta Raised. Se il giocatore rialza in seguito una di quelle celle, può ricomparire il colore ruggine del vagone. | Dopo un passaggio, rialzare una cella occupata prima da un vagone e confrontarne il colore con una cella nuova. | Cancellare la tinta quando il treno spiana la cella; aggiungere un controllo sul rialzo successivo. |

**Ordine consigliato:** verificare e correggere F-01 e F-03, poi F-04; chiarire la regola di danno per F-05; riprodurre F-02; infine affrontare F-06 e F-07. Le suite `railway_tests`, `train_tests`, `driller_tests` e `campaign_tests` restano da eseguire in un ambiente con `godot_console` disponibile.

| F-08 | M | `railway_district.gd:82-101` | Trovato dall'agente principale nell'inventario dell'ambiente: `RailwayDistrict._compose()` non chiama `_reset_ruin_details()` ne `_build_ruin_details()`: le corone di frammenti e i tondini delle rovine e delle torri (D-068, D-070) non vengono mai costruiti nel livello 2 e i buffer `_wall_crown`/`_edge_crown` crescono a ogni ricostruzione. | Aprire `railway_run.tscn`: nessun nodo `RuinCrowns`/`RuinRebar`. | Chiamare le due funzioni come fa `RuinsDistrict._compose()`; test in `railway_tests` sulla presenza dei due MultiMesh. |

## Stato

| ID | Stato |
|---|---|
| F-01 | da verificare |
| F-02 | da verificare |
| F-03 | da verificare |
| F-04 | da verificare |
| F-05 | da verificare |
| F-06 | da verificare |
| F-07 | da verificare |
| F-08 | confermata; **corretta il 10 ottobre 2026**: `RailwayDistrict._compose()` chiama `_reset_ruin_details()` e `_build_ruin_details()`; test in `railway_tests` sui due MultiMesh e sulle statistiche |
