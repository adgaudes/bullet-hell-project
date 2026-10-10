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

## Questioni aperte prima dell'Art Lock

- grado esatto di caricatura delle proporzioni;
- eventuale outline o rim light selettiva;
- numero e diversita dei personaggi iniziali;
- rapporto fra tecnologia terrestre, fantasy e aliena;
- tecnica foliage e budget su Steam Deck;
- provenienza e licenza di ogni reference o modello destinato a superare la fase placeholder.
