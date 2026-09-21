# Concept di lavoro - Ingegnere del campo

## Stato

- Nome in codice provvisorio: **Project Fieldwright**.
- Stato: base creativa scelta per l'esplorazione; modificabile.
- Non costituisce Concept Lock.
- Data: 21 settembre 2026.

## High concept

In un mondo fantasy post-apocalittico, colorato e in rotazione perpetua, un ingegnere improvvisatore insegue una fascia mobile di luce costruendo una carovana di macchine modulari. I mezzi possono accompagnarlo, separarsi per modificare il campo di battaglia e fondersi in configurazioni sempre piu grandi. Ogni crescita aumenta potenza e possibilita, ma introduce ingombro, consumo, vulnerabilita o perdita di flessibilita.

## Promessa centrale provvisoria

> Costruisci una carovana di macchine modulari, separale per riscrivere il campo di battaglia e fondile in un colosso mentre insegui l'alba attraverso un mondo in eterna rotazione.

Il pitch deve ancora essere verificato senza riferimenti ad altri giochi e confrontato con il mercato.

Versione breve candidata:

> Costruisci, aggancia, separa e trasforma la tua macchina prima che il mondo giri oltre la luce.

La promessa non e ancora definitiva. Deve essere pronunciabile, visibile nel gameplay e dimostrata dal prototipo.

## Ambientazione e tono selezionati

### Mondo in rotazione perpetua

Il mondo ruota in modo anomalo o e attraversato da una fascia di luce in movimento. Regioni diverse passano attraverso condizioni luminose e temporali che cambiano risorse, creature, percorsi e comportamento delle macchine.

La causa della rotazione, la scala del mondo e la natura dell'apocalisse restano da definire. La regola deve avere conseguenze di gameplay senza richiedere una simulazione globale continua nel primo prototipo.

### Fantasy post-apocalittico caldo

L'apocalisse non viene rappresentata principalmente con grigio, ruggine fredda e desolazione. Il mondo deve risultare accogliente, vitale e colorato nonostante le rovine:

- palette calde: oro, terracotta, corallo, verde vegetale, turchese e magenta controllato;
- luce radente simile ad alba o tramonto come firma ricorrente;
- natura, magia e tecnologia che hanno colonizzato le rovine invece di lasciarle morte;
- insediamenti piccoli ma vivi, oggetti riparati e materiali riutilizzati con cura;
- oscurita ricca di bioluminescenza e colori profondi, non semplicemente nera o fredda;
- pericolo espresso attraverso trasformazione e contrasto, non soltanto degrado.

Il tono candidato e **meraviglia operosa**: il mondo e stato spezzato, ma costruire e viaggiare producono speranza concreta. Evitare cinismo uniforme, militarismo generico e iconografia distopica standard.

### Natura che riconquista le rovine

La natura ha preso il sopravvento sulle strutture del mondo precedente:

- alberi e radici attraversano edifici, ponti e macchinari ormai decrepiti;
- corsi d'acqua, fiori, funghi e creature trasformano vecchi spazi artificiali;
- le rovine conservano tracce leggibili della loro funzione passata;
- il nuovo ecosistema non e soltanto decorazione: puo aprire, bloccare, sostenere o alterare percorsi e macchine;
- alcune strutture vengono recuperate con cura dagli abitanti invece di essere soltanto saccheggiate.

*The Last of Us* e un riferimento per la capacita della vegetazione di intaccare e ridefinire vecchie strutture, non per tono, palette, storia, personaggi o composizioni riconoscibili. La nostra direzione deve restare fantasy, calda, accogliente e piu cromaticamente vitale.

La natura non viene considerata automaticamente nemica. Puo essere rifugio, risorsa, infrastruttura o forza indifferente. La natura dei nemici resta aperta: organica, meccanica, magica, ibrida o legata alle anomalie del mondo verra decisa in una fase successiva.

## Fantasia del giocatore

Il giocatore non e soltanto un combattente che trova armi piu forti. E un tecnico creativo sotto pressione:

- osserva un problema spaziale;
- raccoglie o recupera componenti;
- improvvisa una macchina incompleta ma utile;
- cambia l'arena a proprio favore;
- gestisce l'effetto collaterale della modifica;
- sposta, riconfigura o sacrifica la macchina quando la situazione cambia.

