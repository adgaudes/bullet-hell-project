# Proposta di visione — 3 ottobre 2026

> **Aggiornamento 4 ottobre 2026:** il proprietario ha risposto alle domande principali, vedi sezione 5. Concept Lock e Vision Lock restano aperti.
>
> **DRAFT per il proprietario.** Questo documento propone una sintesi per chiudere la Fase 1; non approva Vision Lock, Concept Lock, identità o tono.

## 1. Stato

| Area | Stato documentato | Cosa resta aperto |
|---|---|---|
| Prodotto e piattaforma | Qualità prima della velocità e budget iniziale molto basso (D-001); Windows su Steam, controller primario con parità tastiera/mouse, Steam Deck LCD via Proton come obiettivo (D-003, D-026). | Pubblico più preciso, prezzo e obiettivo commerciale. |
| Forma di gioco | Base provvisoria: 3D isometrico/top-down, ingegnere improvvisatore e mondo fantasy post-apocalittico caldo (D-005). | Concept Lock, nemici, mira/auto-fire e struttura definitiva della run. |
| Tono | Divertente, spiritoso, burlone e irriverente (D-010); protagonista soprattutto cinico e sboccato, ma simpatico (D-013). | Frequenza del linguaggio esplicito, rapporto con l'alcol, rating e quantità di voce. |
| Promessa e loop | Promessa di lavoro e loop `Leggi–Intervieni–Sfrutta–Paga–Riconfigura–Avanza` sono provvisori (D-011). | Formulazione finale e prova della catena terreno–macchina–conseguenza. |
| Macchine | Primo compagno autonomo: segue, trasporta, aiuta in combattimento e modifica lievemente il terreno; non è pilotabile (D-012). | Regole di aggancio/fusione, mezzi pilotabili, carovana e forma colossale. |
| Terreno | Stati discreti obbligatori per la prima validazione; niente voxel/plugin runtime nel Prototipo 01 (D-006). Terrain Slice A ha ricevuto `Continua` (D-009). | Collisioni/navigazione sotto carico, due conseguenze tattiche, ruolo delle macchine e rappresentazione finale. |
| Arte | Realismo stilizzato caldo, forme quasi cartoonesche, materiali e luce credibili, leggibilità isometrica (D-014, provvisoria). | Firma audiovisiva originale e prova a camera reale a 1280×800. |

## 2. One-page vision — DRAFT

**Fantasia.** Il giocatore è un ingegnere improvvisatore competente, cinico e sboccato che attraversa un mondo fantasy post-apocalittico caldo e vitale. La natura ha riconquistato rovine e macchine; il ciclo di luce, buio e tempeste riscrive percorsi e opportunità. La catastrofe è enorme, ma il protagonista la affronta con inventiva, insolenza e attrezzatura assemblata sul campo.

**Promessa proposta.** *Sopravvivi a un mondo impazzito costruendo macchine improvvisate che riscrivono il campo di battaglia: sfrutta ogni trasformazione, affrontane le conseguenze e riconfigura la tua carovana prima che il mondo cambi di nuovo.* È una riscrittura della direzione D-011, non una sua approvazione finale.

**Verbi del giocatore.** Leggere pressione, terreno e cambiamenti in arrivo; muoversi e schivare; scavare, rialzare o consolidare; raccogliere componenti; impartire comandi al compagno; costruire e riconfigurare; sfruttare nuovi percorsi; pagare una conseguenza prevista; avanzare o abbandonare una soluzione diventata pericolosa.

**Core loop.** In 10–30 secondi il giocatore identifica un problema spaziale, interviene col tool personale o con il compagno, usa il nuovo stato per combattere/raccogliere/attraversare e reagisce al costo creato. In 3–5 minuti raggiunge un obiettivo, ottiene un modulo comportamentale e decide se usarlo, sovraccaricarlo o sacrificarlo quando la configurazione precedente smette di funzionare. Tool e macchina devono essere complementari: il primo corregge con precisione, la seconda trasforma o mantiene su scala maggiore (`TERRAIN_SYSTEM.md`).

