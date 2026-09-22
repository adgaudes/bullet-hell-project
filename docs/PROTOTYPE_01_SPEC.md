# Prototipo 01 - Terreno sotto pressione

## Stato

- Specifica candidata in implementazione: toolchain Windows superata; input, movimento e camera pronti per il collaudo manuale dal 21 settembre 2026.
- Scopo: verificare il rischio principale del concept, non rappresentare la qualita finale.
- Engine previsto: Unreal Engine 5.8.2.
- Target: Windows; smoke test successivo su Steam Deck LCD.

## Domanda centrale

> Modificare il terreno da una visuale isometrica/top-down durante un combattimento a orde e divertente, leggibile e preciso con controller e tastiera/mouse?

Il prototipo non deve dimostrare l'intero gioco. Se questa domanda riceve una risposta negativa, si modifica il sistema prima di costruire carovana, veicoli, meteo o contenuti.

## Esperienza target

Durata di una sessione: 3-5 minuti.

Il giocatore deve:

1. muoversi e schivare forme nemiche provvisorie;
2. mirare un tool sul terreno;
3. scavare una trincea o alzare un terrapieno;
4. osservare i nemici cambiare percorso;
5. scoprire che la stessa modifica crea anche uno svantaggio;
6. usare una macchina per applicare la trasformazione su scala maggiore;
7. sopravvivere o riavviare rapidamente.

## Scope obbligatorio

### Personaggio

- capsula o mesh provvisoria;
- movimento analogico e WASD;
- orientamento indipendente con stick destro o mouse;
- dash con cooldown leggibile;
- punti vita e breve invulnerabilita dopo un colpo;
- morte e restart rapido;
- arma automatica provvisoria, senza sistema di build.

### Camera

- prospettiva fissa isometrica/top-down candidata;
- zoom e inclinazione definiti come dati modificabili;
- nessuna rotazione libera nel primo test;
- ostacoli trasparenti o rimossi quando coprono giocatore e cursore;
- test a 16:9 e 16:10/1280x800.

### Input

Azioni Enhanced Input candidate:

- `IA_Move`;
- `IA_Aim`;
- `IA_Dash`;
- `IA_TerrainTool`;
- `IA_TerrainMode`;
- `IA_DeployMachine`;
- `IA_Confirm`;
- `IA_Cancel`;
- `IA_Pause`.

Mapping context:

- `IMC_Gameplay`;
- `IMC_TerrainTool`;
- `IMC_UI`.

Non legare la logica a tasti fisici. Il prototipo deve poter essere completato senza cambiare dispositivo.

### Arena

- piccola superficie graybox delimitata;
- la mappa `SmokeTest` mantiene una preview editoriale calda e leggibile tramite attori nella cartella `EditorPreview`; sono `Editor Only` e `Hidden In Game`, quindi non sostituiscono ne alterano l'arena generata a runtime;
- stato logico suddiviso in celle o regioni, inizialmente non deformazione continua;
- terreno normale;
- stato abbassato/trincea;
- stato rialzato/terrapieno;
- un corridoio iniziale e almeno due vie alternative;
- una zona protetta/non modificabile per verificare feedback e limiti.

Dimensioni e risoluzione esatte vengono scelte dopo un test di scala nell'Editor. Evitare numeri fissati senza osservazione della camera e del movimento.

### Tool personale

Un solo strumento con due modalita:

- **Scava:** abbassa una cella o regione piccola;
- **Solleva:** rialza una cella o regione piccola.

Requisiti:

- volume bersaglio chiaramente visibile;
- anteprima valida/non valida;
- portata limitata;
- breve tempo di utilizzo o carica;
- feedback audio/visivo provvisorio;
- costo semplice, ad esempio energia che si rigenera;
- annullamento prima della conferma;
- nessun menu radiale complesso.

### Macchina

Una sola macchina provvisoria: **Terraformer Lineare**.

Comportamento:

- viene posizionata o orientata dal giocatore;
- applica Scava oppure Solleva lungo una breve linea o area;
- lavora piu lentamente del tool istantaneo, ma su scala maggiore;
- consuma energia o richiede un breve tempo di avvio;
- genera rumore/pressione aumentando temporaneamente l'arrivo dei nemici;
- puo bloccare la via di fuga se posizionata male.

La macchina non e pilotabile e non si aggancia ancora ad altri moduli.

### Nemici provvisori

Nessuna decisione artistica o narrativa viene implicata.

1. **Ground Chaser:** segue il giocatore e rispetta trincee, terrapieni e percorsi validi.
2. **Terrain Ignorer:** forma volante/astratta che ignora la modifica del terreno ma ha pressione inferiore.

La coppia serve a impedire che una singola barriera risolva tutto e a verificare se il terreno produce decisioni invece di una strategia dominante.

### Obiettivo

Difendere per 3-5 minuti un nucleo provvisorio o sopravvivere a ondate brevi. Il nucleo puo rendere interessante la geometria, ma non deve introdurre un sistema tower defense completo.

## Regole di terreno da testare

### Trincea

Vantaggio:

- devia o rallenta i nemici terrestri;
- puo creare una zona sicura temporanea.

