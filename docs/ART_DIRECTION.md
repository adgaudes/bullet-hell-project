# Direzione artistica provvisoria

## Stato

- Data prima analisi reference: 22 settembre 2026.
- Stato: direzione provvisoria, non Art Lock.
- Fonti visive locali: `Screenshots/Character` e `Screenshots/World`; restano escluse dal repository e non sono asset di produzione approvati.

## Sintesi

La direzione candidata e **realismo stilizzato caldo**: quasi cartoonesco nelle forme e nelle proporzioni, ma non nella fisica dei materiali, nell'illuminazione o nella credibilita del mondo. L'obiettivo non e cel shading o comicita visiva estrema; e rendere personaggi, macchine e terreno immediatamente leggibili dall'alto, mantenendo peso, usura e presenza tridimensionale.

Scala indicativa, da validare con prove:

- forme e proporzioni: 60-70% stilizzate;
- materiali e luce: 60-70% credibili;
- dettaglio minuto: subordinato alla silhouette e alla lettura isometrica;
- tono cromatico: caldo, vitale e accogliente anche dentro rovine e pericoli.

## Personaggi

Le reference convergono su ingegneri compatti, caricaturali e sovraccarichi di utensili. Gli elementi utili sono:

- busto ampio, arti relativamente corti, mani e testa leggermente maggiorate;
- silhouette massiccia e stabile, leggibile anche a distanza;
- zaino/officina e utensili come seconda silhouette;
- materiali consumati ma non fotorealistici: cuoio, tela, metallo, gomma e parti recuperate;
- volto espressivo, barba/capelli e occhiali come accenti di personalita;
- asimmetria controllata e riparazioni visibili.

### Correzioni necessarie per una firma originale

- non limitare il roster a uomini anziani, bassi, barbuti e simili fra loro;
- evitare l'equazione automatica `ingegnere = nano steampunk` e la vicinanza percettiva a *Deep Rock Galactic*;
- non riempire ogni superficie di ingranaggi decorativi senza funzione;
- introdurre differenze forti di altezza, corporatura, eta, genere, postura, silhouette dello zaino e linguaggio dei materiali;
- dare a ogni personaggio un colore di accento e un profilo riconoscibile soprattutto da schiena e tre quarti alto, cioe dagli angoli reali di gioco;
- collegare l'equipaggiamento al mondo: rottami dell'infrastruttura precedente, componenti terraformanti alieni, natura adattata e riparazioni artigianali.

Il carattere cinico e sboccato deve emergere da postura, animazioni, reazioni ai guasti, nomi dati agli attrezzi e uso poco reverenziale della tecnologia, non soltanto dal dialogo.

## Mondo

Le reference mostrano tre idee forti:

1. infrastrutture urbane riconoscibili sommerse, spezzate o invase dalla natura;
2. vegetazione che non decora soltanto, ma cambia percorsi e scala degli spazi;
3. contrasti fra luce calda, ombra profonda, acqua, ruggine e crescita organica.

Le immagini fotorealistiche sono reference di scala, composizione e rapporto natura-rovina; non definiscono il rendering finale. Le immagini illustrative con masse semplificate, bordi leggibili e colori piu netti sono piu vicine alla resa candidata.

### Adattamento al gameplay dall'alto

- usare grandi masse e campiture, non affidare la bellezza al microdettaglio delle facciate;
- distinguere terreno modificabile, ostacoli, risorse e pericoli tramite forma e valore prima che tramite texture;
- riservare grattacieli, voragini urbane e monumenti alla scala dello sfondo o a landmark; l'arena giocabile usa cortili, tetti bassi, stazioni, viadotti, canali e rovine attraversabili;
- trasformare ferrovie, gallerie, strade collassate e zone allagate in sistemi di percorso e non in semplice scenografia;
- mantenere contrasto sufficiente per personaggio, compagno, nemici, proiettili e telegraph.

### Palette candidata

Base calda:

- terracotta, rame, ocra, crema sporco e legno caldo;
- verdi vivi con variazioni gialle, non una dominante verde-grigia uniforme;
- corallo, turchese e magenta controllati per flora anomala, tecnologia aliena e segnali di gameplay;
- luce dorata da alba/tramonto come firma ricorrente;
- notti blu-violacee con bioluminescenza calda, evitando il monocromo freddo.

