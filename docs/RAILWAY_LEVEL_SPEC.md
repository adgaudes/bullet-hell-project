# Livello 2: la ferrovia — specifica

**Stato:** **implementata il 9 ottobre 2026** (D-066, D-067) cosi come scritta, con una differenza: la Trivella devia dalle rovine seguendo il campo di percorso quando la linea diretta e chiusa (sezione 5). Il proprietario non ha ancora giocato ne il livello 1 ne questo: tutto cio che segue si ritocca dopo il playtest. Valori **non bilanciati**. Per giocarlo: dal menu, Gioca, mappa di campagna (sbloccato dopo una vittoria nel quartiere), oppure `godot --path godot -- --level=railway`; `--boss-at=60` anticipa la Trivella. Catture in `output/railway/` e `output/campaign/`.

## 1. In una frase

Un corridoio ferroviario stretto e lungo (122 x 319 m) dove ogni due minuti e mezzo passa un treno che spiana la fascia dei binari, con un boss, la **Trivella**, che carica in linea retta scavando solchi e che si ferma solo contro un terrapieno.

## 2. Arena: `RailwayDistrict` (`scripts/arena/railway_district.gd`)

Estende `RuinsDistrict`: stessi mattoni (rovine basse, oggetti, perimetro, cortili, depositi, trincee), pianta **rettangolare** (`play_half_extents` = 61,2 x 159,6 m, griglia 51 x 133 celle di 2,4 m, `terrain_railway.tres`). L'asse lungo e X (est-ovest); la camera guarda da sud come nel livello 1.

- **Binari**: fascia di tre righe di celle attorno a z = 0 (righe -1, 0, +1 in assi Unreal), per tutta la lunghezza. Due binari (z = -2,4 e +2,4) con rotaie e traversine come mesh senza collisione; la fascia e **riservata**: niente rovine ne oggetti, le celle restano Normal.
- **Cortile di partenza** all'origine, a cavallo dei binari: i varchi est e ovest coincidono con la fascia. Il treno passa dai varchi, non tocca le mura nord e sud.
- **Depositi di rottami sui binari** (vagoni merci abbandonati, 2x2 o 2x3 celle Raised): ricchi e vicini, ma il treno li spazza via senza lasciare rottami. Chi li vuole deve scavarli prima del treno.
- **Scali e magazzini**: cortili secondari e depositi normali a nord e a sud della fascia; trincee parallele ai binari (canali di scolo).
- **Perimetro**: torri a nord, bordo basso a sud; alle due estremita est e ovest un portale di galleria da cui il treno entra ed esce.
- **Seme fisso** come il livello 1 (D-065).

## 3. Evento: il treno (`TrainEvent`, `scripts/run/train_event.gd`)

- **Ritmo**: primo passaggio a 90 s, poi ogni 150 s (`train_interval_seconds`), finche il boss non e sconfitto. Direzione alternata (da est, da ovest), binario scelto a caso.
- **Preavviso**: 10 s prima compare "TRENO DA EST" con freccia a bordo schermo e suona il fischio; a 3 s un secondo fischio.
- **Passaggio**: locomotiva piu 5 vagoni (circa 60 m), 18 m/s, attraversa tutta l'arena in circa 18 s. Mentre avanza:
  - ogni cella della **fascia** (tre righe) sotto il muso torna **Normal**: terrapieni, barricate, depositi sui binari spariscono senza rottami; trincee riempite;
  - i **rottamatori** nella fascia vengono travolti: contano come uccisi dal giocatore (esperienza), cosi attirarli sui binari e una tattica;
  - il **giocatore** nella fascia subisce 2 danni e viene spinto fuori; il **compagno** viene spinto fuori senza danni;
  - i **lampioni** nella fascia cadono; i rottami a terra nella fascia spariscono.
