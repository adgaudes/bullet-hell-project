# Indice dei documenti

**Scopo:** trovare il documento giusto senza leggerli tutti. Leggere qui la riga pertinente, poi aprire solo i file indicati.

**Manutenzione obbligatoria:** chi crea, rinomina, archivia o cambia di stato un documento aggiorna questo indice nello stesso commit. Una riga per file, al massimo due frasi.

Legenda stato: **vivo** = aggiornato e autorevole; **riferimento** = stabile, si consulta quando serve; **storico** = non descrive piu il presente, non seguirlo come istruzione.

## Per iniziare una sessione

| File | Contenuto | Leggilo quando | Stato |
|---|---|---|---|
| `docs/MIGRATION_STATUS.md` | Stato corrente, ultimo lavoro fatto, prossimo passo concreto, cosa aspetta il proprietario | **sempre per primo** | vivo |
| `AGENTS.md` | Regole operative per tutti gli agenti: engine, limiti, autonomia, qualita, Git | prima di una modifica sostanziale | vivo |
| `CLAUDE.md` | Istruzioni specifiche per Claude (autonomia, consegna, delega a Codex) | caricato automaticamente | vivo |
| `README.md` | Presentazione breve del progetto e link principali | per orientarsi da zero | vivo |

## Lavoro tecnico su Godot

| File | Contenuto | Leggilo quando | Stato |
|---|---|---|---|
| `docs/GODOT_WORKFLOW.md` | Comandi verificati (check-only, test, cattura, export), trappole reali, uso dell'editor | prima di eseguire qualunque comando Godot | vivo |
| `docs/GODOT_PARITY_CHECKLIST.md` | Ogni funzione del prototipo Unreal con la sua controparte Godot e l'evidenza | per sapere dove sta una funzione o se e verificata | riferimento |
| `docs/GODOT_MIGRATION_ANALYSIS.md` | Analisi della migrazione: inventario Unreal, architettura Godot, mappature tecniche, piano in 10 fasi | per capire perche il codice e strutturato cosi | riferimento |
| `docs/DECISIONS.md` | Registro delle decisioni (D-001…), con stato e motivazione | prima di cambiare una scelta gia presa; per registrarne una nuova | vivo |
| `docs/PLATFORM_AND_INPUT.md` | Requisiti Steam Deck, parita controller/tastiera, schema input, impostazioni grafiche richieste | per input, controlli, impostazioni, Steam Deck | vivo |
| `docs/TOOLS_AND_LICENSES.md` | Strumenti installati, versioni, licenze, strumenti rimandati | prima di installare o aggiornare un tool | vivo |
| `tools/blender/build_arena_assets.py` | Generatore degli asset Blender dell'arena; convenzioni di scala, assi e materiali in testa al file (non e un documento) | prima di creare o modificare un modello | vivo |
| `tools/blender/painter.py` | Pittore condiviso del restyling (D-077): grafi Cycles per albedo dipinta, normal e ORM, coordinate toroidali per le tile; `selftest_painter.py` lo verifica in 20 s | prima di toccare la pittura dei modelli o delle tile | vivo |
| `tools/blender/build_surface_tiles.py` | Tile dipinte e ripetibili del mondo (ground, walls, plants) come `Texture2DArray`, con gli `.import` | prima di aggiungere o cambiare una tile | vivo |
| `tools/blender/build_character_assets.py` | Generatore dei personaggi con scheletro e animazioni (D-060): riproporziona lo scheletro CC0 di `third_party/quaternius_ual/`, pezzi rigidi, export `.glb`; convenzioni in testa al file (non e un documento) | prima di creare o modificare un personaggio animato | vivo |
| `tools/audio/build_sfx.py` | Effetti sonori dal bundle Sonniss (D-084): ricette per id (sorgente, taglio, intonazione, strati), mix e OGG in `godot/assets/audio/sfx/`, anteprima in fila | prima di cambiare o aggiungere un suono | vivo |
| `tools/godot/Invoke-GodotChecks.ps1` | Gate di qualita unico (non e un documento: commento in testa al file) | prima di dichiarare finito un lavoro | vivo |

## Design e gameplay

