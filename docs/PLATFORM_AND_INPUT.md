# Piattaforme e input

## Stato e obiettivi

- Piattaforma di sviluppo e prima release: **Windows PC**.
- Distribuzione prevista: **Steam**.
- Input primario: **controller/gamepad**.
- Input pienamente supportato: **tastiera e mouse**.
- Obiettivo secondario: buona esperienza su **Steam Deck**, con aspirazione alla classificazione Verified se sostenibile.
- Build Linux nativa: non prevista inizialmente; la prima strategia e testare la build Windows attraverso Proton.

La classificazione Steam Deck non puo essere promessa prima dei test e della revisione Valve. Il progetto deve tuttavia evitare fin dall'inizio scelte che la rendano inutilmente difficile.

## Principio controller-first, input-parity

Controller-first significa che movimento, combattimento, costruzione, guida, inventario, menu e impostazioni vengono progettati prima per un gamepad standard. Non significa offrire a tastiera e mouse un'esperienza inferiore.

Requisiti:

- ogni funzione necessaria deve essere raggiungibile con entrambi gli schemi;
- nessun menu deve richiedere il mouse;
- nessuna azione obbligatoria deve richiedere precisione da cursore non riproducibile con stick;
- cambiare dispositivo deve aggiornare rapidamente i glifi mostrati;
- controller collegato o scollegato durante il gioco non deve bloccare la sessione;
- rimappatura, sensibilita, inversione assi e dead zone devono essere previste nell'architettura;
- le impostazioni devono distinguere chiaramente controller, tastiera e mouse;
- il gameplay non deve dipendere da combinazioni scomode o dal clic degli stick per azioni frequenti;
- vibrazione e aim assist, se presenti, devono essere configurabili.

## Implementazione Unreal candidata

Usare **Enhanced Input**, incluso in Unreal Engine, con azioni semantiche e mapping context separati per:

- gameplay a piedi;
- modalita costruzione;
- guida delle macchine;
- menu e UI;
- eventuale modalità foto o debug, non inclusa nel prototipo.

Le azioni devono descrivere intenzioni (`Move`, `Aim`, `Dash`, `Build`, `RotateMachine`, `Interact`, `EnterVehicle`) e non tasti fisici. Blueprint e codice devono ascoltare le azioni, non controllare direttamente pulsanti specifici.

## Schema iniziale candidato

Non e ancora approvato e verra verificato nel prototipo.

| Intenzione | Controller | Tastiera/mouse |
|---|---|---|
| Movimento | stick sinistro | WASD |
| Mira o orientamento costruzione | stick destro | mouse |
| Dash/evasione | pulsante frontale | Spazio |
| Interazione | pulsante frontale | E |
| Modalita costruzione | dorsale o grilletto | tasto dedicato |
| Posizionamento/conferma | grilletto o pulsante frontale | clic sinistro |
| Rotazione/modulo | dorsali o croce direzionale | rotella/tasti |
| Abilita mirata | grilletto | clic destro o tasto dedicato |
| Pausa/menu | Menu | Esc |

L'arma personale automatica resta la prima ipotesi, per lasciare gli stick a movimento e orientamento/ingegneria. Un attacco manuale o semi-automatico verra aggiunto soltanto se non sovraccarica il controllo durante costruzione e trasformazione del campo.

## UI e accessibilita di input

- navigazione direzionale esplicita e prevedibile;
- focus sempre visibile;
- nessun hover indispensabile;
- conferma e annullamento coerenti in tutti i menu;
- slider regolabili con controller senza salti eccessivi;
- prompt con glifi corretti per il dispositivo attivo;
- opzione per aumentare dimensione testo e UI;
- contrasto sufficiente in luce e buio;
- pausa disponibile durante le schermate di scelta in single-player, salvo test contrario;
- evitare input a pressione prolungata senza indicatore di avanzamento;
- valutare alternative a ripetute pressioni rapide.

