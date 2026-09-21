# Review Terrain Grid Slice A

## Oggetto

- Branch: `feature/terrain-grid-slice`
- Commit: `40b7682`
- Revisori: Codex; seconda lettura read-only Claude Code 2.1.278.
- Stato: verifiche automatiche superate; playtest umano ancora richiesto.

## Evidenze verificate da Codex

- diff circoscritto a Character, GameMode, nuovo TerrainGridActor e specifica slice;
- nessuna dipendenza, `.uasset`, `.umap` o plugin aggiunto;
- UHT e compilazione Editor superati;
- compilazione Game e packaging Windows superati;
- avvio headless con marker griglia 7x7 e modalita iniziale Dig;
- screenshot a 1280x720 con griglia, preview e cella protetta leggibili;
- mapping mira validato `Direction=(-Y,+X)` preservato;
- clone remoto pulito dello stesso commit compilato e avviato headless.

## Disposizione dei rilievi della seconda review

### Cella protetta in `(0,0)`

**Nessuna modifica.** La posizione nell'angolo e intenzionale e richiesta dal brief di implementazione. Evita di bloccare la prima cella bersagliata davanti allo spawn e obbliga il tester a muoversi per verificare un rifiuto. La posizione e visibile nello screenshot automatico.

### Allineamento fra arena e griglia

**Nessuna modifica.** `FloorTopTarget` rappresenta la quota superiore desiderata. L'arena sposta la propria origine di `FloorThickness / 2`, quindi la faccia superiore torna esattamente a `FloorTopTarget`; la griglia viene collocata direttamente a quella quota. Il controllo visivo non mostra separazioni o compenetrazioni problematiche.

### Un componente e un materiale dinamico per cella

**Accettato per il prototipo.** Il default e 7x7, quindi 49 celle. Il limite configurabile 15x15 non costituisce un target produttivo. Prima di aumentare dimensione o usare ombre/collisioni dinamiche, misurare e confrontare `UInstancedStaticMeshComponent` o una presentazione batched.

### Include del TerrainGridActor nel Character header

**Accettato.** Il Character memorizza e inizializza `EPrototypeTerrainToolMode`, definito nello stesso header del TerrainGridActor; una semplice forward declaration dell'attore non elimina questa dipendenza. Separare i tipi in un nuovo header ora sarebbe astrazione prematura.

### Test automatici della logica discreta

**Debito reale, non bloccante per Slice A.** Transizioni e conversione mondo-cella sono piccole e testabili, ma la grammatica puo cambiare dopo il primo playtest. Aggiungere Automation Tests prima di rendere collisioni, percorsi o salvataggi dipendenti da questa logica.

## Rischi aperti prima del merge

- equivalenza reale di grilletto destro/clic sinistro;
- naturalezza del cambio modalita con dorsale, `Q` e clic destro;
- comprensione di colori e tre stati senza coaching;
- assenza di regressioni percepite su movimento, mira e dash;
- esecuzione e leggibilita sullo Steam Deck LCD.

Il branch non deve essere unito in `main` finche il proprietario non completa almeno il test desktop e sceglie `Continua`, `Modifica` oppure `Scarta/ripensa`.