- **Boss**: la Trivella nella fascia subisce 30 danni e viene spinta fuori (il treno e anche un'arma contro il boss: attirarla sui binari e la soluzione piu redditizia e piu rischiosa).
- Marker: `PROTOTYPE01_TRAIN_WARNING`, `PROTOTYPE01_TRAIN_PASS`, `PROTOTYPE01_TRAIN_HIT`.

## 4. Nemico nuovo: il saltatore

Rottamatore verde, piu leggero (vita x0,5), stessa velocita dell'orda, che **non viene rallentato dalle celle Lowered** (le salta). Compare dal minuto 2 con quota crescente fino al 25 % delle nascite. Toglie valore ai fossati, che la Trivella regala in abbondanza: il giocatore deve usare anche i muri, che la Trivella consuma. Si implementa come variante nel direttore (`EnemyKind`), senza sottoclassi: colore, `speed_scale`, `health_share`, `ignores_lowered`.

## 5. Boss: la Trivella (`scripts/enemies/driller.gd`)

Regola col terreno, leggibile al primo incontro: **carica in linea retta e scava un solco; un terrapieno la ferma**.

- **Carica**: mira al giocatore, telegraph di 2 s (la punta accelera, striscia a terra fino al bersaglio), poi avanza a 6 m/s per al massimo 30 m ignorando il campo di percorso. Ogni cella sotto la punta diventa **Lowered** (solco). Il giocatore colpito subisce 2 danni e viene spinto di lato.
- **Terrapieno sul percorso**: la carica finisce, la cella viene smontata (Normal) e lascia un rottame, la Trivella resta **stordita 3 s** con la punta scoperta: in quel tempo subisce danno doppio. E l'unico modo per fermarla prima dei 30 m.
- **Riposo**: dopo ogni carica si ferma 3 s (si gira lentamente verso il giocatore), poi ricomincia.
- **Fossati**: non la rallentano (scava). Barricate: non ne costruisce. Lampioni: li abbatte a contatto.
- **Soluzioni che il campo offre**: un muro a sacrificio la stordisce dove la chiodatrice la colpisce (costa un rottame, ne rende uno); i suoi solchi sono fossati gratis contro l'orda, ma rallentano anche te e il compagno; attirarla sui binari prima del treno.
- Valori iniziali: 180 punti vita, contatto 2, carica 6 m/s, 30 m, stordimento 3 s, riposo 3 s. Chiamata a 12 minuti, come il Demolitore.

## 6. Campagna: catalogo, mappa, sblocco

- `LevelCatalog` (`scripts/run/level_catalog.gd`): elenco ordinato dei livelli (`id`, titolo, scena, boss). Oggi: `district` (Quartiere in rovina), `railway` (Ferrovia). Il terzo (Cantiere, Gru) e nel catalogo come "in costruzione", non giocabile.
- `ArenaRun.level_id` dice quale livello e; una vittoria sblocca il successivo nel profilo (`levels_unlocked`).
- **Mappa di campagna** (`CampaignMapPanel`): dal menu iniziale "Gioca" apre la mappa con i livelli in fila; si sceglie fra quelli sbloccati, A conferma, B torna. Dalla schermata di fine livello, in caso di vittoria, il pulsante **Prossimo livello**.
- Riga di comando: `--level=railway` avvia subito quel livello (fa saltare il menu come `--autostart`).

## 7. Verifica

Suite nuove: `railway_tests.gd` (pianta rettangolare, fascia libera, depositi sui binari, cortile a cavallo), `train_tests.gd` (preavviso, celle spianate, nemici travolti, giocatore spinto, lampioni), `driller_tests.gd` (carica dritta, solco, muro che ferma e stordisce, danno doppio, riposo, sconfitta che chiude il livello), `campaign_tests.gd` (catalogo, sblocco, mappa, prossimo livello, `--level=`). Catture: `capture_railway.gd` (panoramica, treno in arrivo, Trivella in carica). Simulazioni: `simulate_runs.gd -- --level=railway`.

## 8. Prime simulazioni (9 ottobre 2026, bot di D-055, semi 1-3, `--level=railway`)

| Bot | Esito | Fine run (s) | Rottami fuori | Note |
|---|---|---|---|---|
| passive (fermo nel cortile) | 3 morti | 24-36 | 1 | nel quartiere resisteva molto di piu: qui i varchi est e ovest sono larghi tre celle (la fascia dei binari) e l'orda entra subito |
| novice | 1 vittoria, 2 morti | 473-1118 | 2-18 | una morte prima della Trivella, una durante |
| kiter | 2 vittorie, 1 morte | 778-912 | 7-32 | Trivella battuta in 60-190 s dall'arrivo, con 3-4 punti vita |
| scrapper | 3 vittorie | 798-882 | 14-16 | Trivella battuta in 80-160 s, mai sotto 5 punti vita; 6-9 lampioni piazzati (il treno ne abbatte) |

Letture: (1) la **Trivella e debole**: cade in uno o tre minuti senza che i bot usino muri per stordirla (non sanno farlo), quindi per un giocatore che li usa sara ancora piu rapida: alzare vita o ridurre la finestra di stordimento dopo il playtest; (2) il **cortile di partenza aperto sui binari** cambia l'inizio del livello: chi resta fermo muore in mezzo minuto; e voluto (il livello 2 non e un tutorial) ma va visto a mano; (3) i rottami portati fuori sono simili al quartiere per kiter e scrapper (D-055: 1-3 run per upgrade). Il treno non ha mai ucciso un bot (si muovono fuori dalla fascia); quante volte abbia travolto l'orda non e nei marker di riepilogo. Simulazioni fatte con la build di questa sera, 4 processi in parallelo, circa 6 minuti.
