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
- **Compagno e rottami** come nel Companion Slice: scavare produce rottami, rialzare costa un rottame e richiede il compagno vicino. Il compagno usa lo stesso campo di percorso e non resta chiuso fuori dalle mura.
- **Senza sfera hazard** (scelta del proprietario): un solo tipo di pericolo per misurare nemici e terreno.

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
| Pezzo compagno | Torretta sul cassone, Calamita, Cassone rinforzato | pezzo visibile sul compagno; spara, attira frammenti, porta piu rottami |
| Tool terreno | Scavo esplosivo, Terrapieni spinati | onda d'urto allo scavo; le mura cambiano colore e feriscono chi le spinge |
| Personaggio | Scarponi slacciati, Toppa, Tasche larghe | riempitivi comuni |

Rinviati come da specifica: sinergia (regola 5), leggendari, limite di slot per armi aggiuntive (nel prototipo c'e una sola arma).

## Valori

Tutti in `godot/resources/tuning/run_default.tres` (`RunTuning`): vita 5, nemici a 2,2 m/s con 2 punti vita (+1 ogni 150 s), intervallo di comparsa da 1,6 s a 0,3 s in 5 minuti, massimo 70 vivi; chiodatrice ogni 0,5 s, portata 9 m; esperienza 5 per il primo livello, +3 a ogni livello.

## Scala: l'arena definitiva sara molto piu grande

Indicazione del proprietario (5 ottobre 2026): l'arena del gioco finale sara **molto, molto piu grande** di quella attuale (48x48 m). Questo prototipo misura il loop in uno spazio piccolo; non fissa la scala. Conseguenze tecniche da affrontare quando si allarga:

- `PathField` ricalcola tutto il campo (1.600 celle) quando il giocatore cambia cella: su un'arena dieci volte piu lunga sono 100 volte le celle. Servira un campo locale attorno al giocatore, celle piu grandi lontano, o `NavigationServer3D`.
- La comparsa dai bordi dell'arena non regge: i nemici dovranno nascere in un anello attorno al giocatore, fuori dallo schermo.
- La griglia terreno 11x11 al centro dovra diventare una griglia estesa o piu griglie, con costo di celle e collisioni da misurare (Steam Deck).
- Il cortile con le mura diventa un punto di interesse fra tanti, non l'intera arena.

## Fuori scope

Estrazione e fine della run a tempo, altri tipi di nemico, audio, effetti di colpo oltre al lampo, bilanciamento fine, prestazioni su Steam Deck (da misurare), menu iniziale.

## Marker diagnostici

`PROTOTYPE01_RUN_START seed=N`, `PROTOTYPE01_PATH_FIELD_READY`, `PROTOTYPE01_ENEMY_KILLED total=N`, `PROTOTYPE01_PLAYER_DAMAGED health=N`, `PROTOTYPE01_LEVEL_UP level=N offer=a,b,c`, `PROTOTYPE01_UPGRADE_CHOSEN id=.. level=N`, `PROTOTYPE01_DIG_BLAST`, `PROTOTYPE01_COMPANION_TURRET level=N`, `PROTOTYPE01_PLAYER_DIED time=.. level=.. kills=.. seed=N`.

Per ripetere una run: `-- --seed=N` sulla riga di comando.

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
