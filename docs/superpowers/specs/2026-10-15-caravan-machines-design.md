# Carovana di macchine e fusione — design (bozza in corso)

Data: 15 ottobre 2026. Stato: **in progettazione col proprietario: Sezioni 1-6 approvate, 7 da presentare. Niente implementazione finche il design non e approvato per sezioni e la spec scritta non e rivista.**
Decisione: **D-093** (in progettazione). Contesto: D-011 (costruire, fondere, pilotare macchine), D-012 (primo compagno autonomo), D-033 (promessa A; la carovana come struttura, la macchina sempre piu assurda come payoff), D-035 (la build si vede nel mondo), roadmap sezione 2 ("carovana di macchine... agganciarsi e separarsi; fusione in configurazioni crescenti e forma colossale"), D-092 (armi e classi: casse, carte, Officina, ricettario gia esistono).

## Perche

Il proprietario (15 ottobre): "e una meccanica fondamentale del gameplay, che lo fa distinguere da tanti altri". Oggi esiste un solo compagno autonomo (raccoglie e fornisce rottami) con pezzi montabili (Torretta, Calamita, Cassone, Faro); niente seconda macchina, aggancio, fusione o pilotaggio.

## Scelte del proprietario (15 ottobre 2026)

| Domanda | Risposta |
|---|---|
| Momento che rende il gioco diverso | **Entrambi, in sequenza**: la carovana che cresce durante la run, poi la scelta strategica fra tante macchine piccole separate e poche grandi fuse, col colosso come culmine |
| Come si ottiene una macchina | **Relitti sepolti** (si scavano, come le casse), **carte del level-up**, **sblocco in Officina** |
| Regola della fusione | **Moduli che si sommano liberamente**, piu **bonus di combinazione** da scoprire nel ricettario |
| Agganciare e sganciare | **Entrambi costano rottami**; solo su una **piazzola fissa che arriva a meta livello**; **gli eventi (terremoto, treno) possono staccare moduli** |
| Colosso | **Si puo sia pilotare sia lasciare autonomo**, ognuna con pro e contro (da definire) |
| Danni | Le macchine **si guastano e si riparano coi rottami** (non si distruggono) |
| Approccio | **Approccio 1, macchine a moduli** (telaio + modulo; fusione = una macchina con piu moduli) |
| Protezione della carovana | **Grappolo attorno al giocatore** (2-4 m, dentro la portata delle armi), **fuse piu robuste**, **ritirata automatica** sotto il 30% di vita, e (aggiunta del proprietario) **rigenerazione lenta della vita dopo un periodo senza danni**. Scartate per ora: "bersaglio solo se isolate", comando di richiamo. I rottamatori inseguono il giocatore come oggi e feriscono le macchine che toccano |

## Approcci valutati

1. **Macchine a moduli (scelto).** Ogni macchina e un telaio con un modulo; separate lavorano ognuna per conto suo; fuse sulla piazzola diventano una macchina con piu moduli, piu forte per taglia e coi bonus di combinazione. Il compagno di oggi diventa la prima macchina (modulo Cassone); i pezzi di oggi diventano moduli.
2. Tipi fissi che salgono di livello fondendosi: piu facile da bilanciare, ma perde la somma libera.
3. Una sola macchina che cresce: la piu economica, ma perde la carovana.

## Sezione 1 — macchine e moduli (APPROVATA dal proprietario il 15 ottobre 2026)

