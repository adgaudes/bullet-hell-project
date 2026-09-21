# Sistema di trasformazione del terreno

## Stato

- Pilastro centrale del concept, approvato come direzione modificabile.
- Implementazione tecnica non ancora scelta.
- Il prototipo deve dimostrare profondita sistemica prima di adottare tecnologia voxel o plugin esterni.

## Promessa

Il terreno non e uno sfondo passivo. Il giocatore lo osserva, lo modifica con strumenti personali e lo trasforma su scala maggiore con le macchine. Le modifiche cambiano combattimento, movimento, risorse, luce e configurazione della carovana.

La profondita non viene misurata soltanto dalla liberta geometrica. Una modifica e significativa quando produce conseguenze comprensibili e permette piu soluzioni valide.

## Due scale di intervento

### Tool personali

Funzione: interventi precisi, rapidi e limitati mentre il giocatore e a piedi.

Caratteristiche candidate:

- rimuovere un piccolo ostacolo o aprire un varco;
- piazzare un ancoraggio, ponte breve o supporto;
- consolidare terreno fragile;
- deviare una piccola quantita d'acqua o energia;
- tagliare vegetazione e recuperare materiale senza distruggere indiscriminatamente;
- marcare un punto per una macchina;
- creare temporaneamente luce, ombra o un segnale.

Costi possibili: tempo di utilizzo, esposizione, carica, calore, durabilita o consumo di materiale.

### Macchine

Funzione: trasformazioni ampie, persistenti e capaci di cambiare la strategia dell'intera arena.

Caratteristiche candidate:

- scavare trincee o corridoi;
- sollevare terrapieni e piattaforme;
- comprimere, frantumare o stabilizzare superfici;
- spostare grandi rovine o radici;
- pompare, trattenere o liberare acqua;
- creare ponti, rampe o linee di trasporto;
- schermare, riflettere o concentrare luce;
- accelerare o ripristinare localmente uno stato del terreno.

Costi possibili: energia, rumore, tempo di preparazione, spazio, nuovi ingressi nemici, blocco delle vie di fuga, instabilita o perdita del modulo.

## Regola di complementarita

Tool e macchine non devono duplicarsi:

- il tool prepara, corregge o rifinisce;
- la macchina trasforma, mantiene o automatizza;
- il mezzo pilotabile trasporta e applica la trasformazione mentre si muove;
- la carovana collegata combina piu effetti ma aumenta ingombro e costo;
- la forma colossale puo produrre una trasformazione eccezionale, mai disponibile senza la build che l'ha generata.

Esempio: il giocatore usa un tool per segnare una linea e rimuovere piccoli detriti; l'escavatore apre il corridoio completo; un modulo di consolidamento impedisce il crollo; la scelta crea pero un nuovo percorso per le orde.

## Famiglie di terreno candidate

Il primo prototipo usa soltanto due o tre famiglie. Il set esteso puo includere:

- **suolo morbido:** facile da scavare, instabile e adatto a trincee;
- **roccia o rovina:** resistente, utile come barriera e ricca di componenti;
- **vegetazione:** puo bloccare, sostenere, ricrescere o reagire a luce e acqua;
- **acqua:** cambia accesso, flusso e comportamento delle macchine;
- **terreno temporale:** conserva stati, accelera crescita/crollo o ripete una trasformazione;
- **superficie luminosa/ombrosa:** influenza sensori, energia e minacce.

## Conseguenze sistemiche richieste

Una trasformazione significativa deve influenzare almeno due aree:

- percorso e densita dei nemici;
- movimento e vie di fuga del giocatore;
- posizione o efficienza delle macchine;
- accesso a risorse, segreti o obiettivi;
- distribuzione di luce e ombra;
- flusso dell'acqua o di altra materia;
- linee di tiro, traiettorie e visibilita;
- stabilita, crollo o ricrescita;
- percorso della carovana e possibilita di aggancio/separazione.

Modifiche puramente cosmetiche non contano come profondita del sistema.

## Principi di leggibilita

- Il giocatore deve capire prima dell'azione che cosa puo essere modificato.
- Anteprima, area d'effetto e possibile conseguenza primaria devono essere mostrate.
- Collisione visiva e collisione reale devono coincidere.
- I bordi fra stati del terreno devono restare leggibili con molti nemici e VFX.
- Un errore non deve intrappolare definitivamente il giocatore senza via di recupero comprensibile.
- Controller e tastiera/mouse devono permettere selezione e orientamento equivalenti.
- Le trasformazioni devono restare riconoscibili a 1280x800 su Steam Deck.