**Ipotesi di run, da validare.** Una spedizione a tappe di circa 20–30 minuti segue o attraversa una fascia mobile di condizioni favorevoli. Si parte a piedi con tool e piccolo compagno autonomo; si affrontano situazioni con obiettivi, si recuperano moduli e si rende visibile la build nella carovana. Eventi ambientali annunciati obbligano a riconfigurare. La run termina con estrazione, boss o transizione; quale delle tre forme sia primaria resta una decisione del proprietario. Pilotaggio, acqua/aria e fusione colossale sono payoff futuri, non requisiti del primo loop.

**Differenza riconoscibile.** La build non vive soltanto in un menu: prende forma nel mondo come terreno modificato e macchine presenti, con benefici e costi spaziali leggibili. Scavare un corridoio può offrire accesso e insieme aprire una rotta alla minaccia; sollevare una barriera può proteggere e insieme togliere spazio di fuga. Se terreno e macchine diventano decorazione, raccolta o bonus passivi, la firma fallisce.

**Presentazione.** 3D isometrico leggibile, realismo stilizzato caldo, grandi masse e silhouette chiare, macchine artigianali asimmetriche e trasformazioni visibili. L'umorismo emerge anche da feedback, guasti e nomi, senza coprire telegraph o obiettivi. Target primario: Windows su Steam; controller-first con piena parità tastiera/mouse; UI e leggibilità verificate a 1280×800 per Steam Deck LCD via Proton (D-003, D-014, D-026).

## 3. Formulazioni alternative della promessa

| Promessa | Enfatizza | Sacrifica | Prototipo che la prova o smentisce |
|---|---|---|---|
| **A. “Riscrivi il campo con macchine improvvisate: ogni soluzione crea l'opportunità e il pericolo successivi.”** | Firma meccanica, causalità e chiarezza immediata. | Viaggio, personalità del compagno e payoff di fusione. | Arena con corridoio apribile e barriera rialzabile; successo solo se il tester prevede vantaggio e costo e trova almeno due soluzioni. |
| **B. “Costruisci una carovana di macchine per restare un passo avanti a un mondo che cambia sotto i tuoi piedi.”** | Viaggio, progressione visibile e mondo dinamico. | Specificità del combattimento e centralità esplicita delle conseguenze. | Compagno D-012 più una transizione ambientale annunciata: il tester deve scegliere se radunare, fermare o riconfigurare, non limitarsi a seguire un timer. |
| **C. “Sopravvivi trasformando terreno e rottami in una macchina sempre più assurda, potente e difficile da gestire.”** | Crescita tangibile, tono irriverente e tradeoff della build. | Chiarezza sulla fascia di luce e sulla carovana come viaggio. | Due moduli agganciabili: uniti cambiano silhouette e funzione ma impongono un costo leggibile; separati restano entrambi utili. |

**Default raccomandato:** A come promessa primaria verificabile; B come struttura della run; C come payoff, senza promettere ancora mezzi pilotabili o forma colossale.

## 4. Checklist per il Concept Lock

Stati applicati ai criteri del gate di Fase 1 in `PROJECT_ROADMAP.md`:

- **Necessita decisione del proprietario —** due concept abbastanza precisi da prototipare in pochi giorni: esistono concept card, ma non due finalisti correnti approvati e confrontati.
- **Necessita un prototipo —** nessun concept dipende da tecnologia non validata: il terreno discreto ha una prima evidenza, ma compagno, carovana, aggancio e conseguenze su nemici/navigazione non sono validati.
- **Necessita decisione del proprietario —** target, emozione e vincolo di scope comprensibili in meno di due minuti: il target e lo scope sono documentati; manca l'approvazione dell'emozione dominante e della sintesi qui proposta.
- **Necessita un prototipo —** ogni finalista possiede firme meccanica, fantastica e audiovisiva distinguibili: le firme sono descritte, ma graybox completo e screenshot muto non le hanno dimostrate.
- **Già soddisfatto —** il pitch funziona senza dipendere dal nome di un gioco esistente: le formulazioni sopra non richiedono riferimenti esterni.