Conseguenza:

- riduce spazio di movimento;
- puo convogliare troppi nemici verso lo stesso punto;
- non protegge dal nemico che ignora il terreno.

### Terrapieno

Vantaggio:

- blocca o devia il percorso;
- protegge la macchina o il nucleo.

Conseguenza:

- interrompe linee di tiro o fuga;
- puo intrappolare il giocatore;
- genera un percorso piu lungo ma piu denso.

## Architettura candidata

Separare fin dall'inizio:

- `TerrainState`: dati logici delle celle/regioni;
- `TerrainPresentation`: mesh/materiali graybox;
- `TerrainCollision`: collisioni applicate;
- `TerrainNavigation`: aggiornamento dei percorsi;
- `TerrainCommand`: richiesta validata di scavo/sollevamento;
- `TerrainPreview`: anteprima locale per input;
- `TerrainModifier`: interfaccia condivisa da tool e macchina.

Blueprint e C++:

- iniziare in Blueprint per iterare su camera, input e regole;
- mantenere dati e responsabilita separati;
- spostare aggiornamenti critici in C++ soltanto dopo profiling o quando la struttura si stabilizza;
- non aggiungere plugin voxel nel Prototipo 01.

## Ordine di implementazione

1. Progetto C++ minimo e packaging Windows verificato.
2. Enhanced Input per controller e tastiera/mouse.
3. Personaggio, camera, collisione, dash e restart.
4. Arena graybox e stato logico del terreno.
5. Anteprima e tool Scava/Solleva.
6. Aggiornamento visivo e collisioni.
7. Ground Chaser e aggiornamento percorso.
8. Terrain Ignorer.
9. Terraformer Lineare.
10. Energia, conseguenza e feedback provvisori.
11. HUD minimo e timer.
12. Scena di stress e profiling.
13. Build Windows pacchettizzata.
14. Smoke test su Steam Deck LCD tramite Proton.
15. Primo playtest e decisione continua/modifica/scarta.

## Fuori scope

- arte finale e ambientazione completa;
- vegetazione complessa;
- acqua, pioggia e super-temporali;
- luce/buio sistemici;
- terreno voxel o deformazione continua;
- tunnel e caverne;
- carovana, aggancio e fusione;
- mezzi pilotabili terrestri, aerei o acquatici;
- manipolazione temporale;
- inventario, crafting libero o meta-progressione;
- boss, narrativa, salvataggio permanente e Steamworks;
- demo pubblica.

## Metriche tecniche

Registrare almeno:

- frame time prima, durante e dopo la modifica;
- tempo per aggiornare collisioni e percorsi;
- numero di modifiche consecutive senza errore;
- nemici attivi e costo del loro pathfinding;
- memoria della scena;
- input latency percepita;
- prestazioni a 1280x800 su Steam Deck LCD.

I budget numerici vengono fissati dopo la prima baseline, non inventati prima di avere una build.

## Protocollo di playtest

Non spiegare la strategia corretta. Spiegare soltanto controlli e obiettivo.

Osservare:

- quanto tempo serve per capire il bersaglio del tool;
- quante modifiche accidentali avvengono;
- se il giocatore usa sia Scava sia Solleva;
- se anticipa i percorsi dei nemici;
- se riconosce lo svantaggio creato;
- se preferisce controller o mouse e perche;
- se desidera continuare a modificare il campo dopo 3-5 minuti.

Domande finali:

- Quale modifica ti e sembrata piu utile?
- Hai mai creato involontariamente un problema interessante?
- Il terreno era leggibile dalla camera?
- Il tool sembrava preciso o frustrante?
- Avresti voluto una terza azione? Quale?
- La macchina sembrava un'estensione del tool o un sistema separato?

## Criteri di successo

Il prototipo supera il gate se:

- il giocatore comprende il bersaglio del tool senza spiegazioni ripetute;
- controller e tastiera/mouse permettono entrambi modifiche intenzionali;
- Scava e Solleva producono decisioni differenti;
- almeno una modifica crea spontaneamente un vantaggio e un problema;
- i nemici reagiscono senza blocchi frequenti;
- restart e nuova prova sono rapidi;
- le prestazioni restano stabili dopo modifiche ripetute;
- il playtester vuole sperimentare altre forme del terreno.

## Criteri di arresto o revisione

Fermare l'espansione e rivedere il sistema se:

- la camera rende impossibile giudicare profondita o pendenza;
- il controller richiede assistenza tanto forte da eliminare intenzionalita;
- l'aggiornamento dei percorsi causa stutter o blocchi continui;
- una modalita domina sempre;
- le conseguenze risultano casuali anziche prevedibili;
- il terreno viene usato soltanto come arma o raccolta e non come spazio da progettare;
- il prototipo non e interessante senza contenuti, progressione o grafica finale.

## Deliverable

- progetto Unreal compilabile;
- mappa graybox del prototipo;
- build Windows Development;
- risultato smoke test Steam Deck;
- video non montato di una sessione;
- metriche tecniche iniziali;
- note del primo playtest;
- decisione: continuare, modificare radicalmente o scartare l'approccio.
