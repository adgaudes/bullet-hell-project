# Playtest del proprietario — 14 ottobre 2026

**Cosa:** build Windows del 14 ottobre (`LocalBuilds/Prototype01-Godot-Win64/`, include l'audit), livello 1 (quartiere), **solo tastiera e mouse**, una partita breve. Impostazioni salvate: preset **Massimo**, camera lontana. Dal log: morte a 176 s, prima della notte.

**Esito: Modifica.** Il gioco e giudicato piatto e poco coinvolgente, la grafica scialba. Il ciclo di base (orda, scavo, boss) non e scartato, ma serve un salto di qualita su gameplay, grafica, audio e interfaccia prima del prossimo playtest.

## Osservazioni e causa trovata nel codice

| # | Osservazione del proprietario | Causa (analisi del 14 ottobre) | Area |
|---|---|---|---|
| O-01 | Il giocatore "muore subito", deve avere degli HP | Gli HP ci sono (5, `run_tuning.gd`), ma con un nemico a contatto se ne perde 1 ogni 0,8 s: circa 3 s per morire, 1,6 s di notte al buio. Nessuna spinta all'indietro, lo scatto non protegge, la barra (fulmini da 22 px in alto a sinistra) non si nota | gameplay |
| O-02 | Non si capisce cosa permetta di deformare il terreno, nessun indicatore della disponibilita | Scavare e gratis e riempie lo zaino di terra (60 m³); rialzare la consuma; il lampione costa 3 rottami. L'indicatore numerico dello zaino esiste nel HUD ma `set_pack` non e mai chiamato: **non compare mai**. Resta solo la barretta sullo zaino del modello, illeggibile dalla camera | gameplay, HUD |
| O-03 | Scavando troppo si resta in una buca senza uscita | Unico limite: altezza assoluta −2,5 m. Una buca oltre circa 1,25 m ha pareti piu ripide della pendenza percorribile (0,8); niente salto, lo scatto e piano; col mouse si scava sotto i piedi. Nessuna protezione | gameplay |
| O-04 | Il proiettile parte dalle spalle se il nemico e dietro | L'arma mira da sola al nemico piu vicino e spara dal centro del busto in qualsiasi direzione; il corpo e la pistola seguono il mouse, non il bersaglio | combattimento, animazione |
| O-05 | Gameplay piatto e banale; servono nuove armi, come ottenerle, nuove funzioni per le armi | Una sola arma (chiodatrice automatica), nessuna struttura per piu armi; 17 carte, quasi tutte percentuali | design |
| O-06 | Frecce viola a terra sgradite | Sono le "impronte dell'orda" (`flow_preview.gd`): compaiono per 3 s dopo ogni pennellata e col terremoto | grafica, leggibilita |
| O-07 | Grafica scialba: niente occlusione ambientale, profondita, ombre "completamente assenti" | Su Massimo ombre, SSAO e SDFGI sono attivi nel codice: nessun percorso le spegne. Probabili cause percettive: sole basso con ombre che cadono lontano dalla camera, luce ambiente piatta e forte, ombre morbide PCSS, erba senza ombra, rovine basse. **Da verificare con una cattura a ombre accese e spente** | grafica |
| O-08 | Texture del terreno unite male, "quadratoni", qualita generale bassa | Il detiling ruota ogni cella da circa 8,3 m in modo casuale e la sfuma su soli 0,5 m: griglia visibile. La texture lastricato e una griglia 3x3 di lastre che si spezza a ogni cella. La pittura scrive un solo strato per vertice senza miscela: bordi a scalino | grafica |
| O-09 | Erba troppo rada e grezza | Ciuffi da 12 triangoli alti 0,4 m, circa 1,5 per m², normali tutte verso l'alto, senza ombra. SimpleGrassTextured installato ma spento | grafica |
| O-10 | Edifici in rovina troppo basici e primitivi | Tutti scatole procedurali (un solo BoxMesh scalato), 2,5-4,5 m, senza modelli | grafica |
| O-11 | Impostazioni: testo sfalsato; vanno divise in sezioni | Etichette da 18 px allineate in alto accanto a menu da 40 px con testo da 22; interruttori a tutta larghezza fuori colonna; etichette lunghe oltre i 280 px. Una sola lista lunga, senza schede | UI |
| O-12 | Sfondo animato del menu principale da migliorare di molto | Tre strati di poligoni 2D in parallasse su un cielo a gradiente, 40 granelli di polvere | UI, grafica |
| O-13 | Officina troppo confusionaria | Una lista di 8 righe con testo spostato di 10 spazi, livello scritto due volte, tutta la riga colorata, nessuna categoria ne pannello di dettaglio, acquisto immediato senza conferma, non spiega cosa sono i rottami | UI |
| O-14 | Suoni banali, nessuna musica | Niente musica per scelta (D-048); effetti dal bundle Sonniss (D-084) | audio |

## Domande della specifica non coperte

La partita breve non ha raggiunto il boss, la notte, la ferrovia ne il controller. Le domande 1-28 restano aperte per il prossimo playtest.

## Piano proposto (agente, 14 ottobre 2026)

**Ordine scelto dal proprietario (D-089): prima il blocco 2 (grafica), poi 1, 3, 4.** La ricerca della musica (blocco 4) parte subito in parallelo.

**Blocco 1 — gioco leggibile e giusto** (subito, senza decisioni aperte tranne la mira):
- O-01 salute: barra grande con numero, spinta dei nemici al colpo, scatto con invulnerabilita, schermo che segnala il danno.
- O-02 terra: indicatore dello zaino e della modalita corrente nel HUD, accanto al tool.
- O-03 buca: lo scavo non abbassa il terreno sotto i piedi oltre la pendenza percorribile, piu una via d'uscita se si resta bloccati.
- O-04 sparo: dalla canna della pistola; mira manuale e automatica commutabili con un tasto in qualsiasi momento (D-089).
- O-06 frecce viola: spente di default.
- O-11 impostazioni: schede Grafica / Audio / Controlli, colonne allineate.

**Blocco 2 — grafica** (catture da giudicare a ogni passo): cattura di verifica delle ombre (O-07), poi passata luce e occlusione; terreno con texture nuove, detiling e miscela tra strati (O-08); erba (O-09, valutare l'instancer di Terrain3D e SimpleGrassTextured); rovine in Blender a moduli (O-10); sfondo del menu come scena 3D vera (O-12); Officina ridisegnata a categorie con dettaglio (O-13).

**Blocco 3 — profondita di gioco** (O-05): progettare col proprietario armi multiple, come si ottengono e come evolvono, prima di scrivere codice.

**Blocco 4 — audio** (O-14): musica e passata sugli effetti; servono fonti gratuite con licenza verificata.

## Avanzamento

- **14 ottobre, notte, blocco 2 in parte (D-090):** O-06 frecce spente; O-07 luce (nebbia del Massimo, ambiente, AO, GI); O-08 terreno con texture CC0 e bordi sfumati; O-09 prato a particelle; O-10 rovine a moduli con texture CC0 e normal map. Restano O-12 (menu), O-13 (Officina), alberi e finestre. Catture in `output/lighting/`.
- **14 ottobre, notte, secondo giro:** O-12 menu con sfondo 3D (quartiere al tramonto, `MenuDiorama`); O-13 Officina a carte per sezione con dettaglio; finestre vere nelle rovine; chiome degli alberi piene. Blocco 1 (D-091): O-01 vita 10, spinta, scatto intoccabile, vita in numero, bordo rosso; O-02 indicatore della terra; O-03 rampa d'uscita; O-04 mira commutabile (V, rotella, R3) e chiodo dalla canna; O-11 impostazioni a schede. Musica: candidati scaricati in `Videogame-assets/music-candidates/` (fuori repo), aspetta la scelta del proprietario. **Resta: O-05 armi (blocco 3, da progettare col proprietario) e l'integrazione della musica scelta.**