La soddisfazione deve provenire tanto dall'aver costruito una soluzione intelligente quanto dalla precisione nel movimento.

## Tre firme iniziali

### Firma meccanica

**Carovana riconfigurabile con conseguenze:** le macchine si costruiscono, si agganciano, si separano e si fondono. La configurazione modifica movimento, combattimento, geometria e tempo dell'arena. Ogni configurazione offre un beneficio e un costo sistemico, non soltanto statistiche positive.

La trasformazione profonda del terreno tramite tool personali e macchine e parte obbligatoria della firma meccanica. La specifica e i gate tecnici sono in `TERRAIN_SYSTEM.md`.

Esempi ancora da prototipare:

- un compressore solleva barriere dal terreno, ma restringe anche le vie di fuga;
- un escavatore apre un corridoio e recupera materiali, ma crea un nuovo ingresso per le orde;
- un attrattore sposta detriti e nemici, ma altera anche la traiettoria dei proiettili;
- un'ancora temporale salva lo stato locale dell'arena e lo ripristina, riportando pero anche minacce o pericoli precedenti;
- un acceleratore fa lavorare piu rapidamente le macchine, ma accelera nemici e fenomeni presenti nella stessa zona.

### Firma fantastica

Un professionista dell'improvvisazione che guida una piccola officina viaggiante attraverso un mondo fantasy spezzato e colorato. La macchina perfetta non esiste: il giocatore costruisce una famiglia di mezzi, li combina per affrontare il problema corrente e accetta le conseguenze di ogni forma.

Origine della rotazione, natura dell'apocalisse e obiettivo narrativo restano aperti. Evitare iconografia da minatore spaziale, nani, estrazione mineraria tradizionale e altri elementi troppo vicini al riferimento principale.

### Firma audiovisiva

Direzione ancora da progettare, con questi requisiti:

- costruzione visibile in piu passaggi, non apparizione istantanea di una torre generica;
- macchine asimmetriche, riparate e riconfigurate sul campo;
- silhouette della carovana leggibile mentre nuovi moduli ne cambiano forma e comportamento;
- fusioni costruite a partire da componenti realmente presenti, non trasformazioni scollegate dalla build;
- trasformazioni dell'arena chiaramente leggibili dall'alto;
- segnali distinti per stato normale, preparazione, attivazione ed effetto collaterale;
- suoni meccanici ritmici che permettono di capire lo stato della macchina senza guardarla;
- effetti temporali basati su comportamento e movimento, non soltanto su filtri cromatici.

## Core loop provvisorio

### Ciclo di 10-30 secondi

1. Leggere pressione, terreno e traiettorie.
2. Muoversi, schivare e usare l'equipaggiamento personale.
3. Modificare localmente il terreno con un tool oppure recuperare componenti o energia in punti rischiosi.
4. Agganciare, separare, alimentare o riconfigurare una macchina per una trasformazione piu ampia.
5. Sfruttare il nuovo campo e reagire alle conseguenze create.

### Ciclo di 3-5 minuti

1. Raggiungere un obiettivo o una nuova zona.
2. Scegliere un modulo che cambia il comportamento di una macchina.
3. Combinare due funzioni in una carovana visibile oppure separarle per coprire ruoli diversi.
4. Affrontare un evento che rende problematica una configurazione precedentemente efficace.
5. Salvare, riciclare o sacrificare parte della macchina.

### Ciclo della run

Una run e una spedizione che segue o attraversa la fascia di luce, composta da piu situazioni con obiettivi. Non e soltanto sopravvivenza passiva in un'unica arena. Le macchine accompagnano il giocatore e formano una carovana, ma spazio, energia, terreno e instabilita impediscono di mantenere sempre la configurazione piu grande.

Ipotesi di loop della run, da validare:

1. partire con un nucleo-officina e una funzione semplice;
2. attraversare una zona mentre luce e buio modificano opportunita e pressione;
3. recuperare un nuovo telaio o modulo da costruire;
4. decidere se agganciarlo alla carovana, usarlo come macchina autonoma o sacrificarlo;
5. affrontare un evento che richiede una riconfigurazione;
6. raggiungere il culmine con una fusione temporanea o forma colossale costruita dalla build effettiva;
7. superare boss, estrazione o transizione prima che la fascia favorevole si sposti.

