# Registro dei rischi

## Scala

- Probabilita e impatto: `Bassa`, `Media`, `Alta`.
- Un rischio viene chiuso soltanto da evidenze; una mitigazione pianificata non equivale a chiusura.

| ID | Rischio | Prob. | Impatto | Segnale o trigger | Mitigazione corrente | Stato / revisione |
|---|---|---:|---:|---|---|---|
| R-001 | La modifica del terreno non e precisa o divertente dall'alto. | Alta | Alta | Bersaglio frainteso, modifiche accidentali, preferenza per ignorare il tool. | Slice discreti, anteprima evidente, test separati controller/mouse e gate prima delle collisioni. | Aperto; playtest Slice A. |
| R-002 | Collisioni e navigazione dinamiche causano blocchi o stutter. | Alta | Alta | Nemici incastrati, frame spike dopo modifiche ripetute. | Separare stato, presentazione, collisione e navigazione; aggiornamenti locali; profiling prima di aumentare fedelta. | Non ancora testato; Slice B/C. |
| R-003 | Il concept appare come un survivor-like derivativo. | Media | Alta | Pitch comprensibile solo citando altri giochi; terreno usato come semplice skin o raccolta. | Firma meccanica terreno-macchine-conseguenze; scorecard e playtest senza affidarsi ai riferimenti. | Aperto; Concept Lock. |
| R-004 | Carovana, mezzi e fusione fanno esplodere lo scope. | Alta | Alta | Ogni sistema richiede controlli, fisica, animazioni e livelli dedicati prima del core loop. | Introdurre una sola macchina non pilotabile; telaio terrestre isolato solo dopo il gate del core loop. | Contenuto; revisione dopo Prototype Complete. |
| R-005 | Bullet hell, terreno e VFX diventano illeggibili insieme. | Alta | Alta | Pericoli coperti, profondita ambigua, morti non comprese. | Gerarchia visiva, camera fissa, palette funzionale, limiti di densita e stress scene precoci. | Aperto; primi nemici/proiettili. |
| R-006 | Steam Deck LCD non mantiene prestazioni o leggibilita. | Media | Alta | Frame pacing instabile, testo piccolo, controlli o Proton problematici. | Test fisico precoce a 1280x800, build Windows Development, profiling e preset dedicato solo su dati reali. | Aperto; primo smoke test Deck. |
| R-007 | Codice AI introduce regressioni o architettura eccessiva. | Media | Alta | Diff ampi, dipendenze nuove, dichiarazioni non verificate. | Brief circoscritti, branch isolati, review Codex, build e playtest prima del merge. | Attivo e mitigato a ogni incremento. |
| R-008 | Claude Code diventa indisponibile o esaurisce capacita. | Media | Media | `ConnectionRefused`, rate limit o avviso di piano. | Eseguire la CLI con rete esplicitamente autorizzata; nessun fallback PAYG automatico; retry limitati; Codex interviene solo secondo eccezione. | Mitigato: causa dei rifiuti identificata nel sandbox e canale verificato il 21 settembre 2026. |
| R-009 | Licenze o provenienza di asset esterni non sono dimostrabili. | Media | Alta | Asset importato senza URL, licenza o permesso commerciale. | Registro prima dell'adozione, placeholder separati, nessun download massivo. | Aperto quando iniziano asset esterni. |
| R-010 | Repository binario cresce oltre Git LFS gratuito o produce conflitti. | Media | Media | Quote, clone lenti, modifiche simultanee a `.uasset`/`.blend`. | LFS gia configurato; ownership dei binari; misurazione periodica; valutare locking/Perforce solo su evidenza. | Baseline sana; revisione a inizio produzione asset. |
| R-011 | Pipeline Blender-Godot produce scala, assi, pivot o materiali incoerenti (Godot: metri, Y-up). | Media | Media | Correzioni manuali ripetute dopo ogni import. | Definire preset e completare un round-trip prima della produzione in serie. | Aperto; Fase 2. |
| R-012 | Il progetto accumula documentazione senza evidenza giocabile. | Media | Media | Molte specifiche, nessuna build o playtest recente. | Ogni documento deve supportare un gate; build giocabile regolare; evitare espansione del GDD prematura. | Monitorato mensilmente. |

## Rischi chiusi o ridotti

| ID | Evidenza | Esito |
|---|---|---|
| R-C01 | Toolchain C++ UE 5.8.2 con Visual Studio 2026, cook, packaging e avvio verificati. | Rischio di ambiente Windows non funzionante ridotto; monitorare l'avviso MSVC 14.51 piu recente della versione preferita da Epic. |
| R-C02 | Clone remoto pulito del commit `40b7682`, download LFS, compilazione Editor e avvio headless riusciti. | Rischio di backup GitHub non ripristinabile ridotto. |
| R-C03 | Test manuale di WASD, mouse, due stick, dash e cooldown. | Rischio iniziale di mapping input errato ridotto; remapping completo resta futuro. |