- **Macchina = telaio + moduli.** Telaio con vita (6 PV) e un modulo. Al massimo **6 moduli in tutta la carovana** (sei piccole separate, o qualunque fusione fino a una sola da 6).
- **Otto moduli:** Cassone (raccoglie e fornisce rottami: il compagno di oggi), Torretta (chiodatrice), Calamita (frammenti d'esperienza), Faro (luce di notte), Trivella (scava buche attorno al grappolo; su una vena estrae rottami), Pala (alza un piccolo argine davanti al nemico piu vicino coi rottami del Cassone), Saldatore (ripara le altre macchine, 1 PV ogni 3 s), Sirena (attira i rottamatori vicini su di se).
- **Taglie della macchina fusa:** 1 modulo piccola, 2-3 media, 4-5 grande, 6 colosso. Ogni modulo oltre il primo rende gli altri del 15% piu forti; vita = somma dei telai + 25% per taglia sopra la piccola; velocita -10% per taglia; da media in su travolge i rottamatori piccoli (1 danno al contatto quando si muove).
- **Sei combinazioni di partenza** (bonus quando i due moduli stanno nella stessa macchina): Estrattore (Trivella + Calamita: le buche risucchiano i rottami vicini nel Cassone), Riflettore (Torretta + Faro: i nemici illuminati prendono doppio danno dalla Torretta), Betoniera mobile (Pala + Cassone: argini della Pala gratis), Esca blindata (Saldatore + Sirena: mentre attira subisce meta danno), Ruspa (Trivella + Pala: fossato con argine a lato dove passa), Trappola (Torretta + Sirena: chi e attirato prende doppio danno dalla Torretta).
- Valori di partenza, non bilanciati.

## Sezione 2 — piazzola di fusione (APPROVATA dal proprietario il 15 ottobre 2026, opzione A: gioco in pausa)

- **Arrivo:** a meta della chiamata del boss (oggi 6:00 su 12:00), annunciata 15 s prima con scritta, freccia e conto alla rovescia come il boss. Atterra su un tratto piano a 20-30 m dal giocatore: pedana 4x4 celle con gru e faro, visibile di notte da lontano.
- **Durata:** resta ferma fino alla chiamata del boss, poi si richiude; il boss si affronta con la carovana che si ha. Prima dell'arrivo la carovana cresce solo con macchine piccole separate; dopo, la scelta strategica.
- **Uso:** giocatore sulla pedana, col grappolo al seguito, tasto azione: si apre il **banco di fusione** e **il gioco va in pausa** come al level-up (il rischio sta nell'arrivarci con l'orda addosso).
  - **Fondere:** scegliere una macchina, poi una seconda; anteprima di taglia, PV, velocita e combinazioni (quelle mai scoperte come "???"; alla prima scoperta entrano nel ricettario).
  - **Sganciare:** scegliere una macchina e un modulo; il modulo diventa una macchina piccola con telaio nuovo.
  - **Costi:** fondere 1 rottame per modulo della macchina assorbita; sganciare 1 rottame per modulo. Sei macchine in un colosso costano 5 rottami (un Cassone pieno). Si paga dai Cassoni della carovana.
- Le macchine ottenute dopo l'arrivo (relitti, carte) arrivano piccole; si torna alla piazzola quante volte si vuole fino al boss.

## Sezione 3 — colosso pilotato o autonomo (APPROVATA dal proprietario il 15 ottobre 2026)

- **Salire e scendere:** vicino al colosso, tasto azione tenuto circa 0,5 s; lo stesso per scendere. **Solo il colosso** (6 moduli) si pilota; le altre taglie restano autonome.
- **Pilotato, pro:** il corpo del giocatore non prende danni (li prende il colosso); moduli **+50%**; il giocatore decide dove scavano e alzano Trivella, Pala e Ruspa (il terreno in grande); travolge anche i rottamatori medi.
- **Pilotato, contro:** armi del giocatore spente (restano quelle del colosso), niente attrezzo, niente scatto, velocita -30% rispetto al giocatore a piedi.
- **Carburante:** 1 rottame ogni 10 s dai Cassoni; senza rottami, o sotto il 30% di vita, il giocatore viene sbalzato fuori e il colosso va in ritirata.
- **Autonomo:** segue nel grappolo alla forza normale, nessun consumo; il giocatore tiene armi, attrezzo e scatto.

## Sezione 4 — danni, guasti ed eventi (APPROVATA dal proprietario il 15 ottobre 2026)

- **Guasto:** a 0 PV la macchina si ferma e fuma, i moduli si spengono, i nemici la ignorano. **Riparazione:** giocatore entro 2 m, tasto azione tenuto 1,5 s, **2 rottami**, riparte a meta vita. Il **Saldatore** ripara gratis anche le guaste, in 6 s. Rischio della fusione: il colosso guasto ferma tutto insieme.
- **Ritirata:** sotto il 30% di vita la macchina va dietro al giocatore, dal lato opposto al nemico piu vicino, a 4-6 m; i moduli continuano a lavorare; torna al posto sopra il 50%.
- **Rigenerazione:** dopo 8 s senza danni, 1 PV ogni 4 s fino al pieno.
- **Eventi** (D-097: casuali, quanti ne sceglie il giocatore nella scheda Gameplay; un evento spento non stacca moduli; solo macchine fuse; le piccole non perdono moduli): **terremoto**, se la crepa attraversa la macchina, stacca 1 modulo a caso; **treno**, guasta subito la macchina investita e, se fusa, stacca 1 modulo scagliandolo a 6-8 m.
- **Modulo staccato:** relitto luccicante a terra come le casse; col tasto azione torna una macchina piccola, gratis; per rifonderlo si torna alla piazzola.
- Boss e rottamatori non staccano moduli: fanno solo danno (rottamatori 1 al contatto, come oggi).

## Sezione 5 — come si ottengono le macchine; classi e Officina (APPROVATA dal proprietario il 15 ottobre 2026)

- **Partenza:** tutti con una macchina (Cassone, il compagno di oggi); il **Meccanico** con due (Cassone e Torretta).
- **Relitti sepolti:** due per livello sotto cumuli e vagoni, distinti dalle casse (telaio arrugginito che spunta, luccichio arancione invece che turchese); allo scavo scelta fra due moduli sbloccati; a carovana piena valgono 3 rottami; il treno che spiana un vagone porta via il relitto come la cassa.
- **Carte:** le carte dei pezzi del compagno di oggi (Torretta sul cassone, Calamita, Faro) diventano "Nuova macchina: <modulo>" (Rare nel mazzo comune, Non comuni in quello del Meccanico); al massimo una carta macchina per level-up, solo se c'e posto. Le carte che oggi potenziano un pezzo (livelli di Torretta, Faro, Cassone rinforzato) potenziano tutti i moduli di quel tipo; Motore truccato e Saldatura al volo valgono per tutte le macchine.
- **Officina:** sbloccati da subito Cassone, Torretta, Calamita, Faro; nuova scheda "Macchine" per sbloccare Trivella, Pala, Saldatore, Sirena (15-25 rottami l'uno); Cassone saldato, Scorta e Torretta fissa (Meccanico) restano. Il Ricettario ha la sezione "Combinazioni" (6 voci a "???" fino alla prima fusione); profilo versione 3, un profilo v2 si carica intatto.
- **Meccanico, "carovana potenziata":** parte con due macchine; carta di classe "Officina mobile" che porta il limite a 7 moduli (un colosso piu una piccola); le sue armi che usano il compagno (Calamita da gru) usano la macchina col Cassone piu vicina.

## Sezione 6 — comandi, HUD, prestazioni, bot (APPROVATA dal proprietario il 15 ottobre 2026)

- **Comandi:** nessun tasto nuovo. Il tasto azione esistente, secondo il contesto, ripara la macchina guasta vicina (tenuto), apre il banco sulla piazzola, fa salire e scendere dal colosso; controller e tastiera equivalenti. Le macchine sono autonome, niente ordini.
- **HUD:** striscia di icone sopra la barra delle armi, una per macchina, con taglia, vita e segno di guasto. Nel mondo un anello colorato a terra sotto ogni macchina per staccarla dall'orda; la guasta fuma e ha un'icona sopra.
- **Prestazioni:** al piu 6 corpi; budget 0,5 ms per passo sul preset Deck, misurato col benchmark come le armi; se si sfora si riducono prima gli effetti.
- **Bot:** il simulatore raccoglie i relitti, fonde sulla piazzola e ripara, per bilanciare i numeri.

## Ancora da progettare (sezioni successive)

- Verifica, piani di implementazione e ordine rispetto al piano 5 delle armi (effetti e suoni).

## Prossimo passo

Sezioni 1-6 approvate il 15 ottobre 2026. Riprendere dalla **Sezione 7** (verifica, piani di implementazione, ordine rispetto al piano 5 delle armi), poi la spec definitiva al posto di questa bozza.