Durata, numero di tappe e struttura esatta restano aperti. Una prima ipotesi da testare e 20-30 minuti.

## Costruzione durante il combattimento

Il sistema deve comunicare improvvisazione senza richiedere un editor complesso sotto attacco.

Ipotesi iniziale:

- il giocatore possiede un **telaio mobile** o un numero molto limitato di slot macchina;
- i componenti raccolti appartengono a poche famiglie leggibili;
- ogni scelta aggiunge, sostituisce o sovraccarica un modulo;
- la forma e l'animazione della macchina cambiano in modo visibile;
- la costruzione richiede posizione e tempo, creando una decisione rischiosa;
- il giocatore puo smontare o sacrificare un modulo per reagire a un'emergenza.

Famiglie candidate, non approvate:

- **Forma:** muro, scavo, ponte, spinta, attrazione;
- **Energia:** accumulo, impulso, trasferimento, sovraccarico;
- **Tempo:** rallentamento locale, accelerazione, registrazione/ripristino;
- **Controllo:** sensore, priorita bersagli, sincronizzazione fra macchine.

Il primo prototipo non deve contenere una griglia di crafting libera, catene logiche complesse o decine di componenti.

## Macchine pilotabili, carovana e mobilita avanzata

Direzione creativa scelta: alcune costruzioni diventano mezzi pilotabili e possono agganciarsi o fondersi, permettendo al personaggio di non muoversi soltanto a piedi e, in fasi avanzate, di attraversare terra, acqua o aria.

Questa idea rafforza la fantasia dell'ingegnere, ma non e parte del primo micro-prototipo. Deve crescere dallo stesso sistema modulare delle macchine da campo, evitando tre sottogiochi indipendenti.

Progressione tecnica consigliata:

1. **Telaio da campo terrestre:** una macchina esistente puo essere montata o guidata per brevi periodi nella stessa arena; movimento semplice, nessuna fisica veicolo complessa.
2. **Aggancio di due moduli:** due macchine si collegano in un ordine leggibile e ottengono una proprieta combinata, con penalita di ingombro o manovrabilita.
3. **Separazione tattica:** i moduli collegati possono essere distaccati per modificare l'arena o coprire una funzione autonoma.
4. **Fusione controllata:** una configurazione piu grande nasce dagli stessi moduli e dura per un evento limitato, con costo e vulnerabilita propri.
5. **Mezzo aereo:** prima come macchina distinta con movimento e ruolo semplici; il volo libero tridimensionale non e assunto automaticamente.
6. **Mezzo acquatico:** valutato quando esiste un ambiente che ne giustifica realmente navigazione e trasformazione.
7. **Forma colossale:** culmine della run e della build, soltanto dopo aver dimostrato che aggancio, separazione e leggibilita funzionano con pochi moduli.

Principi candidati:

- entrare nel mezzo deve cambiare rischio, spazio occupato e accesso alle macchine, non eliminare il combattimento a piedi;
- il mezzo deve essere costruito o riconfigurato durante la run, non selezionato come veicolo separato da un menu;
- l'ordine o la posizione dei moduli agganciati deve produrre differenze comprensibili senza richiedere un editor ingegneristico complesso;
- un convoglio piu grande deve ottenere potenza o sinergie pagando almeno un costo fra agilita, bersaglio, energia, calore e difficolta di riconfigurazione;
- danni o sovraccarico devono costringere a riparare, abbandonare o cannibalizzare il mezzo;
- i componenti devono restare utili anche fuori dal mezzo per evitare sistemi di upgrade duplicati;
- ogni modalita di movimento deve offrire decisioni proprie, non essere una semplice chiave per attraversare un ostacolo colorato;
- camera, collisioni e leggibilita del bullet hell devono restare coerenti durante entrata, guida e uscita.

Rischi specifici:

- triplicazione del level design per terra, acqua e aria;
- fisica e collisioni difficili da leggere in un gioco con molti nemici e proiettili;
- perdita di precisione arcade durante la guida;
- moltiplicazione di animazioni, VFX, audio, UI e bilanciamento;
- mezzi troppo potenti che rendono irrilevanti movimento a piedi e macchine stazionarie;
- ambienti costruiti come corridoi obbligati per giustificare ogni mezzo.
- combinazioni modulari che moltiplicano animazioni, collisioni e bug in modo ingestibile;
- forma colossale che appare come una cutscene o un bonus automatico invece del risultato della build scelta;

