# Smoke test toolchain - 21 settembre 2026

## Esito

**Superato.** Il progetto tecnico `Prototype01` compila, genera una mappa Unreal, esegue il cook, produce una build Windows Development e avvia correttamente il GameMode nativo.

Questo nome e un identificatore interno del prototipo, non il titolo commerciale del gioco.

## Ambiente verificato

- Unreal Engine 5.6.1, changelist 44394996;
- Visual Studio Community 2022 17.14.41;
- MSVC 14.44.35207, compilatore 19.44.35229;
- Windows SDK 10.0.26100;
- target Windows x64 Development.

## Controlli completati

1. Compilazione `Prototype01Editor`: riuscita, incluso UnrealHeaderTool e codice reflection.
2. Avvio headless di Unreal Editor: riuscito.
3. Generazione e salvataggio di `/Game/Maps/SmokeTest`: riusciti tramite `LevelEditorSubsystem`.
4. Validazione della mappa: 0 errori e 0 avvisi.
5. Compilazione target `Prototype01` Windows Development: riuscita.
6. Cook: 433 pacchetti prodotti, 0 errori e 0 avvisi finali.
7. Staging, pak, IoStore e archivio: riusciti.
8. Avvio dell'eseguibile pacchettizzato: codice 0.
9. GameMode caricato: `SmokeTestGameMode`.
10. Marcatore runtime rilevato: `PROTOTYPE01_SMOKE_TEST_OK`.
11. Log runtime: nessun errore, fatal error o warning rilevato.
12. `Content/Maps/SmokeTest.umap`: correttamente coperto da Git LFS.

La build locale non ottimizzata occupa circa 868 MiB. E una baseline Development vuota con runtime Unreal e non rappresenta la dimensione finale del gioco; `LocalBuilds/` resta esclusa da Git.

## Avvisi non bloccanti

- UnrealBuildTool accetta MSVC 14.44 ma segnala 14.38 come versione preferita. Non aggiungere ora una seconda toolchain: la compilazione e il packaging sono riusciti; rivalutare solo davanti a errori riproducibili o prima di fissare l'ambiente di release.
- XGE/Incredibuild e presente ma senza licenza e lavora in standalone. Non acquistare o configurare una licenza in questa fase.
- La memoria libera durante i test era bassa e ha limitato la compilazione a un processo, senza causare errori. Chiudere applicazioni pesanti prima delle future build estese.
- La build e stata verificata senza rendering (`-nullrhi`). Apertura grafica, input reale e resa visiva restano test separati.

## Gate e prossimo passo

Il gate della toolchain Windows e superato. Il prossimo incremento del Prototipo 01 e configurare Enhanced Input con azioni semantiche e parita funzionale tra controller e tastiera/mouse, seguito da un primo avvio grafico controllato.

Restano fuori da questo test:

- gameplay e UI;
- input con controller reale;
- prestazioni grafiche;
- build Shipping;
- avvio tramite Proton su Steam Deck LCD.
