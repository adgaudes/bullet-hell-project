# Scheda iniziale del progetto

## Stato del documento

- Data: 21 settembre 2026.
- Fase: fondazione e brainstorming.
- Scopo: fissare i vincoli reali gia dichiarati e separare fatti, direzione candidata e decisioni ancora aperte.

## Obiettivo del proprietario

Realizzare senza fretta un videogioco indipendente ben rifinito, pubblicabile su Steam e capace di trovare un pubblico pagante. Il successo non viene definito soltanto dal completamento tecnico: il gioco deve avere una promessa comprensibile, un buon livello di polish e una ragione credibile per essere scelto rispetto ad altri survivor-like.

Il concept deve essere originale e riconoscibile pur potendo imparare da titoli esistenti. Il prodotto finale non deve sembrare un clone, un collage di asset o il risultato impersonale di generazione automatica. I criteri vincolanti sono in `CREATIVE_PRINCIPLES.md`.

Non e ancora fissato un obiettivo di vendite. Prima di costruire un business case serviranno una vertical slice, una stima attendibile dei costi e dati iniziali da playtest e comunicazione.

## Vincoli confermati

| Area | Vincolo attuale | Conseguenza di progetto |
|---|---|---|
| Tempo | Nessuna urgenza di pubblicazione | Evitare una data prematura; lavorare per gate di qualita |
| Budget | Iniziale molto basso | Preferire strumenti gratuiti, asset originali riutilizzabili e acquisti solo con beneficio provato |
| Originalita | Requisito centrale per attrarre il pubblico | Concept Lock subordinato a firma meccanica, fantastica e audiovisiva |
| Percezione dell'AI | Il gioco non deve apparire generico o generato automaticamente | AI come supporto supervisionato; direzione e asset finali con intenzionalita autoriale |
| Team | Progetto personale con supporto di Codex e possibili contributi di altre AI | Scope da solista; ogni output AI deve essere revisionato e testato |
| Godot / GDScript | Esperienza da costruire (engine adottato il 3 ottobre 2026, D-019) | Apprendimento sul prototipo gia migrato; scene e script sono testo leggibile e diffabile |
| Programmazione (GDScript) | Esperienza quasi nulla | Architettura semplice, componenti piccoli, test automatici, review rigorosa e niente ottimizzazioni premature |
| Blender | Esperienza di base, non recente | Stile 3D producibile, kit modulari e pipeline di export validata prima della produzione |
| Metodo di apprendimento | Guida continua richiesta | Un passaggio alla volta, spiegazione semplice, risultato atteso e verifica esplicita |
| Divisione del lavoro | Codex o altre AI svolgono il grosso dell'implementazione | Proprietario e Codex valutano insieme; intervento manuale del proprietario minimo nelle fasi iniziali |
| Piattaforma | Steam, inizialmente Windows | Controller, packaging, prestazioni e pagina Steam entrano nella roadmap |
| Input | Controller primario, tastiera e mouse pienamente supportati | Progettare controlli e UI controller-first con parita funzionale |
| Steam Deck | Buona compatibilita se sostenibile | Target 1280x800/16:10, Proton e test su hardware prima della release |
| Hardware Steam Deck | Modello LCD gia posseduto; capacita da registrare | Dispositivo di riferimento dalla prima build Windows pacchettizzata |
| Grafica | 3D vicina per leggibilita e resa a *Deep Rock Galactic: Survivor* | Camera isometrica/top-down come direzione principale; no produzione sprite 2D come stile centrale |
| Anima del gioco | Divertente, spiritosa, burlona e irriverente | Evitare solennita uniforme; gameplay, feedback, scrittura e presentazione devono condividere la stessa energia |
| Asset esterni | Librerie di asset gratuiti ammesse previa valutazione condivisa | Verificare uso commerciale, attribuzione, provenienza, coerenza e costo di adattamento prima dell'adozione |

## Riferimenti dichiarati

### Deep Rock Galactic: Survivor

Riferimento principale per:

- presentazione 3D isometrica;
- leggibilita di personaggio, nemici, terreno ed effetti;
- sensazione di crescita durante la run;
- atmosfera forte ottenuta con una premessa chiara e un mondo coerente.

Non deve diventare un modello da copiare. Tema, silhouette, struttura delle mappe, economia e meccanica distintiva dovranno essere riconoscibili come nostri.