## Obiettivo Steam Deck

La build Windows puo essere eseguita su Steam Deck tramite Proton. La build Linux nativa verra valutata soltanto se Proton presenta problemi non risolvibili o se esiste un vantaggio misurabile.

Obiettivi di progettazione:

- funzionamento completo con i controlli fisici del Deck e configurazione predefinita;
- nessuna configurazione manuale richiesta prima di giocare;
- supporto a 1280x800, aspect ratio 16:10, e 1280x720;
- UI sicura ai bordi e scalabile;
- testo mai sotto il minimo richiesto da Valve; target interno almeno 12 pixel a 1280x800, salvo elementi non testuali;
- glifi coerenti con l'input effettivamente usato;
- nessun launcher esterno necessario;
- tastiera virtuale richiamata automaticamente se viene richiesto testo;
- preset grafico adatto al Deck selezionato automaticamente o come default appropriato;
- frame pacing stabile e gameplay leggibile nelle scene di stress;
- salvataggi e Steam Cloud, se adottato, coerenti fra PC e Deck;
- niente middleware, codec o anti-cheat non verificati con Proton.

Target prestazionale iniziale: progettare per 60 fps, misurare appena esiste una scena di stress e definire solo allora preset e fallback realistici. Non dichiarare compatibilita sulla base dell'Editor o di un PC desktop.

## Strategia di test

### Dal primo prototipo

- testare ogni incremento sia con controller sia con tastiera/mouse;
- iniziare ogni nuova schermata verificando la navigazione senza mouse;
- simulare 1280x800 e 16:10 nell'Editor;
- controllare glifi, focus e cambio dispositivo;
- registrare separatamente bug specifici dei due schemi.

### Alla vertical slice

- provare la build Windows reale tramite Proton;
- testare su Steam Deck fisico, preso in prestito o tramite tester se non e disponibile internamente;
- usare SteamOS Devkit Client quando esiste hardware disponibile;
- misurare frame time, memoria, temperature percepite, consumo e leggibilita;
- testare sospensione/ripresa, dock/undock e cambio fra controlli integrati ed esterni;
- verificare testo e UI alla distanza d'uso reale.

### Prima della release

- eseguire la checklist Valve aggiornata;
- richiedere la Compatibility Review quando disponibile nel partner site;
- correggere i risultati e richiedere una nuova revisione se necessario;
- non usare badge o dichiarazioni di compatibilita non ancora assegnati da Valve.

## Hardware e acquisti

Non e necessario acquistare ora uno Steam Deck. Il bisogno diventa concreto alla vertical slice, quando esiste una build rappresentativa da profilare. Prima di un acquisto valutare prestito, tester affidabili o altre forme di accesso fisico; emulazione e test desktop non sostituiscono completamente display, controlli, sospensione e prestazioni del dispositivo.

## Gate di input del prototipo

Il prototipo del core loop non supera il gate se:

- una funzione necessaria e disponibile soltanto su uno schema;
- costruzione o orientamento risultano significativamente frustranti con il controller;
- il focus UI puo andare perduto;
- i prompt mostrano input errati dopo il cambio dispositivo;
- dead zone o sensibilita non permettono movimento e orientamento precisi;
- il gioco richiede il mouse per riprendere una sessione avviata col controller.

## Fonti ufficiali

- [Valve - Steam Deck e Steam Machine Compatibility Review](https://partner.steamgames.com/doc/steamhardware/compat?l=english)
- [Valve - Caricare ed eseguire build su Steam Deck](https://partner.steamgames.com/doc/steamhardware/loadgames?language=english)
- [Epic Games - Steam Deck Quick Start per Unreal Engine](https://dev.epicgames.com/documentation/unreal-engine/steam-deck-quick-start-in-unreal-engine)

I criteri Valve, Proton e Unreal possono cambiare e devono essere ricontrollati prima della vertical slice e della release.