## Persistenza candidata

- Le modifiche persistono per la durata della situazione o della run, salvo azioni di ripristino esplicite.
- Il mondo fra le run non memorizza inizialmente ogni deformazione geometrica.
- Eventuali cambiamenti permanenti usano stati narrativi o macro-varianti controllate, non salvataggio completo di tutta la geometria.
- Riavvolgimento temporale e rigenerazione della natura devono essere regole visibili, non reset arbitrari.

Questa impostazione protegge salvataggi, dimensione dei dati e riproducibilita dei test.

## Strategie tecniche da confrontare

### A. Celle e stati discreti - prima scelta per il prototipo

Il campo e composto da celle o regioni con pochi stati: integro, scavato, rialzato, allagato, consolidato.

Vantaggi:

- collisioni e navigazione prevedibili;
- facile anteprima con controller;
- salvataggio e replica dello stato semplici;
- costo misurabile su Steam Deck;
- rapido da prototipare con mesh provvisorie.

Limiti:

- bordi piu artificiali;
- minore liberta geometrica;
- necessita di buona presentazione per non sembrare una griglia rigida.

### B. Zone deformabili controllate - candidato per la vertical slice

Solo alcune superfici consentono deformazioni piu continue o combinano stati discreti con mesh e materiali dinamici.

Vantaggi:

- resa piu organica;
- permette rovine e natura visivamente convincenti;
- conserva controllo su collisioni e performance.

Limiti:

- transizioni, navmesh e sincronizzazione visiva piu complesse;
- authoring specifico per area.

### C. Terreno voxel completamente dinamico - ricerca successiva

Offre grande liberta, ma introduce rischi rilevanti per performance, salvataggi, pathfinding, collisioni, arte, packaging e dipendenze esterne.

Non adottare questa strategia solo perche promette liberta. Valutarla dopo il prototipo discreto con un esperimento isolato e una matrice build-vs-buy. Qualsiasi plugin deve superare verifica di costo, licenza, manutenzione, accesso al sorgente, Unreal 5.6, Windows, Proton e Steam Deck.

## Primo micro-prototipo

Arena piccola con griglia o regioni nascoste alla presentazione finale.

Contenuto minimo:

- suolo normale;
- ostacolo resistente;
- area scavabile;
- tool personale per modificare una singola cella o piccola regione;
- macchina che modifica una linea o area piu ampia;
- due tipi di nemico con reazioni diverse al nuovo percorso;
- anteprima di modifica;
- annullamento o recupero controllato;
- misurazione di frame time e aggiornamento della navigazione.

Test A:

- aprire un corridoio accorcia il percorso e offre risorse;
- lo stesso corridoio consente alle orde un ingresso aggiuntivo.

Test B:

- sollevare una barriera devia i nemici e protegge una macchina;
- la barriera riduce lo spazio di schivata e puo bloccare la carovana.

## Gate per proseguire

- I tester usano il terreno per risolvere problemi, non soltanto per raccogliere risorse.
- Almeno due soluzioni sono valide nella stessa situazione.
- Vantaggio e conseguenza sono prevedibili prima dell'attivazione.
- Tool e macchina hanno ruoli complementari.
- Nemici e proiettili restano leggibili durante e dopo la trasformazione.
- Navigazione e collisioni non producono blocchi frequenti.
- Controller e tastiera/mouse risultano entrambi naturali.
- La scena di stress rispetta il budget provvisorio su PC e Steam Deck LCD.

Se questi gate falliscono, modificare la grammatica del terreno prima di aumentare liberta, risoluzione o numero di materiali.

## Decisioni aperte

- griglia visibile, nascosta o regioni irregolari;
- visuale e strumenti di anteprima durante la costruzione;
- quantita di terreno modificabile per situazione;
- velocita e rischio degli interventi personali;
- pathfinding continuo, a regioni o comportamento ibrido dei nemici;
- ruolo di acqua, vegetazione e ricrescita;
- persistenza fra tappe della stessa run;
- possibilita e costo di riparare una trasformazione sbagliata;
- necessita reale di deformazione continua o voxel.
