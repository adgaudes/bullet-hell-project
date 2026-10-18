# Prototipo della promessa A — specifica

**Stato:** provvisoria (D-038, 5 ottobre 2026). Proposta e implementata dall'agente; il proprietario valuta giocando: Continua / Modifica / Scarta.

## Domanda a cui risponde

D-033: "Riscrivi il campo con macchine improvvisate: ogni soluzione crea l'opportunita e il pericolo successivi." Il prototipo passa se **il tester prevede vantaggio e costo di una modifica al terreno e trova almeno due soluzioni diverse** alla stessa pressione.

## Cosa c'e

Scena `godot/scenes/main/arena_run.tscn`, ora scena principale. L'arena "rovine riconquistate" (D-036) resta in `ruins_arena.tscn`, con la sfera hazard.

- **Cortile in rovina:** la griglia 11x11 parte con un anello di mura (celle Raised a 4 celle dal centro) e **quattro varchi**, uno per lato. Il giocatore parte al centro con il compagno.
- **Orda lenta** (scelta del proprietario): rottamatori che nascono dai bordi dell'arena a ritmo crescente e seguono un campo di percorso verso il giocatore. Aggirano le mura e passano dai varchi; se il cortile e chiuso del tutto puntano dritto e si ammassano contro le mura. Le celle Lowered li rallentano del 50%, come il giocatore. Contatto = 1 danno.
- **Chiodatrice automatica:** spara al nemico piu vicino in linea di tiro. I chiodi si fermano sulle celle Raised: un muro protegge ma toglie anche la linea di tiro.
- **Esperienza:** ogni rottamatore lascia un frammento; il giocatore lo attira entro 2,5 m. Level-up con **tre carte** secondo `PROGRESSION_SPEC.md` (regole 1-4, seed nel log).
- **Vita:** 5 punti, breve invulnerabilita dopo un colpo. A zero: schermata "Rottamato" con tempo, livello e abbattuti, poi Ricomincia.
- **Compagno e rottami**: smontare una cella rialzata produce un rottame (scavare terreno nudo no, D-056), rialzare costa un rottame e richiede il compagno vicino. Il compagno usa lo stesso campo di percorso e non resta chiuso fuori dalle mura.
- **Senza sfera hazard** (scelta del proprietario): un solo tipo di pericolo per misurare nemici e terreno.

## Regole ritoccate dopo la simulazione (D-056)

- **I rottami sono finiti.** Scavare terreno nudo fa un fossato e basta. I rottami vengono solo dallo smontare celle rialzate: mura dei cortili, depositi, barricate del boss, terrapieni tuoi (che rendono il rottame speso).
- **Rottamatori veloci**: blu, 4,2 m/s, meta vita. Dal minuto 2:30, fino al 30% dei nuovi nati al minuto 10. Tu corri a 6 m/s; un fossato li dimezza come gli altri.
- **Carte ripetibili** quando gli upgrade veri finiscono: Rattoppo al volo, Rottame di fortuna, Barattolo di chiodi.
- **Cassone rinforzato** e Non comune e ha due livelli.

Valori in `run_default.tres` (gruppo Runners, `recovery_scrap_levels`) e in `upgrade_catalog.gd`.

## Impronte dell'orda (D-053)

Dopo ogni scavo o rialzo, per 3 secondi, galloni magenta a terra mostrano da dove arrivera l'orda con il terreno com'e adesso. Piu scie confluiscono, piu i galloni sono grandi. Se il cortile e sigillato le scie finiscono contro le mura con una sbarra bianca.

## Le soluzioni che il terreno offre

| Mossa | Vantaggio | Costo o pericolo |
|---|---|---|
| Chiudere un varco (rialzo) | meno fronti da tenere | costa un rottame; chiude anche te; i nemici si ammassano fuori e l'esperienza non arriva |
| Chiudere tutto | tregua | niente esperienza, l'orda cresce fuori; per uscire devi riaprire |
| Aprire una breccia (scavo di un muro) | rottami e una via di fuga | un fronte in piu |
| Fossato davanti a un varco (scavo) | i nemici rallentano dove la chiodatrice li colpisce | rallenta anche te e il compagno |
| Muro interno | copertura | blocca i tuoi chiodi |

## Upgrade del prototipo

11 upgrade, tre rarita (Comune, Non comune, Raro), definiti in `scripts/progression/upgrade_catalog.gd`:

