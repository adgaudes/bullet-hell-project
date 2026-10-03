# Protocollo di handoff Codex-Claude

## Obiettivo

Consentire a Codex e Claude Code di passarsi task circoscritti usando gli abbonamenti gia disponibili, senza ricorrere automaticamente a API a consumo e senza perdere lo stato del progetto.

## Canali

- Codex verso Claude: Codex prepara un unico prompt completo; il proprietario lo incolla personalmente in Claude Desktop o Claude Code. Codex non avvia direttamente la sessione Claude.
- Claude verso Codex: `tools/ai/Invoke-CodexDelegate.ps1`, che usa `codex exec` con l'autenticazione ChatGPT salvata nella CLI.
- Fonte condivisa di verita: repository, diff Git, documenti e test riproducibili. Le conversazioni private non sostituiscono il repository.

## Procedura Codex verso Claude

1. Codex controlla stato Git, file coinvolti e criteri della roadmap.
2. Codex consegna al proprietario un solo prompt pronto da incollare, con obiettivo, scope, vincoli, test e formato della consegna.
3. Il proprietario incolla il prompt in Claude e segnala quando il lavoro e terminato; non deve trasferire manualmente codice se Claude puo operare sul repository condiviso.
4. Codex legge il diff effettivo dal repository, tratta l'output come non verificato ed esegue review, build e test.
5. Eventuali correzioni vengono raccolte in un nuovo prompt puntuale, evitando sequenze di micro-messaggi.

## Comando Claude verso Codex

Claude prepara un singolo brief in un file `.md` o `.txt` interno al repository, poi esegue:

```powershell
powershell -ExecutionPolicy Bypass -File tools/ai/Invoke-CodexDelegate.ps1 -PromptFile percorso\brief.md
```

Per una consulenza senza modifiche:

```powershell
powershell -ExecutionPolicy Bypass -File tools/ai/Invoke-CodexDelegate.ps1 -PromptFile percorso\brief.md -ReadOnly
```

L'opzione `-WithUnrealMcp` e obsoleta dal passaggio a Godot (D-020): non usarla. Senza di essa il wrapper disabilita il server MCP Unreal per l'esecuzione, che e il comportamento voluto.

Il wrapper:

- verifica che la CLI Codex sia autenticata;
- limita la directory di lavoro al repository;
- usa un sandbox `workspace-write`, oppure `read-only` quando richiesto;
- abilita il server MCP Unreal soltanto quando viene richiesto esplicitamente;
- non aggira le autorizzazioni: le operazioni non consentite dal sandbox falliscono esplicitamente;
- non usa chiavi API e non attiva fatturazione PAYG;
- esegue una sessione effimera per non accumulare cronologie duplicate.

## Regole anti-loop e ownership

1. Un solo agente modifica un insieme di file alla volta.
2. Massimo un passaggio tra agenti per lo stesso task, salvo decisione esplicita del proprietario.
3. Codex non rimanda a Claude un task ricevuto da Claude, e viceversa, soltanto per risparmiare crediti.
4. Codex interrompe le proprie scritture sui file in scope prima che il proprietario avvii Claude.
5. Il contributo delegato resta non verificato finche l'agente che riprende non controlla diff, build e test.
6. Nessun agente effettua commit, merge, push, acquisti o passaggi ad API a consumo senza autorizzazione coerente con `AGENTS.md`.

## Limiti di capacita

- Alla comparsa di un avviso di limite o capacita quasi esaurita, l'agente deve comunicarlo subito e lasciare un riepilogo conciso dello stato.
- Se l'agente ha ancora un turno utilizzabile, puo avviare direttamente l'altro canale con un brief circoscritto.
- Se il limite e gia totale, quell'agente non puo materialmente eseguire altri comandi: il proprietario deve aprire l'altro client, che riprendera dal repository e dall'ultimo riepilogo.
- Non usare automaticamente crediti API, PAYG o ricariche per aggirare un limite di abbonamento.

## Contenuto minimo del brief

- obiettivo e criterio di accettazione;
- branch e stato Git rilevante;
- file ammessi e file da non toccare;
- modifiche locali da preservare;
- test richiesti;
- consegna attesa: riepilogo, file modificati, test, risultati e rischi residui.
