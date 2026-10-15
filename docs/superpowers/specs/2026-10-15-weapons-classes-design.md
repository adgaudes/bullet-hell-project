# Armi e classi (blocco 3 del playtest, O-05) — design

Data: 15 ottobre 2026. Stato: **approvato a voce dal proprietario sezione per sezione; da rivedere per iscritto prima del piano.**
Contesto: playtest del 14 ottobre (`docs/PLAYTESTS/OWNER_PLAYTEST_2026-10-14.md`, O-05), D-033 (firma: il terreno), D-035 e `PROGRESSION_SPEC.md` (carte, rarita, upgrade visibili nel mondo), D-077 e `ART_DIRECTION.md` (roster fisso di quattro classi), D-089 (mira commutabile), D-091 (blocco di gioco). Decisione: **D-092**.

## 1. Obiettivo e criteri di successo

Il proprietario ha trovato il gioco "piatto e banale": una sola arma automatica, carte quasi tutte percentuali. Alla domanda su cosa mancasse ha indicato **tutto**: varieta da vedere, scelte di build, cose da fare con le mani, legame delle armi col terreno; e ha aggiunto che il gioco resta graficamente scialbo.

Questo blocco introduce **quattro classi giocabili, ciascuna con un kit d'armi e un mazzo di carte propri, piu un kit e un mazzo comuni**: 6 armi automatiche, 6 armi attive su tasto, 6 fusioni, 48 trasformazioni a bivio, casse sepolte, sblocchi in Officina e scelta della classe prima del livello.

Successo = esito **Continua** del proprietario nel prossimo playtest, con queste domande:

1. Due partite con classi diverse sembrano due giochi diversi?
2. Due partite con la stessa classe vanno in modo diverso grazie ai bivi?
3. Le armi attive danno qualcosa da fare con le mani senza togliere spazio allo scavo?
4. Si vede a colpo d'occhio cosa fa ogni arma, e cosa fa al terreno?
5. Trovare una cassa scavando e scoprire una fusione sono momenti che si ricordano?

## 2. Scelte del proprietario (15 ottobre 2026)

| Domanda | Risposta |
|---|---|
| Cosa manca | varieta da vedere, scelte di build, cose da fare, legame col terreno; grafica ancora scialba |
| Controllo | **armi base automatiche** (con la mira commutabile di D-089) **piu 1-2 armi attive su tasto** con ricarica |
| Come si ottengono | **tutte e quattro**: scavando (casse sepolte), carte di level-up, sblocco in Officina, scelta prima del livello |
| Evoluzione | **bivi e fusioni** |
| Munizioni delle attive | **solo ricarica a tempo** (niente terra dello zaino, niente rottami) |
| Ampiezza | **catalogo ampio subito** (approccio B), non una fetta minima |
| Organizzazione | **per classi**: armi e upgrade divisi fra le quattro classi del roster |
| Classi giocabili | **tutte e quattro in questo blocco**, con segnaposto grafico per le tre senza modello |

Il legame col terreno passa quindi dagli **effetti** delle armi (crateri, argini, solchi, dossi, rovi, proiettili che seguono le pendenze o si fermano sugli argini), non dal consumo di terra.

## 3. Regole generali

