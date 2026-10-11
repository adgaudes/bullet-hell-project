# Restyling grafico: stilizzato ricco, pipeline propria

**Data:** 11 ottobre 2026. **Stato:** specifica approvata a voce dal proprietario sezione per sezione, in attesa della sua revisione scritta. **Decisione collegata:** da registrare in `docs/DECISIONS.md` come D-077 (direzione e roster) e D-078 (camera a tre distanze) al primo commit di implementazione.

## 1. Obiettivo

Portare il gioco a una resa "attuale": texture in alta risoluzione dipinte, modelli con forme morbide e dense, luce e post-produzione decise. Riferimento di resa: **Hades II** (texture dipinte, colori saturi con contrasti caldo/freddo, rim light e glow marcati, dettaglio decorativo dove conta) tradotto in 3D. Riferimento per i personaggi: statuine tozze e morbide con testa e mani grandi, zaino-macchina come seconda silhouette, cuoio/tela/gomma/metallo consumati (reference AI fornite dal proprietario l'11 ottobre 2026, usate solo come ispirazione, mai come asset).

Non è un refactoring del gioco: scene, griglia, collisioni, scheletro e animazioni, logica, tuning e suite di test restano. Cambiano tre strati: la pipeline Blender, gli shader e i materiali Godot, luce e post.

### Cosa il proprietario ha deciso (11 ottobre 2026)

1. Direzione **A, stilizzato ricco** alla Hades II; niente PBR fotografico.
2. Asset al **100% dalla pipeline Blender nostra**; nessun pacchetto esterno, nessuna generazione AI: "dobbiamo dare uno stile nostro".
3. Ordine: **fetta visiva** del cortile di partenza, ambiente prima, poi l'ingegnere; giudizio sulle catture prima di estendere.
4. Personaggi: linguaggio visivo delle reference (tozzi, testa e mani grandi, zaino-macchina, materiali usurati, resa morbida) ma **archetipo nostro**: niente nano barbuto steampunk, niente ingranaggi d'ottone decorativi; attrezzi recuperati dalle infrastrutture del mondo.
5. **Roster fisso, un personaggio per classe**, nessuna scelta di sesso, corporatura o età. Il carattere (rozzi, scalmanati, ubriaconi, sboccati, simpatici) deve leggersi dall'aspetto e dalla postura.
6. Le classi come meccanica non esistono ancora: si definiscono le schede visive adesso, si costruisce solo l'ingegnere, le classi entrano nel gioco dopo il playtest.
7. Camera di gioco con **tre distanze** selezionabili da controller e tastiera.
8. PC a **60 fps** basta; Steam Deck 60 fps. **Preset grafici selezionabili più ogni opzione regolabile una a una**; il preset **Massimo** deve essere davvero bello da vedere, anche a costo di effetti che gli altri preset spengono.

## 2. Roster (schede visive)

Regole comuni, da riportare in `docs/ART_DIRECTION.md`:

- testa circa 1,4x e mani circa 1,5x rispetto al realistico, torso ampio, arti corti, baricentro basso;
- un "secondo profilo" sulla schiena (zaino, botte, cariche, chiave) leggibile da dietro e dai tre quarti alti, cioè dagli angoli reali di gioco;
- attrezzi recuperati dalle infrastrutture del mondo (binari, segnali, tubi, carrozzeria, manometri), mai ingranaggi d'ottone decorativi;
- un vizio visibile per ciascuno; materiali cuoio/tela/gomma/metallo sporco con usura dipinta;
- un colore d'accento forte per personaggio, su elementi visibili da dietro;
- pelle con guance e naso più scuri o arrossati, sopracciglia folte, rughe e cicatrici dipinte: facce vissute, mai lisce.

| # | Classe (asse di gioco) | Chi è | Come si vede che è rozzo e simpatico | Accento |
|---|---|---|---|---|
| 1 | **Ingegnere** (equilibrato, personaggio attuale) | Donna sulla cinquantina, tozza, spalle larghe, naso rotto, capelli grigi legati con un cavo elettrico | Tuta slacciata fino alla vita con canottiera macchiata, sigaro spento in bocca, fiaschetta all'anca, chiave da treno enorme a tracolla, postura a mento alto e pancia in fuori | Arancio |
| 2 | **Guastatore** (scavo esplosivo, terreno) | Ragazzo magro e sdentato, iperattivo, sopracciglia bruciate | Occhiali da saldatore storti, giubbotto gonfio di cariche fatte in casa, pantaloni strappati, orecchie fasciate, bocca sempre aperta a ridere; corre a scatti | Rosso |
| 3 | **Meccanico** (compagno potenziato) | Vecchio enorme, calvo, pancia da birra, braccia da gorilla | Grembiule di gomma, un occhio sostituito da una lente recuperata, mani nere di grasso, bottiglia nella tasca posteriore; passo lento e pesante | Turchese |
| 4 | **Erbacciaia** (terreno che cresce, vegetazione come difesa) | Vecchia minuta e cattiva, gobba, pipa accesa | Cappello di paglia bruciacchiato, botte di distillato in spalla con il tubo che le arriva alla bocca, falce arrugginita, gatto-robot sulla botte; sputa per terra | Magenta |

Nomi propri, lingua dei testi e dosaggio di parolacce e alcol restano aperti (brief: "da definire", con effetto sul rating). Nomi di file e identificatori in inglese: `engineer`, `sapper`, `mechanic`, `weeder`.

## 3. Strato 1: pipeline Blender (`tools/blender/`)

Oggi: `refined.py` costruisce primitive smussate, le unisce, cuoce con Cycles una sola texture albedo 1024 (`EMIT`, con pointiness, AO, grana, macchie, fango) e, per l'ingegnere, una normal map da rilievo procedurale. Diventa una pipeline a tre costruttori che condividono un solo **pittore**.

### 3.1 Pittore (`painter.py`, nuovo)

Nodi Cycles riutilizzabili che producono, per ogni materiale semantico, tre texture cotte: **albedo** dipinta, **normal** in spazio tangente, **maschera ORM** (occlusione, roughness, metallo nei tre canali). Ingredienti della pittura, tutti procedurali e parametrici:

- rampa di colore a gradiente per volume (più chiaro in alto e sulle sporgenze, più scuro e saturo nelle cavità), che dipinge la luce d'ambiente "a mano";
- pennellate direzionali (rumore anisotropo allineato a una direzione per materiale) a bassa frequenza, mai grana fotografica;
- usura sugli spigoli (pointiness) con bordo netto e colore proprio del materiale (metallo chiaro sotto la vernice, trama sotto il cuoio);
- sporco verso terra e nelle giunzioni, macchie a bassa frequenza, ruggine a gradiente dal basso e dai bordi;
- maschera di roughness: stoffa opaca, cuoio semilucido, metallo e gomma più lucidi dove consumati.

Risoluzioni: **2048** per personaggi, boss e prop grandi; **1024** per prop piccoli e rottamatori (sono molti sullo schermo). Tile di superficie 2048, ripetibili (seamless via coordinate toroidali nel bake). Campioni 48 come oggi; tempo stimato 1-3 minuti per asset.

### 3.2 Scultore (`refined.py`, esteso)

Alle primitive attuali si aggiungono operazioni di forma applicate prima dell'unione: **displacement** da rumore per rigonfiamenti e pieghe (stoffa, pancia, muscoli), **lattice** per deformare un volume (naso, guance, schiena curva), **shape asimmetriche** (un lato più basso, una toppa), **Subdivision** a 2-3 livelli dove serve morbidezza, **Decimate** controllato per rientrare nel budget di triangoli. Il risultato resta un'unica mesh con un gruppo di vertici per osso e pesi sfumati (`blends`) su tutte le articolazioni.

### 3.3 Costruttore di tile di superficie (`build_surface_tiles.py`, nuovo)

Genera texture dipinte ripetibili per il mondo, in `godot/assets/textures/surfaces/<name>_{albedo,normal,orm}.png`: `dirt` (terra battuta con sassi), `slabs` (lastre di pietra spaccate con erba nelle fughe), `asphalt` (asfalto rotto), `dug_soil` (terra scavata, cime dei terrapieni), `mud` (fango scuro, celle Lowered), `plaster_brick` (intonaco scrostato su mattoni), `moss`, `bark`, `grass_tufts` (tre ciuffi, alpha), `leaf_cards` (cartelle di fogliame, alpha). Ogni tile ha una variante di colore via uniform in Godot, non via texture.

### 3.4 Costruttori esistenti

`build_character_assets.py`, `build_actor_assets.py`, `build_arena_assets.py` usano scultore e pittore. Le rovine basse, oggi gusci procedurali in shader, ricevono un costruttore proprio (`ruin_shell` in `build_arena_assets.py`: 3-4 varianti di guscio con finestre incassate, corone spezzate, buchi) esportate come `.glb`; la collisione resta il blocco pieno gestito dal codice del quartiere.

Tutte le texture prodotte sono versionate in Git LFS come oggi (`*.png` in `godot/assets/`), importate in Godot con compressione VRAM (BCn) e mipmap.

## 4. Strato 2: shader e materiali Godot

Stessi nomi e stesse uniform per istanza (tinte, impronte, stati delle celle, lotti), nuove uniform per le texture. Il rumore procedurale resta solo per variare le tile fra celle e istanze.

- `terrain_cell.gdshader`: tile per cella scelta dal seme fra `dirt`, `slabs`, `asphalt` (indice per istanza); cima del terrapieno `dug_soil` con orlo chiaro dipinto; fianchi a strati con rampa caldo→scuro verso il basso; celle Lowered con `mud` e riflesso. Normal e ORM applicate.
- `ruin_overgrown.gdshader`: diventa il materiale dei gusci `.glb` con `plaster_brick`, macchie di umidità dall'alto, `moss` sulle superfici rivolte al cielo (per normale), finestre incassate scure; modalità `batched` conservata per corone e tondini.
- `ruins_ground.gdshader` e `ruins_ground.gdshaderinc`: suolo del quartiere con le stesse tile e transizioni dipinte fra strada, lastre e terra.
- `grass_blades.gdshader`: texture `grass_tufts` a tre varianti, punte più chiare, ondeggiamento esistente, tinta per istanza.
- `foliage.gdshader`: cartelle `leaf_cards` per cespugli e chioma degli alberi, con traslucenza semplice e tinta.
- `env_baked.gdshader` e `actor_paint.gdshader`: albedo + normal + ORM, **rim light** controllata da uniform (colore e larghezza, legata al colore del sole e della notte), contorno esistente come `next_pass`.
- `rusted_metal.gdshader`: sostituito dalla pittura cotta dove il modello è nostro; resta per i pezzi dinamici (frammenti).

Shader nuovi: nessuno di base; un `sky_painted.gdshader` per il cielo a gradiente dipinto (vedi 5).

## 5. Strato 3: luce, post-produzione e preset grafici

### 5.1 Resa

In `OvergrownArena._make_environment()` e nel ciclo giorno/notte (`DayNightCycle`), ritarati sulla nuova palette:

- sole caldo basso (25-30°), ombre tinte blu-viola tramite colore dell'ambiente e del cielo;
- cielo a gradiente dipinto (`sky_painted`, tre colori interpolati dal ciclo) al posto del procedurale; nebbia che prende il colore del cielo, prospettiva aerea;
- SSAO più morbido (raggio più ampio, intensità più bassa), glow su emissive e alte luci calde con soglia, vignetta leggera, grading di contrasto e saturazione via `adjustment_*`;
- rim light sugli attori nello shader, nessuna luce aggiuntiva;
- tramonto e notte: palette blu-violacea con bioluminescenza calda come da direzione artistica.

Il preset Massimo accende in più: **SDFGI** (illuminazione globale) o, se costa troppo o sfarfalla con la camera isometrica, **SSIL**; **nebbia volumetrica** leggera per i raggi del tramonto e i coni dei lampioni di notte; ombre del sole a **4 split 4096**; MSAA 4x più FXAA; glow a più livelli. Questi effetti sono vietati negli altri preset.

### 5.2 Preset grafici e opzioni singole (`GameSettings`, `SettingsMenu`)

Oggi le Impostazioni hanno limite di fps, VSync, MSAA, risoluzione/finestra, scala di rendering, volumi, inversione assi. Si aggiungono:

| Opzione | Valori | Note |
|---|---|---|
| Preset | Steam Deck, Basso, Medio, Alto, **Massimo**, Personalizzato | Scegliere un preset imposta tutte le voci sotto; toccarne una porta a Personalizzato |
| Qualità ombre | Off, Bassa (1 split 1024), Media (2 split 2048), Alta (4 split 4096) | |
| Occlusione ambientale | Off, Bassa, Alta | SSAO |
| Illuminazione globale | Off, SSIL, SDFGI | Solo Alto e Massimo |
| Glow | Off, Basso, Alto | |
| Nebbia volumetrica | Off, On | Solo Massimo |
| Qualità texture | Bassa (mip +1), Alta | Via `texture_mipmap_bias` |
| Densità vegetazione | Bassa, Media, Alta | Istanze dell'erba e dei detriti |
| Antialiasing | Off, MSAA 2x, 4x, 8x, + FXAA/TAA | MSAA esistente, si aggiunge il filtro schermo |
| Scala di rendering | 0,5-1,0 e upscaling FSR 2 opzionale | Scala esistente |
| Limite fps | 30, 60, 90, 120, 144, **165, 240**, nessuno | Esistente, esteso a 240 (la fisica resta a 120 Hz con interpolazione: sopra i 120 fps migliora solo la fluidità della camera); default **60** |

Preset Steam Deck: MSAA off + FXAA, ombre Bassa, SSAO Bassa, GI off, glow Basso, volumetrica off, texture Alta, vegetazione Media, scala 0,85 con FSR, fps 60. Selezionato automaticamente al primo avvio se Godot riconosce il Deck (`OS.has_feature("steamdeck")` o nome del dispositivo), altrimenti parte Alto; Massimo è una scelta esplicita. Il menu resta navigabile a controller con A/B e glifi dei tasti, come il resto.

Le opzioni grafiche si salvano in `user://settings.cfg` con le regole esistenti (atomico, versione, chiavi sconosciute conservate).

## 6. Camera a tre distanze

- `IsometricCameraRig`: tre preset del braccio, vicino 11 m, normale 15 m (attuale), lontano 20 m; pitch e FOV invariati; passaggio interpolato in circa 0,25 s con easing.
- Input: azione `camera_zoom_cycle` su **Y** del controller (libero) e **C**; azioni `camera_zoom_in` e `camera_zoom_out` sulla rotellina del mouse. Tastiera/mouse e controller restano equivalenti.
- Il preset scelto si salva nelle Impostazioni (`camera_distance`); HUD con il glifo del tasto fra i comandi di gioco.
- Vincolo: l'anello di comparsa dei nemici e gli indicatori a bordo schermo si calcolano dalla finestra visibile; con il preset lontano l'anello si allarga di conseguenza, così i nemici non appaiono in vista. Test dedicato.

## 7. Fetta visiva e ordine dei lavori

La fetta è il **cortile di partenza del quartiere**, dalla camera di gioco, giorno, tramonto e notte. Ogni punto è un commit con gate verde, catture e benchmark:

1. Pipeline: pittore, scultore, tile di superficie; benchmark di riferimento prima di toccare il gioco.
2. Suolo e terrapieni con tile dipinte.
3. Rovine basse come gusci `.glb` dipinti.
4. Vegetazione (erba, cespugli, albero, fiori d'accento) e prop esistenti ridipinti.
5. Luce, cielo, post; preset grafici e opzioni singole; ritaratura di tramonto e notte.
6. Camera a tre distanze.
7. Catture prima/dopo e benchmark: **giudizio del proprietario sull'ambiente** (Continua / Modifica / Scarta).
8. Ingegnere: forma (12-18k triangoli, stesso scheletro e animazioni), pittura 2K, oggetti di carattere (sigaro, fiaschetta, chiave da treno, cinghia con attrezzi recuperati, toppe, accento arancio su manicotti e cinghia), postura (offset di colonna e testa nelle animazioni esistenti), idle di carattere se ricavabile dalle clip CC0 o Mixamo già scaricate; catture: **giudizio del proprietario**.
9. Misura sul Deck del proprietario con il Debug Menu (F3) e la build Windows riesportata.

Fuori da questa specifica, lavori successivi con la stessa ricetta: compagno, rottamatori, boss, Trivella, torri perimetrali, ferrovia e i suoi prop, detriti, acqua, gli altri tre personaggi del roster.

## 8. Budget e misure

| Misura | Oggi (PC, 11 ottobre 2026) | Soglia della fetta |
|---|---|---|
| Frame su PC, preset Alto | 8,3 ms | 12 ms (60 fps con margine) |
| Frame su PC, preset Massimo | n/d | 16 ms |
| Frame su Steam Deck, preset Steam Deck | non misurato | 16 ms (60 fps) |
| Draw call | 350 | 450 (Alto), 600 (Massimo) |
| Primitive | 1,95 M | 3 M (Alto), 4 M (Massimo) |
| Memoria texture (VRAM compressa) | n/d | 300 MB |

Il benchmark esistente (`tests/tools/benchmark_arena.gd`) si estende con il preset come argomento e con la memoria texture. Se una soglia salta, si ridimensiona quel passo (texture 1K, meno triangoli, LOD, meno istanze) prima di proseguire.

## 9. Verifica

- Tutte le suite esistenti restano verdi: collisioni, logica e tuning non cambiano.
- Nuova suite `tests/restyle_tests.gd`: texture presenti e compresse; uniform per istanza ancora funzionanti (stati delle celle, impronte, tinte dei lotti); preset grafici applicati e salvati, passaggio a Personalizzato; preset Deck scelto automaticamente quando il feature tag c'è; camera a tre distanze (ciclo, rotellina, salvataggio, anello di comparsa allargato).
- `tests/tools/inspect_model.gd` elenca anche le ORM e i conteggi di triangoli.
- Catture prima/dopo da inquadrature fisse in `output/restyle/` (`overview`, `start`, `wall_close`, `visit_1`, `combat`, `dusk`, `night_lamps`) e `output/restyle/character/` (fronte, retro, lato, in gioco, strisce delle animazioni).
- Gate unico `tools/godot/Invoke-GodotChecks.ps1` verde prima di ogni commit.

## 10. Rischi

- **Steam Deck**: primitive e texture crescono; la misura reale arriva solo al punto 9 e dipende dal proprietario. Il preset Deck con scala 0,85 e FSR è la rete di sicurezza.
- **SDFGI con camera isometrica**: può sfarfallare quando la camera si sposta; se succede, il Massimo usa SSIL.
- **Scultura procedurale dei volti**: il rischio più alto per la resa; se non basta, la specifica prevede un ritocco manuale del proprietario in Blender (MCP Blender già installato) sulla sola testa, con il resto dalla pipeline.
- **Tempo di bake**: 2K e tre mappe per asset portano i bake a qualche minuto; accettabile perché si rifanno solo quando cambia il costruttore.
- **Rovine come mesh**: la pianta del quartiere non cambia, ma il costo di memoria e le draw call salgono; misurato al punto 3.

## 11. Documenti da aggiornare

`docs/ART_DIRECTION.md` (nuova direzione, regole comuni e schede del roster), `docs/DECISIONS.md` (D-077 restyling e roster fisso, D-078 camera a tre distanze), `docs/PROJECT_ROADMAP.md` (stato operativo), `docs/MIGRATION_STATUS.md` (diario), `docs/PLATFORM_AND_INPUT.md` (preset grafici, nuove azioni di input), `docs/GODOT_WORKFLOW.md` (pittore, tile, tempi di bake), `docs/INDEX.md` (questa specifica).
