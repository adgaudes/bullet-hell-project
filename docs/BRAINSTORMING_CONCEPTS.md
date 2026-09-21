# Brainstorming: prime concept card

## Come usare questo documento

Queste proposte sono materiale da discutere, combinare o scartare. Nessuna e approvata. Sono state costruite intorno alla direzione candidata: survivor-like 3D isometrico, budget basso, produzione da solista e importanza congiunta di abilita arcade, build, atmosfera e progressione.

Per evitare cloni, ogni proposta introduce una regola centrale che modifica movimento, rischio e costruzione della build.

## Concept A - Il Faro Mobile

**Pitch:** su un pianeta immerso in una tempesta senziente, il giocatore trascina e alimenta un faro mobile; la sua luce crea l'unica zona relativamente sicura, ma richiama creature sempre piu pericolose.

**Fantasia del giocatore:** essere un esploratore che conquista centimetro dopo centimetro un ambiente ostile, trasformando energia e rottami in una macchina da sopravvivenza.

**Regola distintiva:** luce ed energia sono contemporaneamente protezione, risorsa per le armi e calamita per i nemici. Spostare il faro cambia il campo di battaglia.

**Loop di 30 secondi:** muoversi fra luce e oscurita, eliminare gruppi, raccogliere energia, decidere se alimentare difesa, arma o avanzamento.

**Loop di 5 minuti:** raggiungere un nodo, collegarlo al faro, scegliere un upgrade sinergico e affrontare una variazione della tempesta.

**Struttura della run:** una spedizione attraversa una piccola sequenza di aree e termina con estrazione o boss. I materiali recuperati sbloccano alternative, non solo potenza permanente.

**Punti di forza:** identita visiva chiara; luce e oscurita aiutano atmosfera e leggibilita; storia ambientale economica.

**Rischio principale:** illuminazione dinamica, VFX e troppi nemici potrebbero essere costosi sulla GPU disponibile.

**Test economico:** arena graybox, cerchio di sicurezza mobile, due tipi di nemico e una sola risorsa condivisa.

## Concept B - La Macchina Affamata

**Pitch:** il giocatore pilota una macchina mineraria vivente che divora il terreno per fabbricare munizioni e modificare l'arena mentre orde sotterranee la assediano.

**Fantasia del giocatore:** costruire una macchina assurda e sempre piu potente, scegliendo fisicamente la propria rotta attraverso un mondo distruttibile.

**Regola distintiva:** scavare genera risorse e vie di fuga, ma apre anche nuovi ingressi ai nemici; il percorso scelto diventa parte della build.

**Loop di 30 secondi:** schivare, distruggere vene o ostacoli, raccogliere materiale e alimentare armi automatiche.

**Loop di 5 minuti:** scegliere una direzione di scavo, completare un obiettivo, aggiungere un modulo e adattarsi ai varchi creati.

**Struttura della run:** discesa attraverso settori compatti con obiettivi e bivii; boss o estrazione alla profondita target.

**Punti di forza:** forte rapporto fra movimento, ambiente e build; possibilita di usare kit modulari low-poly; buon potenziale per clip e trailer.

**Rischio principale:** distruzione del terreno e navigazione dei nemici possono ampliare molto la complessita tecnica.

**Test economico:** griglia semplice di celle distruttibili, nessun terreno voxel, un nemico con percorso aggiornato e due moduli.

## Concept C - Il Convoglio degli Echi

**Pitch:** un piccolo convoglio attraversa una landa contaminata; ogni arma installata crea un'eco ritardata delle azioni del giocatore, costruendo pattern offensivi che possono anche intrappolarlo.

**Fantasia del giocatore:** orchestrare una macchina da guerra in movimento e imparare a danzare con le copie temporali delle proprie azioni.

**Regola distintiva:** movimento, dash e attacchi possono ripetersi dopo un ritardo configurabile; la build modifica numero, ritardo e comportamento degli echi.

**Loop di 30 secondi:** posizionarsi per creare traiettorie future favorevoli, schivare e sfruttare le ripetizioni degli attacchi.

**Loop di 5 minuti:** difendere una tappa, scegliere un nuovo modulo temporale e cambiare ordine o ritmo delle armi.

**Struttura della run:** viaggio a tappe con eventi brevi, combattimenti e una scelta di percorso prima dello scontro finale.