### Vampire Survivors

Riferimento principale per:

- immediatezza del loop;
- densita crescente delle minacce;
- sinergie e trasformazione della build;
- rapporto favorevole fra quantita di contenuto e costo produttivo.

La grafica 2D e l'identita specifica del titolo non sono il target visivo del progetto.

## Direzione candidata

Un **survivor-like 3D isometrico single-player** ambientato in un mondo fantasy post-apocalittico, caldo e colorato, in rotazione perpetua. Un ingegnere improvvisatore costruisce una carovana di macchine modulari durante le missioni: i moduli accompagnano il giocatore, si agganciano, si separano, trasformano il campo e possono fondersi in configurazioni crescenti. Luce, buio e manipolazione temporale creano vantaggi e svantaggi da gestire. La componente bullet hell deve offrire pattern leggibili e decisioni di posizionamento, senza riempire lo schermo in modo indiscriminato.

Pilastro obbligatorio: il terreno deve essere profondamente modificabile tramite tool personali per interventi precisi e macchine per trasformazioni su larga scala. Le modifiche devono influenzare almeno due sistemi fra percorsi, nemici, risorse, luce, acqua, macchine e carovana. La profondita sistemica ha priorita sulla deformazione geometrica completamente libera.

*Astroneer* e il riferimento di esperienza per liberta e tattilita della modifica del terreno. Il nostro adattamento deve conservare aggiunta, rimozione, livellamento e creazione di percorsi, rendendoli leggibili e controllabili da una visuale tendenzialmente dall'alto.

La natura ha riconquistato le vecchie strutture decrepite. Il riferimento a *The Last of Us* riguarda questa relazione visiva fra vegetazione e rovine, mentre palette, tono e mondo devono essere nostri: caldi, accoglienti, fantasy e vitali. La tipologia dei nemici resta intenzionalmente aperta.

Direzione grafica provvisoria: **realismo stilizzato caldo**, quasi cartoonesco nelle forme e proporzioni ma credibile nei materiali e nella luce. Personaggi compatti e caricaturali, macchine asimmetriche e ambienti a grandi masse leggibili devono sostenere il tono spiritoso senza diventare cartoon puro. Criteri e rischi sono descritti in `docs/ART_DIRECTION.md`.

L'anima confermata del gioco e comica e irriverente: il mondo puo essere in condizioni catastrofiche, ma il protagonista rifiuta di trattarlo con solennita. E un ingegnere competente e improvvisatore, sboccato, incline alle parolacce e potenzialmente ubriacone. Questi tratti devono propagarsi a reazioni, macchine, fallimenti e ritmo della presentazione, non limitarsi a battute sovrapposte. Carattere preciso, frequenza del linguaggio esplicito, rapporto con l'alcol e conseguenze sul rating restano da definire.

Causa candidata dell'apocalisse: un'invasione aliena ha introdotto macchine terraformanti che hanno danneggiato o riconfigurato il nucleo planetario, accelerando il ciclo giorno-notte e intensificando piogge e super-temporali. Le inondazioni trasformano il campo e giustificano macchine terrestri, acquatiche e aeree con ruoli differenti. Stato degli invasori e identita dei nemici restano aperti.

Questa e la base creativa scelta per l'esplorazione ed e descritta in `WORKING_CONCEPT.md`; non e ancora un Concept Lock. Tema, implementazione della costruzione, durata della run, forma della progressione e grado di mira manuale devono essere scelti tramite brainstorming e prototipi.

## Gerarchia iniziale dei pilastri

1. **Abilita arcade e game feel:** movimento, schivata, posizionamento, feedback e leggibilita devono essere divertenti anche in graybox.
2. **Costruzione della build:** ogni run deve permettere scelte che cambiano realmente il modo di giocare, non soltanto aumenti percentuali.
3. **Atmosfera e identita:** arte, suono e premessa devono rendere il gioco riconoscibile in uno screenshot e nei primi secondi di un video.
4. **Progressione e storia:** devono dare contesto, obiettivi e desiderio di continuare, senza richiedere una campagna narrativa costosa.

Tutti e quattro i pilastri sono desiderati. La gerarchia stabilisce l'ordine di validazione e protegge lo scope; non elimina atmosfera, storia o meta-progressione.