La ruggine e il degrado non devono rendere tutto marrone. Fiori, tessuti, vernici recuperate, licheni e componenti alieni devono produrre punti cromatici forti.

## Macchine

Le macchine condividono la solidita e l'asimmetria dei personaggi, ma non devono essere steampunk generico:

- ogni parte visibile comunica una funzione;
- moduli e agganci sono leggibili dalla camera di gioco;
- componenti contemporanei recuperati convivono con materiali fantasy e tecnologia aliena;
- tubi, serbatoi, cinghie e ingranaggi sono usati con gerarchia, non come rumore uniforme;
- animazioni leggermente esagerate rendono comprensibili peso, sforzo, guasto e successo;
- piccole reazioni comiche danno personalita senza compromettere i telegraph.

## Audit del modello GLB locale

`Screenshots/Character/edited-image.glb` e stato ispezionato con Blender 5.2.2:

- 2 mesh, 33.738 vertici e 25.957 poligoni complessivi;
- 3 materiali e 5 immagini;
- nessuna armatura e nessuna animazione;
- nomi interni `tripo_*`, coerenti con un asset generato tramite Tripo.

Puo servire come reference volumetrica o placeholder di scala dopo verifica della licenza e della provenienza. Non e pronto come personaggio di produzione: richiede almeno pulizia, retopology/LOD, separazione funzionale degli accessori, rig, skinning, test di deformazione e verifica dei materiali in Godot. Non va importato stabilmente finche i diritti d'uso commerciale non sono documentati.

## Prima prova artistica consigliata

Produrre una sola scena graybox/stylized-lighting, non un personaggio finale:

1. piccola arena urbana riconquistata dalla natura;
2. blocchi architettonici semplificati e un landmark sullo sfondo;
3. palette calda con due accenti di gameplay;
4. capsule/sagome per protagonista, Mulo da campo e nemici;
5. test a 1280x800 dalla camera reale;
6. confronto fra materiali quasi realistici e forme piu stilizzate.

Il test ha successo se una schermata muta comunica insieme mondo post-apocalittico vitale, ingegneria improvvisata, tono non solenne e gerarchia di gameplay.

## Arena "rovine riconquistate" (4 ottobre 2026, D-036)

Prima applicazione della direzione nel gioco: piazza con strada spaccata, lastre invase dall'erba, torri coperte di muschio e rampicanti, treno e auto arrugginiti, alberi, cespugli, fiori corallo/blu/giallo, foschia in lontananza e sole basso dorato. Reference del proprietario in `Screenshots/World/arena_reference_2026-10-04/` (fuori repo; alcune generate con AI, una firmata: solo ispirazione, mai asset). Edifici, macerie e vegetazione bassa sono ancora primitive; auto, vagoni, alberi e barriere sono modelli Blender scriptati (D-037) con i materiali procedurali dell'arena. Mancano texture, fogliame denso, acqua e modelli degli edifici. Dal 9-10 ottobre 2026 attori (D-071, D-072) e prop con modello (D-073: auto, vagoni, alberi, barriere, lampioni) hanno colore, usura, occlusione e sporco cotti in texture da Blender; rovine, torri e terrapieni restano su shader procedurali.

## Direzione dall'11 ottobre 2026 (D-077): stilizzato ricco alla Hades II

Il proprietario ha scelto una resa "attuale": texture dipinte in alta risoluzione (2048 per modelli grandi e tile, 1024 per prop piccoli), forme morbide e dense, colori saturi con contrasti caldo/freddo, rim light e glow marcati, dettaglio decorativo dove conta. **Hades II** e il riferimento di resa tradotto in 3D (texture dipinte, mai foto; niente PBR fotografico). Tutto viene dalla pipeline Blender nostra (`tools/blender/painter.py`, `build_surface_tiles.py`): nessun pacchetto esterno, nessuna AI. La specifica e in `docs/superpowers/specs/2026-10-11-visual-restyle-design.md`; la fetta visiva dell'ambiente e fatta (catture prima/dopo in `output/restyle/`), il resto segue il giudizio del proprietario.

### Personaggi: regole comuni

