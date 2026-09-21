# Playtest Terrain Slice A - desktop e Steam Deck LCD

## Obiettivo

Verificare separatamente:

1. se bersaglio, modalita e stati del terreno sono comprensibili;
2. se la build Windows funziona sullo Steam Deck LCD tramite Proton.

Questo test non valuta ancora combattimento, collisioni dinamiche, grafica finale o divertimento di una run.

## Build

- Branch: `feature/terrain-grid-slice`
- Commit: `40b7682`
- Eseguibile desktop: `LocalBuilds/Prototype01-TerrainGrid-Win64-v1/Windows/Prototype01.exe`
- Archivio Deck consigliato: `Artifacts/Playtests/Prototype01-TerrainGrid-Win64-v1-Deck.zip`
- Dimensione archivio Deck: `286826203` byte, circa 274 MiB.
- Hash SHA-256: `DE499AB9DC0AD619E5599B471AF1B54F23820680C7BE00985E217BC70EBEA755`, registrato anche nel file omonimo `.sha256` accanto all'archivio.
- Verifica archivio: estrazione completata, eseguibile identico alla build sorgente e nessun simbolo `.pdb` incluso. La rimozione dei simboli riduce il trasferimento senza cambiare il gioco.

## Regole del test

- Prima osservare, poi commentare: non cercare una strategia corretta.
- Usare almeno una volta entrambi gli schemi desktop.
- Non valutare l'assenza di collisione delle celle come bug: e intenzionale nello Slice A.
- Annotare il primo istante di confusione, anche se viene risolto subito.
- Se una funzione non e chiara, provare per trenta secondi prima di leggere la legenda sotto.

## Legenda controlli

| Azione | Controller | Tastiera/mouse |
|---|---|---|
| Movimento | stick sinistro | `WASD` |
| Orientamento / bersaglio | stick destro | mouse |
| Dash | `A` / pulsante inferiore | `Spazio` |
| Applica tool | grilletto destro | clic sinistro |
| Cambia Scava/Solleva | dorsale sinistro | `Q` o clic destro |

- anteprima ciano: Scava;
- anteprima gialla: Solleva;
- anteprima rossa: comando impossibile;
- cella rosa: protetta.

## Test A - Desktop, 5-10 minuti

1. Avviare la build senza aprire Unreal Editor.
2. Verificare movimento, mira e dash gia approvati.
3. Puntare almeno otto celle da direzioni diverse con il mouse.
4. Ripetere usando soltanto il controller.
5. Scavare una cella da `Normal` a `Lowered`.
6. Cambiare modalita e riportarla a `Normal`, poi a `Raised`.
7. Tentare un comando oltre il limite dello stato e osservare l'anteprima rossa.
8. Raggiungere la cella rosa e tentare di modificarla.
9. Modificare rapidamente almeno dieci celle, includendo cambi di modalita.

### Risultati desktop

| Domanda | Esito / nota |
|---|---|
| La cella selezionata coincide con la direzione percepita? | |
| Ciano, giallo e rosso comunicano il significato senza esitazione? | |
| Lowered, Normal e Raised sono distinguibili? | |
| Il cambio modalita e naturale con controller? | |
| Il cambio modalita e naturale con mouse/tastiera? | |
| Quante modifiche involontarie sono avvenute? | |
| La cella protetta comunica chiaramente il rifiuto? | |
| Movimento, mira e dash hanno subito regressioni? | |

## Test B - Steam Deck LCD, 10-15 minuti

### Preparazione raccomandata

Per distribuzioni ripetute, la procedura ufficiale Valve usa **SteamOS Devkit Client**, gratuito nella libreria Steam sotto Software. PC e Deck devono trovarsi sulla stessa rete locale; sul Deck vanno abilitati Developer Mode e `Pair new host`. Nel caricamento selezionare la cartella Windows della build, indicare `Prototype01.exe` come comando iniziale e attivare **Steam Play**.

Valve raccomanda di aver gia installato e avviato sul Deck almeno un altro gioco Windows che usa Proton, cosi Proton e le dipendenze sono presenti.

Fonte ufficiale: https://partner.steamgames.com/doc/steamhardware/loadgames?language=english

Non installare SteamOS Devkit Client senza conferma del proprietario. Se domani non e disponibile, rimandare il test invece di improvvisare configurazioni non documentate.

### Esecuzione

1. Avviare la build caricata con Steam Play/Proton.
2. Verificare che appaia e funzioni a 1280x800 o, come fallback, 1280x720.
3. Ripetere movimento, mira, dash e trasformazioni usando soltanto i controlli integrati.
4. Osservare frame pacing durante almeno dieci modifiche consecutive.
5. Controllare leggibilita tenendo il Deck alla normale distanza d'uso.
6. Sospendere il Deck durante la sessione, attendere alcuni secondi e riprendere.
7. Chiudere e riavviare la build.

Valve indica 1280x800 come risoluzione preferita e 1280x720 come supportata; il testo non dovrebbe mai scendere sotto 9 pixel a 1280x800 e il target interno resta 12 pixel.

Fonte ufficiale: https://partner.steamgames.com/doc/steamhardware/compat?language=english

### Risultati Steam Deck

| Campo | Esito / nota |
|---|---|
| Versione SteamOS e canale | |
| Versione Proton | |
| Risoluzione rilevata | |
| Avvio riuscito | |
| Controller integrato completo | |
| Anteprima e stati leggibili | |
| Frame pacing percepito | |
| Sospensione/ripresa | |
| Chiusura e secondo avvio | |
| Problemi specifici | |

## Gate e decisione

Scegliere un solo esito dopo il test:

- **Continua:** interazione chiara; iniziare Terrain Slice B con collisioni/conseguenze.
- **Modifica:** idea valida ma targeting o feedback richiedono un nuovo Slice A.
- **Scarta/ripensa:** la grammatica discreta non consente modifiche intenzionali dalla camera scelta.

Non unire `feature/terrain-grid-slice` in `main` prima di questa decisione.