Gate per iniziare un prototipo pilotabile:

- il core loop a piedi e le macchine da campo sono gia divertenti;
- esiste almeno un telaio modulare con vantaggio e conseguenza leggibili;
- entrare nel mezzo risolve un problema di gameplay dimostrabile;
- il test usa una sola modalita terrestre e riutilizza controlli, moduli e asset esistenti;
- acqua e aria restano fuori scope fino a una decisione successiva basata sul prototipo terrestre.
- la prima fusione usa due soli moduli e una trasformazione preparata, non assemblaggio fisico completamente libero.

## Famiglie di mezzo candidate

Queste famiglie esprimono ruoli e svantaggi, non ancora contenuti approvati.

### Terrestre

- ruolo: trasporto, trazione, scavo, compressione e creazione di percorsi;
- vantaggio: stabilita, capacita di carico e forte interazione col terreno;
- svantaggio: ingombro, inerzia, dipendenza dal percorso e vulnerabilita ai blocchi.

### Aereo

- ruolo: ricognizione, trasporto leggero, controllo della luce/ombra e accesso rapido;
- vantaggio: ignora parte della geometria e osserva o influenza zone lontane;
- svantaggio: poco carico, consumo elevato, esposizione e permanenza limitata.

### Acquatico

- ruolo: attraversamento di zone sommerse, pompaggio, deviazione di correnti e controllo dei livelli d'acqua;
- vantaggio: modifica ambientale su vasta scala e accesso a percorsi esclusivi;
- svantaggio: utilita dipendente dal bioma, transizioni lente e rischio di separazione dalla carovana.

### Forma colossale

- ruolo: culmine temporaneo della configurazione costruita durante la run;
- vantaggio: combina funzioni e permette di affrontare una minaccia o trasformazione altrimenti impossibile;
- svantaggio: enorme consumo, grande bersaglio, minore flessibilita e possibile perdita o danneggiamento dei moduli al termine.

Il termine "Megazord" resta soltanto un riferimento informale alla fantasia di fusione e non deve essere usato come nome, testo pubblico o identita del progetto.

## Il ruolo della manipolazione temporale

Il tempo e una meccanica secondaria candidata, legata alle macchine e non a un potere universale del personaggio. Deve approfondire l'ingegneria, non diventare un secondo gioco separato.

Direzioni da confrontare:

1. **Zone temporali:** una macchina altera la velocita di tutto cio che entra nella sua area, inclusi vantaggi e pericoli.
2. **Stato registrato:** una macchina memorizza posizione o configurazione locale e puo ripristinarla una volta.
3. **Debito temporale:** un forte beneficio anticipa una minaccia futura o richiede di affrontare in seguito il tempo risparmiato.

Per il primo micro-prototipo e preferibile la zona temporale, piu economica da comprendere e costruire. Il ripristino dello stato e piu originale, ma tecnicamente piu rischioso e va isolato in un esperimento separato.

## Luce e buio come condizioni operative

Direzione candidata: luce e oscurita non sono soltanto atmosfera, ma due condizioni con vantaggi e svantaggi che il giocatore puo manipolare attraverso le macchine.

La regola di design e che nessuno stato sia sempre preferibile. Il giocatore deve scegliere quale rischio accettare e, idealmente, costruire transizioni fra i due.

Possibili proprieta da prototipare:

| Condizione | Vantaggi candidati | Svantaggi candidati |
|---|---|---|
| Luce | migliore lettura dell'arena; sensori e macchine piu precisi; costruzione o riparazione piu rapida; nemici chiaramente telegrafati | attira o risveglia nemici; consuma energia condivisa; rende visibili personaggio e macchine; puo surriscaldare o destabilizzare alcuni moduli |
| Buio | riduce il rilevamento; permette imboscate o raccolta sicura; rivela materiali/anomalie invisibili alla luce; puo amplificare effetti temporali | riduce portata dei sensori e precisione; nasconde ostacoli o telegraph; abilita comportamenti nemici piu pericolosi; rende piu fragili alcune operazioni di costruzione |

Interazioni coerenti con il concept:

