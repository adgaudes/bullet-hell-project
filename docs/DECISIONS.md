# Registro delle decisioni

## Uso

Questo file registra le decisioni costose da dimenticare o cambiare. Le proposte creative restano candidate finche non superano il relativo gate. Stati usati:

- **Approvata:** guida il lavoro corrente;
- **Validata:** approvata e verificata con build o test;
- **Provvisoria:** utile per il prossimo esperimento, ma modificabile;
- **Sostituita:** non piu autorevole; la voce indica la decisione successiva.

## Decisioni correnti

| ID | Data | Stato | Decisione | Motivo e conseguenze | Prossima revisione |
|---|---|---|---|---|---|
| D-001 | 2026-09-21 | Approvata | Qualita e sostenibilita hanno priorita sulla velocita di pubblicazione; budget iniziale molto basso. | Preferire scope piccolo, strumenti gratuiti e prove scartabili prima di spese o produzione estesa. | A ogni milestone commerciale. |
| D-002 | 2026-09-21 | Validata | Unreal Engine 5.6.1 e Visual Studio 2022 costituiscono la toolchain del prototipo Windows. | Compilazione C++, cook, packaging e avvio sono riproducibili. Non migrare engine durante il prototipo senza un piano di rollback. | Prima della vertical slice. |
| D-003 | 2026-09-21 | Approvata | Prima piattaforma Windows su Steam; controller primario con parita tastiera/mouse; Steam Deck LCD tramite Proton come obiettivo. | Ogni incremento deve essere testabile con entrambi gli input e considerare 1280x800. Verified resta un obiettivo, non una promessa. | Dopo i primi test fisici sul Deck. |
| D-004 | 2026-09-21 | Validata | GitHub con Git e Git LFS e la fonte remota del progetto. | Asset binari rilevanti sono instradati in LFS; clone pulito, download LFS, compilazione e avvio headless sono stati verificati il 21 settembre 2026. | Quando volume e collaborazione rendono necessario locking o un'alternativa. |
| D-005 | 2026-09-21 | Provvisoria | Il Prototipo 01 usa visuale isometrica/top-down e il concept dell'ingegnere improvvisatore nel mondo fantasy post-apocalittico caldo. | Serve a rendere concreto il test, ma non equivale a Vision Lock o Concept Lock. Nessuna produzione artistica estesa dipende ancora da questa scelta. | Gate dei micro-prototipi comparativi. |
| D-006 | 2026-09-21 | Approvata | Il terreno viene validato prima con stati discreti; voxel e plugin runtime sono vietati nel Prototipo 01. | Prima si misurano intenzionalita, leggibilita e conseguenze. Una tecnologia continua verra valutata solo con uno spike isolato e profilato. | Dopo i test con collisioni e percorsi nemici. |
| D-007 | 2026-09-21 | Approvata | Claude e la prima destinazione per codice; Codex definisce brief, revisiona, integra e verifica. | Nessun output AI entra in `main` senza lettura del diff, compilazione e test pertinenti. In caso di indisponibilita tecnica Claude, Codex puo applicare la minima modifica necessaria documentando l'eccezione. | Se cambiano piano, accesso o affidabilita degli strumenti. |
| D-008 | 2026-09-21 | Validata | Character Feel v1 e integrato in `main`. | Movimento, mira indipendente, indicatore frontale, dash e cooldown sono stati verificati manualmente; inversione assi separata resta requisito delle impostazioni future. | Quando esiste un avatar e una scena piu rappresentativi. |
| D-009 | 2026-09-21 | Provvisoria | Terrain Slice A resta sul branch `feature/terrain-grid-slice` fino al playtest del proprietario. | Build e controlli automatici sono superati, ma leggibilita e precisione richiedono giudizio umano. Non costruire collisioni o nemici su un'interazione non ancora validata. | Playtest Terrain Slice A. |

## Decisioni ancora aperte

- promessa centrale e one-page vision;
- struttura della run e progressione;
- natura dei nemici;
- necessita di un prototipo laterale comparativo;
- rappresentazione finale del terreno;
- scope reale di carovana, veicoli e forma colossale;
- pipeline artistica Blender-Unreal definitiva.