| File | Contenuto | Leggilo quando | Stato |
|---|---|---|---|
| `docs/COMPANION_SLICE_SPEC.md` | Primo compagno macchina: loop scava-raccogli-paga-difendi, regole e valori, domande di playtest | per lavorare sul compagno | vivo |
| `docs/PROGRESSION_SPEC.md` | Progressione nella run: esperienza, level-up con tre upgrade, rarita, logica di estrazione (approvata) | per upgrade, armi, pezzi dei compagni | vivo |
| `docs/PROMISE_A_PROTOTYPE_SPEC.md` | Prototipo della promessa A: cortile, orda, chiodatrice, level-up, upgrade, scala futura dell'arena, domande di playtest | per lavorare sulla run, sui nemici o per il playtest | vivo |
| `docs/CAMPAIGN_STRUCTURE_SPEC.md` | Struttura di campagna (D-040, D-041): livelli, boss, upgrade di livello e permanenti, Officina, prima campagna minima, domande al proprietario (risposte per default in D-066) | per livelli, boss, Officina, profilo permanente | vivo |
| `docs/RAILWAY_LEVEL_SPEC.md` | Livello 2, la ferrovia (D-067): corridoio rettangolare con fascia di binari, treno che spiana, saltatori, boss Trivella, catalogo e mappa di campagna (D-066), suite e catture | per lavorare sul livello 2, sul treno, sulla Trivella o sulla campagna | vivo |
| `docs/DAY_NIGHT_SPEC.md` | Ciclo giorno/notte (D-058): una notte per livello, nemici piu forti al buio, luce di torcia, faro e lampioni piazzabili, architettura, tappe e verifica; approvata, non implementata | per lavorare su notte, luce o lampioni | vivo |
| `docs/DAY_NIGHT_PLAN.md` | Piano di implementazione della tappa 1 del ciclo giorno/notte: punti di aggancio verificati nel codice, addon valutati, unita nuove (`DayNightCycle`, `LightField`), modifiche per file, casi di test, ordine dei commit | per capire come sono fatte le due tappe (implementate il 9 ottobre 2026; i lampioni in `LampField`) | vivo |
| `docs/FEATURE_IDEAS.md` | Backlog creativo: 10 idee per differenziare il gioco dai survivor (nemici che smontano le mura, eventi che deformano l'arena, fusione dei compagni, piazzola di estrazione...), con costo e priorita; nessuna approvata | quando si sceglie cosa prototipare dopo un playtest | vivo |
| `docs/TERRAIN_SYSTEM.md` | Visione e regole della trasformazione del terreno, rilievo continuo della tappa A (cosa c'e, misure, gate), terreno volumetrico rimandato | per qualunque cosa tocchi il terreno | vivo |
| `docs/TERRAIN_MIGRATION_MAP.md` | Mappa di API, consumatori, suite e scene della griglia a celle e dello spike del rilievo continuo (rilevazione del 12 ottobre 2026) | prima di scrivere la spec o il piano della migrazione del terreno (D-082) | vivo |
| `docs/PROTOTYPE_01_SPEC.md` | Specifica del prototipo 01 "Terreno sotto pressione" (scritta per Unreal, contenuti validi) | per scope e criteri del prototipo attuale | riferimento |
| `docs/WORKING_CONCEPT.md` | Concept di lavoro completo: high concept, mondo, tono, fantasia, tre firme, carovana | per contesto creativo ampio (lungo: cercare la sezione) | vivo |
| `docs/VISION_PROPOSAL_2026-10-03.md` | Proposta per chiudere la Fase 1: visione draft, tre promesse alternative, checklist Concept Lock, domande con le risposte del 4 ottobre | **per decidere la visione con il proprietario** | vivo |
| `docs/VISION_WORKSHOP.md` | Alternative di promessa centrale e core loop da discutere col proprietario | per lavorare sulla visione (Fase 1) | vivo |
| `docs/CREATIVE_PRINCIPLES.md` | Principi di originalita e uso responsabile dell'AI | prima di proporre contenuti creativi o asset | riferimento |
| `docs/WORLD_PREMISE.md` | Premessa del mondo: invasione, macchine terraformanti, rotazione, meteo | per lore, ambientazione, nemici | riferimento |
| `docs/ART_DIRECTION.md` | Direzione artistica provvisoria (realismo stilizzato caldo), reference | per grafica, materiali, personaggi | riferimento |
| `docs/superpowers/specs/2026-10-11-visual-restyle-design.md` | Specifica del restyling grafico (stilizzato ricco alla Hades II, pipeline Blender propria, roster fisso di 4 personaggi, preset grafici, camera a tre distanze, fetta visiva e budget) | prima di toccare pipeline Blender, shader, luce, Impostazioni grafiche o personaggi | vivo |
| `docs/superpowers/specs/2026-10-11-identity-ui-design.md` | Specifica di identita e interfaccia (D-079, D-080): nome "Dwarmageddon: Dig or Die", logo vettoriale, font, tema UI con token e varianti, layout di ogni schermata e dell'HUD, intro all'avvio saltabile con aggancio per la vignetta, verifica e catture; **implementata l'11 ottobre 2026** (deviazioni: tema in `.tres`, quadrante accanto al testo) | prima di toccare menu, HUD, pausa, Impostazioni, level-up, Officina, campagna, fine livello, logo o avvio | vivo |
| `docs/superpowers/plans/2026-10-11-visual-restyle-environment.md` | Piano 1 del restyling: fetta visiva dell'ambiente in 11 task (pittore Blender, tile, suolo, rovine, vegetazione, cielo e post, preset grafici, menu, benchmark, camera a tre distanze, catture) | per eseguire o riprendere il restyling dell'ambiente | vivo |
| `docs/superpowers/plans/2026-10-11-identity-ui.md` | Piano di identita e interfaccia in 10 task (catture prima, font e tema, logo, menu, pausa e Impostazioni, level-up e Officina e campagna, fine livello, HUD, intro, catture e documenti) | per eseguire o riprendere il restyling dell'interfaccia | vivo |
| `docs/superpowers/specs/2026-10-11-ui-handmade-polish-design.md` | Passata "fatta a mano" sull'interfaccia (D-081, **implementata l'11 ottobre 2026**): texture generate da script, icone a poligoni, cursore a chiodo, suoni e micro-animazioni, transizioni, sfondo a strati del menu, HUD con strisce e tubo, logo con bisello | prima di toccare texture dell'interfaccia, UiFx, icone o lo sfondo del menu | vivo |
| `docs/superpowers/specs/2026-10-12-continuous-terrain-design.md` | Terreno continuo, tappa A (quartiere): Terrain3D + collisione a chunk + Jolt, pennello continuo, zainetto di terra, pendenza massima, vene di rottami, Demolitore che spiana, eventi e mappa sul rilievo, suolo a strati (D-082, D-085; **approvata a voce il 12 ottobre 2026, revisione scritta del proprietario in corso**) | prima di toccare terreno, tool, percorsi, boss, rottami, lampioni, eventi o mappa | vivo |
| `docs/superpowers/specs/2026-10-12-continuous-terrain-railway-design.md` | Terreno continuo, tappa B: campo rettangolare, ferrovia a pennellate (fascia piatta, vagoni come cumuli con vena, cortile a cavallo), treno che riporta alla base, Trivella che scava solchi e sfonda gli argini senza rottami, saltatori per pendenza, scene minori sul rilievo, eliminazione della griglia (D-087; **scritta in autonomia il 12 ottobre 2026, da giudicare sul risultato**) | prima di toccare ferrovia, treno, Trivella o i resti della griglia | vivo |
| `docs/superpowers/specs/2026-10-13-engineer-restyle-design.md` | Restyling dell'Ingegnere (piano 2 del restyling, D-088): donna cartoon a 3 teste della scheda D-077, tuta blu stinto con accento arancio, modellazione a gabbia con scultura cotta da alta a bassa definizione (`sculpt.py`, `build_engineer.py`), pittura 2048, scheletro riproporzionato, stati di colore come emissione, postura via modificatore, stop sull'argilla (**approvata a voce il 13 ottobre 2026, revisione scritta del proprietario in corso**) | prima di toccare il modello del giocatore, la pipeline Blender dei personaggi o il colore degli stati | vivo |
| `docs/superpowers/plans/2026-10-13-engineer-restyle.md` | Piano dell'Ingegnere D-088 in 7 task: misure e "prima", `sculpt.py`, anteprime a giro, forma in argilla con stop del proprietario, versione alta cotta sulla bassa con pesi ed export, postura e stati di colore in Godot, catture, misure e documenti | durante il restyling dell'Ingegnere | vivo |
| `docs/superpowers/plans/2026-10-12-continuous-terrain-railway.md` | Piano in 8 task della tappa B del terreno continuo (campo rettangolare, scritture per treno e Trivella, ferrovia a pennellate, treno, Trivella, scene minori, rimozione della griglia, bot e documenti) | per eseguire la migrazione della ferrovia e togliere la griglia | vivo |
| `docs/superpowers/plans/2026-10-12-continuous-terrain-district.md` | Piano in 16 task della tappa A del terreno continuo (TerrainField, collisione a chunk, zainetto, tool, percorsi, orda, quartiere a pennellate, vene, Demolitore, lampioni, eventi, mappa, resa, modello, bot e documenti) | per eseguire la migrazione del quartiere al rilievo continuo | vivo |
| `docs/superpowers/plans/2026-10-11-ui-handmade-polish.md` | Piano della passata "fatta a mano" in 8 task (texture e tema, icone e suoni, UiFx, sfondo del menu, carte e pannelli, HUD, logo, catture e documenti) | per eseguire o riprendere la passata | vivo |
| `docs/BRAINSTORMING_CONCEPTS.md` | Prime concept card, nessuna approvata | solo per ripescare idee scartate o alternative | storico |

## Produzione e strategia

| File | Contenuto | Leggilo quando | Stato |
|---|---|---|---|
| `docs/PROJECT_ROADMAP.md` | Fasi di prodotto 0-14 con gate (lungo: cercare la fase); stato operativo in testa | per capire dove siamo nel percorso verso Steam | vivo |
| `docs/PROJECT_BRIEF.md` | Obiettivi, vincoli, risorse e competenze del proprietario | per scope, budget, priorita | riferimento |
| `docs/RISK_REGISTER.md` | Rischi aperti e chiusi con mitigazioni | prima di scelte rischiose; per aggiornare un rischio | vivo |
| `docs/DEMO_STRATEGY.md` | Strategia della demo Steam | per demo, Next Fest, marketing | riferimento |

## Playtest e review

| File | Contenuto | Leggilo quando | Stato |
|---|---|---|---|
| `docs/PLAYTESTS/ARENA_RUN_LEVEL_2026-10-07.md` | Promemoria per il playtest del livello completo: come avviare, problemi gia noti dalla review (da spuntare, non da riscoprire), cosa annotare, esito | **prima di giocare il livello**; dopo, per registrare l'esito | vivo |
| `docs/PLAYTESTS/GODOT_PARITY_PLAYTEST.md` | Playtest di parita Godot: feel, Test A, Steam Deck, preset; esiti registrati | per esiti del feel e test in sospeso | vivo |
| `docs/PLAYTESTS/TERRAIN_GRID_SLICE_A_2026-09-22.md` | Protocollo e esito (Continua) della Terrain Slice A, legenda controlli, Test B Steam Deck | per i protocolli di test terreno e Deck | riferimento |
| `docs/REVIEWS/RAILWAY_CAMPAIGN_2026-10-10.md` | Review indipendente (Codex, statica) di ferrovia, Trivella, treno e campagna: 8 segnalazioni F-01…F-08 con gravita, riproduzione, proposta e stato di verifica | prima di correggere o estendere treno, Trivella, profilo, campagna | vivo |
| `docs/REVIEWS/FULL_CODE_2026-10-09.md` | Review completa di tutto il codice con Godot (4 domini, 47 segnalazioni E/T/P/U, nessuna A), misure di riferimento (frame, direttore, campo, arena, SFX, spike a 96 e 204 m), priorita delle ottimizzazioni, cosa non scala dello spike del terreno, ordine delle correzioni | prima di ottimizzare, prima del piano di migrazione del terreno, prima di correggere nemici, boss, UI o gate | vivo |
| `docs/REVIEWS/ARENA_RUN_LEVEL_2026-10-07.md` | Review a lettura del livello completo (D-042…D-062): 41 segnalazioni con gravita, scenario, correzione e stato di verifica; cosa e gia corretto; percorsi senza test; ordine delle correzioni | prima di correggere o estendere boss, profilo, menu, campo di percorso, arma, audio | vivo |
| `docs/REVIEWS/TERRAIN_GRID_SLICE_A_2026-09-21.md` | Review tecnica della Slice A in Unreal | raramente | storico |

## Archivio (era Unreal)

Non descrivono il progetto attuale. Il codice Unreal e nel tag Git `unreal-prototype-final`.

| File | Contenuto | Stato |
|---|---|---|
| `docs/UNREAL_EDITOR_WORKFLOW.md` | Vecchio flusso di lavoro nell'Unreal Editor e MCP Epic | storico |
| `docs/BLENDER_UNREAL_ROUNDTRIP_SPEC.md` | Round-trip Blender-Unreal; principi validi, preset da rifare per Godot (R-011) | storico |
| `docs/SMOKE_TEST_2026-09-21.md` | Smoke test della toolchain Unreal 5.6 | storico |
| `docs/SMOKE_TEST_UE58_2026-09-22.md` | Smoke test della migrazione a UE 5.8 | storico |
| `docs/INPUT_MOVEMENT_SLICE_2026-09-21.md` | Collaudo dell'incremento input/movimento in Unreal | storico |
| `docs/STORAGE_AUDIT_2026-09-21.md` | Audit dello spazio su disco di settembre | storico |
