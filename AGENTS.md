# AGENTS.md


**Indice dei documenti: `docs/INDEX.md`.** Consultarlo per scegliere quali documenti leggere invece di aprirli tutti; aggiornarlo nello stesso commit quando si crea, rinomina o archivia un documento.

## Progetto e obiettivo

Videogioco indipendente destinato a Steam: candidato survivor-like 3D isometrico/top-down, piccolo ma rifinito, testabile e pubblicabile. Game feel, leggibilita e originalita percepibile prevalgono sulla quantita di contenuti.

Il proprietario sviluppa tramite AI-assisted development e ha budget iniziale ridotto: privilegiare soluzioni gratuite, automazione e riduzione del suo lavoro meccanico.

## Stato corrente essenziale

- **Engine: Godot 4.7.2 stable, edizione standard/GDScript.** Migrazione dal prototipo Unreal Engine 5.8.2 approvata il 3 ottobre 2026 e completata nel codice il giorno stesso (Fasi 0-9 del piano in `docs/GODOT_MIGRATION_ANALYSIS.md`); restano i playtest del proprietario e la Fase 10. Stato vivo: `docs/MIGRATION_STATUS.md`.
- Il progetto Unreal e stato rimosso da `main` il 3 ottobre 2026 su decisione del proprietario (Fase 10). Resta consultabile nel tag Git `unreal-prototype-final` (`git show unreal-prototype-final:Source/Prototype01/<file>`).
- Fase di prodotto: Fase 3 della roadmap, micro-prototipi. Stato e prossimo passo sempre in `docs/PROJECT_ROADMAP.md`, sezione "Stato operativo".
- Canale di lavoro: **filesystem + CLI**, verificato. Dettagli operativi obbligatori in `docs/GODOT_WORKFLOW.md`.
- MCP di terze parti: valutati e **rimandati**, con trigger definiti in `docs/GODOT_WORKFLOW.md`.
- Blender 5.2.2, VS Code, Git e Git LFS restano invariati. La toolchain C++/Visual Studio non serve al progetto Godot; resta finche esiste il progetto Unreal.
- Target: single-player Windows su Steam; controller primario con piena parita tastiera/mouse; Steam Deck LCD. **La build Windows e la build primaria**, anche per Steam Deck via Proton (D-026); la build Linux nativa resta esportabile come alternativa.

## Direzione creativa

- Riferimenti: *Deep Rock Galactic: Survivor* per resa 3D e leggibilita; *Vampire Survivors* per immediatezza e densita; *Astroneer* per la trasformazione del terreno, reinterpretata dall'alto senza copiarne UI o struttura.
- Mondo fantasy post-apocalittico caldo e colorato, in rotazione perpetua; natura su strutture decrepite.
- Protagonista: ingegnere improvvisatore, cinico, spiritoso e sboccato.
- Pilastro: trasformazione profonda e leggibile del terreno tramite tool personali e macchine. Profondita sistemica, non voxel arbitrari.
- Nemici, struttura della run e progressione restano da definire.

Le decisioni registrate sono in `docs/DECISIONS.md`.

## Documenti autorevoli

- **Stato corrente e prossimo passo: `docs/MIGRATION_STATUS.md`** — da leggere per primo e da aggiornare a ogni avanzamento
- Migrazione e architettura Godot: `docs/GODOT_MIGRATION_ANALYSIS.md`
- Flusso di lavoro e CLI: `docs/GODOT_WORKFLOW.md`
- Roadmap: `docs/PROJECT_ROADMAP.md`
- Brief e principi: `docs/PROJECT_BRIEF.md`, `docs/CREATIVE_PRINCIPLES.md`
- Concept: `docs/WORKING_CONCEPT.md`, `docs/BRAINSTORMING_CONCEPTS.md`, `docs/WORLD_PREMISE.md`
- Prototipo: `docs/PROTOTYPE_01_SPEC.md`, `docs/TERRAIN_SYSTEM.md`
- Piattaforma/input: `docs/PLATFORM_AND_INPUT.md`
- Handoff AI: `docs/AI_HANDOFF_PROTOCOL.md`
- Archivio storico Unreal: `docs/UNREAL_EDITOR_WORKFLOW.md`

