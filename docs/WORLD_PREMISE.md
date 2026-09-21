# Premessa del mondo

## Stato

- Causa candidata dell'apocalisse: invasione aliena e terraformazione planetaria fallita o interrotta.
- Direzione approvata come base modificabile, non ancora lore definitiva.
- Nemici, stato attuale degli invasori e natura esatta del pianeta restano aperti.

## Premessa

Un'invasione aliena ha disseminato il pianeta di enormi macchine terraformanti. Per riconfigurare atmosfera, materia e biosfera, queste macchine hanno perforato gli strati profondi e interferito con il nucleo planetario.

Il processo ha gravemente destabilizzato il mondo:

- il ciclo giorno-notte e diventato estremamente rapido o irregolare;
- forti differenze di temperatura e pressione alimentano temporali anomali;
- piogge torrenziali trasformano rapidamente pianure, rovine e vallate in zone allagate;
- frane, erosione, crescita vegetale e crolli continuano a riscrivere il territorio;
- residui della tecnologia terraformante producono anomalie di luce, materia e tempo;
- la natura sopravvissuta ha riconquistato le strutture della civilta precedente e si e adattata al nuovo ciclo.

Non e necessario che la premessa segua la geofisica reale in ogni dettaglio. Deve mantenere una causalita science-fantasy coerente e riconoscibile: le macchine aliene hanno alterato i sistemi planetari e il gameplay mostra le conseguenze.

## Catena causale del gameplay

1. Le macchine aliene danneggiano o riconfigurano il nucleo.
2. Rotazione, luce e condizioni atmosferiche diventano instabili.
3. Il rapido alternarsi termico intensifica pioggia, vento e temporali.
4. Le inondazioni cambiano percorsi, risorse e sicurezza delle zone.
5. Il giocatore modifica terreno e acqua per mantenere aperta la rotta.
6. La carovana deve separarsi, agganciarsi o cambiare modalita di movimento.
7. Mezzi terrestri, acquatici e aerei diventano risposte differenti allo stesso mondo dinamico.

Questa catena e parte della promessa. Se meteo e acqua non cambiano decisioni o configurazione, diventano soltanto scenografia e vanno ridisegnati.

## Ciclo ambientale candidato

Il ciclo non deve essere identico in ogni zona, ma puo utilizzare quattro fasi leggibili:

### Luce crescente

- maggiore visibilita e produzione energetica;
- evaporazione o ritiro graduale di alcune acque;
- riattivazione di strutture e macchine;
- maggiore esposizione della carovana.

### Calore e instabilita

- terreno che si secca, cede o diventa piu facile da scavare;
- differenze di pressione e segnali di tempesta;
- finestra per preparare drenaggi, argini e configurazioni.

### Super-temporale

- pioggia intensa, vento, fulmini e rapido aumento dell'acqua;
- nuove correnti e percorsi acquatici;
- rischio per macchine alte, aeree o sovraccariche;
- opportunita energetiche e materiali trasportati dalla piena.

### Buio umido

- bioluminescenza e risorse prima invisibili;
- terreno saturo, frane e zone ancora sommerse;
- minore rilevamento ma sensori e costruzioni meno affidabili;
- finestra per mezzi acquatici, riparazione o raccolta.

Il primo prototipo non simula l'intero ciclo. Usa una transizione annunciata da asciutto a inondato e, successivamente, un ritorno controllato.

## Ruolo delle famiglie di macchine

### Terrestre

- scava canali, costruisce argini e consolida terreno;
- trasporta molti moduli su superfici stabili;
- rischia impantanamento, allagamento e isolamento;
- puo preparare il campo prima della tempesta.

### Acquatica

- naviga le aree inondate;
- pompa, accumula, devia o rilascia acqua;
- trasporta moduli galleggianti e recupera risorse della piena;
- perde efficacia quando l'acqua si ritira e puo restare bloccata.

### Aerea

- attraversa allagamenti e terreno crollato;
- esplora il fronte della tempesta e posiziona strumenti in zone isolate;
- puo manipolare luce, vento o scariche attraverso moduli dedicati;
- consuma molta energia ed e vulnerabile a vento e fulmini.

