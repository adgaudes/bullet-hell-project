# Smoke test migrazione UE 5.8.2 - 22 settembre 2026

## Esito

Migrazione tecnica riuscita sul branch `codex/ue58-migration`. Il progetto e associato a Unreal Engine 5.8, usa le impostazioni build V7 e fissa Visual Studio 2026 con famiglia MSVC 14.51.36231 per i target Editor e Game.

## Controlli eseguiti

- installazione UE 5.8.2 rilevata in `C:\Program Files\Epic Games\UE_5.8`;
- plugin engine `ModelContextProtocol`, `AllToolsets`, Fab, Bridge, Python e Editor Scripting presenti;
- Visual Studio Community 2026 18.10.1, MSVC 14.51.36231 e Windows SDK rilevati;
- rebuild `Prototype01Editor Win64 Development`: riuscita;
- rebuild `Prototype01 Win64 Development` senza override da riga di comando: riuscita e toolchain VS2026 14.51.36257 selezionata;
- apertura headless di `/Game/Maps/SmokeTest`: mappa caricata, Map Check con 0 errori e 0 avvisi;
- BuildCookRun Windows Development con cook, stage, pak, IoStore e archive: `BUILD SUCCESSFUL`;
- avvio della build pacchettizzata: mappa `SmokeTest` caricata e marcatori `PROTOTYPE01_INPUT_READY`, `PROTOTYPE01_CHARACTER_READY`, `PROTOTYPE01_SMOKE_TEST_OK`, `PROTOTYPE01_EXPOSURE_READY`, `PROTOTYPE01_ARENA_READY` presenti.

## Note e rischi residui

- UE 5.8.2 avvisa che MSVC 14.51.36257 e piu recente della 14.50.35717 preferita. Non sono emersi errori nel codice del progetto; gli avvisi C4996 osservati provengono dagli header dell'engine.
- AutomationTool ha inizialmente rilevato MSBuild di VS2022 per i propri script, mentre UnrealBuildTool ha compilato entrambi i target con VS2026. Dopo la rimozione di VS2022 va ripetuta una build incrementale per confermare la selezione autonoma di MSBuild 18.
- il primo avvio headless in sandbox non poteva scrivere nella cache globale; il test e stato ripetuto con cache in memoria. Cook e packaging eseguiti con accesso normale alla cache sono riusciti.
- asset e mappe non sono stati risalvati in massa nella nuova versione; preservare il rollback e convertire solo quando necessario.

## Gate pulizia

Le condizioni tecniche per rimuovere Unreal Engine 5.6.1, Visual Studio 2022 e IncrediBuild sono soddisfatte. Prima della rimozione salvare e pubblicare il branch di migrazione; dopo la pulizia ripetere la verifica di installazione e almeno una build incrementale.
