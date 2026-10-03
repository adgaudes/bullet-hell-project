# Companion Slice — specifica del primo compagno macchina

**Stato:** provvisoria, proposta dall'agente il 3 ottobre 2026 (D-032). Il proprietario valuta il prototipo e decide se continuare, modificare o scartare.

## Perche

D-012 fissa la prima macchina: un compagno autonomo, non pilotabile, che segue il giocatore, trasporta risorse, aiuta contro i nemici e modifica lievemente il terreno. D-011 chiede di verificare la promessa dopo "la prima catena causale completa terreno-macchina-conseguenza". Questo slice e quella catena, nella forma piu piccola che si possa giocare.

## Domanda a cui risponde il prototipo

**Avere accanto una macchina che porta il materiale e interviene da sola rende il terreno piu interessante, o solo piu complicato?**

Il gate e del proprietario: Continua / Modifica / Scarta.

## Loop (Leggi → Intervieni → Sfrutta → Paga)

1. **Leggi:** la sfera hazard percorre la sua corsia; il compagno ti segue; vedi quanti rottami porta.
2. **Intervieni:** scavi una cella e nasce un **rottame**; il compagno lo va a prendere e lo carica.
3. **Paga:** rialzare costa **1 rottame**, prelevato dal compagno se e abbastanza vicino al bersaglio. Senza rottami, o con il compagno lontano, l'anteprima e rossa.
4. **Sfrutta:** se l'hazard punta verso di te, il compagno spende un rottame e **alza da solo una cella sulla corsia** davanti alla sfera, che si ferma.

Scavare resta gratuito: e il modo di produrre materiale. Rialzare consuma. Ogni terrapieno e quindi una scelta.

## Regole del compagno (valori iniziali, in `CompanionTuning`)

| Regola | Valore |
|---|---|
| Segue il giocatore a distanza | 2,5 m, dietro rispetto alla direzione di marcia |
| Velocita massima | 5 m/s (il giocatore Scattante va a 6,5: il compagno resta indietro negli scatti) |
| Raggio di raccolta | rottami entro 6 m dal giocatore; oltre li ignora per non allontanarsi |
| Capacita | 5 rottami; dotazione iniziale 3 |
| Raggio di fornitura | il giocatore puo rialzare solo se il compagno e entro 5 m dalla cella bersaglio |
| Intervento contro l'hazard | se la sfera e diretta verso il giocatore (giocatore nella corsia, entro 10 m davanti alla sfera), alza la prima cella libera della corsia tra 1,5 e 6 m davanti alla sfera; raggio d'azione 9 m; ricarica 3 s |
| Collisioni | si muove come il giocatore sul mondo statico (celle Raised comprese); non collide con il giocatore ne con l'hazard |

## Hazard

Nello slice la sfera **colpisce** il giocatore: al contatto il corpo lampeggia e la sfera riparte (`PROTOTYPE01_PLAYER_HIT`). Non ci sono punti vita. Nella scena di parita il comportamento Unreal resta invariato (la sfera attraversa il giocatore).

## Leggibilita

- Compagno: cassone chiaro con una striscia gialla davanti; i rottami caricati sono cubetti impilati sopra.
- Rottame a terra: cubetto color ruggine che ondeggia.
- Rialzo del compagno: stesso effetto di quello del giocatore; il log lo distingue.

## Fuori scope

Nemici, punti vita, morte, pathfinding (il compagno scivola lungo gli ostacoli), piu compagni, aggancio/fusione, comandi diretti al compagno, UI oltre il contatore sopra il compagno, audio.

## Marker diagnostici

`PROTOTYPE01_COMPANION_READY`, `PROTOTYPE01_SCRAP_SPAWNED`, `PROTOTYPE01_SCRAP_COLLECTED carried=N`, `PROTOTYPE01_SCRAP_SPENT carried=N`, `PROTOTYPE01_TERRAIN_RAISE_NO_SCRAP`, `PROTOTYPE01_COMPANION_RAISE X=.. Y=..`, `PROTOTYPE01_PLAYER_HIT`.

## Domande per il playtest del proprietario

1. Il compagno si capisce senza spiegazioni (chi e, cosa porta, cosa fa)?
2. Ti viene voglia di scavare per "fare scorta"? Il costo del rialzo cambia le tue scelte?
3. Quando il compagno ferma la sfera da solo, la cosa si legge come aiuto o come caos?
4. Il compagno ti sta tra i piedi o resta troppo indietro?
5. Continua / Modifica / Scarta?