## Principi di produzione

1. Proteggere lo scope: nucleo giocabile prima dei contenuti.
2. Validare i rischi con prototipi piccoli, misurabili e scartabili.
3. Preferire sistemi data-driven e riutilizzabili; evitare duplicazioni e astrazioni premature.
4. Mantenere una build giocabile e verificarla periodicamente pacchettizzata.
5. Separare codice, sorgenti, import, build e file generati.
6. Registrare decisioni costose o irreversibili.
7. Aggiungere tool o dipendenze solo per un problema concreto, dopo verifica di costo, licenza, manutenzione ed esportabilita. **Valutare pero sempre**, per l'obiettivo e per ogni task, se esistono tool esterni, addon Godot, estensioni, plugin o server MCP utili, e proporli (dettagli in `CLAUDE.md`, sezione "Strumenti esterni").
8. **Tenere aggiornata la sezione "Stato operativo" di `docs/PROJECT_ROADMAP.md`** a ogni avanzamento, con il prossimo passo esplicito.
8. Non sacrificare leggibilita, accessibilita o prestazioni per la densita visiva.
9. L'originalita deve emergere dai sistemi e dall'esperienza, non solo da tema o asset.
10. Distinguere sempre cio che e verificato da cio che e assunto.

## Autonomia degli agenti

Modello: **AI-first con autonomia operativa ampia.** Il proprietario valuta i risultati, non il procedimento, e non riceve lavoro meccanico automatizzabile.

### Un agente procede senza chiedere

- creare, modificare, rifattorizzare ed eliminare codice, scene, risorse e configurazioni di progetto;
- eseguire build, test, validazioni, run e catture di verifica;
- creare branch, committare e aggiornare la documentazione;
- scegliere architettura, struttura dei file, nomi, pattern e dettagli implementativi;
- proporre e implementare scelte creative, di design e di contenuto, registrandole in `docs/DECISIONS.md` perche il proprietario possa valutarle o ribaltarle;
- correggere bug, incoerenze e debito tecnico incontrati lungo la strada;
- delegare task a Codex quando conviene.

Non serve chiedere permesso passo per passo. Serve riferire con chiarezza cosa e stato fatto, cosa e stato verificato e cosa no.

### Restano sempre del proprietario

- **Qualunque spesa**: acquisti, licenze, abbonamenti, crediti, API a consumo, PAYG, ricariche automatiche. Nessuna eccezione, nemmeno per importi minimi o prove gratuite che richiedono un metodo di pagamento.
- **Pubblicazione e piattaforma**: caricare build, modificare Steam, inviare a revisione, accettare accordi.
- **Credenziali e dati riservati**: mai accedere, riportare o trasmettere credenziali, token, dati personali, fiscali o Steamworks.
- **Operazioni distruttive e irreversibili** sul lavoro esistente: riscrivere la cronologia Git condivisa, eliminare il progetto Unreal, migrazioni che invalidano salvataggi.
- **Decisione finale** su identita, tono e pubblicazione: l'agente puo proporre e implementare, il proprietario ha l'ultima parola e la esercita sul risultato.

### Qualita come contropartita dell'autonomia

Autonomia ampia implica verifica rigorosa. Un agente:

- esegue i controlli pertinenti prima di dichiarare completato (`--check-only`, run, cattura visiva);
- **non dichiara mai verificato cio che non ha controllato** ed e esplicito sui limiti dell'evidenza;
- preserva il lavoro fuori scope e non sovrascrive modifiche altrui;
- mantiene diff piccoli e leggibili;
- segnala i problemi che trova senza correggerli d'ufficio, se esulano dal task e non lo bloccano.

### Collaborazione fra agenti

Codex e una risorsa delegabile, non un cancello obbligatorio. Conviene coinvolgerlo per review trasversale, verifica indipendente, blocchi tecnici o limiti di capacita, tramite `tools/ai/Invoke-CodexDelegate.ps1` secondo `docs/AI_HANDOFF_PROTOCOL.md`. Non delegare a Codex un task che Codex ha appena affidato, salvo blocco.

Isolare i contributi sostanziali in branch e non far modificare gli stessi file a piu agenti contemporaneamente.

