# Playtest del livello completo — promemoria per il proprietario

**Cosa si gioca:** il livello completo del prototipo della promessa A sul branch `feature/arena-run`: quartiere in rovina, orda, chiodatrice, level-up, Demolitore a 12 minuti con la sua squadra, Officina fra una run e l'altra. **Nessuno l'ha ancora giocato o ascoltato.**

**Le domande a cui rispondere** sono in `docs/PROMISE_A_PROTOTYPE_SPEC.md`, sezione "Playtest del proprietario" (1-7) e nelle sezioni "Boss" e "Officina" (13-22). Questo foglio non le ripete: dice come avviare, **cosa e gia noto** (cosi non lo riscopri) e cosa annotare.

## Come avviare

| Modo | Cosa contiene | Come |
|---|---|---|
| **Editor, F5** (consigliato) | tutto fino a D-065: animazioni, glifi, addon, le 69 correzioni delle review, ciclo giorno/notte con lampioni (D-058) | aprire `godot/project.godot`, F5: parte dal menu iniziale |
| Build Windows in `LocalBuilds/Prototype01-Godot-Win64/` | **riesportata il 9 ottobre 2026**, identica all'editor | doppio clic su `Prototype01.exe` |
| Boss subito | come l'editor, con il Demolitore a 60 secondi | da terminale nella cartella del progetto: `godot --path godot -- --boss-at=60` |
| Notte subito | tramonto dopo 5 secondi invece di 4:30 | `godot --path godot -- --night-at=5` |
| Senza notte | il livello come prima di D-058, per confronto | `godot --path godot -- --night-at=0` |
| Run ripetibile | stesso seme, stessa orda e stesse carte | `godot --path godot -- --seed=7` (sostituire il numero) |

Nell'editor il pannello Output stampa `PROTOTYPE01_RUN_START seed=N`: **annota il seme** quando succede qualcosa di strano, cosi si rigioca la stessa run. F3 cicla il Debug Menu (fps e frametime).

Almeno tre run. Una con il controller e una con tastiera e mouse, come sempre.

## Cosa e gia noto: non serve riscoprirlo

Dalla review del 7 ottobre 2026 (`docs/REVIEWS/ARENA_RUN_LEVEL_2026-10-07.md`). Le otto del punto 1 (R-01, R-02, R-06, R-07, R-13, R-25, R-26, R-38) sono **corrette il 9 ottobre 2026** con un test ciascuna: se le vedi lo stesso, e un dato importante. Le altre restano aperte. Se li vedi, **basta un segno di spunta e il seme**; se non li vedi in tre run, anche questo e un dato.

| Visto? | Cosa | Dove nel gioco | Rif. |
|---|---|---|---|
| ☐ | Il Demolitore resta fermo o spinge contro una rovina invece di arrivare a un terrapieno (**corretto**: dopo 2 s senza avvicinarsi lascia perdere il muro) | boss, quando ha un muro tuo entro 12 m e un edificio in mezzo | R-01 |
| ☐ | Il compagno spinge contro un muro o una barricata senza passare, e intanto non rifornisce i rialzi (**R-02 corretto**: i rottami non restano piu sepolti; R-05 aperto) | un rottame dall'altra parte del muro, entro 6 m da te | R-02, R-05 |
| ☐ | Un rottamatore col rottame in spalla va e viene dal boss ogni 10 secondi, con il suono di presa a ogni giro | boss vicino a un edificio o al bordo | R-04 |
| ☐ | Stando a 4-5 m dal cantiere il boss non alza mai la barricata | boss | R-03 |
| ☐ | Il boss smonta una barricata sua (**corretto**) | boss | R-06 |
| ☐ | Esc non chiude le Impostazioni dal menu iniziale (B si); in gioco Esc dalle Impostazioni chiude tutto, B torna alla pausa (**corretto**) | menu | R-13 |
| ☐ | Dopo aver scelto una carta col mouse, il primo Spazio o clic destro non fa niente | tastiera e mouse | R-17 |
| ☐ | La sirena del boss si interrompe a meta | combattimento denso al momento dell'annuncio | R-36 |
| ☐ | Dopo esserti murato dentro, le impronte dell'orda non mostrano la sbarra (**corretto**) | cortile sigillato, tu non al centro | R-26 |
| ☐ | Un rottamatore riportato sull'anello lascia una striscia per un frame (**corretto**, non visto) | orda dispersa | R-07 |
| ☐ | Scatto breve all'avvio del livello dal menu | "Gioca" | R-40 |
| ☐ | Uno scavo non produce il rottame | molti rottami in giro (oltre 60) | R-09 |

Noto da prima: ogni run ha lo **stesso quartiere** (il seme cambia orda e carte, non la mappa; R-16); la cella viola all'angolo sud-ovest e un residuo della parita Unreal (R-28); i valori di boss, Officina e carte **non sono bilanciati**.

## Cosa annotare oltre alle domande della specifica

- **Animazioni dell'ingegnere** (D-060, D-062, solo editor): corsa, corse laterali e indietro con la mira ferma, capriola sullo scatto, affondo sul tool. Resa, ritmo, durata: e la prima volta che qualcuno le vede in movimento.
- **Audio** (D-048): e tutto sintetizzato e nessuno l'ha ascoltato. Volume, fastidio, suoni che mancano o che coprono gli altri.
- **Glifi dei tasti** (D-059): giusti per il tuo controller? Cambiano quando passi al mouse?
- **Fps** con F3 nel momento piu affollato e durante il boss, a 1280x800, e **di notte con l'orda attorno** (il buio costa poco sulla CPU, ma le luci vere non sono mai state viste su un altro PC).
- **Notte e lampioni** (D-058, nuovo, mai giocato da nessuno): il tramonto si nota in tempo? Il bordo della luce si capisce senza spiegazioni? Uscire dalla luce di notte e una scelta tesa o un errore da non ripetere? I lampioni (terza modalita del tool, 3 rottami, massimo 6) cambiano dove combatti, o li ignori? La notte e leggibile sul tuo schermo? Il prezzo e i raggi sono numeri di partenza: **annota se la notte e troppo dura o troppo facile** e in quale minuto.
- Per ogni cosa strana: **seme, minuto di gioco, cosa stavi facendo.**

## Esito

Per il livello: **Continua / Modifica / Scarta**, piu le risposte alle domande della specifica. L'esito guida il punto 6 della roadmap (bilanciamento, secondo livello, Steam Deck) e decide se le correzioni della review si fanno prima o insieme.
