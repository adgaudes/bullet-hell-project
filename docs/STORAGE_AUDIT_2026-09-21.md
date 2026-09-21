# Audit dello spazio locale - 21 settembre 2026

## Scopo

Misurare lo spazio usato dal progetto e individuare file ricostruibili. La rilevazione iniziale e stata seguita dalla pulizia autorizzata delle sole build obsolete; sorgenti, cache di lavoro e build correnti non sono stati toccati.

## Rilevazione

| Area | Dimensione | Natura |
|---|---:|---|
| `LocalBuilds/` dopo la pulizia | 1.826.921.866 byte, circa 1,70 GiB | due build Windows conservate |
| `Intermediate/` | 4.621.557.286 byte, circa 4,30 GiB | output di compilazione ricostruibile |
| `Saved/` | 1.143.071.388 byte, circa 1,06 GiB | log, cook e dati temporanei |
| `Binaries/` | 765.784.324 byte, circa 0,71 GiB | binari locali ricostruibili |
| `Artifacts/` | 286.826.312 byte, circa 0,27 GiB | archivio di test e checksum generati localmente |
| `DerivedDataCache/` | 1.627.828 byte | cache ricostruibile |

Lo spazio libero sull'unita `C:` dopo la pulizia era circa 607 GiB. Non esiste quindi un'urgenza operativa.

## Build da conservare ora

- `LocalBuilds/Prototype01-CharacterFeel-Win64-v4`: ultimo riferimento approvato prima del terreno.
- `LocalBuilds/Prototype01-TerrainGrid-Win64-v1`: build candidata per il prossimo playtest.
- `Artifacts/Playtests/Prototype01-TerrainGrid-Win64-v1-Deck.zip`: trasferimento verificato per Steam Deck, senza simboli di debug.

## Pulizia eseguita

Con autorizzazione esplicita del proprietario sono state eliminate dodici build precedenti in `LocalBuilds/`, per complessivi `10.957.794.893` byte, circa 10,21 GiB. Sono state verificate prima dell'eliminazione come cartelle figlie dirette di `LocalBuilds/`; al termine entrambe le build da conservare risultavano ancora presenti.

`Intermediate/`, parti di `Saved/`, `Binaries/` e `DerivedDataCache/` sono anch'essi ricostruibili, ma cancellarli ora farebbe perdere tempo alla compilazione successiva senza un beneficio necessario. La raccomandazione e quindi:

1. non pulire le directory di lavoro mentre lo spazio libero resta ampio;
2. eliminare in futuro soltanto build sostituite e ricostruibili, sempre dopo autorizzazione;
3. conservare almeno una build approvata e una candidata;
4. ripetere l'audit quando `LocalBuilds/` supera circa 25 GiB o lo spazio libero scende sotto 100 GiB.

## Nota sugli archivi Deck

La build Development includeva un file `.pdb` da circa 342 MiB, utile per il debug locale ma non necessario al playtest sul Deck. L'archivio dedicato esclude `.pdb` e `Saved/`; e stato estratto in una cartella temporanea, il bootstrap `Prototype01.exe` e risultato identico all'originale e la cartella temporanea e stata rimossa dopo la verifica.
