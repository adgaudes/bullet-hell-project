# Carovana di macchine e fusione — design (bozza in corso)

Data: 15 ottobre 2026. Stato: **in progettazione col proprietario, non approvato. Niente implementazione finche il design non e approvato per sezioni e la spec scritta non e rivista.**
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

## Sezione 1 — macchine e moduli (proposta dell'agente, IN ATTESA DI APPROVAZIONE)

- **Macchina = telaio + moduli.** Telaio con vita (6 PV) e un modulo. Al massimo **6 moduli in tutta la carovana** (sei piccole separate, o qualunque fusione fino a una sola da 6).
- **Otto moduli:** Cassone (raccoglie e fornisce rottami: il compagno di oggi), Torretta (chiodatrice), Calamita (frammenti d'esperienza), Faro (luce di notte), Trivella (scava buche attorno al grappolo; su una vena estrae rottami), Pala (alza un piccolo argine davanti al nemico piu vicino coi rottami del Cassone), Saldatore (ripara le altre macchine, 1 PV ogni 3 s), Sirena (attira i rottamatori vicini su di se).
- **Taglie della macchina fusa:** 1 modulo piccola, 2-3 media, 4-5 grande, 6 colosso. Ogni modulo oltre il primo rende gli altri del 15% piu forti; vita = somma dei telai + 25% per taglia sopra la piccola; velocita -10% per taglia; da media in su travolge i rottamatori piccoli (1 danno al contatto quando si muove).
- **Sei combinazioni di partenza** (bonus quando i due moduli stanno nella stessa macchina): Estrattore (Trivella + Calamita: le buche risucchiano i rottami vicini nel Cassone), Riflettore (Torretta + Faro: i nemici illuminati prendono doppio danno dalla Torretta), Betoniera mobile (Pala + Cassone: argini della Pala gratis), Esca blindata (Saldatore + Sirena: mentre attira subisce meta danno), Ruspa (Trivella + Pala: fossato con argine a lato dove passa), Trappola (Torretta + Sirena: chi e attirato prende doppio danno dalla Torretta).
- Valori di partenza, non bilanciati.

## Ancora da progettare (sezioni successive)

- Pro e contro del colosso pilotato e autonomo (cosa perde il giocatore quando lo pilota: tool, scatto, armi?; durata, carburante in rottami?).
- Piazzola-officina: quando arriva (minuto, evento), dove, come si vede, costi in rottami di aggancio e sgancio, interfaccia della scelta (quali telai unire, in che ordine).
- Eventi che staccano moduli: quali, quanti, cosa succede al modulo staccato (relitto da recuperare?).
- Relitti sepolti (rapporto con le casse delle armi), carte macchina nel level-up (convivenza con le carte arma e i mazzi di classe), sblocchi in Officina (quali moduli bloccati all'inizio), ricettario delle combinazioni.
- Guasto e riparazione: costo in rottami, chi ripara (giocatore vicino? Saldatore?), tempo; rigenerazione (dopo quanti secondi senza danni, quanto in fretta).
- Rapporto con le classi (il Meccanico "compagno potenziato"; le sue armi che usano il compagno) e con i permanenti di oggi (Cassone saldato, Scorta, Torretta fissa).
- HUD e comandi (controller prioritario), leggibilita del grappolo con l'orda, prestazioni sul Deck (piu corpi che si muovono e sparano), simulatore dei bot.
- Verifica, piani di implementazione e ordine rispetto al piano 5 delle armi (effetti e suoni).

## Prossimo passo

Riprendere dalla **Sezione 1**: il proprietario deve dire se la struttura (telaio + moduli, 6 al massimo, otto moduli, taglie, combinazioni) gli torna; poi le sezioni successive una alla volta, poi la spec definitiva al posto di questa bozza.