- un generatore illumina e stabilizza le macchine vicine, ma diventa un richiamo per le orde;
- un faro mobile accompagna il telaio o il mezzo pilotabile, consumando la stessa energia usata da propulsione e moduli;
- una macchina puo spostare, schermare, concentrare o spegnere la luce invece di limitarsi a crearla;
- alcune trasformazioni del terreno proiettano ombre utili o aprono l'arena a una fonte luminosa pericolosa;
- una zona temporale puo accelerare il ciclo luce-buio locale o conservare temporaneamente uno dei due stati.
- la carovana deve scegliere quanta energia assegnare a luce, propulsione, macchine separate e fusione;
- il mezzo aereo puo proiettare ombra o concentrare luce, mentre quello acquatico puo rifletterla o trasportarla lungo correnti.

Rischi da evitare:

- oscurita che rende il gioco semplicemente difficile da vedere;
- luce trattata come aura di bonus permanente da mantenere sempre attiva;
- troppe eccezioni diverse per nemico o macchina;
- VFX e illuminazione che coprono proiettili, telegraph o materiali interagibili;
- costi GPU incompatibili con il numero di nemici e costruzioni previsto.

Il test iniziale deve usare effetti discreti e leggibili, non illuminazione finale costosa: due zone chiaramente identificabili, una sola risorsa energetica e un beneficio/costo per stato.

## Costruzione delle build

Una build interessante deve cambiare il modo in cui il giocatore usa spazio e tempo.

Esempi di direzioni, non di contenuti confermati:

- **Fortificazione mobile:** crea strozzature e trasferisce rapidamente le barriere;
- **Demolizione controllata:** apre terreno, genera risorse e combatte attraverso crolli pianificati;
- **Rete cinetica:** sposta nemici, detriti e proiettili lungo correnti costruite dal giocatore;
- **Officina temporale:** sincronizza cicli delle macchine e usa accelerazione/rallentamento come risorsa;
- **Macchina sciame:** sostituisce una singola costruzione con piccoli elementi coordinati, mantenendo lo sciame come possibile evoluzione futura e non come sistema obbligatorio iniziale.

Gli upgrade puramente percentuali possono esistere come supporto, ma le scelte principali devono modificare comportamento, geometria o relazione fra moduli.

## Progressione fra le run

Direzione candidata:

- sbloccare nuovi progetti, componenti laterali e condizioni iniziali;
- recuperare conoscenza sul mondo e sulle macchine;
- evitare che bonus permanenti sostituiscano l'apprendimento del giocatore;
- usare la base/officina come luogo compatto di scelta e narrazione;
- permettere esperimenti mirati senza rendere obbligatorio un lungo grind.

## Narrazione sostenibile

La storia dovrebbe emergere da:

- scopo delle spedizioni;
- origine e precedenti proprietari delle macchine;
- trasformazioni ambientali;
- descrizioni brevi ma specifiche dei componenti;
- conseguenze delle modifiche compiute dal giocatore;
- pochi personaggi o interlocutori ricorrenti, se necessari.

Evitare una campagna basata su molte cinematiche, dialoghi doppiati o grandi quantita di testo.

## Cosa rende il concept diverso

L'ipotesi di differenziazione non e "survivor-like con crafting". E la seguente relazione sistemica:

> La build del giocatore prende forma come carovana presente nel mondo: i moduli possono combattere, trasformare l'arena, separarsi e fondersi in una configurazione colossale mentre il mondo ruota fra luce e buio.

Il terreno trasformabile e quindi una parte della build: non cambia soltanto dove si combatte, ma che cosa la carovana puo diventare e come viene utilizzata.

Questa promessa dovra essere dimostrata in graybox. Se le macchine diventano torrette con bonus passivi o la trasformazione del campo e soltanto cosmetica, il concept perde la sua ragione d'essere.

## Limiti di scope del primo prototipo

Il micro-prototipo include soltanto:

- un personaggio con movimento, dash e attacco provvisorio;
- una piccola arena graybox;
- due tipi di nemico;
- una risorsa recuperabile;
- un telaio macchina;
- un secondo modulo agganciabile con una sola sinergia di configurazione;
- due moduli di trasformazione del terreno;
- un modulo temporale locale;
- un effetto collaterale per ogni modulo;
- una breve ondata o obiettivo ripetibile;
- metriche minime di leggibilita e prestazioni.

