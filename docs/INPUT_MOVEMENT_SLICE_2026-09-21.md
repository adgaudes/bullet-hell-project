# Incremento input, movimento e camera - 21 settembre 2026

## Esito

**Collaudo manuale parzialmente superato.** Il primo personaggio graybox usa una camera isometrica fissa, movimento planare e orientamento indipendente.

## Controlli

- movimento: `WASD` oppure stick sinistro;
- orientamento: posizione del mouse oppure stick destro;
- camera: prospettiva fissa, senza rotazione libera.

Le azioni `IA_Move`, `IA_Aim` e il mapping `IMC_Gameplay` vengono creati in C++ a runtime per questo primo test. Verranno trasformati in asset dati quando i controlli saranno stati validati, così potremo rimapparli e iterare senza ricompilare.

## Verifiche automatiche superate

- compilazione `Prototype01Editor` Win64 Development;
- inizializzazione di Enhanced Input;
- creazione e possesso del personaggio;
- caricamento della mappa e del GameMode;
- cook, packaging e avvio della build Windows Development;
- marker runtime `PROTOTYPE01_INPUT_READY`, `PROTOTYPE01_CHARACTER_READY` e `PROTOTYPE01_SMOKE_TEST_OK` presenti nel log.

Build locale: `LocalBuilds/Prototype01-Input-Win64/Windows/Prototype01.exe`.

## Collaudo manuale richiesto

Esito desktop del 21 settembre 2026:

- `WASD`: superato;
- orientamento con mouse: superato;
- rendering iniziale: superato dopo l'aggiunta dell'arena graybox e dell'esposizione stabile;
- controller: ancora da verificare.

Verificare con controller reale e tastiera/mouse:

1. direzione e intensita del movimento;
2. assenza di deriva degli stick;
3. passaggio naturale tra mouse e stick destro;
4. stabilita della camera mentre il personaggio ruota;
5. leggibilita a 16:9.

Il test su Steam Deck LCD resta successivo alla stabilizzazione del primo loop giocabile.

## Limiti intenzionali

Non sono ancora presenti dash, terreno, nemici, arena definitiva, HUD o arte. Il cubo allungato e soltanto un indicatore provvisorio della direzione del personaggio.
