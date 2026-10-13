# Restyling dell'Ingegnere (piano 2 del restyling grafico) — design

Data: 13 ottobre 2026. Stato: approvato a voce dal proprietario sezione per sezione; da rivedere per iscritto prima del piano.
Contesto: `docs/superpowers/specs/2026-10-11-visual-restyle-design.md` (punto 8), D-077, scheda in `docs/ART_DIRECTION.md` (roster, riga 1). Decisione da registrare: **D-088**.

## 1. Obiettivo e criteri di successo

Sostituire l'ingegnere attuale (D-071/D-074: primitive smussate unite, elmetto, occhialoni, respiratore, tuta arancione, 28,3k triangoli) con la donna della scheda D-077, **di qualità "modellata a mano in Blender"**: forme organiche continue, topologia pulita che si piega bene, dettaglio scolpito, pittura alla Hades II.

Successo = giudizio **Continua** del proprietario in due momenti:

1. sulla **forma in argilla** (giro a 360°, primo piano del viso, vista dalla camera di gioco), prima di pittura e rig;
2. sulle **catture finali** in gioco, senza regressioni misurabili (sezione 6).

Vincoli fissi: stesso scheletro (nomi delle ossa) e stesse 13 clip; capsula di collisione invariata (raggio 0,34 m, altezza 1,76 m); tutto rigenerabile da script Blender, nessun asset esterno, nessuna AI (D-077); draw call del giocatore invariate.

## 2. Il personaggio

Decisioni del proprietario del 13 ottobre 2026: **caricatura forte (cartoon)**, **tuta blu stinto con accento arancio**.

- **Proporzioni**: circa **3 teste** di altezza; altezza totale come oggi; testa **1,7x**, collo quasi assente, spalle larghe, **pancia tonda in fuori**, gambe corte e grosse, stivaloni; **mani a muffola enormi** (pollice e tre dita grosse).
- **Viso**: naso grosso, storto (rotto) e arrossato; mento alto e sporgente; occhi piccoli socchiusi, sguardo di sfida; sopracciglia grigie folte; rughe e una cicatrice; **sigaro spento** all'angolo di un ghigno.
- **Capelli**: grigi, a ciocche scolpite (massa stilizzata alla Hades, non fili), raccolti in una crocchia legata da un **cavo elettrico arancio** con lo spinotto che penzola.
- **Abiti**: tuta da lavoro **blu-petrolio stinta**, abbassata in vita con le maniche annodate davanti, toppe sulle ginocchia; **canottiera bianco-sporca** macchiata d'olio, tesa sulla pancia; **manicotti e guantoni arancio**; stivaloni a punta rinforzata.
- **Oggetti di carattere**: **chiave da treno enorme** in diagonale sulla schiena con **cinghia arancio** (seconda silhouette); **fiaschetta** all'anca; cintura con attrezzi recuperati (pinza, nastro, chiavi).
- **Zaino-officina**: rifatto con pezzi recuperati (tanica, manometro, tubi); la **sacca di terra con la striscia indicatore** (D-086) resta sotto lo zaino con lo stesso comportamento. Spariscono elmetto, occhialoni, respiratore, antenna con bandierina.
- **Lampada**: una **lanterna da segnale ferroviario** sulla spalla al posto della lampada dell'elmetto (superficie `lamp`).
- **Chiodatrice**: rifatta nello stesso stile, come attrezzo da binari recuperato; punta nella stessa posizione rispetto alla mano.
- **Postura**: **mento alto e pancia in fuori** su tutte le animazioni (sezione 4.3). Idle di carattere solo se ricavabile dalle clip CC0 o Mixamo già presenti; altrimenti rimandato.

Palette: blu-petrolio desaturato per la tuta, bianco caldo sporco per la canottiera, arancio saturo (accento) su manicotti, guanti, cinghia, cavo dei capelli e dettagli dello zaino visibili da dietro, pelle calda con guance e naso arrossati, grigio freddo per i capelli, cuoio bruno, metalli scuri consumati.

## 3. Pipeline Blender (`tools/blender/`)

### 3.1 `sculpt.py` (nuovo): modellazione a gabbia

Modulo senza dipendenze dal personaggio, testabile da solo.

