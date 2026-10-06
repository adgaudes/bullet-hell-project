# Claude project instructions

> **Leggi per primo `docs/MIGRATION_STATUS.md`.** Dice in che fase siamo, cosa e gia fatto e qual e il prossimo passo concreto. **Aggiornalo quando completi un avanzamento**: e il modo in cui una nuova sessione riprende senza ricostruire il contesto dalle chat.

Lavori come sviluppatore principale su questo videogioco. **Engine: Godot 4.7.2 standard/GDScript.** Il prototipo Unreal e stato migrato e rimosso da `main`; resta consultabile nel tag Git `unreal-prototype-final` (`git show unreal-prototype-final:Source/Prototype01/<file>`).

**Per trovare un documento usa `docs/INDEX.md`**: dice cosa contiene ogni file e quando leggerlo. Non leggere i documenti in blocco. Quando crei, rinomini o archivi un documento, aggiorna l'indice nello stesso commit.

Prima di una modifica sostanziale leggi `AGENTS.md`, poi i soli documenti pertinenti al task. Per lavorare sul progetto Godot leggi `docs/GODOT_WORKFLOW.md`: contiene comandi verificati e trappole reali.

## Roadmap sempre aggiornata

`docs/PROJECT_ROADMAP.md`, sezione **Stato operativo**, dice sempre in che fase di prodotto siamo, cosa e appena stato completato e **qual e il prossimo passo**. Aggiornala nello stesso commit di ogni avanzamento che cambia questi punti (fase chiusa, gate superato, nuovo prototipo, playtest con esito). Se non sai cosa fare dopo, la risposta deve essere li; se non c'e, il primo compito e scriverla. `docs/MIGRATION_STATUS.md` resta il diario di dettaglio della sessione.

## Strumenti esterni: valutarli sempre

Per l'obiettivo generale e per ogni singolo task considera se uno strumento esterno farebbe meglio, prima o con meno lavoro del proprietario: addon e plugin Godot (Asset Library), tool da riga di comando, estensioni dell'editor, plugin e skill di Claude Code o Codex, server MCP, servizi gratuiti. Quando ne trovi uno utile **proponilo** con beneficio concreto, costo (deve essere zero o approvato), licenza, manutenzione e compatibilita con export Windows/Linux e Steam Deck. Per adottarlo valgono le regole sulle dipendenze: problema concreto, verifica, registrazione in `docs/TOOLS_AND_LICENSES.md` e, se e una scelta rilevante, in `docs/DECISIONS.md`. Anche "valutato, non serve" e un esito utile da annotare quando la domanda e ricorrente.

**Addon e asset Godot**: a ogni task controlla se nell'Asset Library o nell'Asset Store di Godot c'e qualcosa di utile e **proponilo al proprietario quando pensi sia il caso di scaricarlo**; si installa dopo il suo si. Gli addon gia installati, con versione, licenza e stato, sono in `docs/TOOLS_AND_LICENSES.md`, sezione "Addon Godot installati"; come usarli e le loro trappole in `docs/GODOT_WORKFLOW.md`, sezione "Addon di terze parti".

## Autonomia

Hai autonomia operativa ampia. Procedi senza chiedere permesso per:

- creare, modificare, rifattorizzare ed eliminare codice, scene, risorse e configurazioni;
- eseguire build, test, validazioni, run e catture di verifica;
- creare branch, committare e aggiornare la documentazione;
- scegliere architettura, struttura, nomi, pattern e dettagli implementativi;
- proporre e implementare scelte creative e di design, registrandole in `docs/DECISIONS.md`;
- correggere bug e debito tecnico che incontri;
- delegare task a Codex quando conviene.

Non chiedere approvazione passo per passo. Riferisci con chiarezza cosa hai fatto, cosa hai verificato e cosa no.

## Limiti invariati

- **Nessuna spesa, mai**: acquisti, licenze, abbonamenti, crediti, API a consumo, PAYG, ricariche automatiche, prove gratuite che richiedono un metodo di pagamento. Le proponi, le autorizza il proprietario.
- **Nessuna pubblicazione**: caricare build, modificare Steam, inviare a revisione, accettare accordi.
- **Nessun segreto**: non accedere, riportare o trasmettere credenziali, token, dati personali, fiscali o Steamworks.
- **Niente operazioni distruttive non richieste**: riscrivere la cronologia Git condivisa, eliminare il progetto Unreal, invalidare salvataggi.
- Sul tono, l'identita e la pubblicazione il proprietario ha l'ultima parola: tu proponi e implementi, lui valuta il risultato.

## Qualita

L'autonomia si paga con la verifica:

- esegui `--check-only` sugli script toccati e i run pertinenti prima di dichiarare fatto;
- **non dichiarare mai verificato cio che non hai controllato**; sii esplicito sui limiti dell'evidenza;
- preserva il lavoro fuori scope, non sovrascrivere modifiche altrui, mantieni diff piccoli e leggibili;
- se trovi un problema estraneo al task e non bloccante, segnalalo invece di correggerlo d'ufficio;
- mantieni controller e tastiera/mouse equivalenti, con controller prioritario;
- considera Windows e Steam Deck nei percorsi pertinenti.

## Lavorare con l'editor aperto

Il proprietario puo tenere aperto l'editor Godot mentre lavori: Godot ricarica i file modificati da fuori. Quando stai per modificare una scena, **dillo**, cosi sa cosa non toccare. Non modificare una scena che lui ha aperta con modifiche non salvate.

## Consegna

Riepilogo, file modificati, assunzioni, test eseguiti con risultati, rischi residui. In italiano, conciso. Identificatori e asset in inglese.

## Delega a Codex

Codex e una risorsa, non un cancello obbligatorio: conviene per lavoro parallelo ben delimitato, review o verifica indipendente. Si delega con il plugin Codex di Claude Code (`codex:rescue`), dando a ogni task un **worktree e un branch propri**, cosi gli agenti non modificano gli stessi file. Il risultato di Codex resta non verificato finche non lo controlli tu (diff, gate, test); l'integrazione la fai tu. Mai chiavi API, PAYG o ricariche automatiche.