## Vincoli di scope iniziali

Salvo nuova decisione motivata, il primo prototipo non include:

- multiplayer o cooperativa;
- open world;
- dialoghi doppiati o cinematiche complesse;
- generazione procedurale avanzata delle mappe;
- molte classi, biomi o decine di armi;
- backend online, live service o contenuti stagionali;
- sistemi che dipendono da plugin commerciali.

## Strategia tecnica per il livello di esperienza

- Imparare l'engine costruendo sul micro-prototipo, non seguendo mesi di corsi generici prima di iniziare.
- Usare l'editor Godot per osservare e ritoccare scene e tuning (`.tres`) mentre gli agenti lavorano sui file.
- Restare in GDScript tipizzato; valutare C# o GDExtension (C++) solo per percorsi misurati come critici. Il codice scritto da un agente e verificato da test, gate (`tools/godot/Invoke-GodotChecks.ps1`) e, quando utile, da una review indipendente.
- Tenere armi, modificatori, nemici e curve di bilanciamento data-driven.
- Usare Blender inizialmente per semplici mesh graybox e un solo asset di prova; definire lo stile finale dopo aver misurato il costo reale di produzione.

## Decisioni ancora aperte

- dettagli della rotazione, stato degli invasori e obiettivo del viaggio;
- formulazione finale della promessa centrale;
- auto-fire, mira manuale o sistema ibrido;
- arena aperta, stanze collegate o percorso con obiettivi;
- durata target di una run;
- struttura di morte, estrazione e ricompensa;
- profondita e forma della meta-progressione;
- dosaggio della comicita, del linguaggio esplicito e dell'eventuale rapporto del protagonista con l'alcol;
- target hardware minimo (l'obiettivo di frame rate e 120 fps, D-031; Steam Deck LCD 60);
- schema definitivo per controller e tastiera/mouse;
- livello di compatibilita Steam Deck dimostrabile e possibile obiettivo Verified;
- prezzo e obiettivo commerciale.
- contenuto, durata e finestra della demo pubblica pre-release;
- natura dei nemici: organica, meccanica, magica, ibrida o altra.

## Preferenze emerse dal brainstorming

Le seguenti meccaniche interessano il proprietario e devono restare nel bacino di esplorazione:

- modificare fisicamente il campo di battaglia;
- manipolare il tempo;
- controllare uno sciame;
- costruire una macchina durante lo scontro.

Non sono ancora feature approvate e non devono essere sommate automaticamente. Le concept card successive proveranno combinazioni controllate con una meccanica primaria e, al massimo, una secondaria strettamente sinergica.

La prima combinazione scelta come base modificabile e:

- fantasia primaria: ingegnere improvvisatore;
- ambientazione: fantasy post-apocalittico caldo e colorato in un mondo in rotazione perpetua;
- meccanica primaria: costruire una carovana di macchine modulari che si agganciano, si separano e trasformano radicalmente il campo;
- meccanica secondaria candidata: manipolazione temporale attraverso le macchine;
- estensione futura possibile: comportamento a sciame per una famiglia di costruzioni.

Estensione avanzata da conservare nel concept, ma non nel primo prototipo:

- costruire e pilotare macchine o mezzi modulari;
- iniziare da un telaio terrestre e due moduli con una fusione controllata;
- introdurre un mezzo aereo con ruolo limitato dopo la validazione dell'aggancio;
- valutare il mezzo acquatico quando un ambiente ne giustifica le peculiarita;
- far culminare la build in una configurazione colossale derivata dai moduli realmente costruiti.

Sistema ambientale candidato:

- luce e buio devono offrire entrambi vantaggi e svantaggi;
- le macchine possono creare, spostare o consumare luce;
- luce, costruzioni e propulsione possono competere per la stessa energia;
- l'oscurita non deve compromettere la leggibilita essenziale del combattimento.

## Prossimo gate

La scheda e completa quando il proprietario conferma che rappresenta correttamente obiettivi e vincoli. Il passo seguente e confrontare le concept card in `BRAINSTORMING_CONCEPTS.md`, modificarle insieme e scegliere due idee per micro-prototipi economici. Nessuna proposta passa il Concept Lock senza superare i test di originalita definiti in `CREATIVE_PRINCIPLES.md`.
