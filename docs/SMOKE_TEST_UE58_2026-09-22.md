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

## Pulizia e verifica definitiva

- Unreal Engine 5.6 e i relativi manifest Fab/Bridge sono stati rimossi tramite Epic Games Launcher; rimane soltanto `UE_5.8`.
- Visual Studio 2022 e IncrediBuild sono stati rimossi; `vswhere` rileva soltanto Visual Studio Community 2026, completo e avviabile.
- dopo la pulizia, AutomationTool ha selezionato `C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe`;
- build Editor/Game, cook completo di 501 pacchetti, stage, pak, IoStore e archive sono riusciti con `BUILD SUCCESSFUL`;
- la nuova build pacchettizzata ha emesso nuovamente tutti i marcatori `PROTOTYPE01_*` attesi senza errori fatali;
- le due build temporanee usate per la migrazione sono state eliminate, recuperando circa 1,8 GB. Sorgenti, asset e cronologia Git sono rimasti intatti.

## Note e rischi residui

- UE 5.8.2 avvisa che MSVC 14.51.36257 e piu recente della 14.50.35717 preferita. Non sono emersi errori nel codice del progetto; gli avvisi C4996 osservati provengono dagli header dell'engine.
- Prima della pulizia AutomationTool rilevava MSBuild di VS2022 per i propri script; dopo la rimozione seleziona correttamente MSBuild 18 di VS2026.
- il primo avvio headless in sandbox non poteva scrivere nella cache globale; il test e stato ripetuto con cache in memoria. Cook e packaging eseguiti con accesso normale alla cache sono riusciti.
- asset e mappe non sono stati risalvati in massa nella nuova versione; preservare il rollback e convertire solo quando necessario.

## Gate pulizia

Completato. UE 5.6, Visual Studio 2022 e IncrediBuild sono stati rimossi soltanto dopo il backup remoto della migrazione; la toolchain rimanente e stata verificata nuovamente.
