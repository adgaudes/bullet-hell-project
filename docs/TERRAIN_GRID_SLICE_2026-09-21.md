# Terrain Slice A - griglia, mira e trasformazione

## Stato

- Fase: Prototipo 01, primo incremento del sistema terreno.
- Branch: `feature/terrain-grid-slice`.
- Obiettivo: verificare leggibilita e precisione dell'interazione dalla camera isometrica.
- Natura: esperimento graybox scartabile; non e la tecnologia finale del terreno.

## Domanda del test

Il giocatore comprende quale regione sta mirando e riesce a scavare, sollevare e ripristinare celle con naturalezza usando sia controller sia tastiera/mouse?

## Scope autorizzato

- griglia logica discreta piccola, centrata nell'arena;
- stati `Lowered`, `Normal` e `Raised`, separati dalla mesh di presentazione;
- una cella protetta/non modificabile per verificare il feedback di rifiuto;
- cursore/anteprima sulla cella davanti al personaggio, aggiornato dalla direzione di mira;
- modalita `Dig` e `Raise` commutabile;
- un comando applica un singolo passo reversibile:
  - `Dig`: `Raised -> Normal -> Lowered`;
  - `Raise`: `Lowered -> Normal -> Raised`;
- input semantici creati nel mapping di prototipo:
  - usa tool: clic sinistro / grilletto destro;
  - cambia modalita: clic destro o `Q` / dorsale sinistro;
- feedback visivo graybox e marker di log riproducibili;
- parametri principali configurabili in C++/Editor.

## Fuori scope

- voxel o deformazione continua;
- collisioni e navigazione dinamiche;
- nemici, danno, arma, risorse, energia e HUD definitivo;
- macchina terraformante, acqua, vegetazione e persistenza fra sessioni;
- asset o plugin esterni.

Le celle di questo incremento sono rappresentazione e stato logico: non devono ancora alterare il movimento. Collisioni e conseguenze tattiche appartengono al successivo incremento, dopo la validazione dell'interazione.

## Architettura minima

- `APrototype01TerrainGridActor`: possiede stato logico, conversione mondo-cella, validazione dei comandi e presentazione graybox.
- `APrototype01Character`: possiede soltanto azioni input e modalita tool; inoltra bersaglio e comando alla griglia.
- `ASmokeTestGameMode`: crea e collega la griglia alla stessa quota del pavimento dell'arena.

Non inserire logica del terreno nel Level Blueprint o nell'attore dell'arena. Non usare `.uasset` o `.umap` nuovi.

## Criteri di accettazione automatici

- compilazione Editor e Game Win64 Development;
- packaging e avvio della build Windows;
- marker `PROTOTYPE01_TERRAIN_GRID_READY` senza nuovi errori nei log;
- stato logico indipendente dalla scala/posizione visuale delle celle;
- indice e coordinate validati prima di ogni modifica;
- input di movimento, mira e dash esistenti non regressi.

## Collaudo manuale richiesto

1. l'anteprima segue chiaramente mouse e stick destro;
2. la cella selezionata corrisponde alla direzione percepita;
3. cambio modalita e comando funzionano con entrambi gli schemi;
4. i tre stati sono distinguibili a colpo d'occhio;
5. la cella protetta comunica chiaramente il rifiuto;
6. movimento, mira e dash precedenti restano corretti.

## Gate

Il slice supera il gate solo se il bersaglio e la trasformazione risultano comprensibili senza spiegazioni ripetute. La fedelta geometrica non e un criterio di successo in questa fase.

## Verifiche automatiche del 21 settembre 2026

- compilazione `Prototype01Editor` Win64 Development superata;
- reflection/UHT delle nuove classi superata;
- avvio headless senza nuovi errori;
- marker `PROTOTYPE01_TERRAIN_GRID_READY Width=7 Height=7` e modalita iniziale `Dig` presenti;
- build Game Win64 Development e packaging superati;
- controllo visivo a 1280x720 superato per griglia, personaggio, anteprima e cella protetta.

Build locale da collaudare: `LocalBuilds/Prototype01-TerrainGrid-Win64-v1/Windows/Prototype01.exe`.

Il gate resta aperto fino al collaudo manuale degli input e della comprensione dei tre stati.