| Categoria | Upgrade | Effetto nel mondo |
|---|---|---|
| Arma | Grilletto limato, Chiodi da carpentiere, Canna doppia | cadenza, perforazione, ventaglio di chiodi |
| Pezzo compagno | Torretta sul cassone, Calamita, Cassone rinforzato (Non comune, 2 livelli) | pezzo visibile sul compagno; spara, attira frammenti, porta piu rottami |
| Tool terreno | Scavo esplosivo, Terrapieni spinati | onda d'urto allo scavo; le mura cambiano colore e feriscono chi le spinge |
| Personaggio | Scarponi slacciati, Toppa, Tasche larghe | riempitivi comuni |

Rinviati come da specifica: sinergia (regola 5), leggendari, limite di slot per armi aggiuntive (nel prototipo c'e una sola arma).

## Valori

Tutti in `godot/resources/tuning/run_default.tres` (`RunTuning`): vita 5, nemici a 2,2 m/s con 2 punti vita (+1 ogni 150 s), intervallo di comparsa da 1,6 s a 0,3 s in 5 minuti, massimo 70 vivi; chiodatrice ogni 0,5 s, portata 9 m; esperienza 5 per il primo livello, +3 a ogni livello.

## Scala: l'arena grande (D-042, 6 ottobre 2026)

Indicazione del proprietario (5 ottobre 2026, poi D-040): le arene del gioco finale sono **molto grandi**, come in Vampire Survivors o Deep Rock Galactic: Survivor. `arena_run.tscn` e ora il **quartiere in rovina** (`RuinsDistrict`, `scripts/arena/ruins_district.gd`): 204x204 m giocabili, tutti coperti da una sola griglia terreno 85x85 (`resources/tuning/terrain_district.tres`).

- **Griglia a lotti**: `TerrainGrid` disegna le 7225 celle con tre MultiMesh (uno per stato) e tiene una forma di collisione solo per ogni cella Raised. API, log e regole sono invariati; cambia solo la presentazione.
- **Punti di interesse del terreno**, generati dal seme dell'arena e applicati alla griglia da `ArenaRun` all'avvio:
  - il **cortile di partenza** di D-038 (anello a 4 celle, quattro varchi) attorno all'origine, in una piazza lastricata di 30 m di raggio;
  - **sei cortili secondari** (raggio 3-5 celle, ad almeno 40 m l'uno dall'altro) in quattro varianti: tre varchi, due varchi opposti, anello rotto (30% delle mura mancanti), doppio anello con varco interno su un altro lato;
  - **dieci depositi di rottami**: blocchi Raised 2x2 o 3x3; scavarli produce un rottame per passo, come scavare un muro;
  - **quattro trincee**: file di 6-14 celle gia Lowered, fossati pronti che rallentano anche te.
- **Rovine basse** (2,5-4,5 m, con collisione) sui lotti liberi, auto, macerie, barriere, lampioni, alberi: formano strade e strettoie per il campo di percorso; nulla dentro il perimetro supera i 4,5 m, cosi la camera non perde mai il giocatore. Torri alte solo fuori dal perimetro.
- Il campo di percorso a finestra (D-039) e la comparsa ad anello restano come sono: con l'arena grande i nemici nascono davvero fuori schermo.
- Vegetazione sopra le celle Normal (12 cm): su una cella scavata i ciuffi restano 8 cm sopra il fondo. Difetto noto e accettato nel prototipo.

Misure sul PC del proprietario in D-042 e in `tests/tools/benchmark_arena.gd`. **Steam Deck non misurato.** Densita, conteggi e dimensioni sono esportati su `District` e si cambiano dall'Inspector; il seme e `layout_seed`.

**Indicatori a bordo schermo** (D-044): freccia, nome e distanza dei due cortili e dei due depositi di rottami piu vicini fuori vista, e del boss quando e in campo; un deposito esaurito non e piu indicato.

Prima passata artistica (D-046): le rovine basse sono gusci sventrati senza tetto (la collisione resta il blocco pieno) e i terrapieni hanno fianchi di terra a strati. Personaggio, compagno, rottamatori e boss hanno modelli low-poly statici generati da script (D-050), senza animazioni.

Non ancora: obiettivi di livello, eventi che deformano l'arena.

## Boss: il Demolitore (D-043, 6 ottobre 2026)

Il livello si chiude con un boss (`scripts/enemies/demolisher.gd`), come da `CAMPAIGN_STRUCTURE_SPEC.md`.

- **Chiamata**: a 12 minuti (`boss_call_seconds`) compare "IL DEMOLITORE ARRIVA DA NORD/EST/SUD/OVEST" con conto alla rovescia di 12 s e una freccia a schermo. Sono i secondi per preparare il terreno.
- **Arrivo**: entra a 30 m dal giocatore dalla direzione annunciata; in basso compare la sua barra vita. L'orda continua.
- **Regola col terreno**: i terrapieni entro 12 m lo attirano piu di te. Li smonta in 1,2 s (la lama martella). Ogni muro smontato lascia un **rottame** a terra.
- **Rottamatori al lavoro** (D-045): fino a 3 rottamatori vicini smettono di inseguirti, raccolgono i rottami entro 10 m dal boss (anche i tuoi) e li portano, con un cubo color ruggine sulla schiena, al **cantiere**: una lastra arancione a due celle dal boss verso di te. Ogni due rottami consegnati li si alza una **barricata** scura, che ferma i tuoi chiodi. Senza rottamatori, niente barricate.
- **Fine**: alla sua morte l'orda si ritira e compare "Livello completato" con i rottami portati fuori (quelli nel cassone del compagno piu 5). Morendo se ne salva la meta. I rottami vanno nel profilo e si spendono in Officina (D-049).

| Mossa | Vantaggio | Costo o pericolo |
|---|---|---|
| Muro a sacrificio lontano da te | lo tiene fermo dove la chiodatrice lo colpisce | ogni due mura gli regali una barricata; il muro costa un rottame |
| Fossato sul suo percorso | dimezza la sua velocita | rallenta anche te e il compagno |
| Scavare una sua barricata | riapre la linea di tiro e rende un rottame | devi avvicinarti a 4,8 m da lui |
| Abbattere un rottamatore carico | il rottame cade: se arriva prima il compagno e tuo | devi dare la caccia ai portatori invece che al boss |
| Scavare o rialzare la cella del cantiere | il boss deve scegliere un altro cantiere | spendi un colpo di tool (e un rottame, se rialzi) vicino a lui |
| Mandare il compagno sui rottami delle mura | rottami per te, nessuno per lui | il compagno raccoglie solo entro 6 m da te: devi stare vicino al boss |
| Nessun muro attorno | niente barricate | ti punta dritto: 2 danni a contatto |

Valori in `run_default.tres` (`RunTuning`, gruppo Boss): 150 punti vita, 1,7 m/s, 2 danni. **Non bilanciati.** Per provarlo subito: `godot --path godot -- --boss-at=60`.

Domande di playtest in piu:

8. Hai capito da dove arrivava e hai avuto tempo di preparare qualcosa?
9. Hai capito da solo che i muri lo attirano e che le barricate scure sono sue?
10. Hai usato il terreno contro di lui in almeno due modi diversi? Quali?
11. Durata dello scontro e difficolta: troppo, giusto, poco?
12. Gli indicatori a bordo schermo ti hanno fatto andare verso cortili e rottami? Sono troppi, pochi, leggibili?
13. Hai capito da solo che i rottamatori col cubo sulla schiena portano i rottami alla lastra arancione, e che li nasce la barricata? Hai provato a fermarli?
14. Audio (D-048, mai ascoltato da nessuno): quale suono stanca, quale manca, quale e troppo forte o troppo debole? I volumi sono in Pausa > Impostazioni.

Marker: `PROTOTYPE01_BOSS_CALLED`, `PROTOTYPE01_BOSS_SPAWNED`, `PROTOTYPE01_BOSS_DEMOLISH_START`, `PROTOTYPE01_BOSS_WALL_DEMOLISHED`, `PROTOTYPE01_BOSS_BARRICADE`, `PROTOTYPE01_BOSS_BARRICADE_DOWN`, `PROTOTYPE01_BOSS_SITE`, `PROTOTYPE01_BOSS_SCRAP_TAKEN`, `PROTOTYPE01_BOSS_SCRAP_DELIVERED`, `PROTOTYPE01_BOSS_SCRAP_DROPPED`, `PROTOTYPE01_LEVEL_COMPLETE`.

## Officina e profilo permanente (D-049, 6 ottobre 2026)

A fine livello, vinto o perso, i rottami portati fuori vanno nel profilo (`user://profile.cfg`, su Windows `%APPDATA%\Godot\app_userdata\Prototype01\profile.cfg`; per ripartire da zero basta cancellarlo). La schermata di fine livello ha il pulsante **Officina**: 7 upgrade permanenti definiti in `scripts/progression/permanent_catalog.gd`, con costo in rottami per livello.

| Upgrade | Livelli e costi | Effetto dal livello successivo |
|---|---|---|
| Prolunga | 6, 14 | il tool arriva una cella piu lontano |
| Telaio rinforzato | 4, 8, 14 | +1 punto vita |
| Riflessi da officina | 5, 10 | +0,2 s di invulnerabilita dopo un colpo |
| Cassone saldato | 4, 8, 12 | il compagno porta 2 rottami in piu |
| Scorta | 3, 7 | il compagno parte con 2 rottami in piu |
| Torretta fissa | 30 | il compagno parte con la chiodatrice montata |
| Paracadute per rottami | 10 | morendo si salvano tre quarti del cassone |

**Rottami portati fuori** (D-055, D-056): quelli nel cassone, piu **uno ogni due livelli di esperienza guadagnati**, piu 5 se batti il boss; morendo si salva meta di cassone e livelli. Aspettare chiusi dentro non rende nulla. Prezzi tarati con bot simulati (`tests/tools/simulate_runs.gd`), non da un giocatore: per un principiante simulato ogni upgrade costa 1-3 run, la Torretta 6. L'Officina si raggiunge dal menu iniziale (D-051) e dalla schermata di fine livello, che mostra anche la mappa del campo scolpito (D-052).

Domande di playtest in piu:

15. Dopo la prima run, in Officina c'era qualcosa che volevi e potevi quasi permetterti? I prezzi sono un obiettivo o un muro?
16. Un upgrade permanente ha cambiato come hai giocato il livello dopo, o solo i numeri?

21. Rottamatori veloci (D-056): li riconosci? Ti costringono a usare il terreno o sono solo un fastidio?
22. Rottami (D-056): sei andato a cercare depositi e mura da smontare? Hai mai smontato le tue mura per recuperarli?
19. Impronte dell'orda (D-053): le guardi prima di decidere dove scavare o murare? Aiutano a prevedere, o distraggono?
20. Movimento dei personaggi (D-054): qualcosa si muove troppo, troppo poco, o in modo che stona?
18. Mappa di fine livello (D-052): l'hai guardata? Ti ha aiutato a capire cosa ha funzionato e perche sei morto?
17. Modelli (D-050): capisci sempre dove guardano tu, il compagno e i rottamatori? Qualcuno stona o si confonde con lo sfondo?

Marker: `PROTOTYPE01_PROFILE_BANKED`, `PROTOTYPE01_PERMANENT_BOUGHT`, `PROTOTYPE01_PERMANENT_APPLIED`.

## Fuori scope

Mappa di campagna, obiettivi di livello, altri tipi di nemico, musica e audio definitivo (gli effetti sintetizzati di D-048 sono un segnaposto), bilanciamento fine, prestazioni su Steam Deck (da misurare), menu iniziale.

## Marker diagnostici

`PROTOTYPE01_RUN_START seed=N`, `PROTOTYPE01_PATH_FIELD_READY`, `PROTOTYPE01_ENEMY_KILLED total=N`, `PROTOTYPE01_PLAYER_DAMAGED health=N`, `PROTOTYPE01_LEVEL_UP level=N offer=a,b,c`, `PROTOTYPE01_UPGRADE_CHOSEN id=.. level=N`, `PROTOTYPE01_DIG_BLAST`, `PROTOTYPE01_COMPANION_TURRET level=N`, `PROTOTYPE01_PLAYER_DIED time=.. level=.. kills=.. seed=N`.

Nota del 18 ottobre 2026 (D-093): il compagno e diventato la carovana di macchine. `PROTOTYPE01_COMPANION_TURRET` non esiste piu (la Torretta e un modulo: `PROTOTYPE01_MACHINE_ADDED module=turret`); all'avvio la carovana stampa `PROTOTYPE01_CARAVAN_READY machines=N carried=N`.

Per ripetere una run: `-- --seed=N` sulla riga di comando. Dal menu iniziale (D-051) `--seed=`, `--boss-at=` e `--autostart` portano dritti al livello.

## Playtest del proprietario

Giocare almeno tre run (F5 dall'editor o la build). Dopo ognuna, rispondere a voce o per iscritto:

1. Prima di scavare o rialzare, sapevi cosa avresti guadagnato e cosa rischiavi?
2. Quante strategie diverse hai provato con le mura (chiudere, aprire brecce, fossati, altro)? Ce n'e una che vince sempre?
3. Le carte del level-up ti hanno fatto cambiare modo di giocare, o erano solo numeri?
4. I pezzi sul compagno (torretta, calamita, cassone) si vedono e si capiscono?
5. Ritmo: troppo lento, giusto, troppo frenetico? Dopo quanto sei morto?
6. Il compagno ti aiuta o ti intralcia?
7. Continua / Modifica / Scarta?

Il companion slice (D-032) confluisce qui: le sue domande 1-4 valgono anche in questa scena.
