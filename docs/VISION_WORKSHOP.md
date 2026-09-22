# Workshop della visione - promessa centrale e core loop

## Stato e uso

Questo documento prepara il prossimo confronto con il proprietario. Non approva una promessa, non costituisce Vision Lock e non aggiunge feature allo scope. Le tre alternative usano gli stessi ingredienti, ma attribuiscono priorita emotive e produttive diverse.

## Criterio principale

Una promessa centrale valida deve essere:

- descrivibile senza citare altri videogiochi;
- visibile in trenta secondi di gameplay;
- ripetuta nel ciclo breve, non riservata al finale;
- abbastanza specifica da guidare tagli e priorita;
- producibile con un piccolo team e budget iniziale basso.

## Tre direzioni da confrontare

### A - Riscrivi il campo, accetta le conseguenze

> Improvvisa macchine che trasformano fisicamente il campo di battaglia: ogni soluzione apre una nuova opportunita e crea un nuovo pericolo.

**Emozione primaria:** ingegno sotto pressione.

**Cosa deve vedersi subito:** il giocatore apre o chiude un percorso, sfrutta il cambiamento e affronta una conseguenza prevedibile della stessa azione.

**Forza:** e la direzione piu distinta dal semplice survivor-like e puo essere provata con graybox economico.

**Rischio:** senza conseguenze forti diventa soltanto raccolta o costruzione di barriere; con troppa liberta diventa imprecisa dalla camera isometrica.

### B - Costruisci una carovana che insegue l'alba

> Costruisci e riconfigura una carovana vivente per attraversare un mondo che ruota troppo in fretta, scegliendo quali macchine portare nella luce e quali rischiare nel buio.

**Emozione primaria:** viaggio, cura e adattamento.

**Cosa deve vedersi subito:** la condizione ambientale si sposta, una configurazione smette di essere ideale e il giocatore separa o riallaccia un modulo per proseguire.

**Forza:** unisce tono caldo, progressione visibile e struttura della run; crea un'immagine comunicabile nello store.

**Rischio:** carovana e luce possono richiedere molti sistemi prima di risultare autentiche; se il movimento della fascia e soltanto un timer, la promessa si indebolisce.

### C - Costruisci la macchina che diventerai

> Recupera componenti durante la battaglia, trasformali in macchine e fondili in un mezzo sempre piu grande che conserva le scelte e i compromessi della tua build.

**Emozione primaria:** crescita tangibile e metamorfosi.

**Cosa deve vedersi subito:** un componente cambia insieme silhouette, movimento e possibilita; la forma piu potente paga un costo leggibile.

**Forza:** offre un payoff spettacolare, trailer-friendly e immediatamente legato alla costruzione della build.

**Rischio:** e la direzione piu costosa; veicoli, agganci e fusioni possono moltiplicare collisioni, animazioni, UI e bilanciamento prima che il core sia divertente.

## Ipotesi raccomandata per i prossimi prototipi

Usare **A come promessa di gameplay**, **B come struttura e fantasia del viaggio** e **C come payoff di progressione**, senza promettere ancora la forma colossale.

In forma compatta:

> Costruisci macchine che riscrivono il campo, sfrutta le conseguenze e riconfigura la tua carovana prima che il mondo cambi di nuovo.

Il 22 settembre 2026 il proprietario ha accettato provvisoriamente una formulazione equivalente come guida di lavoro, senza chiudere il Vision Lock:

> Sopravvivi a un mondo impazzito costruendo, fondendo e pilotando macchine improvvisate capaci di trasformare fisicamente il campo di battaglia.

Il vantaggio e che il prossimo prototipo puo validare A senza dover prima costruire l'intero sistema di B o C. La prima macchina sara un compagno a piedi; la guida dei mezzi resta un payoff di progressione successivo.

## Core loop candidato

Il proprietario ha accettato provvisoriamente questo loop come base da verificare e modificare durante i prototipi.

Il ciclo breve viene espresso con sei verbi:

1. **Leggi:** individua pressione, percorso, terreno e condizione in arrivo.
2. **Intervieni:** modifica una zona con il tool personale o prepara una macchina.
3. **Sfrutta:** attraversa, combatte o raccoglie grazie al nuovo stato.
4. **Paga:** affronta l'effetto collaterale creato o accelerato dall'intervento.
5. **Riconfigura:** sposta, separa, alimenta o sacrifica un modulo.
6. **Avanza:** raggiunge un obiettivo prima del successivo cambiamento del mondo.

Il loop fallisce se `Intervieni` produce solo danno, se `Paga` e casuale o invisibile, oppure se `Riconfigura` equivale soltanto a scegliere un bonus percentuale.

## Prova minima della promessa

Il prossimo incremento dopo Terrain Slice A non deve dimostrare tutto il concept. Deve mostrare una singola catena causale:

> apro un corridoio -> ottengo accesso o spazio -> creo anche un ingresso per una minaccia -> decido se consolidare, deviare o abbandonare la zona.

Successo osservabile:

- il tester prevede almeno una conseguenza prima di agire;
- usa il terreno per risolvere un problema e non soltanto per sperimentare;
- sa descrivere il proprio piano con i verbi del loop;
- riconosce che una scelta utile ha creato la difficolta successiva;
- immagina spontaneamente una seconda soluzione valida.

## Scorecard per il confronto

Assegnare da 1 a 5 a ciascuna direzione dopo averne discusso un esempio concreto. Non sommare in automatico: un punteggio basso su `prototipabilita` o `firma originale` e un veto finche il rischio non viene ridotto.

| Criterio | A | B | C | Domanda guida |
|---|---:|---:|---:|---|
| Firma originale | | | | Si riconosce senza il tema o i riferimenti? |
| Chiarezza in 30 secondi | | | | Un osservatore capisce cosa fa il giocatore? |
| Prototipabilita economica | | | | Possiamo provarla con graybox e pochi sistemi? |
| Profondita di build | | | | Cambia decisioni e comportamento, non solo statistiche? |
| Coerenza con tono e mondo | | | | Rotazione, natura e ingegneria hanno una funzione? |
| Potenziale visivo/commerciale | | | | Produce immagini e momenti riconoscibili? |
| Controllabilita dello scope | | | | Possiamo tagliare contenuti conservando la promessa? |

## Quattro domande per il proprietario

1. Quale fantasia vuoi provare piu spesso: risolvere spazio, far crescere una carovana o trasformarti in una macchina?
2. Quale fallimento ti sembra piu interessante: aver aperto il percorso sbagliato, essere rimasto indietro rispetto alla luce o aver costruito una forma troppo ingombrante?
3. Alla fine di una run, che cosa vuoi ricordare: una soluzione ingegnosa, il viaggio compiuto o la macchina ottenuta?
4. Se dovessimo eliminare due idee su tre dal primo anno di sviluppo, quale deve assolutamente sopravvivere?

## Gate

Il workshop e concluso soltanto quando:

- viene scelta una promessa primaria e vengono indicati i ruoli delle altre due;
- la frase viene riscritta con le parole del proprietario;
- esiste almeno una prova graybox economica che potrebbe smentirla;
- la decisione viene registrata in `DECISIONS.md` come provvisoria o approvata.