- testa circa 1,4x e mani circa 1,5x rispetto al realistico, torso ampio, arti corti, baricentro basso;
- un "secondo profilo" sulla schiena (zaino, botte, cariche, chiave) leggibile da dietro e dai tre quarti alti;
- attrezzi recuperati dalle infrastrutture del mondo (binari, segnali, tubi, carrozzeria, manometri), **mai ingranaggi d'ottone decorativi**; il linguaggio delle reference (tozzi, morbidi, usurati) si, l'archetipo "nano steampunk" no;
- un vizio visibile per ciascuno; materiali cuoio/tela/gomma/metallo sporco con usura dipinta; facce vissute (guance e naso arrossati, sopracciglia folte, rughe e cicatrici dipinte), mai lisce;
- un colore d'accento forte per personaggio, su elementi visibili da dietro;
- **roster fisso, un personaggio per classe, nessuna scelta di sesso, corporatura o eta**; il carattere (rozzi, scalmanati, ubriaconi, sboccati, simpatici) si legge dall'aspetto e dalla postura.

### Roster (schede visive)

| # | Classe (asse di gioco) | Chi e | Come si vede che e rozzo e simpatico | Accento |
|---|---|---|---|---|
| 1 | **Ingegnere** (equilibrato, personaggio attuale) | Donna sulla cinquantina, tozza, spalle larghe, naso rotto, capelli grigi legati con un cavo elettrico | Tuta slacciata fino alla vita con canottiera macchiata, sigaro spento in bocca, fiaschetta all'anca, chiave da treno enorme a tracolla, postura a mento alto e pancia in fuori | Arancio |
| 2 | **Guastatore** (scavo esplosivo, terreno) | Ragazzo magro e sdentato, iperattivo, sopracciglia bruciate | Occhiali da saldatore storti, giubbotto gonfio di cariche fatte in casa, pantaloni strappati, orecchie fasciate, bocca sempre aperta a ridere; corre a scatti | Rosso |
| 3 | **Meccanico** (compagno potenziato) | Vecchio enorme, calvo, pancia da birra, braccia da gorilla | Grembiule di gomma, un occhio sostituito da una lente recuperata, mani nere di grasso, bottiglia nella tasca posteriore; passo lento e pesante | Turchese |
| 4 | **Erbacciaia** (terreno che cresce, vegetazione come difesa) | Vecchia minuta e cattiva, gobba, pipa accesa | Cappello di paglia bruciacchiato, botte di distillato in spalla con il tubo che le arriva alla bocca, falce arrugginita, gatto-robot sulla botte; sputa per terra | Magenta |

Le classi come meccanica non esistono ancora: si costruisce prima l'Ingegnere (piano 2), le classi entrano nel gioco dopo il playtest. Identificatori: `engineer`, `sapper`, `mechanic`, `weeder`.

### Ambiente: ricetta della fetta visiva

Tile dipinte e ripetibili per suolo (terra, lastre, asfalto, terra scavata, fango, erba), muri (intonaco scrostato con mattoni, muschio, corteccia) e piante (ciuffi, cartelle di foglie); maschera mondo condivisa fra piano e celle del terreno; rovine generate per impronta e dipinte in triplanare; prato basso a chiazze di fili sottili e cespugli a cartelle, mossi dallo stesso campo di vento (`wind.gdshaderinc`, D-083); prop con albedo, normal e ORM cotte; cielo a gradiente dipinto, sole caldo basso con ambiente freddo (ombre blu-viola), ACES, glow in soft light, contrasto 1,12 e saturazione 1,22; rim light su attori e prop; notte blu-violacea.

### Suolo sul rilievo continuo (12 ottobre 2026, D-085)

Il suolo e Terrain3D con cinque strati dalle stesse tile dipinte (terra, lastre, asfalto, terra smossa, fango) scelti dal control map: piazza lastricata, strada in asfalto, cime di argini e cumuli in terra smossa, il resto terra con il prato dipinto sul color map sotto i ciuffi. Lo shader del rilievo tinge dal delta rispetto alla base del livello: rame caldo dove il giocatore ha alzato (argini spinati piu chiari), terra scura dove ha scavato, fango lucido nelle conche sotto -0,6 m, fianchi ripidi piu spenti. Il prato non cresce sui fianchi ripidi ed e piu fitto nelle conche; rovine, alberi e prop poggiano sulle quote. Lo zainetto di terra dell'ingegnere e una sacca di tela sotto lo zaino-officina con una striscia sul fianco che si riempie dal basso e si gonfia a zaino pieno. Catture in `output/terrain/`; giudizio del proprietario aperto (gli argini mostrano i gradini della heightfield da 0,5 m).

## Questioni aperte prima dell'Art Lock