Il Concept Lock richiede inoltre i test vincolanti di `CREATIVE_PRINCIPLES.md`; quelli non documentati come eseguiti restano aperti.

## 5. Domande al proprietario, per impatto

1. Quale promessa scegli come primaria: A, B o C? **Default: A.**
2. Quale emozione deve dominare minuto per minuto? **Default: ingegno sotto pressione.**
3. La run è soprattutto una spedizione a tappe, un'arena continua o una sequenza di stanze? **Default: spedizione a tappe.**
4. Quale chiusura provvisoria testiamo per prima: estrazione, boss o transizione? **Default: estrazione.**
5. Durata target della run? **Default: 25 minuti.**
6. Combattimento: auto-fire, mira manuale o ibrido? **Default: ibrido, base automatica e tool/abilità mirati.**
7. Il primo anno deve promettere mezzi pilotabili al pubblico? **Default: no; solo se il telaio terrestre supera il gate.**
8. Il linguaggio esplicito deve essere raro, moderato o frequente? **Default: moderato e contestuale.**

### Risposte del proprietario (4 ottobre 2026)

| # | Risposta | Stato |
|---:|---|---|
| 1 | **A** come promessa primaria; B struttura, C payoff come da default. | Decisa (D-033) |
| 2 | **Ingegno sotto pressione.** | Decisa (D-033) |
| 3-4 | **Arena continua con estrazione** (non spedizione a tappe). | Decisa (D-034) |
| 5 | Durata: non discussa, resta il default di 25 minuti. | Provvisoria |
| 6 | Combattimento: non risposto in modo esplicito; le "armi aggiuntive" da level-up sono coerenti con l'ibrido (base automatica + tool mirati). | Provvisoria |
| 7-8 | Mezzi pilotabili e linguaggio esplicito: non discussi, restano i default. | Provvisoria |
| + | **Progressione nella run**: ogni nemico sconfitto rilascia esperienza; a ogni livello si sceglie fra tre upgrade (armi, pezzi per costruire i compagni, altro da definire insieme) con rarita diverse. Logica di estrazione da decidere. | Decisa nella forma (D-035), logica proposta |

## 6. Incoerenze e lacune documentali

- `PROJECT_ROADMAP.md` richiede scorecard e due finalisti; `BRAINSTORMING_CONCEPTS.md` archivia le quattro card e `WORKING_CONCEPT.md` porta avanti una sola base. Manca un confronto finale corrente fra due candidati.
- D-011 promette costruzione, fusione e pilotaggio, mentre D-012 stabilisce che la prima macchina non sia pilotabile. È una progressione compatibile, ma la promessa può far attendere troppo presto funzioni non ancora validate.
- `TERRAIN_SYSTEM.md` richiede nemici, macchina e due conseguenze tattiche. Il playtest `PLAYTESTS/TERRAIN_GRID_SLICE_A_2026-09-22.md` valida soltanto il passaggio allo Slice B e non contiene le risposte qualitative; `PLAYTESTS/GODOT_PARITY_PLAYTEST.md` lascia ancora vuoto il gate percettivo terreno. Non c'è evidenza per dichiarare validata la firma completa.
- `PROJECT_BRIEF.md` conserva riferimenti operativi a C++ e alla pipeline Blender–Unreal e lascia aperti target hardware/frame rate, mentre D-019 adotta Godot/GDScript e D-031 fissa l'obiettivo 120 fps. Sono residui documentali, non decisioni creative.
- La causa aliena, la fascia di luce, le inondazioni e l'obiettivo del viaggio restano candidati in `WORLD_PREMISE.md`; non vanno presentati come lore definitiva nel Vision Lock senza scelta del proprietario.