## Regole Godot

- **Le scene e le risorse sono file di testo e si modificano direttamente.** La vecchia regola Unreal "non toccare gli asset a mano" non si applica.
- Il proprietario usa normalmente **l'editor grafico Godot** in parallelo: e la stessa fonte di verita vista da un'altra angolazione. Un agente dichiara in anticipo le scene che sta per modificare e non tocca una scena aperta con modifiche non salvate.
- `.godot/` e cache rigenerabile e va ignorata in Git; i file `.uid` accanto a script e risorse **vanno versionati**, perche mantengono i riferimenti quando un file viene spostato o rinominato.
- Usare sempre `godot_console`, mai `godot`: la seconda non scrive su stdout. Passare sempre `--quit-after` nei run non interattivi. Vedi `docs/GODOT_WORKFLOW.md`.
- Separare interfaccia, logica di gioco, dati, servizi e stato. Non concentrare la logica in un singolo script.
- Preferire GDScript con tipizzazione statica; segnali per il disaccoppiamento; componenti riutilizzabili; autoload solo quando realmente giustificati.
- Nomi dei file in `snake_case`, classi in `PascalCase`, identificatori in inglese. Organizzare per dominio e feature.
- Parametri iterativi in risorse `.tres`, non cablati nel codice.
- UI con Control, container, anchor e size flag; niente coordinate fisse. Verificare 1280x800 e 16:10.
- Terreno: separare stato logico, presentazione, collisioni e navigazione; comandi deterministici e testabili.
- Input: azioni semantiche nella mappa di progetto, mai gameplay legato a tasti fisici. Ogni funzione deve essere completa con controller e con tastiera/mouse. Testare cambio dispositivo, glifi, focus, dead zone e sensibilita.
- Profilare prima di ottimizzare; fissare budget prima della vertical slice.
- Verificare periodicamente una build esportata su macchina pulita.

## Blender, asset e licenze

- Separare i sorgenti `.blend` da export e import; conservare i sorgenti editabili.
- Prima della produzione fissare scala, assi, pivot, unita, nomi e preset di export, poi validare un round-trip completo. **Godot usa metri e Y-up**: i preset definiti per Unreal vanno rifatti.
- Registrare provenienza, licenza e attribuzioni di ogni asset, font, texture, audio e addon.

## Git e file generati

- Non versionare build locali, cache o file rigenerabili. `Binaries/`, `DerivedDataCache/`, `Intermediate/`, `Saved/` sono residui Unreal rigenerabili, da trattare insieme alla decisione della Fase 10.
- Trattare `.blend`, audio compresso e texture sorgenti come binari in Git LFS. Le scene Godot sono testo e non vanno in LFS.
- Mai committare credenziali, token o dati riservati.
- Commit piccoli e descrittivi. Non riscrivere la cronologia condivisa senza autorizzazione.

## Qualita e review

Una feature e completa, quando applicabile, solo con percorso nominale e casi limite verificati, parita di input, feedback comprensibili, log puliti, bilanciamento esterno alla logica, impatto prestazionale misurato e documentazione aggiornata. Per un bug: riprodurlo prima, poi verificare esplicitamente il caso corretto.

Priorita di review: requisiti; regressioni, crash, perdita di dati, sicurezza; ciclo di vita dei nodi e gestione delle risorse; costi per frame e per entita; test mancanti; compatibilita con salvataggi, input e build; complessita futura.

## Guida del proprietario

Quando serve un suo intervento: spiegare obiettivo e motivo, dare pochi passi ordinati con nomi di interfaccia correnti, risultato atteso e verifica; segnalare prima costi, rischi e irreversibilita. Comandi copiabili, con rollback proporzionato.

Chiedere il suo intervento solo per login, credenziali, acquisti, autorizzazioni sensibili, hardware o valutazioni percettive che richiedono occhi umani, come il feel di gioco.

## Lingua e fonti

- Comunicazione e documentazione in italiano; identificatori e asset in inglese; testo UTF-8.
- Distinguere fatti, ipotesi, candidati e decisioni.
- Ordine delle fonti: decisioni registrate; documentazione ufficiale delle versioni fissate; esperimenti riproducibili; fonti secondarie.