- grado esatto di caricatura delle proporzioni;
- eventuale outline o rim light selettiva;
- numero e diversita dei personaggi iniziali;
- rapporto fra tecnologia terrestre, fantasy e aliena;
- tecnica foliage e budget su Steam Deck;
- provenienza e licenza di ogni reference o modello destinato a superare la fase placeholder.


## Identita e interfaccia (11 ottobre 2026, D-079 e D-080)

**Nome: "Dwarmageddon: Dig or Die".** Gioco di parole Dwarf + Armageddon: i quattro personaggi del roster sono nani di questo mondo (tozzi, testa e mani grandi, baricentro basso, come gia nelle schede); il divieto resta sull'archetipo steampunk con ingranaggi d'ottone, non sulla parola. Il sottotitolo dice la firma del gioco: il terreno.

**Logo** (`scenes/ui/game_logo.tscn`, vettoriale, nessun PNG sorgente): wordmark "DWARMAGEDDON" in Alfa Slab One con gradiente rame → ocra, outline scuro e linea di base ad arco (la parola "spinge" come un terrapieno); due sole decorazioni, un chiodo della chiodatrice piantato di sbieco nella prima "O" con una crepa, e una zolla di terra con tre ciuffi d'erba sotto la parola; "DIG OR DIE" in crema su una targa scura inclinata di due gradi. Impaginazioni `wide` (menu, intro, capsule larghe) e `stacked` (icona e formati quadrati: stessa riga unica, targa del sottotitolo piu larga; la divisione DWARMA / GEDDON e stata scartata dal proprietario il 12 ottobre 2026). Esportazione PNG con `tests/tools/capture_logo.gd`.

**Font** (SIL OFL 1.1, `godot/assets/fonts/`): Alfa Slab One per titoli, logo e numeri dell'HUD (mai sotto 16 px); Rubik (variabile, pesi 400/500/700) per testo, pulsanti e opzioni (mai sotto 14 px).

**Palette dell'interfaccia** (`scripts/ui/ui_palette.gd`):

| Token | Valore | Uso |
|---|---|---|
| `BG` | `#17110d` | fondo del menu, overlay |
| `PANEL` / `PANEL_RAISED` | `#2a1f18` a 0,94 / `#38291f` | pannelli / pulsanti, righe, carte |
| `BORDER` / `BORDER_LIGHT` | `#b5652d` / `#e0a060` | bordo rame / luce sul bordo e intestazioni |
| `TEXT` / `TEXT_MUTED` | `#f2e6cf` / `#c9a25f` | testo / secondario |
| `FOCUS` | `#3fc1b5` | bordo e bagliore del controllo attivo |
| `DANGER` / `SUCCESS` | `#e3553f` / `#7fc24f` | vita, sconfitta / vittoria, acquistato |
| `SCRAP` / `XP` | `#f28a2e` / `#1ad9a6` | rottami / esperienza |

Le rarita del level-up restano i colori di `UpgradeCatalog.RARITY_COLORS`. Il tema vale per tutte le schermate attraverso `resources/ui/theme.tres` (vedi `GODOT_WORKFLOW.md`); i nodi usano le varianti di tipo e non si colorano da soli.

**Intro all'avvio**: 4 secondi, il terreno sale con la polvere, le lettere cadono con una scossa, il chiodo si pianta, la targa si stampa, l'erba spunta; saltabile. Il punto d'aggancio per una vignetta con i personaggi nuovi (dopo il piano 2 del restyling) e `BootIntro.vignette`.


### Materia e feedback (D-081)

L'interfaccia e fatta di tre materiali generati dalla pipeline nostra (`tests/tools/build_ui_textures.gd`): **cuoio** scuro con cornice di rame battuto e rivetti per i pannelli, **lamiera** di rame in rilievo per i pulsanti (incassata quando premuti, bordo turchese con alone quando a fuoco), **pergamena** con bordi bruciacchiati per carte e righe, con testo scuro (`INK` `#3b2718`). Le icone sono pittogrammi a poligoni (`UiIcon`), in rame o crema con outline scuro. Il focus ha un cursore fisico, un chiodo di rame che insegue il controllo attivo; ogni azione ha un suono breve di metallo e un rimbalzo; i pannelli entrano con un pop-in e le scene cambiano con un velo. Il menu ha uno sfondo a strati in parallasse (torri in rovina, viadotto spezzato, colline, terrapieno) sotto il cielo dipinto.