- **Gabbie a quadrilateri**: `loft(rings)` costruisce un tubo da sezioni ellittiche (centro, raggi, rotazione, numero di lati costante) con chiusure a ventaglio o a polo; `mirror_x` per le parti simmetriche; unione di gabbie con ponti fra anelli (busto-braccia, polso-dita).
- **Superfici di suddivisione** (Catmull-Clark) a livelli scelti per la versione bassa e quella alta; **crease** sugli spigoli che devono restare vivi (orli della tuta, suola, bordi delle toppe).
- **Pennelli** con caduta morbida (smoothstep sul raggio), applicati ai vertici dopo la suddivisione: `grab` (sposta), `inflate` (lungo la normale), `pinch` (verso una linea), `crease_line` (incisione lungo una polilinea: cuciture, rughe, solchi fra le ciocche), `fold_noise` (pieghe da rumore anisotropo per la stoffa). Deterministici (seme fisso).
- Le gabbie usano un numero di lati e di anelli tale che le articolazioni (spalle, gomiti, polsi, anche, ginocchia, collo) abbiano **almeno tre anelli** per piegarsi bene.

### 3.2 `build_engineer.py` (nuovo): il personaggio

Separato da `build_character_assets.py` (722 righe), che conserva `Skeleton`, il riporto delle clip Quaternius e Mixamo, la sacca (`build_pack_sack`) e l'export; `build_engineer.py` li importa.

- Dalla stessa gabbia escono **due versioni**: **alta** (suddivisione 3-4 più pennelli fini: rughe, cuciture, pieghe, trama delle ciocche, grana della pelle e del cuoio) e **bassa** (suddivisione 1-2 più i soli pennelli di forma), **20-28k triangoli** complessivi con accessori.
- Accessori duri (chiave da treno, lanterna, zaino, chiodatrice, fiaschetta, attrezzi della cintura) con `refined.py` (`RefinedBuilder`), ciascuno rigido su un osso.
- Il vecchio ingegnere resta ricostruibile come `player_engineer_d074` (solo da script, non esportato nel gioco); il blocky resta `player_engineer_blocky`.

### 3.3 Cottura e pittura (`painter.py`, esteso)

- **Da alta a bassa**: normal map in spazio tangente e occlusione cotte dalla versione alta sulla bassa (selected-to-active con estrusione della gabbia di cottura), **2048**.
- **Albedo dipinta 2048** per regione semantica (pelle, tuta, canottiera, capelli, cuoio, metallo, accento arancio) con gli ingredienti di `painter.py` già in uso: rampa a gradiente per volume, pennellate direzionali a bassa frequenza, usura sugli spigoli, sporco verso terra, macchie (olio sulla canottiera, fango sugli stivali); ORM coerente (stoffa opaca, cuoio semilucido, metallo consumato lucido).
- **Un solo atlante** per tutto il personaggio; più materiali solo dove il codice li sostituisce (`suit`, `lamp`, sacca e `pack_gauge`), così le draw call restano quelle di oggi.

### 3.4 Scheletro e pesi

- `Skeleton` riproporzionato a 3 teste (gambe più corte, testa e mani più grandi, spalle più larghe), con la stessa regola di D-060: lunghezze diverse, stesse direzioni e rollio, traslazione del bacino scalata con le gambe. Le 13 clip restano valide.
- **Pesi automatici** di Blender (armatura con pesi automatici) sul corpo organico, poi normalizzati e limitati a 4 ossa per vertice; ritocco con le bande di `blends` (D-074) solo dove le automatiche sbagliano. Accessori rigidi sul proprio osso.

### 3.5 Anteprime

`render_turntable.py` (nuovo) rende in background una versione (argilla o dipinta) in `output/engineer/<variante>/`: 8 viste attorno al modello, primo piano del viso, vista dall'angolo della camera di gioco. Usato a ogni iterazione della forma e per il punto di controllo.

## 4. Integrazione nel gioco

### 4.1 File e nomi

Stesso `godot/assets/models/player_engineer.glb`, stesse convenzioni: superficie `suit` (tuta, materiale costruito dal codice con texture, normal e rim), superficie `lamp` (lanterna), nodo `PackSack` con materiale `pack_gauge`; le altre superfici tengono il materiale importato più il contorno (`ActorModel.outline_remaining_surfaces`).

### 4.2 Colore degli stati

Oggi `BODY_COLOR_LINEAR` (arancione) moltiplica la texture della tuta e cambia per scatto (`dash_color_linear`), ricarica dello scatto (`dash_cooldown_color_linear`) e colpo. Su una tuta blu dipinta la moltiplicazione la sporcherebbe. Nuova regola:

