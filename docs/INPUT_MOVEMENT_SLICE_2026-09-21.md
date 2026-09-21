# Incremento input, movimento e camera - 21 settembre 2026

## Esito

**Collaudo manuale superato.** Il primo personaggio graybox usa una camera isometrica fissa, movimento planare e orientamento indipendente.

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
- stick sinistro: superato;
- orientamento con stick destro: superato dopo la correzione dell'asse orizzontale;
- leggibilita dell'orientamento: da migliorare, perche il rettangolo graybox ruota sul proprio asse senza un indicatore frontale evidente.

Verificare con controller reale e tastiera/mouse:

1. direzione e intensita del movimento;
2. assenza di deriva degli stick;
3. passaggio naturale tra mouse e stick destro;
4. stabilita della camera mentre il personaggio ruota;
5. leggibilita a 16:9.

Il test su Steam Deck LCD resta successivo alla stabilizzazione del primo loop giocabile. Velocita, accelerazione, sensibilita e dead zone saranno tarate in un incremento successivo; questo gate verifica soltanto correttezza e parita funzionale degli input.

## Character Feel v1 - collaudo manuale superato

Il secondo incremento aggiunge:

- un indicatore frontale ciano sul graybox;
- accelerazione, decelerazione, dead zone, sensibilita e rapidita di rotazione configurabili;
- dash semantico con `Spazio` o pulsante inferiore del gamepad;
- direzione del dash basata sull'ultima direzione di movimento valida, con fallback sull'orientamento;
- durata e cooldown configurabili, blocco del retrigger e feedback graybox tramite colore e scala;
- marker runtime `PROTOTYPE01_DASH_STARTED` e `PROTOTYPE01_DASH_READY`.

Verifiche automatiche superate il 21 settembre 2026:

- controllo del diff e degli errori di whitespace;
- compilazione Editor e Game Win64 Development;
- avvio headless con inizializzazione di input, personaggio, arena ed esposizione senza nuovi errori;
- packaging Windows Development;
- controllo visivo automatico dell'indicatore frontale a 1280x720.

Build locale da collaudare: `LocalBuilds/Prototype01-CharacterFeel-Win64-v2/Windows/Prototype01.exe`.

Esito manuale del 21 settembre 2026 sulla build v4:

- mira con stick destro corretta su entrambi gli assi dopo la verifica delle quattro direzioni;
- dash con il pulsante inferiore `A` funzionante;
- blocco durante il cooldown e successiva disponibilita del dash confermati;
- controlli precedentemente verificati con tastiera/mouse preservati.

Il gate Character Feel v1 e superato. Velocita, accelerazione, frenata e valori di sensibilita restano parametri di bilanciamento da affinare con scene e avatar piu rappresentativi, non blocchi per il prossimo incremento.

## Limiti intenzionali

Non sono ancora presenti terreno, nemici, arena definitiva, HUD, audio o arte finale. Il corpo e l'indicatore frontale sono soltanto graybox provvisori.