### Fusione multimodale

- permette alla carovana di superare una crisi ambientale eccezionale;
- combina galleggiamento, trazione o portanza solo se i moduli necessari sono stati costruiti;
- aumenta massa, bersaglio, consumo e complessita di controllo;
- non deve annullare l'identita e gli svantaggi dei singoli mezzi.

## Acqua come terreno dinamico

L'acqua e uno stato del campo, non soltanto una superficie attraversabile.

Deve poter influenzare:

- accessibilita e profondita delle zone;
- velocita e modalita di movimento;
- stabilita di terreno, radici e rovine;
- percorsi dei nemici;
- conduzione di energia o pericoli elettrici;
- posizione, alimentazione e rischio delle macchine;
- risorse trasportate o rese accessibili;
- luce riflessa e visibilita.

Il giocatore deve poter anticipare la piena attraverso segnali visivi e sonori. Una transizione istantanea e inevitabile senza preavviso sarebbe ingiusta.

## Rappresentazione tecnica iniziale

Non usare simulazione fluidodinamica generale nel primo prototipo.

Approccio candidato:

- bacini e canali definiti come regioni;
- livelli d'acqua discreti o interpolati fra pochi stati;
- mesh/materiali e VFX separati dallo stato logico;
- punti di ingresso, uscita, pompa e argine espliciti;
- aggiornamento controllato di collisioni e percorsi;
- galleggiamento semplificato per oggetti selezionati;
- effetti visivi di corrente che non richiedono simulazione fisica completa.

Questo consente di costruire decisioni profonde e testabili su Windows e Steam Deck prima di aumentare la fedelta.

## Tono visivo

Anche il temporale deve rispettare la direzione calda e colorata:

- cielo viola, corallo, ambra e verde temporale invece di grigio uniforme;
- lampi caldi o iridescenti legati alla tecnologia aliena;
- acqua che riflette vegetazione, rovine e bioluminescenza;
- ritorno della luce percepito come trasformazione, non semplice cambio di esposizione;
- vegetazione piegata, sommersa o nutrita dalla pioggia, con conseguenze visibili.

Le macchine terraformanti aliene devono avere una grammatica visiva diversa dalle costruzioni artigianali del giocatore, senza obbligare ora a scegliere se i nemici siano alieni, macchine autonome o creature mutate.

## Stato degli invasori - decisione aperta

Alternative da esplorare in seguito:

- invasione terminata, terraformatori abbandonati ancora attivi;
- invasori ritirati dopo un fallimento e presenza solo attraverso residui;
- invasione congelata o ciclica, con nuove incursioni;
- invasori ancora presenti ma non necessariamente antagonisti unici;
- macchine terraformanti divenute un ecosistema indipendente.

La scelta determinera nemici, storia e obiettivo finale. Non e necessaria per il primo prototipo del terreno.

## Domande narrative aperte

- Il pianeta e la Terra trasformata o un mondo fantasy autonomo?
- Perche il protagonista deve seguire la fascia di luce?
- Vuole riparare il nucleo, fermare i terraformatori, raggiungere un luogo o salvare una comunita?
- La rotazione continua ad accelerare oppure ha raggiunto un nuovo equilibrio instabile?
- Quanto tempo e trascorso dall'invasione?
- Le popolazioni comprendono la tecnologia aliena oppure la interpretano attraverso magia e mito?
- La natura si e adattata spontaneamente o e anch'essa il risultato della terraformazione?

## Gate della premessa

La premessa viene mantenuta se:

- spiega almeno terreno, acqua, luce/buio e macchine senza una lunga esposizione;
- produce decisioni osservabili nel core loop;
- sostiene palette e tono caldi senza contraddire il pericolo;
- non obbliga a costruire subito un mondo aperto o una simulazione meteorologica globale;
- permette nemici diversi senza rendere qualunque scelta intercambiabile;
- e comunicabile in poche frasi e distinguibile dai riferimenti.