- tinta di base della tuta **bianca neutra** (il blu sta nella texture);
- stati espressi come **emissione** del colore di stato sulla superficie `suit` (scatto: ciano acceso; colpo: lampo chiaro breve), e la ricarica dello scatto come **scurimento** (moltiplicazione verso il grigio), che su qualunque colore resta leggibile;
- `_set_body_color` / `_set_state_color` mantengono la firma; cambia l'implementazione.

### 4.3 Postura

Un modificatore dello scheletro sul modello di `HipTwistModifier` (`PostureModifier`) aggiunge dopo l'animazione una rotazione costante: colonna indietro (pancia in fuori) e collo/testa in su (mento alto), con ampiezze esportate. Spento durante la morte; compatibile con la mira (il petto resta rivolto dove si mira).

### 4.4 Proporzioni

Capsula invariata. Da verificare e, se serve, riallineare: altezza della bocca della chiodatrice (`muzzle_height`), posizione della sacca, origine dell'anteprima del pennello, inquadratura delle tre distanze della camera.

## 5. Verifiche

- **Blender**: autoverifica da riga di comando sul `.glb` esportato: triangoli 20-28k, corpo senza bordi aperti, stessi nomi delle ossa, 13 clip, superfici `suit` e `lamp` e nodo `PackSack` presenti, UV dentro l'atlante.
- **Godot**: `character_animator_tests` (postura applicata, assente nella morte, mira invariata); `player_tests` (tre stati di colore distinguibili sulla tuta, sacca e striscia collegate); gate completo `tools/godot/Invoke-GodotChecks.ps1` verde.
- **Catture**: `output/engineer/before/` (modello attuale), `output/engineer/clay/` (punto di controllo), `output/engineer/` finale: fronte, retro, fianco, vista di gioco, viso, strisce di corsa, scavo e capriola, notte con la lanterna accesa.

## 6. Budget e misure

| Misura | Riferimento | Soglia |
|---|---|---|
| Triangoli del giocatore | 28,3k (D-074) | 20-28k |
| Texture | albedo, normal, ORM 1024 | albedo, normal, ORM 2048 |
| Draw call del giocatore | attuali | invariate |
| Frame su PC, preset Alto, 70 nemici (`benchmark_arena.gd`) | misurato prima di iniziare | +0,3 ms al massimo |
| Primitive totali | misurate prima di iniziare | +3 % al massimo |

Steam Deck non misurabile dall'agente: resta nel punto 9 della spec del restyling.

## 7. Ordine dei lavori

Branch e worktree propri (`feature/engineer-restyle`). Ogni passo è un commit con verifica.

1. Misure di riferimento e catture del "prima"; `sculpt.py` e `render_turntable.py` con autoverifica.
2. Gabbia e forma: corpo, viso, capelli, abiti, oggetti, zaino, chiodatrice; iterazioni guardando le anteprime. **Stop: giudizio del proprietario sull'argilla** (Continua / Modifica / Scarta).
3. Cottura da alta a bassa e pittura.
4. Scheletro riproporzionato, pesi, export; autoverifica Blender.
5. Integrazione nel gioco: colore degli stati, postura, proporzioni; test.
6. Catture finali, misure, gate; documenti (D-088, `ART_DIRECTION.md`, `PROJECT_ROADMAP.md`, `MIGRATION_STATUS.md`). **Giudizio del proprietario sulle catture.**

## 8. Fuori da questa specifica

Idle di carattere nuovo (oltre le clip esistenti), espressioni facciali animate, vignetta dell'intro, gli altri tre personaggi del roster, compagno, nemici e boss con la stessa tecnica.

## 9. Rischi

- **Pesi automatici** su una forma cartoon con pancia e mani grandi: possono fallire (Blender lo segnala) o compenetrare; rimedio previsto con le bande `blends` e, al limite, gabbie più semplici sulle articolazioni.
- **Clip su proporzioni cartoon**: braccia corte con mani grandi possono compenetrare il corpo nella mira e nello scavo; si verifica sulle strisce di movimento e si corregge con offset delle spalle nel modificatore di postura.
- **Leggibilità dalla camera alta**: la tuta blu è meno squillante dell'arancione; l'accento arancio su schiena e spalle deve bastare, si giudica sulla vista di gioco già in argilla (silhouette) e poi dipinta.
- **Qualità "a mano" da script**: è il rischio principale; il punto di controllo sull'argilla serve a scoprirlo prima di investire su pittura e rig.
