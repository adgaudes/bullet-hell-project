# Audit dello spazio locale - 21 settembre 2026

## Scopo

Misurare lo spazio usato dal progetto e individuare file ricostruibili senza cancellare dati durante la sessione autonoma. Questo documento e una proposta: nessuna vecchia build e stata eliminata.

## Rilevazione

| Area | Dimensione | Natura |
|---|---:|---|
| `LocalBuilds/` | 12.784.716.759 byte, circa 11,91 GiB | build Windows ricostruibili |
| `Intermediate/` | 4.621.557.286 byte, circa 4,30 GiB | output di compilazione ricostruibile |
| `Saved/` | 1.143.071.388 byte, circa 1,06 GiB | log, cook e dati temporanei |
| `Binaries/` | 765.784.324 byte, circa 0,71 GiB | binari locali ricostruibili |
| `Artifacts/` | 286.826.312 byte, circa 0,27 GiB | archivio di test e checksum generati localmente |
| `DerivedDataCache/` | 1.627.828 byte | cache ricostruibile |

Lo spazio libero sull'unita `C:` al momento della misura era circa 598 GiB. Non esiste quindi un'urgenza operativa.

## Build da conservare ora

- `LocalBuilds/Prototype01-CharacterFeel-Win64-v4`: ultimo riferimento approvato prima del terreno.
- `LocalBuilds/Prototype01-TerrainGrid-Win64-v1`: build candidata per il prossimo playtest.
- `Artifacts/Playtests/Prototype01-TerrainGrid-Win64-v1-Deck.zip`: trasferimento verificato per Steam Deck, senza simboli di debug.

## Pulizia proposta, non eseguita

Le dodici build precedenti in `LocalBuilds/` occupano complessivamente `10.957.794.893` byte, circa 10,21 GiB. Dopo il playtest e con approvazione esplicita del proprietario possono essere eliminate, mantenendo le due build sopra indicate.

`Intermediate/`, parti di `Saved/`, `Binaries/` e `DerivedDataCache/` sono anch'essi ricostruibili, ma cancellarli ora farebbe perdere tempo alla compilazione successiva senza un beneficio necessario. La raccomandazione e quindi:

1. non pulire le directory di lavoro mentre lo spazio libero resta ampio;
2. eliminare soltanto le vecchie build dopo autorizzazione;
3. conservare almeno una build approvata e una candidata;
4. ripetere l'audit quando `LocalBuilds/` supera circa 25 GiB o lo spazio libero scende sotto 100 GiB.

## Nota sugli archivi Deck

La build Development includeva un file `.pdb` da circa 342 MiB, utile per il debug locale ma non necessario al playtest sul Deck. L'archivio dedicato esclude `.pdb` e `Saved/`; e stato estratto in una cartella temporanea, il bootstrap `Prototype01.exe` e risultato identico all'originale e la cartella temporanea e stata rimossa dopo la verifica.