**Punti di forza:** meccanica comunicabile e legata sia all'abilita sia alle build; non richiede grandi quantita di ambiente; storia raccontabile attraverso tappe e passeggeri.

**Rischio principale:** gli echi possono creare confusione visiva e rendere difficile capire danni e collisioni.

**Test economico:** arena vuota, registrazione di pochi secondi di movimento, un attacco ripetuto e colori distinti per presente/futuro.

## Concept D - Sciame Simbiotico

**Pitch:** un organismo artificiale sopravvive legandosi temporaneamente ai nemici: assorbe i loro tratti, ma ogni mutazione modifica anche comportamento, vulnerabilita e aspetto dello sciame ostile.

**Fantasia del giocatore:** evolvere in tempo reale e trasformare le capacita del nemico nella propria build.

**Regola distintiva:** gli upgrade non arrivano da una lista astratta; si ottengono marcando e assorbendo archetipi nemici durante il combattimento.

**Loop di 30 secondi:** identificare un bersaglio utile, aprirsi un varco, marcarlo, assorbirlo e sfruttare subito il nuovo tratto.

**Loop di 5 minuti:** completare una catena di mutazioni, affrontarne il costo e cacciare un bersaglio raro per chiudere una sinergia.

**Struttura della run:** ecosistemi-arena successivi; la build influenza quali varianti emergono e come reagisce il boss.

**Punti di forza:** build visibile nel mondo e nel personaggio; forte potenziale per identita organica; progressione narrativa attraverso scoperte biologiche.

**Rischio principale:** combinazioni, trasformazioni visive e bilanciamento possono moltiplicare il lavoro sui contenuti.

**Test economico:** tre archetipi nemici, tre tratti esclusivi e massimo due slot di mutazione, senza trasformazioni grafiche complesse.

## Confronto preliminare

La valutazione seguente e intenzionalmente provvisoria. Deve essere corretta dopo il confronto con il proprietario e dopo i test.

| Concept | Core loop | Distinzione | Fattibilita | Leggibilita | Espansione controllata | Budget | Nota |
|---|---:|---:|---:|---:|---:|---:|---|
| A - Faro Mobile | 4 | 4 | 4 | 4 | 4 | 4 | Equilibrio promettente fra identita e scope |
| B - Macchina Affamata | 5 | 4 | 2 | 4 | 4 | 2 | Molto attraente, ma terreno e AI sono un rischio tecnico |
| C - Convoglio degli Echi | 4 | 5 | 4 | 2 | 4 | 4 | Distintivo e prototipabile; leggibilita da dimostrare subito |
| D - Sciame Simbiotico | 4 | 4 | 3 | 3 | 3 | 3 | Buona integrazione build-tema, alto costo combinatorio |

Con i pesi della roadmap, A e C sono i candidati iniziali piu sicuri da esplorare. B merita di restare nel gruppo se l'idea di scavare e modificare l'arena e particolarmente attraente; il test deve pero evitare subito una tecnologia voxel. D richiede limiti molto rigidi al numero di combinazioni.

## Domande per la sessione con il proprietario

1. Quale fantasia vorresti provare anche se la grafica fosse composta soltanto da forme semplici?
2. Quale delle quattro regole distintive riesci a spiegare con piu entusiasmo a un amico?
3. Preferisci controllare soltanto il movimento, mirare manualmente oppure alternare auto-fire e abilita mirate?
4. Vuoi che una run sembri soprattutto un'arena continua, una spedizione con obiettivi o un viaggio a tappe?
5. Fra fantascienza industriale, horror cosmico, fantasy e un tono piu originale, quali atmosfere ti attirano e quali vuoi evitare?
6. Quanto dovrebbe durare idealmente una run completa: circa 15, 25-30 o 40 minuti?

## Criterio per i due finalisti

Non selezionare in base alla quantita di lore possibile. I finalisti devono:

- risultare interessanti in graybox;
- essere spiegabili in una frase senza nominare *Deep Rock Galactic: Survivor* o *Vampire Survivors*;
- usare al massimo due sistemi tecnici nuovi nel primo prototipo;
- permettere un test significativo con un personaggio, due nemici, un'arena e pochi upgrade;
- conservare un percorso credibile verso atmosfera, progressione e narrazione dopo la validazione del combattimento.