- **Slot:** 3 automatiche e 2 attive. Si parte col kit della classe (1 automatica e 1 attiva).
- **Livelli:** ogni arma va dal livello 1 al **5**. Ai livelli 2 e 4 migliorano i numeri; ai livelli **3 e 5 si sceglie un bivio** fra due trasformazioni (A o B). I bivi si sommano: al livello 5 un'arma ha due trasformazioni, una del 3 e una del 5.
- **Fusione:** ogni automatica ha un'**attiva compagna**. Quando entrambe sono al livello 5 si fondono in un'arma automatica che **conserva il comportamento dell'automatica con i suoi bivi** e ci aggiunge un effetto proprio. Lo slot attivo si libera.
- **Classi e kit:** una classe trova solo le armi del proprio kit e del kit comune; lo stesso vale per il mazzo di carte.
- **Mira delle attive:** in mira manuale partono verso dove guardi (col mouse: verso il cursore, fino alla portata dell'arma); in mira automatica vanno sul centro del gruppo di nemici piu fitto entro la portata (conteggio su una griglia di 2 m sui nemici di `enemies_near`). Senza nemici in portata: davanti a te, a meta portata.
- **Boss:** i blocchi (cemento, stordimento, radici) sui boss diventano un rallentamento del 50%; attrazione e spinta non li muovono.
- **Terreno toccato dalle armi:** rispetta le zone protette (`is_protected`), non consuma terra dello zaino e passa dalla **coda di scritture** del par. 8.
- **Valori:** tutti i numeri sotto sono **di partenza, non bilanciati**. I nemici di riferimento hanno 2 PV (rottamatore) e 1 PV (rottamatore veloce); la chiodatrice di oggi fa 1 danno ogni 0,5 s. Vivono in `WeaponCatalog` (un solo posto, come `UpgradeCatalog`).

## 4. Catalogo delle armi

### 4.1 Ingegnere (equilibrata, accento arancio)

**Chiodatrice** — automatica, quella di oggi.
- Base: 1 chiodo ogni 0,5 s, 1 danno, portata 9 m. Gli argini fermano i chiodi.
- Liv. 2: cadenza +25%. Liv. 4: +1 nemico trapassato.
- **Bivio 3** — A *Raffica*: cadenza ×2, dispersione di 8°. B *Chiodi da ponte*: trapassano tutto, 2 danni, un colpo ogni 0,7 s.
- **Bivio 5** — A *Rimbalzanti*: un chiodo che colpisce un argine rimbalza una volta. B *Incandescenti*: ogni chiodo lascia a terra una macchia di fuoco (raggio 1 m, 2 s, 1 danno ogni 0,5 s).

**Picchetto sismico** — attiva, ricarica 15 s, portata 6 m.
- Base: dopo 0,6 s si alza un anello di argine (raggio 3 m, alto 1,2 m, spesso 0,8 m) che torna giu dopo 12 s. Chi e dentro resta chiuso, i rottamatori lo rosicchiano come gli altri argini.
- Liv. 2 e 4: ricarica -15%.
- **Bivio 3** — A *Anello largo*: raggio 4,5 m. B *Argine permanente*: non torna giu.
- **Bivio 5** — A *Argine chiodato*: chi lo spinge prende 1 danno ogni 0,6 s. B *Scossa*: all'alzata 3 danni a chi sta sull'anello, scagliato fuori.

**Fusione: Fortino** (Chiodatrice + Picchetto). Ogni 10 s alza entro 5 m un piccolo argine-torretta (cono alto 1,5 m) che per 8 s spara chiodi con i valori e i bivi della chiodatrice al 70%; al massimo due torrette.

### 4.2 Guastatore (scavo esplosivo, accento rosso)

**Lanciarottami** — automatica.
- Base: ogni 1,6 s un rottame a parabola sul gruppo piu fitto entro 12 m; scoppio raggio 1,8 m, 2 danni. **Scavalca gli argini**: si puo sparare da dietro un muro.
- Liv. 2: raggio +0,4 m. Liv. 4: cadenza +25%.
- **Bivio 3** — A *Grappolo*: allo scoppio tre frammenti (1 danno, raggio 1 m) intorno. B *Rottame pesante*: 4 danni e spinta.
- **Bivio 5** — A *Bulloni sparsi*: lascia quattro triboli per 4 s (rallentano del 40%, 1 danno al passaggio). B *Cratere*: lo scoppio scava 0,4 m su raggio 1,5 m.

**Carica da scavo** — attiva, ricarica 8 s, portata 6 m.
- Base: esplode dopo 1 s; 4 danni su raggio 2,5 m; apre un cratere profondo 0,8 m, raggio 2 m (rallenta come ogni scavo).
- Liv. 2: +1 danno. Liv. 4: ricarica -15%.
- **Bivio 3** — A *Grappolo*: tre cariche minori a ventaglio (2 danni, crateri da 0,4 m). B *Pozzo*: cratere da 1,6 m, pareti troppo ripide per risalire: chi ci cade resta dentro finche il fondo non viene spianato o rosicchiato.
- **Bivio 5** — A *Doppia carica*: due usi per ricarica. B *Mina*: resta a terra finche un nemico la calpesta, fino a due piazzate.

**Fusione: Mortaio a crateri** (Lanciarottami + Carica). Ogni rottame apre un cratere da 0,5 m; ogni quarto colpo e una carica da scavo completa.

### 4.3 Meccanico (compagno potenziato, accento turchese)

**Saldatrice** — automatica.
- Base: ogni 1,2 s un arco elettrico al nemico piu vicino entro 6 m, che salta fino a 3 nemici entro 2,5 m l'uno dall'altro, 1 danno ciascuno. **Nei fossati** (delta sotto -0,5 m) il salto arriva a 4 m. Un secondo arco parte dal compagno quando e entro 8 m da te.
- Liv. 2: +1 salto. Liv. 4: cadenza +25%.
- **Bivio 3** — A *Arco doppio*: due archi per colpo. B *Punto di fusione*: 3 danni al primo bersaglio, nessun salto.
- **Bivio 5** — A *Carica statica*: i colpiti restano elettrici 2 s e fanno 1 danno ai nemici che toccano. B *Filo teso*: un filo fra te e il compagno ferisce chi lo attraversa (1 danno ogni 0,5 s).

**Calamita da gru** — attiva, ricarica 14 s, portata 6 m.
- Base: un elettromagnete per 3 s tira i nemici entro 6 m verso il centro (4 m/s) e tutti i frammenti d'esperienza entro 10 m verso di te.
- Liv. 2: raggio +1 m. Liv. 4: durata +1 s.
- **Bivio 3** — A *Schiacciasassi*: alla fine i nemici attratti si scontrano, 3 danni. B *Gru mobile*: la calamita si monta sul compagno e lo segue.
- **Bivio 5** — A *Polarita inversa*: alla fine respinge forte; chi finisce contro un argine prende danno doppio. B *Raccolta*: attira anche i rottami a terra e li porta al compagno.

**Fusione: Bobina di Tesla** (Saldatrice + Calamita). Un campo di 5 m attorno a te e al compagno attira piano (1,5 m/s) e ogni 0,6 s scarica un arco su un nemico dentro.

### 4.4 Erbacciaia (vegetazione come difesa, accento magenta)

**Falce rotante** — automatica.
- Base: 2 falci girano attorno a te a 2,2 m, un giro ogni 1,5 s, 1 danno al contatto (ogni nemico al massimo un colpo ogni 0,5 s). **Sul prato** girano il 30% piu veloci.
- Liv. 2: +1 falce. Liv. 4: raggio +0,5 m.
- **Bivio 3** — A *Falce lunga*: raggio 3,2 m. B *Falce affilata*: 2 danni.
- **Bivio 5** — A *Fienagione*: dove muore un nemico cresce un ciuffo di prato. B *Pale da scavo*: le falci lasciano un anello di terra smossa che rallenta del 30% (solo pittura dello strato e zona di rallentamento, nessuna scrittura di quota).

**Roveto** — attiva, ricarica 12 s, portata 5 m.
- Base: un seme fa crescere in 1 s una siepe di rovi ad arco (6 m) di traverso alla direzione di lancio; dura 15 s, rallenta del 50%, 1 danno ogni 0,8 s a chi la attraversa. I rottamatori la rosicchiano (20 PV).
- Liv. 2: durata +5 s. Liv. 4: ricarica -15%.
- **Bivio 3** — A *Cerchio di rovi*: un anello chiuso di raggio 2,5 m. B *Spine lunghe*: 2 danni.
- **Bivio 5** — A *Radici*: chi entra resta fermo 1,5 s. B *Rovo che avanza*: la siepe cresce di 2 m al secondo verso i nemici per 3 s.

**Fusione: Falciarovi** (Falce + Roveto). Le falci lasciano dietro una scia di rovi che dura 4 s.

### 4.5 Kit comune (tutte le classi; si sblocca in Officina)

**Lama da cantiere** — automatica.
- Base: ogni 2,5 s lancia un disco che rotola a terra per 10 m a 8 m/s, 2 danni, attraversa tutti. **Segue il terreno**: in discesa accelera, e se entra in un fossato (delta sotto -0,5 m) gira lungo il fondo per 3 s.
- Liv. 2: +1 danno. Liv. 4: cadenza +25%.
- **Bivio 3** — A *Due lame*: due dischi a 30°. B *Lama dentata*: raggio ×1,6, velocita -30%.
- **Bivio 5** — A *Rimbalzo*: rimbalza sugli argini fino a tre volte. B *Solco*: dove passa scava un solco (0,25 m, largo 0,6 m).

**Martello pneumatico** — automatica.
- Base: ogni 2 s un'onda attorno a te (raggio 3 m), 1 danno, spinta a 6 m/s. **Chi viene spinto contro un argine** (parete oltre la pendenza percorribile entro 1 m) prende danno doppio.
- Liv. 2: raggio +0,5 m. Liv. 4: +1 danno.
- **Bivio 3** — A *Onda larga*: raggio 5 m. B *Stordente*: ferma i colpiti 0,8 s.
- **Bivio 5** — A *Crepe*: ogni onda apre tre crateri (0,3 m, raggio 1 m) attorno a te. B *Eco nei fossati*: l'onda corre lungo i tratti bassi collegati fino a 8 m.

**Ariete** — attiva, ricarica 10 s.
- Base: scatto di 8 m in 0,5 s, intoccabile; 3 danni e spinta a chi tocchi; **spiana** il terreno lungo il percorso (verso la base, raggio 1,2 m).
- Liv. 2: +1 danno. Liv. 4: ricarica -15%.
- **Bivio 3** — A *Rincorsa*: 12 m. B *Scudo*: 1,5 s di intoccabilita all'arrivo.
- **Bivio 5** — A *Trincea*: invece di spianare scava un fossato da 0,6 m lungo il percorso. B *Botto*: all'arrivo un'onda di raggio 3 m, 3 danni.

**Betoniera** — attiva, ricarica 12 s, portata 6 m.
- Base: una pozza di cemento (raggio 2,5 m); chi e dentro resta fermo 3 s; poi indurisce in un **dosso** di 0,4 m, dipinto a lastricato.
- Liv. 2: raggio +0,5 m. Liv. 4: blocco +1 s.
- **Bivio 3** — A *Doppia colata*: due pozze affiancate. B *Muro di getto*: il dosso sale a 1,2 m, un argine.
- **Bivio 5** — A *Presa rapida*: 3 danni ai bloccati quando indurisce. B *Pavimento*: invece del dosso spiana alla base (una piazzola liscia: aiuta l'estrazione di D-076).

**Fusione: Ruspa a dischi** (Lama + Ariete). Dischi di raggio doppio che spianano dove passano; ogni 10 s un disco enorme parte dritto per 20 m.

**Fusione: Costipatore** (Martello + Betoniera). Ogni onda blocca i colpiti per 0,6 s; ogni terza onda lascia un anello di cemento basso (0,3 m).

## 5. Carte non legate alle armi: mazzi per classe

Le carte di `UpgradeCatalog` ricevono il campo `deck` (`&"common"`, `&"engineer"`, `&"sapper"`, `&"mechanic"`, `&"weeder"`). Le carte `nail_rate`, `nail_pierce`, `nail_spread` **escono dal catalogo**: diventano i livelli e i bivi della chiodatrice.

| Mazzo | Carte esistenti | Carte nuove |
|---|---|---|
| Comune | Scarponi slacciati, Toppa, Tasche larghe, Torcia, Calamita (compagno), Cassone rinforzato; riempitivi Rattoppo al volo, Rottame di fortuna, Barattolo di chiodi | — |
| Ingegnere | Pala larga, Argini spinati | *Argini rinforzati* (Non comune, 2 liv.): i tuoi argini si rosicchiano il 30% piu piano per livello. *Getto rapido* (Comune, 2 liv.): alzare costa il 20% di terra in meno per livello |
| Guastatore | Scavo esplosivo | *Miccia corta* (Comune, 3 liv.): ricarica delle attive -10% per livello. *Reazione a catena* (Raro, 1 liv.): un nemico ucciso dentro un cratere esplode (1 danno, raggio 1,5 m) |
| Meccanico | Torretta sul cassone, Faro | *Motore truccato* (Non comune, 2 liv.): compagno +20% velocita, travolge (1 danno). *Saldatura al volo* (Raro, 1 liv.): se il compagno ti e vicino ti ridà 1 PV ogni 45 s |
| Erbacciaia | — | *Erba alta* (Comune, 2 liv.): sul prato i nemici rallentano del 20% per livello. *Cespuglio medicinale* (Non comune, 2 liv.): ogni 60 s un cespuglio vicino ti ridà 1 PV (40 s al liv. 2). *Semi in tasca* (Comune, 1 liv.): gli argini che alzi si coprono di prato |

L'Erbacciaia parte con **Erba alta al livello 1** per avere un mazzo di partenza pari alle altre classi.

## 6. Come si ottengono le armi

### 6.1 Prima del livello: la classe

Nella mappa della campagna, prima di entrare in un livello, si sceglie la classe fra quattro carte (nome, colore, ritratto, kit, una riga sul ruolo). Tutte e quattro sono disponibili da subito. Si ricorda l'ultima scelta (default: Ingegnere).

### 6.2 Officina

- **Sezioni:** Comune, Ingegnere, Guastatore, Meccanico, Erbacciaia, Ricettario.
- **Comune:** gli upgrade di oggi della sezione "Ingegnere" diventano comuni (Prolunga, Zainetto largo, Telaio rinforzato, Riflessi da officina; gli `id` restano uguali, i salvataggi non cambiano), con Cassone saldato, Scorta e Paracadute per rottami. In piu lo **sblocco delle quattro armi comuni**: Lama 15, Martello 15, Ariete 20, Betoniera 20 rottami. Finche non e sbloccata, un'arma comune non compare ne nelle casse ne nelle carte.
- **Per classe**, due upgrade ciascuna:
  - Ingegnere: *Cassetta degli attrezzi* (8/16: al livello 1 la chiodatrice parte al livello 2, al livello 2 anche il picchetto); *Picchetti di scorta* (10: ricarica del picchetto -10%).
  - Guastatore: *Polvere asciutta* (8/16: carica da scavo +1 danno per livello); *Zaino di cariche* (12: parte con Scavo esplosivo al livello 1).
  - Meccanico: *Torretta fissa* (30, spostata dalla sezione Compagno); *Olio buono* (8: compagno +15% velocita).
  - Erbacciaia: *Semi buoni* (8/16: il roveto dura +3 s per livello); *Pollice verde* (12: Erba alta parte al livello 2).
- **Ricettario:** le sei fusioni. Quelle non ancora fatte compaiono in sagoma con l'indizio "Chiodatrice + ?"; si scoprono la prima volta che le si fa.
- Tutti i costi sono provvisori.

### 6.3 Durante la partita

- **Level-up:** tre carte, regole 1-5 di `PROGRESSION_SPEC.md`. La regola delle categorie diventa: di norma **una carta arma, una dal mazzo della classe, una libera** (mazzo comune, mazzo della classe o arma).
- **Casse sepolte:** 3-4 per livello, nascoste in cumuli e rovine come le vene dei rottami (`ScrapField`). Da 3 m un luccichio a terra le rivela. Scavando sotto la base dove sta una cassa, la cassa emerge e si apre una scelta fra **3 carte, solo arma**. Il gioco si mette in pausa come al level-up.
- **Carte arma:**

| Carta | Quando compare | Rarita |
|---|---|---|
| Arma nuova | c'e uno slot libero del suo tipo | Non comune |
| Livello 2 o 4 | arma posseduta sotto il livello 5 | Comune |
| Bivio (livello 3 o 5) | arma posseduta al livello 2 o 4; sceglierla apre una seconda schermata con le due trasformazioni, che non si puo annullare | Raro |
| Fusione | sicuramente nella prima offerta dopo che una coppia e arrivata al livello 5 | Leggendario |

- A slot pieni compaiono solo carte per le armi possedute (regola 2 di `PROGRESSION_SPEC`). Se nessuna carta arma e possibile, il posto va al mazzo della classe.
- Le carte arma pesano con la sinergia (regola 5): l'attiva compagna di un'automatica posseduta pesa il doppio.

### 6.4 Fine partita

Le armi si perdono. Restano gli sblocchi dell'Officina, il ricettario e l'ultima classe scelta.

## 7. Interfaccia

- **HUD:** una striscia in basso a sinistra con i 3 slot automatici (icona, cinque tacche di livello, lettera del bivio preso) e i 2 attivi (icona, ricarica a spicchio, tasto: LT/RB oppure E/F, con `ButtonPrompts`). Si legge senza coprire la terra e la barra dell'esperienza. Posizione definitiva nelle catture.
- **Schermata delle carte:** si riusa `LevelUpMenu` per il level-up, per la cassa (titolo "Cassa sepolta"), per il bivio (due carte, titolo con il nome dell'arma) e per la fusione (carta leggendaria con le due icone che si uniscono). Le carte arma mostrano tipo (automatica o attiva), livello attuale e prossimo, e l'effetto sul terreno con un'icona.
- **Campagna:** pannello di scelta della classe prima del livello (quattro carte, colore di classe sul bordo).
- **Officina:** schede per sezione (come le Impostazioni a schede di D-091), con le carte di oggi.
- **Icone:** 12 armi e 6 fusioni come icone a poligoni (`UiIcon`, D-081). Le trasformazioni non hanno icona propria: la lettera A o B sulla tacca.
- **Comandi:** azioni nuove `weapon_active_1` (E; grilletto sinistro LT) e `weapon_active_2` (F; dorsale destro RB). Compaiono in Impostazioni > Controlli e nella riga dei comandi del HUD. Liberi oggi su entrambi i dispositivi; Steam Deck ha gli stessi tasti.
- **Effetti:** ogni arma ha un effetto leggibile da 15 m di camera: chiodi luminosi (oggi), rottami in parabola con scia, dischi che rotolano e lasciano polvere, anello d'onda a terra, archi elettrici spezzati, falci con scia, anelli di argine che salgono con polvere, crateri con detriti, cemento grigio che si opacizza, rovi a cespuglio (mesh dei cespugli di oggi in MultiMesh). Ogni attiva ha un telegrafo a terra durante la mira (cerchio o linea del colore della classe).
- **Suoni:** una ricetta per arma in `tools/audio/build_sfx.py` dal bundle Sonniss (D-084).

## 8. Codice

| Unita | File | Responsabilita |
|---|---|---|
| `WeaponCatalog` | `scripts/combat/weapon_catalog.gd` | dati di ogni arma e fusione: `id`, `deck`, `slot` (`&"auto"` / `&"active"`), valori per livello, bivi (testi e valori), `partner`, `fusion`, costo di sblocco. Testi con `{chiave}` come `UpgradeCatalog.describe` |
| `ClassCatalog` | `scripts/progression/class_catalog.gd` | le quattro classi: `id` (`engineer`, `sapper`, `mechanic`, `weeder`), nome, colore, armi iniziali, carte iniziali, riga di descrizione |
| `Weapon` | `scripts/combat/weapon.gd` | base delle automatiche: `shooter`, `director`, `terrain`, `level`, `branches` (Dictionary livello -> `&"a"`/`&"b"`), `stat(key)` che legge il catalogo con livello e bivi, `apply_level()` |
| `ActiveWeapon` | `scripts/combat/active_weapon.gd` | base delle attive: ricarica, `can_trigger()`, `trigger(aim_point)`, `aim_point()` secondo la mira (par. 3), telegrafo |
| Armi | `scripts/combat/weapons/<id>.gd` | una per arma e per fusione; la chiodatrice e `AutoWeapon` rifatta su `Weapon` (resta il nome di classe `AutoWeapon` finche il compagno la usa) |
| `WeaponLoadout` | `scripts/combat/weapon_loadout.gd` | sul giocatore: slot, `add(id)`, `level_up(id)`, `choose_branch(id, branch)`, `fuse(id)`, input delle attive, segnali `changed` e `cooldown_changed` per il HUD |
| `WeaponOffers` | `scripts/progression/weapon_offers.gd` | costruisce le carte arma dallo stato del loadout, dagli sblocchi e dalla classe; usata da `RunProgression` e dalle casse |
| `TerrainWriteQueue` | `scripts/terrain/terrain_write_queue.gd` | coda delle scritture delle armi sul terreno: al massimo una scrittura per passo fisico, raggio massimo 2,5 m, dentro `begin_batch`/`end_batch` |
| `BuriedCaches` | `scripts/run/buried_caches.gd` | casse sepolte sul modello delle vene di `ScrapField`: posa, luccichio, uscita allo scavo, segnale `cache_opened` |

Modifiche ai file esistenti:

- `arena_run.gd` (1187 righe) **cede le armi a `WeaponLoadout`**: `apply_upgrade` perde i rami `nail_*`, la creazione delle armi passa dal loadout, e il codice nuovo non entra in `arena_run.gd`.
- `UpgradeCatalog`: campo `deck`; via le tre carte `nail_*`; carte nuove del par. 5.
- `RunProgression`: filtra per classe; regola delle categorie del par. 6.3; carte arma da `WeaponOffers`.
- `PermanentCatalog`: gruppi `common`, `engineer`, `sapper`, `mechanic`, `weeder`; sblocchi delle armi comuni; upgrade nuovi del par. 6.2.
- `PlayerProfileService`: `VERSION` 2; sezioni `[weapons]` (sbloccate), `[recipes]` (fusioni scoperte), chiave `last_class`. Un profilo versione 1 si carica con i valori di default; le chiavi sconosciute restano conservate come oggi.
- Campagna e `RunLaunchOptions`: la classe scelta arriva alla run (`--class=<id>` da riga di comando per test e catture).
- Giocatore: colore di classe sul modello. Le tre classi senza modello usano l'Ingegnere con la tuta tinta del colore di classe (emissione o tinta del materiale, come gli stati di colore di D-088).
- Bot del simulatore (D-055): ricevono la classe e usano le attive appena cariche sul gruppo piu fitto.

## 9. Prestazioni

- **Budget:** tutte le armi insieme, nel caso peggiore (3 automatiche e 2 attive al livello 5, 70 nemici), costano **al massimo 1,0 ms per passo** in piu rispetto a oggi, misurati col benchmark su preset Deck sul PC di sviluppo.
- Proiettili e falci in pool o `MultiMesh`, niente nodi creati a ogni colpo (la chiodatrice di oggi crea un `MeshInstance3D` per chiodo: da portare al pool).
- Ricerca dei nemici sempre con `EnemyDirector.enemies_near`; niente scorrimento di tutti i nemici per arma e per passo.
- Scritture sul terreno solo dalla `TerrainWriteQueue`; collisione aggiornata a chunk come oggi.
- La misura sul Steam Deck vero resta del proprietario (con il Debug Menu, F3).

## 10. Verifica

- **Suite nuove:**
  - `weapons_tests.gd`: ogni arma fa danno; ogni effetto sul terreno cambia la quota dove deve; **ogni bivio cambia davvero il comportamento** (confronto A, B e base sugli stessi nemici); ogni fusione si forma, libera lo slot e conserva i bivi.
  - `loadout_tests.gd`: slot, livelli, bivi non annullabili, fusione solo con la coppia al 5, input delle attive, ricarica.
  - `weapon_offers_tests.gd`: carte per stato, classe, sblocchi, slot pieni, fusione garantita, sinergia.
  - `classes_tests.gd`: kit e mazzi per classe, nessuna carta di un'altra classe in 500 offerte con seme fisso.
  - `profile_v2_tests.gd`: un profilo versione 1 si carica, mantiene rottami e livelli, ottiene i default nuovi; salvataggio e ricarica della versione 2.
- **Suite esistenti** tutte verdi nel gate (`Invoke-GodotChecks.ps1`), aggiornate dove le carte `nail_*` spariscono.
- **Benchmark** col caso peggiore del par. 9.
- **Simulazioni dei bot:** dieci partite per classe con seme fisso; nessuna classe vince o perde in modo anomalo rispetto alle altre (scarto da annotare, non da chiudere in questo blocco).
- **Catture** in `output/weapons/`: ogni arma alla base e con ciascun bivio, ogni fusione, la cassa che emerge, i pannelli di classe e dell'Officina, il HUD con cinque armi.

## 11. Ordine di lavoro

Tutto nello stesso blocco, **un playtest alla fine**. Il piano di implementazione dettaglia i task.

1. Impianto: `WeaponCatalog`, `ClassCatalog`, `Weapon`, `ActiveWeapon`, `WeaponLoadout`, `WeaponOffers`, `TerrainWriteQueue`, input, striscia del HUD; chiodatrice rifatta sulla base nuova con i suoi bivi; carte `nail_*` tolte. Gate verde prima di proseguire.
2. Kit comune (Lama, Martello, Ariete, Betoniera) e fusioni comuni.
3. Le quattro classi, una alla volta: armi, fusione, mazzo, segnaposto grafico. Si possono dare a Codex in parallelo, una per worktree e branch.
4. Casse sepolte, Officina a sezioni, ricettario, scelta della classe, profilo versione 2.
5. Suoni ed effetti di rifinitura.
6. Bilanciamento di prima mano con i bot, benchmark, catture, documenti.

## 12. Fuori da questo blocco

- Modelli veri di Guastatore, Meccanico ed Erbacciaia (pipeline di D-088, un piano per personaggio).
- Rarita leggendaria con costo (regola 1 di `PROGRESSION_SPEC`) per le carte non arma.
- Bilanciamento fine: dopo il playtest.
- La resa grafica generale che il proprietario trova ancora scialba: va giudicata sulla build con il blocco grafica del 14 ottobre (D-090), prima di aprire un altro giro.

## 13. Rischi

- **Quantita di contenuto:** 12 armi, 6 fusioni e 48 trasformazioni sono molto lavoro di effetti, test e bilanciamento; e il motivo per cui l'impianto viene prima e da solo.
- **Terreno scritto dalle armi:** crateri, argini, solchi e dossi possono rompere i percorsi dell'orda o costare troppo sul Deck. La coda di scritture e il budget del par. 9 servono a questo; il Pozzo e l'Argine permanente vanno guardati nel playtest perche possono chiudere l'orda.
- **Economia della terra:** gli argini delle armi non costano terra. Se nel playtest rendono inutile lo zaino si mette un limite (per esempio argini delle armi che tornano sempre giu).
- **Segnaposto:** tre classi con l'Ingegnere tinto si distinguono solo dal colore; la loro identita nel playtest la portano le armi.
- **Gate intermittente** (`run_progression_tests`, uscita oltre 300 s una volta su quattro): con piu suite il rischio cresce; da tenere d'occhio.