Non include arte finale, salvataggi, meta-progressione, generazione procedurale, crafting libero, storia completa o molte armi.

Non include ancora mezzi pilotabili, aerei, acquatici o una forma colossale completa. Include soltanto una versione minima di aggancio/separazione fra due moduli; il primo telaio terrestre pilotabile appartiene a un esperimento successivo condizionato ai gate definiti sopra.

## Ordine dei micro-prototipi

Le meccaniche non vengono costruite tutte insieme. Ogni gradino produce una build osservabile e puo fermare o modificare il successivo:

1. **Movimento e pressione:** personaggio, camera, controller, due nemici e sopravvivenza breve.
2. **Ingegneria del campo:** una macchina con un vantaggio spaziale e una conseguenza.
3. **Seconda trasformazione:** verificare che due macchine producano decisioni diverse, non varianti cosmetiche.
4. **Aggancio e separazione:** due moduli, una sinergia da uniti e un'utilita da separati; nessuna fisica di assemblaggio libero.
5. **Luce e buio:** due zone, una risorsa energetica condivisa e una regola per stato.
6. **Tempo locale:** una sola zona temporale con effetto simmetrico su vantaggi e minacce.
7. **Telaio terrestre pilotabile:** riutilizzare i moduli gia validati e confrontare guida e movimento a piedi.

Mezzo aereo, mezzo acquatico e forma colossale entrano in prototipi successivi soltanto se i primi sette gradini dimostrano che la carovana e divertente, leggibile e producibile.

## Esperimenti iniziali

### Esperimento A - Il campo cambia davvero?

Confrontare due macchine:

- barriera che crea una strozzatura ma limita la fuga;
- escavatore che apre un passaggio ma genera un nuovo punto di ingresso.

Domanda: il giocatore prende decisioni spaziali nuove o usa sempre la macchina nello stesso modo?

### Esperimento B - Il tempo approfondisce la costruzione?

Aggiungere una zona che accelera macchine, nemici e proiettili presenti al suo interno.

Domanda: il doppio effetto crea pianificazione interessante oppure soltanto confusione?

### Esperimento C - La macchina sembra una build?

Permettere di scegliere fra due modificatori comportamentali per lo stesso telaio.

Domanda: il giocatore percepisce di aver costruito una soluzione propria e cambia strategia di conseguenza?

### Esperimento D - Luce e buio creano decisioni?

Dividere temporaneamente l'arena in una zona illuminata e una buia. Nella luce le macchine operano meglio ma generano piu pressione nemica; nel buio il giocatore viene rilevato meno facilmente ma perde parte del supporto dei sensori.

Domanda: il giocatore cambia posizione o configurazione intenzionalmente, oppure uno stato risulta sempre dominante o soltanto frustrante?

### Esperimento E - La carovana e la build?

Collegare due moduli in una configurazione predefinita. Uniti ottengono una sinergia ma si muovono peggio; separati coprono due funzioni o zone diverse.

Domanda: decidere quando unire o dividere le macchine e interessante e leggibile, oppure esiste sempre una configurazione ottimale?

## Criteri per proseguire

Il concept resta candidato principale soltanto se il prototipo dimostra che:

- costruire sotto pressione e divertente e comprensibile;
- almeno due trasformazioni del campo producono decisioni diverse;
- vantaggio ed effetto collaterale sono entrambi leggibili;
- la macchina e parte attiva della build, non un accompagnatore passivo;
- l'idea resta interessante senza arte finale e meta-progressione;
- il costo tecnico e produttivo resta compatibile con un progetto personale.

## Decisioni da prendere prima del prototipo completo

- controllo delle armi: automatico, manuale o ibrido;
- mobilita e vulnerabilita durante la costruzione;
- macchina singola riconfigurabile o poche macchine specializzate;
- trasformazione continua del terreno o stati discreti preparati;
- rapporto fra obiettivi e sopravvivenza;
- causa della rotazione, natura dell'apocalisse e obiettivo del viaggio;
- cosa viene conservato fra una tappa e l'altra;
- prima direzione temporale da testare.
- ruolo di luce e buio e loro eventuale legame con l'energia delle macchine.
- regole di aggancio, separazione e fusione dei moduli;
- ruolo a lungo termine di terra, aria e acqua e forma della configurazione colossale.
