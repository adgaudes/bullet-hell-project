# Strategia della demo Steam

## Stato

- Una demo pubblica prima della release e parte della strategia candidata del progetto.
- Contenuto, data e durata non sono ancora approvati.
- La demo viene pianificata dopo la vertical slice e pubblicata soltanto quando rappresenta con qualita il gioco finale.
- Una possibile partecipazione a Steam Next Fest verra scelta in base alla maturita reale, non a una data desiderata prematuramente.

## Perche una demo puo essere utile

Il concept dipende da interazioni difficili da comunicare soltanto con testo o immagini: costruire una carovana, agganciare e separare moduli, trasformare il campo e gestire luce/buio. Una demo di qualita puo:

- far comprendere direttamente la promessa;
- raccogliere feedback su controlli, onboarding e originalita percepita;
- verificare Windows, controller, tastiera/mouse, Proton e Steam Deck su un pubblico piu ampio;
- trasformare interesse in wishlist attraverso la pagina del gioco;
- fornire dati per bilanciamento e scope prima del content complete.

Una demo scadente puo invece ridurre fiducia e intenzione di acquisto. Non verra pubblicata per rispettare una scadenza se il core loop non e pronto.

## Posizione nella roadmap

1. **Prototype Complete:** il loop funziona in graybox; nessuna demo pubblica.
2. **Vertical Slice:** qualita, pipeline e prestazioni sono rappresentative; decisione go/no-go sulla demo.
3. **Demo Candidate:** estrazione di una porzione breve, rifinita e autonoma dalla vertical slice/gioco.
4. **Closed test:** QA interno ed esterno, incluso Steam Deck LCD.
5. **Steam review:** pagina Coming Soon del gioco gia pubblica, demo configurata e revisionata.
6. **Demo Launch:** uscita coordinata con un momento marketing o Steam Next Fest selezionato.
7. **Post-demo:** analisi dei feedback, aggiornamenti controllati e decisione se mantenerla disponibile.

## Contenuto candidato

Durata obiettivo iniziale: **15-25 minuti** per una prima run completa della demo. La durata verra misurata, non imposta artificialmente.

La demo dovrebbe includere:

- onboarding breve, giocabile con controller o tastiera/mouse;
- una zona rappresentativa del mondo caldo e riconquistato dalla natura;
- almeno una transizione significativa fra luce e buio;
- nucleo-officina e due moduli con aggancio/separazione;
- una trasformazione leggibile del campo di battaglia;
- 2-3 scelte capaci di produrre build differenti;
- un evento culminante o miniboss;
- una piccola fusione a due moduli, se gia validata e stabile;
- conclusione chiara con invito non invasivo a wishlist e feedback;
- impostazioni, pausa e uscita complete;
- prestazioni rappresentative su Windows e Steam Deck LCD.

La demo non deve promettere attraverso video o testo feature assenti dalla build. Mezzo aereo completo, mezzo acquatico e forma colossale possono essere anticipati soltanto con materiale reale e chiaramente distinto dal contenuto giocabile.

## Cosa lasciare al gioco completo

- varieta completa di biomi e macchine;
- progressione permanente estesa;
- forma colossale definitiva;
- risoluzione narrativa;
- combinazioni avanzate e contenuti di alta difficolta;
- maggior parte di boss, eventi e segreti.

La demo deve terminare dopo una soddisfazione concreta e una nuova domanda, non con un taglio arbitrario nel mezzo dell'azione.

## Architettura e manutenzione

- La demo deve derivare dallo stesso progetto e dagli stessi sistemi del gioco, con contenuti e configurazione selezionati tramite dati o build target.
- Evitare un fork manuale destinato a divergere.
- Usare save namespace/versione espliciti e decidere in seguito se permettere il trasferimento al gioco completo.
- Disabilitare achievement nella demo salvo nuova decisione motivata.
- Tenere separati App ID, depot, configurazione e checklist Steam della demo.
- Non raccogliere telemetria personale senza una decisione, informativa e consenso appropriati; iniziare con feedback volontario e dati Steam disponibili.

## Steam e pagina Coming Soon

Secondo la documentazione Steamworks attuale:

- una demo usa un App ID separato associato al gioco base;
- se esce prima del gioco, la pagina del gioco base deve essere visibile come Coming Soon affinche i giocatori possano aggiungerlo alla wishlist;
- la demo puo comparire sulla pagina del gioco base oppure avere una pagina separata;
- una pagina demo separata richiede contenuti, screenshot e descrizioni specifici della demo;
- la notifica ai wishlister per il lancio iniziale della demo e un'opportunita singola disponibile per un periodo limitato, quindi il momento va pianificato;
- la review di Valve non sostituisce il QA interno.

Decisione candidata: iniziare senza pagina demo separata, usando la pagina principale per concentrare messaggio e wishlist. Rivalutare una pagina separata solo se la demo possiede contenuti o comunicazione sufficientemente distinti.

## Steam Next Fest

Steam Next Fest puo offrire feedback e visibilita, ma ogni titolo puo partecipare a una sola edizione. La scelta deve avvenire quando:

- il concept e stabile;
- la pagina Steam rappresenta bene arte e gameplay;
- la demo e gia divertente e tecnicamente affidabile;
- esiste tempo per QA e correzioni prima delle scadenze;
- la release completa e abbastanza vicina da convertire l'interesse, ma non tanto da impedire interventi sostanziali.

Non selezionare un'edizione finche la vertical slice non permette una stima credibile. Le date e le regole vanno ricontrollate al momento della decisione.

## Criteri di qualita

La demo non viene pubblicata se:

- il primo momento distintivo richiede troppo tempo per essere raggiunto;
- controller o tastiera/mouse hanno funzioni mancanti;
- l'esperienza non e stabile sullo Steam Deck LCD;
- testo, glifi o UI non sono leggibili a 1280x800;
- il giocatore non comprende quando agganciare o separare i moduli;
- il finale non comunica chiaramente che cosa offre il gioco completo;
- bug, stutter o crash compromettono la prima impressione;
- il contenuto usa asset o materiali non autorizzati per la distribuzione pubblica.

## Metriche e feedback

Domande minime per i playtest della demo:

- Qual e, secondo il giocatore, la promessa del gioco?
- Che cosa ha percepito come originale?
- Quando ha capito il vantaggio di unire o separare le macchine?
- Quale scelta di build ha modificato maggiormente il suo comportamento?
- Dove ha perso orientamento, controllo o leggibilita?
- Vorrebbe giocare un'altra run e perche?
- Aggiungerebbe il gioco alla wishlist dopo questa esperienza?

Metriche aggregate candidate: avvio, completamento onboarding, durata, raggiungimento della fusione, completamento run, errori/crash e configurazione hardware. Implementarle solo se proporzionate e nel rispetto della privacy.

## Fonti ufficiali

- [Valve - Steam Demos](https://partner.steamgames.com/doc/store/application/demos?l=english)
- [Valve - Steam Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest?l=english)
- [Valve - Coming Soon](https://partner.steamgames.com/doc/store/coming_soon?l=english)

Regole, finestre e funzionalita Steam devono essere verificate nuovamente quando la demo entra in produzione.
