# Roadmap di produzione

## 1. Obiettivo e metodo

L'obiettivo non e semplicemente creare un prototipo, ma portare su Steam un bullet hell indipendente con identita chiara, prestazioni solide e uno scope compatibile con le risorse disponibili.

La produzione procede per fasi con un **gate di uscita**. Una fase e conclusa solo quando i suoi deliverable sono verificati. Le durate sono intervalli orientativi per una piccola squadra o un autore singolo part-time; verranno ricalibrate dopo aver raccolto disponibilita, competenze, budget e specifiche hardware.

Principio guida:

> Prima dimostriamo che e divertente. Poi dimostriamo che e producibile. Solo dopo costruiamo tutto il resto.

## Stato operativo al 6 ottobre 2026

> **Engine: Godot 4.7.2** (D-019). Le fasi di prodotto qui descritte restano valide: cambia la tecnologia, non la sequenza ne i gate. I riferimenti a Unreal, Visual Studio e MCP Epic nelle sezioni successive sono storici; il codice Unreal e nel tag `unreal-prototype-final`. Dettaglio della migrazione: `docs/MIGRATION_STATUS.md`; parita: `docs/GODOT_PARITY_CHECKLIST.md`.

- **Fase 0:** quasi completata. Restano da formalizzare disponibilita settimanale e budget massimo.
- **Fase 1:** in corso. Il 4 ottobre 2026 il proprietario ha scelto la **promessa A** e l'emozione "ingegno sotto pressione" (D-033), la run ad **arena continua** (D-034, struttura poi sostituita da D-040) e la **progressione a esperienza con tre upgrade per livello e rarita** (D-035, logica in `docs/PROGRESSION_SPEC.md` approvata il 5 ottobre 2026). Il 5 ottobre 2026 il proprietario ha fissato la **struttura**: campagne con percorso a livelli, arene molto grandi (riferimento Vampire Survivors e DRG: Survivor) e boss di fine livello (D-040). Restano provvisori combattimento, durata, mezzi pilotabili e linguaggio. Vision e Concept Lock non ancora approvati.
- **Fase 2:** toolchain Godot verificata end-to-end: editor, test headless, export Windows (primario, D-026) e Linux, gate unico `tools/godot/Invoke-GodotChecks.ps1`. Resta il round-trip Blender → Godot (R-011).
- **Fase 3: fase attiva.** Fatto il 3 ottobre 2026:
  - migrazione a Godot completata a parita; feel "quasi uguale" a Unreal, preset **Scattante** scelto come base (D-030), fisica e rendering a 120 (D-028, D-031);
  - **Companion Slice** (D-032, `docs/COMPANION_SLICE_SPEC.md`): primo compagno macchina, ora scena principale; **non ancora playtestato**;
  - **menu pausa e Impostazioni** (grafica, inversione assi, salvataggio; Esc o Start, A conferma e B indietro);
  - 8 suite di test automatici, tutte verdi; build Windows e Linux aggiornate in `LocalBuilds/`;
  - 4 ottobre 2026: **arena "rovine riconquistate"** (D-036), nuova scena principale con compagno e griglia 11x11 integrata nel suolo; impianto a primitive, modelli Blender da fare. 9 suite verdi. Build non riesportate.
  - 5 ottobre 2026: **prototipo della promessa A** (D-038, `docs/PROMISE_A_PROTOTYPE_SPEC.md`), nuova scena principale `arena_run.tscn`: cortile con mura e varchi, orda lenta, chiodatrice, esperienza, level-up a tre carte, 11 upgrade, vita e fine run. **Playtest rimandato dal proprietario**; build non riesportate.
  - 5 ottobre 2026: **scala dell'arena, parte tecnica** (D-039): campo di percorso a finestra con cache dei chunk (2,3 ms per calcolo anche a 1 km di lato) e comparsa dei nemici ad anello attorno al giocatore. 12 suite verdi. Misura su Steam Deck da fare. Backlog creativo in `docs/FEATURE_IDEAS.md`.
  - 6 ottobre 2026: **arena grande giocabile** (D-042): `arena_run.tscn` e ora un quartiere in rovina di 204x204 m con griglia terreno unica 85x85 presentata a lotti (MultiMesh, collisione solo sulle Raised), cortile di partenza, sei cortili secondari in quattro varianti, dieci depositi di rottami, quattro trincee, rovine basse, perimetro di torri. 13 suite verdi, misure su PC in D-042. **Steam Deck non misurato.** Build non riesportate.
  - 6 ottobre 2026: **primo boss, il Demolitore, e fine del livello** (D-043): chiamata a 12 minuti con direzione annunciata, boss che smonta i terrapieni e li trasforma in barricate, barra vita, schermata "Livello completato" con i rottami portati fuori. 14 suite verdi. Valori non bilanciati. **C'e ora un livello completo da giocare.**
  - 6 ottobre 2026: **indicatori a bordo schermo** per cortili, depositi di rottami e boss (D-044); **build Windows e Linux riesportate**, smoke test della build Windows superato.
  - 6 ottobre 2026, rifiniture del livello in attesa del playtest (scelta del proprietario): **i rottamatori portano i rottami del Demolitore al cantiere della barricata** (D-045): rottami contesi con il compagno, portatori da abbattere, cantiere visibile da sabotare. 14 suite verdi.
  - 6 ottobre 2026: **passata artistica dell'arena, primo passo** (D-046): rovine basse sventrate senza tetto al posto dei cubi, terrapieni con fianchi di terra a strati; stesse collisioni, stesse prestazioni su PC. **Frammenti sui colpi** (D-047): rottamatori abbattuti, scavo e rialzo, muri smontati.
  - 6 ottobre 2026: **primo audio** (D-048): 19 effetti sintetizzati nel codice, volumi generale ed effetti nelle Impostazioni. 15 suite verdi; **nessuno l'ha ancora ascoltato**. Build Windows e Linux riesportate.
  - 6 ottobre 2026: **profilo permanente e Officina** (D-049): i rottami portati fuori si accumulano su disco e si spendono in 7 upgrade permanenti dalla schermata di fine livello. Il ciclo gioca, guadagna, potenzia, rigioca e chiuso. Costi non bilanciati.
  - 6 ottobre 2026: **modelli low-poly statici per ingegnere, compagno, rottamatore e Demolitore** (D-050), generati da script Blender; collisioni e valori invariati, 120 fps invariati su PC. 16 suite verdi, build Windows e Linux riesportate.
  - 6 ottobre 2026: **menu iniziale** (D-051), nuova scena principale con Officina raggiungibile prima di giocare, e **mappa del campo scolpito a fine livello** (D-052).
  - 6 ottobre 2026: **impronte dell'orda** dopo ogni modifica al terreno (D-053), **movimento procedurale degli attori** (D-054), **primo bilanciamento dell'economia con run simulate** (D-055: un rottame al minuto, Torretta a 30). 19 suite verdi, 120 fps invariati su PC, build Windows e Linux riesportate.
  - 6 ottobre 2026: **corretti i cinque problemi emersi dalla simulazione** (D-056): rottami solo dalle celle rialzate, carta Cassone ridimensionata, reddito per livelli invece che per tempo, rottamatori veloci e carte ripetibili, level-up aperto a fine passo. 20 suite verdi, build riesportate.
  - 6 ottobre 2026: **quattro addon Godot installati** (D-057): Debug Menu (F3, per la misura su Steam Deck), Controller Icons (glifi dei tasti, non ancora nell'interfaccia), Debug Draw 3D, SimpleGrassTextured (spento, per la seconda passata artistica). 21 suite verdi. Build in `LocalBuilds/` non riesportate.
  - 6 ottobre 2026: **glifi dei tasti nell'interfaccia** (D-059): suggerimenti "icona + testo" in menu, Officina, pausa, level-up e fine livello, e i quattro comandi di gioco nell'HUD; seguono controller o tastiera e mouse. Nuova suite `button_prompts_tests.gd`. Build in `LocalBuilds/` non riesportate.
  - 6 ottobre 2026: **specifica del ciclo giorno/notte approvata** (D-058, `docs/DAY_NIGHT_SPEC.md`): una notte per livello, rottamatori piu forti al buio, torcia e faro con upgrade, lampioni piazzabili. **Solo documento, nessun codice.**
  - 6 ottobre 2026: **primo personaggio con scheletro e animazioni** (D-060): l'ingegnere corre, mira, incassa e cade con animazioni CC0 (Quaternius) su un modello a pezzi rigidi generato da script Blender; gambe girate verso la marcia, busto sulla mira. Gate verde. **Resa da giudicare dal proprietario nel playtest**; build non riesportate.
  - 6 ottobre 2026: **MCP for Blender installato e Rigify abilitato** (D-061) per modellare con Blender aperto; Mixamo resta un servizio web da usare con l'account del proprietario quando manca un'animazione.
  - 6 ottobre 2026: **corse laterali e all'indietro, scavo e capriola dell'ingegnere** (D-062), da cinque animazioni Mixamo scaricate dal proprietario e riportate sullo scheletro: la mira resta ferma mentre le gambe seguono la marcia, lo scatto fa la capriola, il tool del terreno un affondo. Gate verde. **Resa da giudicare dal proprietario**; build non riesportate.
  - 6 ottobre 2026: **spike del terreno a rilievo continuo** (D-063): il proprietario vuole scolpire liberamente montagnette e solchi invece dei blocchi, e una pianta non squadrata. Scena isolata `scenes/spikes/terrain_spike.tscn` funzionante nelle catture e a 120 fps su PC. Il livello a celle resta invariato.
  - 9 ottobre 2026: **spike del terreno completato** (D-063): il campo di percorso ora misura la strada in metri e controlla la pendenza vertice per vertice come chi cammina (le tre verifiche fallite erano errori del campo e del test: direzione letta dal punto invece che dalla casella, passi contati alla Chebyshev, campionamento troppo grosso); suite `tests/height_terrain_tests.gd` nel gate, 36 controlli verdi; campo 6 ms. **Prova del proprietario da fare.**
- **Fasi 4-14:** non iniziate formalmente. Esperimenti tecnici anticipati non equivalgono al superamento dei relativi gate.

**Prossimo passo (in ordine):**

0. **Terreno libero (D-063), prova del proprietario:** lo spike e completo (9 ottobre 2026: campo di percorso corretto, suite nel gate, catture e misure rifatte). Tocca al proprietario provare `scenes/spikes/terrain_spike.tscn`; solo dopo il suo si scrivere il piano di migrazione del livello vero al rilievo continuo. Dettaglio in `docs/MIGRATION_STATUS.md`.

1. **Specifica della struttura di campagna**: scritta il 5 ottobre 2026 (`docs/CAMPAIGN_STRUCTURE_SPEC.md`, D-041 upgrade di livello e permanenti). **In attesa delle risposte del proprietario** alle 4 domande della sezione 8; senza risposta si procede con le proposte.
2. **Arena grande giocabile**: fatta il 6 ottobre 2026 (D-042). Restano la misura su Steam Deck e la seconda passata artistica (edifici in rovina, rampicanti, SSAO ed erba), dopo il playtest.
3. **Primo boss di fine livello**: fatto il 6 ottobre 2026 (D-043, il Demolitore).
4. **Playtest del proprietario** (**prossimo passo, tocca al proprietario**): il livello completo con boss esiste, ora con rottamatori che portano i rottami al cantiere (D-045), rovine sventrate (D-046), frammenti (D-047), audio (D-048), Officina (D-049), modelli e movimento degli attori (D-050, D-054), menu (D-051), mappa di fine livello (D-052), impronte dell'orda (D-053), economia ritoccata e rottamatori veloci (D-055, D-056). **Promemoria con avvio, problemi gia noti e cosa annotare: `docs/PLAYTESTS/ARENA_RUN_LEVEL_2026-10-07.md`.** Almeno tre run con le domande in `docs/PROMISE_A_PROTOTYPE_SPEC.md` (sezioni "Playtest del proprietario", "Boss" e "Officina": le domande 13-22 sono nuove). **Nulla di tutto questo e stato giocato o ascoltato da una persona.** F5 dall'editor oppure `LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe`; per provare subito il boss, da riga di comando: `godot --path godot -- --boss-at=60`. Esito: Continua / Modifica / Scarta.
5. **Correzioni dalla review del 7 ottobre 2026** (agente, con Godot): `docs/REVIEWS/ARENA_RUN_LEVEL_2026-10-07.md`, sezione 4. Le prime otto (boss incastrato contro le rovine, rottami sepolti sotto le barricate, campo di percorso dopo il ricentraggio, scie senza sbarra, Esc nelle Impostazioni, tre minori) sono **fatte il 9 ottobre 2026**, con un test ciascuna e gate verde. Restano il punto 2 della sezione 4 (R-03, R-04, R-05, R-12, R-35, R-36, R-37, R-17) e le build in `LocalBuilds/` da riesportare.
6. **Dopo il playtest** (agente, in base all'esito): confermare o ritoccare le correzioni di D-056 (rottamatori veloci, rottami finiti, reddito per livelli) e la curva di esperienza; bilanciamento di boss e prezzi dell'Officina (fatta in D-049), secondo livello e mappa di campagna, misura su Steam Deck (la build Windows aggiornata e in `LocalBuilds/Prototype01-Godot-Win64/`), animazioni e rifinitura dei modelli degli attori (statici, D-050), audio vero e musica al posto degli effetti sintetizzati.
7. **In sospeso, senza urgenza:**
   - Test A percettivo e test su Steam Deck via Proton (`docs/PLAYTESTS/GODOT_PARITY_PLAYTEST.md`); dopo, eliminare la build Unreal `LocalBuilds/Prototype01-TerrainGrid-Win64-v1` (872 MB);
   - eliminare a mano le cartelle vuote `Desktop/Videogame-settings` e `Desktop/Videogame-vision` (worktree di Codex) dopo aver chiuso Codex;
   - pipeline dei personaggi animati avviata (D-060, ingegnere); andature, scavo e capriola aggiunti (D-062); dopo il giudizio del proprietario: ritmi e durate, animazione di tiro, altri personaggi del roster, volti e forme organiche.
8. **Ciclo giorno/notte** (D-058, richiesto dal proprietario il 6 ottobre 2026): il proprietario rivede `docs/DAY_NIGHT_SPEC.md`; il piano di implementazione della tappa 1 e scritto (`docs/DAY_NIGHT_PLAN.md`, 7 ottobre 2026); poi l'agente implementa la tappa 1 (notte giocabile: ciclo, luce, nemici al buio, due carte), quindi la tappa 2 (lampioni). Non blocca il playtest del punto 4; le correzioni del punto 5 vanno prima, perche toccano gli stessi file: prima del tramonto il livello resta identico.

Fonti operative: `DECISIONS.md`, `RISK_REGISTER.md` e i protocolli in `PLAYTESTS/`.

## 2. Assunzioni provvisorie

Queste non sono ancora decisioni definitive:

- gioco premium single-player;
- prima piattaforma: Windows su Steam;
- controller/gamepad come input primario con pieno supporto tastiera/mouse;
- buona compatibilita Steam Deck tramite Proton come obiettivo, senza promessa di Verified prima dei test;
- Unreal Engine 5 e Blender;
- sessioni relativamente brevi e rigiocabili;
- controllo con tastiera/mouse e controller;
- niente multiplayer, open world, live service o contenuti generati proceduralmente complessi nella prima release;
- team molto piccolo, con uso selettivo di asset o servizi esterni.

Vincoli gia confermati e quindi non piu trattati come semplici assunzioni:

- nessuna urgenza di lancio, con qualita e sostenibilita prioritarie;
- budget iniziale molto basso;
- esperienza di base in Blender e quasi nulla in Unreal Engine e C/C++;
- grafica 3D vicina, per livello generale di resa e leggibilita, a *Deep Rock Galactic: Survivor*;
- *Vampire Survivors* come riferimento di loop e build, non come target grafico;
- abilita arcade, costruzione della build, atmosfera e progressione/narrazione sono tutte desiderate, nell'ordine di validazione definito in `PROJECT_BRIEF.md`.

Base creativa attualmente selezionata per l'esplorazione, non ancora bloccata:

- ingegnere improvvisatore come fantasia del giocatore;
- mondo fantasy post-apocalittico caldo e colorato in rotazione perpetua;
- carovana di macchine costruite durante le missioni, capaci di accompagnare il giocatore, agganciarsi e separarsi;
- trasformazione radicale del campo con vantaggi e conseguenze;
- manipolazione temporale come meccanica secondaria candidata;
- mezzi terrestri, aerei e acquatici come famiglie candidate introdotte per fasi;
- fusione in configurazioni crescenti e forma colossale come culmine avanzato della build, subordinato ai test modulari;
- invasione aliena e terraformatori come causa candidata della rotazione accelerata, dei super-temporali e delle inondazioni;
- specifica e criteri di scarto in `WORKING_CONCEPT.md`.

Ogni assunzione potra essere confermata, modificata o eliminata nelle prime fasi.

## 3. Milestone principali

| Milestone | Domanda a cui deve rispondere | Prova richiesta |
|---|---|---|
| Vision Lock | Che gioco stiamo facendo e per chi? | One-page vision approvata |
| Concept Lock | Quale variante merita di essere prodotta? | Concept selezionato con scorecard e test |
| Prototype Complete | Il nucleo e divertente senza contenuti finali? | Build graybox osservata in playtest |
| Vertical Slice | Sappiamo raggiungere la qualita finale? | Breve esperienza rappresentativa e profilata |
| Content Complete / Alpha | Tutti i contenuti previsti esistono? | Gioco completabile dall'inizio alla fine |
| Feature Complete / Beta | Possiamo concentrarci solo su qualita e bug? | Nessuna feature essenziale mancante |
| Release Candidate | Questa build puo essere venduta? | Checklist tecnica, store e legale superata |
| Launch | Il prodotto e pubblicato e supportabile? | Build live, monitoraggio e rollback pronti |

## 4. Fasi dettagliate

### Fase 0 - Fondazione del progetto

**Scopo:** creare un ambiente di lavoro affidabile prima che arrivino file binari e dipendenze.

Attivita:

1. Raccogliere vincoli reali: ore settimanali, budget massimo, data desiderata, competenze, hardware, lingue e tolleranza al rischio.
2. Definire ruoli e responsabilita, anche se ricoperti dalla stessa persona: creative direction, gameplay, art, audio, QA, marketing e release management.
3. Inizializzare il repository e scegliere strategia di versionamento e backup.
4. Creare `.gitignore`, regole Git LFS e struttura delle cartelle prima di aggiungere asset Unreal/Blender, se Git e la scelta approvata.
5. Stabilire un registro delle decisioni, un backlog, una cartella per ricerche/licenze e una per i playtest.
6. Verificare hardware e spazio disponibile rispetto ai requisiti della versione UE scelta.
7. Definire una cadenza: build giocabile almeno settimanale e revisione dello scope almeno mensile.
8. Stabilire il protocollo di collaborazione tra proprietario, Codex supervisore e altre AI contributrici.
9. Condurre installazione, apprendimento e produzione con istruzioni progressive, verifiche esplicite e nessuna conoscenza tecnica presunta.
10. Adottare un flusso AI-first: Codex implementa e supervisiona, il proprietario partecipa soprattutto a valutazione e decisioni, con interazione manuale minima finche non acquisisce dimestichezza.

Deliverable:

- scheda dei vincoli;
- repository e backup verificati;
- `AGENTS.md` e struttura documentale;
- prima matrice dei rischi;
- Definition of Done iniziale.

Gate di uscita:

- il progetto puo essere clonato o ripristinato senza file locali segreti;
- e chiaro chi approva scope, spese e pubblicazione;
- le incognite che impediscono il brainstorming sono state raccolte.

Durata indicativa: 2-5 giorni.

### Fase 1 - Brainstorming guidato e visione

**Scopo:** trasformare l'idea generica in piu concept confrontabili, senza innamorarsi prematuramente di una soluzione.

#### 1.1 Vincoli creativi

Rispondere insieme a queste domande:

- Quale emozione deve dominare: trance, panico controllato, potere, precisione, sopravvivenza o spettacolo?
- Quanto deve durare una run e quanto tempo serve per vedere una decisione interessante?
- Il giocatore mira, spara automaticamente o alterna movimento e attacco?
- Quanto deve essere punitivo il contatto? Vita, scudo, grazia, rallentamento o morte immediata?
- Il focus e mastery arcade, costruzione di build, narrazione o progressione permanente?
- Quale pubblico vogliamo servire e quali giochi conosce gia?
- Quale elemento si puo descrivere in una frase e riconoscere in uno screenshot?

#### 1.2 Assi di esplorazione

Generare almeno tre opzioni per ciascun asse:

- prospettiva: isometrica arena, top-down libera, laterale a stanze, laterale in avanzamento;
- struttura: run roguelite, livelli autoconclusivi, boss rush, campagna breve, endless score attack;
- combattimento: twin-stick, auto-fire, armi modulari, parry/assorbimento, cambio di polarita, dash offensivo;
- ritmo: continuo, ondate, alternanza esplorazione-combattimento, combattimenti musicali;
- identita: tema, silhouette, palette, tono e premessa narrativa;
- innovazione: una sola regola distintiva, comprensibile e prototipabile.

#### 1.3 Tre concept iniziali da sfidare

Non sono proposte definitive; servono ad avviare il confronto.

1. **Arena isometrica reattiva**: il giocatore deforma o ruota l'arena per deviare pattern, creando spazio invece di limitarsi a schivare.
2. **Bullet hell laterale a polarita**: assorbire proiettili compatibili alimenta l'arma; cambiare stato espone a un diverso insieme di minacce.
3. **Boss-rush isometrico modulare**: ogni boss altera una regola del movimento; tra gli scontri si costruisce un loadout molto compatto.

Per ogni concept produrre:

- pitch di una frase;
- promessa al giocatore;
- ciclo di 30 secondi, 5 minuti e una run;
- tre pilastri e tre elementi esplicitamente fuori scope;
- riferimento visivo e sonoro;
- rischio maggiore e test piu economico per ridurlo;
- motivo per cui un giocatore dovrebbe sceglierlo rispetto ai concorrenti.

#### 1.4 Scorecard

Valutare ogni concept da 1 a 5 con pesi concordati:

| Criterio | Peso iniziale |
|---|---:|
| Divertimento del core loop | 25% |
| Distinzione e comunicabilita | 20% |
| Fattibilita per il team | 20% |
| Coerenza autoriale: meccanica, mondo e audiovisivo | 10% |
| Chiarezza e leggibilita del bullet hell | 10% |
| Potenziale di espansione controllata | 5% |
| Compatibilita con budget e calendario | 10% |

La scorecard restringe il campo ma non sostituisce il playtest. Un concept che fallisce i test vincolanti in `CREATIVE_PRINCIPLES.md` non passa il gate anche con una media alta.

Deliverable:

- 3-5 concept cards;
- moodboard iniziali;
- elenco dei giochi comparabili e degli anti-riferimenti;
- scorecard e due finalisti;
- bozza di one-page vision.

Gate di uscita:

- due concept abbastanza precisi da poter essere prototipati in pochi giorni;
- nessun concept dipende da una tecnologia non ancora validata;
- target, emozione e vincolo di scope sono comprensibili in meno di due minuti.
- ogni finalista possiede una firma meccanica, fantastica e audiovisiva distinguibile;
- il pitch funziona senza dipendere dal nome di un gioco esistente.

Durata indicativa: 1-2 settimane.

### Fase 2 - Valutazione di app, tool e pipeline

**Scopo:** scegliere il set minimo di strumenti che riduce rischio e attrito. Nessuna app viene adottata soltanto perche popolare.

#### Criteri di valutazione

Per ogni strumento registrare:

- problema risolto e alternativa manuale;
- licenza, costo iniziale e costo ricorrente;
- formati aperti, export e rischio di lock-in;
- integrazione con Unreal e Blender;
- maturita, aggiornamenti, sicurezza e possibilita di automazione;
- impatto su repository, build e collaborazione;
- tempo di apprendimento;
- decisione: adottare ora, provare, rimandare o rifiutare.

La valutazione degli strumenti non termina con questa fase. A ogni milestone Codex mantiene un **tool radar** leggero: segnala opportunita nuove o problemi che giustificano un tool, assegna una priorita e propone adozione, prova limitata o rinvio. Le raccomandazioni devono restare proporzionate al progetto e non autorizzano automaticamente installazioni, account, acquisti o nuove dipendenze.

#### Workflow con Claude e altre AI

Quando un'altra AI contribuisce allo sviluppo:

1. Codex o il proprietario prepara un task brief con scope e criteri di accettazione.
2. Il contributo viene prodotto in un branch, commit o worktree isolato quando possibile.
3. L'AI restituisce riepilogo, assunzioni, diff, test e limiti della verifica.
4. Codex revisiona il diff effettivo e ripete i controlli pertinenti nel progetto.
5. Correzioni o riduzioni di scope vengono richieste prima dell'integrazione.
6. Soltanto il contributo verificato entra nel branch principale.

Questo permette di usare modelli diversi come forza produttiva senza frammentare architettura, standard o fonte di verita.

#### Matrice iniziale da verificare

| Area | Candidato principale | Alternative | Decisione da prendere |
|---|---|---|---|
| Engine | Godot 4.7.2 standard/GDScript (D-019) | - | Aggiornamenti di versione solo dopo verifica con `tools/godot/Invoke-GodotChecks.ps1` |
| Modellazione/animazione | Blender | - | Versione fissata, scala, assi e preset di export |
| IDE | Visual Studio 2026 | JetBrains Rider | Valutare costo, debugging e supporto UE |
| Versionamento piccolo team | Git + Git LFS | Perforce | Stimare volume binari e necessita di file locking |
| Hosting repository | GitHub | GitLab, Azure DevOps | Limiti LFS, backup, issue e CI |
| Reference/moodboard | PureRef | Canva, cartelle locali | Scegliere uno standard esportabile e archiviabile |
| Concept/texture 2D | Krita | Affinity, Photoshop | Verificare esigenze e licenze |
| Materiali 3D | Blender | Substance 3D, ArmorPaint | Adottare solo se la direzione artistica lo richiede |
| Audio editing | Reaper | Audacity | Valutare pipeline non distruttiva e licenza |
| Audio middleware | Audio nativo UE | FMOD, Wwise | Usare middleware solo con un requisito concreto |
| Task tracking | Markdown + issue tracker | Trello, Linear, Notion | Evitare duplicazione tra sistemi |
| Profiling | Profiler e monitor di Godot | RenderDoc | Definire test CPU/GPU e scena di stress |
| Automazione build | `godot_console --export-release` + `Invoke-GodotChecks.ps1` | CI GitHub/altro | Introdurre CI quando esiste una build ripetibile |
| Cattura trailer | OBS Studio | cattura GPU | Verificare output pulito e frame pacing |
| Video | DaVinci Resolve | Kdenlive | Verificare hardware, codec e licenza |
| Distribuzione | Steamworks SDK/SteamPipe | - | Onboarding, depot, branch di test e ownership |
| QA | checklist + issue tracker | servizi esterni | Device matrix, crash reporting e privacy |
| Localizzazione | tabelle/localization UE | CAT tool esterno | Lingue, font e processo di revisione |

#### Prove pratiche obbligatorie

1. Importare in Unreal un cubo metrico, una mesh con pivot significativo, un asset con materiali e una semplice animazione da Blender.
2. Rinominare/spostare asset in Unreal e verificare redirector e source control.
3. Simulare un conflitto su un file binario e validare il processo di locking o ownership.
4. Pacchettizzare una build Windows vuota e lanciarla fuori dall'Editor.
5. Ripristinare il progetto da clone/backup su un percorso pulito.
6. Misurare tempo e dimensione di clone, import, cook e package.

Deliverable:

- registro strumenti con decisioni e licenze;
- versioni fissate e politica di aggiornamento;
- pipeline Blender-Unreal documentata;
- strategia source control/backup;
- build tecnica vuota riproducibile.

Gate di uscita:

- il toolchain minimo funziona end-to-end;
- ogni strumento a pagamento o cloud ha proprietario, costo e giustificazione;
- non esistono passaggi critici affidati a file non versionati o a memoria personale.

Durata indicativa: 3-7 giorni, in parallelo alla chiusura del brainstorming.

### Fase 3 - Micro-prototipi comparativi

**Scopo:** scegliere con dati tra visuale isometrica e laterale e validare la meccanica distintiva.

Costruire due prototipi graybox deliberatamente piccoli, con gli stessi limiti:

- una sola arena o stanza;
- un personaggio, un attacco, un dash o difesa;
- due pattern di proiettili e un nemico/boss dummy;
- HUD minimo;
- nessun asset finale e nessuna meta-progressione;
- target di prestazioni e contatore di proiettili visibile.

Misurare:

- tempo necessario a comprendere il controllo;
- morti percepite come giuste/ingiuste;
- capacita di leggere traiettorie, hitbox e profondita;
- precisione di mira e movimento su mouse/tastiera e controller;
- divertimento dopo 5, 15 e 30 minuti;
- costo stimato per telecamera, animazioni, livelli e contenuti;
- comportamento a carico elevato.

Eseguire almeno 5 playtest con persone non coinvolte nello sviluppo. Non spiegare i comandi oltre cio che vedrebbe un giocatore reale; osservare prima di intervistare.

Deliverable:

- due build comparabili;
- registrazioni, metriche e note dei playtest;
- decisione documentata su prospettiva e controllo;
- concept finale e one-page vision approvata.

Gate di uscita:

- almeno il 70% dei tester comprende loop e pericoli senza coaching sostanziale;
- il prototipo scelto mostra un momento ripetibile di divertimento;
- il rischio tecnico principale ha un percorso credibile;
- la prospettiva e bloccata fino a una revisione formale.

Durata indicativa: 2-4 settimane.

### Fase 4 - Pre-produzione e design eseguibile

**Scopo:** convertire la visione in specifiche sufficienti a costruire la vertical slice.

Attivita:

1. Scrivere un GDD leggero: loop, controlli, combattimento, danno, progressione, contenuti, economia e accessibilita.
2. Definire architettura tecnica: ownership, state machine, pooling proiettili, dati, salvataggi, input, UI e caricamento.
3. Definire art bible: silhouette, palette, valori, scala, camera, VFX e limiti di densita visiva.
4. Definire audio bible: priorita del mix, segnali di pericolo, musica e feedback.
5. Creare budget: frame time, draw call, memoria, proiettili, VFX, texture, dimensione build e tempi di caricamento.
6. Preparare piano contenuti e stime per unita: nemico, boss, arma, arena, brano, UI e localizzazione.
7. Creare registro rischi con probabilita, impatto, trigger e mitigazione.

Deliverable:

- GDD leggero e technical design;
- art/audio bible;
- backlog della vertical slice;
- budget prestazionali e piano di test;
- matrice dei rischi aggiornata.

Gate di uscita:

- ogni elemento della vertical slice ha criterio di accettazione e stima;
- il totale rientra nella capacita disponibile con margine almeno del 20-30%;
- sistemi ad alto rischio hanno una prova pianificata prima dei contenuti dipendenti.

Durata indicativa: 1-2 settimane.

### Fase 5 - Prototipo del core loop

**Scopo:** rendere solido e divertente il combattimento prima della qualita visiva finale.

Ordine raccomandato:

1. movimento, collisioni, camera e input;
2. stato discreto del terreno e primo tool personale;
3. macchina di trasformazione con vantaggio e conseguenza;
4. aggiornamento di collisioni, percorsi nemici e anteprima;
5. generazione e aggiornamento efficiente dei proiettili;
6. danno, invulnerabilita, morte e restart rapido;
7. arma e feedback provvisorio;
8. authoring dei pattern data-driven;
9. nemico/boss e telegraph;
10. HUD minimo;
11. difficolta e curva di apprendimento;
12. scena di stress e profiling, inclusa trasformazione del terreno;
13. build pacchettizzata per playtest.

Per tutto il prototipo verificare controller e tastiera/mouse a ogni incremento. Simulare anche 1280x800/16:10 e navigare ogni schermata senza mouse. Dalla prima build Windows pacchettizzata eseguire smoke test tramite Proton sullo Steam Deck gia posseduto; i criteri completi sono in `PLATFORM_AND_INPUT.md`.

Deliverable:

- build graybox del core loop;
- libreria minima di pattern riutilizzabili;
- baseline prestazionale;
- report di almeno due cicli build-test-modifica.

Gate di uscita:

- 15-20 minuti di gioco mantengono interesse senza dipendere da grafica finale;
- input e hit risultano affidabili;
- tool e macchine producono almeno due trasformazioni del terreno con conseguenze tattiche differenti;
- collisioni e navigazione restano affidabili dopo trasformazioni ripetute;
- il carico obiettivo gira entro il budget sulla macchina minima candidata;
- restart e iterazione sono rapidi.

Durata indicativa: 3-6 settimane.

#### Esperimento opzionale successivo - macchina pilotabile

Soltanto dopo il gate del core loop, costruire un test isolato di un singolo telaio terrestre pilotabile che riutilizzi i moduli delle macchine da campo. Il test deve verificare se guidare aggiunge una decisione interessante senza compromettere precisione, leggibilita o scope.

Movimento acquatico e aereo non entrano nella roadmap di produzione finche il test terrestre non dimostra valore e sostenibilita. La loro adozione richiede una decisione di scope separata con costo per controlli, fisica, camera, ambienti, nemici, UI, audio e prestazioni.

#### Esperimento ambientale - luce e buio

In una scena graybox, confrontare una zona illuminata e una buia con un solo beneficio e un solo costo ciascuna. Verificare se il giocatore modifica consapevolmente posizione e uso delle macchine, mantenendo leggibili movimento, proiettili e telegraph.

Luce dinamica complessa, ciclo globale e numerose eccezioni per nemico restano fuori scope finche questa regola minima non dimostra valore.

#### Esperimento ambientale - super-temporale e piena

Dopo aver validato gli stati del terreno, usare un bacino e un canale con pochi livelli d'acqua. Annunciare una tempesta, permettere al giocatore di preparare argine o drenaggio e trasformare almeno un percorso terrestre in acquatico.

Il test deve dimostrare che anticipazione e riconfigurazione sono interessanti senza simulazione fluidodinamica generale. Un mezzo acquatico semplice entra solo dopo che acqua, percorsi e preavviso risultano leggibili.

### Fase 6 - Vertical slice

**Scopo:** dimostrare una piccola porzione alla qualita attesa per la release.

Contenuto indicativo:

- onboarding breve;
- un livello/arena rappresentativo;
- 2-3 famiglie di nemici;
- un miniboss o boss completo;
- una scelta significativa di build o progressione;
- UI, VFX, audio, arte e illuminazione vicini alla qualita finale;
- salvataggio, impostazioni base, controller e remapping minimo;
- build Steam di test privata, se l'onboarding Steamworks e pronto.
- test della build Windows tramite Proton e su Steam Deck fisico, se accessibile;

Testare anche pipeline e costi: tempo reale per creare un nemico, un pattern e un ambiente; dimensione della build; memoria; packaging; feedback di giocatori esterni.

Deliverable:

- vertical slice pacchettizzata;
- trailer interno o video gameplay non montato;
- metriche prestazionali;
- stima aggiornata di costi e calendario;
- lista esplicita di tagli possibili.

Gate di uscita, il piu importante del progetto:

- giocatori esterni riconoscono promessa e punti di forza;
- la qualita target e producibile con il team disponibile;
- non restano rischi tecnici esistenziali non mitigati;
- scope, budget e calendario vengono approvati o il progetto viene ridimensionato.
- viene presa una decisione go/no-go sulla demo pubblica e sul suo contenuto rappresentativo.

Durata indicativa: 6-12 settimane.

### Fase 7 - Pianificazione della produzione

**Scopo:** trasformare quanto appreso nella vertical slice in un piano realistico di contenuti.

Attivita:

- creare content matrix con quantita minime, target e stretch;
- stimare usando velocita osservata, non desiderata;
- ordinare il lavoro per dipendenze e rischio;
- bloccare nuove feature salvo sostituzione di scope equivalente;
- pianificare milestone interne, playtest e buffer;
- decidere outsourcing e marketplace asset con verifica licenze;
- avviare calendario della pagina Steam e materiali marketing.

Gate di uscita:

- ogni contenuto appartiene a must/should/could/cut;
- esiste margine di calendario e una lista di tagli ordinata;
- e definita una data di feature freeze interna, non ancora necessariamente pubblica.

Durata indicativa: 3-5 giorni.

### Fase 8 - Produzione

**Scopo:** produrre contenuti senza destabilizzare il nucleo validato.

Ciclo per ogni incremento:

1. specifica e criterio di accettazione;
2. graybox giocabile;
3. implementazione e authoring dati;
4. art/audio pass;
5. test funzionale, leggibilita e prestazioni;
6. integrazione in build pacchettizzata;
7. aggiornamento del backlog e delle metriche.

Revisioni ricorrenti:

- settimanale: build e rischi;
- bisettimanale: playtest e bilanciamento;
- mensile: scope, burn rate e previsione di completamento;
- a ogni milestone: backup/ripristino e test su macchina non di sviluppo.

Gate di uscita:

- tutti i contenuti must sono presenti e il gioco e completabile;
- nessuna pipeline fondamentale e ancora manuale e fragile;
- i tagli non compromettono la promessa della one-page vision.

Durata indicativa: da stimare dopo la vertical slice; per un piccolo indie, spesso diversi mesi.

### Fase 9 - Alpha: content complete

**Scopo:** rendere affidabile il gioco completo prima del polish finale.

Attivita:

- test dall'inizio alla fine e soak test;
- classificazione bug per severita e frequenza;
- verifica salvataggi, migrazione dati, impostazioni e fallback;
- profiling di tutte le scene peggiori;
- verifica accessibilita: contrasto, flash, screen shake, volume, input e leggibilita;
- prima revisione completa di testi, tutorial, crediti e licenze;
- compatibilita con diverse risoluzioni, aspect ratio e hardware target.

Gate di uscita:

- nessun blocco noto impedisce di completare il gioco;
- performance e memoria rispettano i budget nella maggior parte dei casi target;
- bug critici hanno proprietario e piano;
- non vengono piu aggiunti contenuti salvo sostituzioni necessarie.

Durata indicativa: 3-6 settimane.

### Fase 10 - Beta: feature complete e playtest esteso

**Scopo:** validare qualita, bilanciamento, compatibilita e comprensione su scala maggiore.

Attivita:

- feature freeze;
- playtest esterno strutturato con consenso e raccolta dati proporzionata;
- test di controller, Steam Input, overlay, achievement e cloud save se inclusi;
- checklist aggiornata per la Steam Hardware Compatibility Review;
- verifica installazione, aggiornamento, disinstallazione e salvataggi;
- localizzazione e linguistic QA per le lingue approvate;
- test della demo, se prevista, come prodotto separato;
- preparazione supporto, FAQ e procedura crash report.

Gate di uscita:

- zero bug bloccanti noti e soglia concordata per bug gravi;
- completamento e difficolta sono coerenti col target;
- nessuna regressione su salvataggi o progressione;
- store description e gioco promettono la stessa esperienza.

Durata indicativa: 3-6 settimane.

### Fase 11 - Steam, marketing e operazioni di lancio

**Scopo:** preparare presenza commerciale e distribuzione senza lasciare tutto alla fine.

Questa fase inizia in parte dopo la vertical slice e corre in parallelo, ma ha un gate finale proprio.

Attivita:

1. Completare onboarding Steamworks, dati bancari/fiscali e pagamento Steam Direct sotto controllo del proprietario.
2. Configurare app, depot, branch, package, utenti e permessi.
3. Preparare capsule, descrizioni, tag, screenshot, trailer, requisiti e privacy.
4. Pubblicare la pagina Coming Soon con anticipo sufficiente e avviare raccolta wishlist.
5. Configurare funzionalita deliberate: achievement, cloud, input, leaderboard e demo; non abilitarle per inerzia.
6. Preparare build upload, note di versione, simboli/debug privati e rollback.
7. Inviare pagina e build alla revisione Valve con buffer per correzioni.
8. Preparare press kit, mailing list/creator outreach e calendario annunci in misura compatibile con il progetto.
9. Preparare e pubblicare una demo pre-release se supera i gate in `DEMO_STRATEGY.md`; valutare una sola edizione di Steam Next Fest quando il calendario e credibile.

Vincoli Steam da ricontrollare al momento dell'esecuzione:

- Steam Direct indica attualmente una fee di 100 USD per prodotto;
- per i primi titoli esiste attualmente un'attesa minima di 30 giorni dal pagamento;
- la pagina Coming Soon deve essere pubblica attualmente per almeno due settimane;
- Valve indica attualmente una revisione nell'ordine di 1-5 giorni, ma il piano deve prevedere margine.

Gate di uscita:

- build e store page hanno superato la revisione;
- prezzo, data, lingue, requisiti e materiali sono approvati;
- esiste una procedura provata di upload, test branch, promozione e rollback;
- canali di supporto e responsabilita del day one sono definiti.

Durata: avvio 3-6 mesi prima del lancio; buffer finale minimo da ricalcolare sulle regole Steam vigenti.

### Fase 12 - Release candidate e go/no-go

**Scopo:** decidere sulla base di evidenze se pubblicare una specifica build immutabile.

Checklist minima:

- build Shipping installata tramite Steam su una macchina pulita;
- smoke test completo e test di almeno un'intera partita/run;
- nessun blocker o crash riproducibile ad alta frequenza;
- salvataggio, aggiornamento, cloud e achievement verificati se inclusi;
- log privi di errori nuovi critici;
- crediti e licenze completi;
- materiali store corrispondenti alla build;
- backup di sorgenti, build, configurazione depot e asset registry/release data;
- build precedente recuperabile;
- piano di supporto, hotfix e comunicazione pronto.

Gate di uscita:

- verbale go/no-go con rischi residui accettati dal proprietario;
- release candidate identificata in modo univoco e non modificata;
- data non viene difesa a scapito di blocker, perdita dati o requisiti della piattaforma.

Durata indicativa: 1-2 settimane oltre il bug fixing beta.

### Fase 13 - Lancio

**Scopo:** pubblicare in modo controllato e reagire rapidamente ai problemi reali.

Attivita:

- controllo finale di store, prezzo, build live e branch;
- monitoraggio crash, discussioni, recensioni e richieste di supporto;
- triage con categorie: perdita dati/crash, blocco, regressione, bilanciamento, richiesta;
- hotfix solo con riproduzione, test di regressione e rollback pronto;
- comunicazioni brevi, fattuali e coerenti;
- nessuna modifica strutturale impulsiva nelle prime ore senza dati sufficienti.

Gate di uscita:

- stabilita accettabile per il periodo concordato;
- backlog post-lancio classificato;
- retrospettiva iniziale completata.

### Fase 14 - Post-lancio

**Scopo:** sostenere il prodotto senza trasformarlo automaticamente in un live service.

Attivita:

- patch di stabilita e qualita;
- analisi aggregata di feedback, funnel e difficolta, nel rispetto della privacy;
- valutazione separata di porting, contenuti aggiuntivi, localizzazioni e DLC;
- manutenzione di dipendenze ed engine solo con strategia di test/migrazione;
- retrospettiva completa e archiviazione delle lezioni apprese;
- definizione esplicita della fine del supporto attivo, quando appropriato.

Ogni espansione richiede un mini business case e non deve compromettere la stabilita della versione pubblicata.

## 5. Rischi iniziali specifici del bullet hell

| Rischio | Segnale precoce | Mitigazione iniziale |
|---|---|---|
| Il concept sembra derivativo | Il pitch richiede citare altri giochi per essere interessante | Una sola meccanica distintiva, testata nella Fase 3 |
| Scarsa leggibilita isometrica | I tester confondono profondita, collisione o piano dei proiettili | Ombre/indicatori, hitbox semplici, camera fissa e test comparativo |
| Costo animazioni laterali | Ogni arma/direzione moltiplica gli asset | Rig modulare, set movimenti limitato, prototipo del costo prima dell'art lock |
| Troppi attori/proiettili | Frame time cresce linearmente e il GC causa hitch | Pooling o rappresentazione ottimizzata, scene di stress precoci |
| Pattern belli ma ingiusti | Morti non comprese o proiettili coperti da VFX | Gerarchia visiva, telegraph, safe color e replay dei test |
| Terreno dinamico troppo complesso | Bug di collisione/pathfinding, stutter o salvataggi enormi | Stati discreti prima, prototipi isolati e voxel solo dopo prove misurate |
| Modifica del terreno superficiale | Il giocatore scava solo per risorse o usa sempre la stessa soluzione | Ogni trasformazione influenza almeno due sistemi e include una conseguenza |
| Acqua dinamica ingestibile | Fluidi, collisioni e navigazione consumano troppo o producono bug | Bacini e livelli discreti, preavviso, pompe/argini espliciti e nessuna simulazione generale iniziale |
| Deformazione illeggibile dall'alto | Profondita, pareti o bersaglio del tool non sono comprensibili | Anteprima volumetrica, limiti iniziali a rampe/trincee, gestione occlusione e test controller |
| Meta-progressione gonfia lo scope | Il bilanciamento richiede troppe combinazioni | Set piccolo di scelte significative e cap esplicito |
| Produzione contenuti troppo lenta | Un nemico completo richiede molto piu della stima | Misurare nella vertical slice e tagliare quantita |
| Repository binario ingestibile | Clone lenti, conflitti, quote LFS | LFS/locking o Perforce scelti prima della produzione |
| Marketing tardivo | Nessuna pagina o materiale quando il gioco e gia quasi finito | Store planning dalla vertical slice |

## 6. Documenti vivi da creare quando servono

- `docs/VISION.md`: one-page vision e pilastri.
- `docs/CREATIVE_PRINCIPLES.md`: criteri di originalita, autorialita e uso dell'AI.
- `docs/WORKING_CONCEPT.md`: concept attivo durante brainstorming e micro-prototipi.
- `docs/DECISIONS.md`: decision log con data, contesto, scelta e conseguenze.
- `docs/GDD.md`: design eseguibile, non enciclopedia.
- `docs/TECHNICAL_DESIGN.md`: architettura e contratti dei sistemi.
- `docs/ART_BIBLE.md` e `docs/AUDIO_BIBLE.md`.
- `docs/TOOLS_AND_LICENSES.md`: versioni, costi, licenze e provenienza asset.
- `docs/RISK_REGISTER.md`.
- `docs/PLAYTESTS/`: protocollo, osservazioni e sintesi anonimizzate.
- `docs/RELEASE_CHECKLIST.md`.

I documenti vengono creati quando hanno un proprietario e un uso concreto; non devono diventare lavoro sostitutivo del prototipo.

## 7. Prossima sessione: agenda di brainstorming

Tempo consigliato: 60-90 minuti.

1. **10 min - Vincoli:** tempo, budget, competenze, hardware, obiettivo personale.
2. **10 min - Fantasia del giocatore:** cosa deve sentirsi capace di fare.
3. **15 min - Riferimenti e anti-riferimenti:** cosa prendere e cosa evitare.
4. **20 min - Generazione:** almeno 10 combinazioni senza valutarle subito.
5. **15 min - Selezione:** raggruppamento e scorecard preliminare.
6. **10 min - Esperimenti:** scegliere i due micro-prototipi piu economici e informativi.
7. **5 min - Chiusura:** decisioni, dubbi, proprietari e prossima verifica.

Output della sessione: 3-5 concept cards e due candidati al prototipo, non una promessa di produzione definitiva.

## 8. Fonti ufficiali consultate

- [Istruzioni personalizzate con AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Steamworks - Getting Started](https://partner.steamgames.com/doc/gettingstarted)
- [Steam Direct](https://partner.steamgames.com/steamdirect)
- [Unreal Engine - Hardware and Software Specifications](https://dev.epicgames.com/documentation/unreal-engine/hardware-and-software-specifications-for-unreal-engine)
- [Unreal Engine - Packaging Your Project](https://dev.epicgames.com/documentation/unreal-engine/packaging-your-project)
- [Unreal Engine - Virtual Assets Overview](https://dev.epicgames.com/documentation/unreal-engine/overview-of-virtual-assets-in-unreal-engine)

Prezzi, versioni, tempi di revisione e requisiti delle piattaforme devono essere verificati nuovamente quando diventano decisioni operative.
