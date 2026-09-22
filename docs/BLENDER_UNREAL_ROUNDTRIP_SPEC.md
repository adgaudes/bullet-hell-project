# Specifica del round-trip Blender-Unreal

## Obiettivo

Validare una pipeline ripetibile fra Blender 5.2.2 e Unreal Engine 5.8.2 prima di produrre asset. Il test misura scala, orientamento, pivot, normali, slot materiale, reimport e provenienza dei file. Non serve a creare arte definitiva.

## Vincoli

- Nessun plugin aggiuntivo nel primo test.
- FBX come formato iniziale per coerenza con la pipeline mesh e animazione di Unreal.
- Sorgenti `.blend` separati dagli export `.fbx` e dagli asset Unreal.
- Unita di riferimento: metri in Blender; `1 Unreal Unit = 1 cm` in Unreal.
- Nomi tecnici in inglese e prefisso `SM_` per Static Mesh.
- Nessun file binario entra in `main` prima della verifica visiva e del reimport.

La documentazione Epic indica FBX 2020.2 per la pipeline Unreal e ricorda che una Unreal Unit equivale a un centimetro. Blender esporta FBX tramite il proprio convertitore; per questo il risultato reale, non il numero mostrato in un preset, costituisce il gate.

Fonti ufficiali:

- https://dev.epicgames.com/documentation/unreal-engine/fbx-content-pipeline
- https://dev.epicgames.com/documentation/unreal-engine/importing-static-meshes-in-unreal-engine
- https://docs.blender.org/manual/en/5.0/addons/import_export/scene_fbx.html

## Struttura candidata

```text
SourceAssets/
  Blender/PipelineTest/SM_PipelineTest.blend
  Exports/PipelineTest/*.fbx
Content/
  Art/PipelineTest/
```

`SourceAssets/` deve essere tracciato con Git LFS secondo le regole gia presenti. L'export FBX e mantenuto durante la validazione per rendere diagnosticabile la conversione; la politica degli export di produzione verra decisa dopo il test.

## Gate A - Static Mesh

Creare nello stesso `.blend` tre oggetti semplici, ma esportarli in tre FBX distinti. Per ogni export l'origine desiderata dell'asset deve coincidere con l'origine della scena `(0,0,0)`: la pipeline Static Mesh di Unreal usa l'origine esportata come pivot, quindi la semplice posizione dell'oggetto nella scena non va usata per preservare il pivot.

| Oggetto | Prova | Risultato atteso in Unreal |
|---|---|---|
| `SM_Pipeline_Cube_1m` | cubo esattamente 1 x 1 x 1 m, origine centrale | bounds di circa 100 x 100 x 100 cm |
| `SM_Pipeline_HingedPanel` | pannello 1 x 0,1 x 2 m, origine sul bordo inferiore sinistro | rotazione locale simile a una porta, senza traslazione inattesa |
| `SM_Pipeline_MaterialSplit` | mesh con due slot materiale e una faccia smussata/una netta | due slot nello stesso ordine e normali coerenti |

Preparazione Blender:

1. scena in `Metric`, Unit Scale `1.0`;
2. geometria costruita a dimensioni reali;
3. `Ctrl+A > Rotation & Scale` prima dell'export; la posizione resta intenzionale rispetto al pivot;
4. triangolazione lasciata all'import per questa prova, senza modificatori non applicati salvo quello esplicitamente testato;
5. posizionare a turno l'origine desiderata dell'asset in `(0,0,0)` e selezionare soltanto l'oggetto da esportare;
6. esportare un FBX per oggetto, mantenendo identico il preset.

Baseline di export da verificare, non ancora preset approvato:

- `Selected Objects`: attivo;
- Object Types: `Mesh`;
- Scale: `1.0`;
- Apply Unit: attivo;
- Forward: `-Z Forward`;
- Up: `Y Up`;
- Apply Transform / Bake Space Transform: disattivo nel test statico iniziale;
- Apply Modifiers: attivo;
- Smoothing: `Normals Only` se disponibile con questa versione;
- Bake Animation: disattivo.

L'introspezione locale di Blender 5.2.2 ha confermato come default effettivi: scala `1.0`, Apply Unit attivo, `-Z Forward`, `Y Up`, Apply Modifiers attivo e Bake Space Transform disattivo. `Selected Objects` e Bake Animation vanno quindi impostati esplicitamente.

Import Unreal in una cartella isolata `Content/Art/PipelineTest`:

- import come Static Mesh;
- non combinare le mesh;
- non creare collisione automatica per il primo confronto dei bounds;
- importare normali e tangenti secondo il risultato piu fedele osservato, registrando l'opzione scelta;
- evitare la generazione di materiali definitivi: bastano slot e materiali placeholder;
- salvare gli asset, chiudere e riaprire il progetto.

## Verifiche Gate A

- bounds del cubo vicini a 100 cm per asse senza correzione di scala in Unreal;
- freccia/orientamento coerente con la convenzione del progetto;
- pannello ruota dal bordo previsto;
- due slot materiale presenti e ordinati;
- nessun warning inatteso di degenerazione, smoothing o trasformazione;
- sovrascrivere una dimensione nel `.blend`, riesportare e usare `Reimport` in Unreal;
- il reimport aggiorna la mesh conservando riferimenti e materiali assegnati;
- file `.blend`, `.fbx` e `.uasset` finiscono nelle cartelle previste e sono instradati in LFS.

Se uno dei primi quattro controlli fallisce, non correggere la scala o la rotazione a mano nell'asset Unreal: modificare il preset o la sorgente e ripetere l'import.

## Gate B - Skeletal Mesh e animazione

Iniziare soltanto dopo Gate A. Usare un oggetto distinto con una catena di due ossa e una sola azione di dieci fotogrammi. Verificare:

- assenza di scala `100` o `0.01` su mesh e root importate;
- root stabile e nessuna traslazione inattesa;
- deformazione coerente;
- durata e frame rate corretti;
- reimport dell'animazione senza duplicati;
- comportamento di `Add Leaf Bones` e assi osso documentato esplicitamente.

Il Gate B non definisce ancora il rig del personaggio o dei veicoli. Serve soltanto a scoprire incompatibilita prima che esistano asset costosi.

## Evidenze da registrare

- versione Blender e Unreal;
- screenshot delle dimensioni Blender e dei bounds Unreal;
- preset di export effettivo o schermata completa;
- opzioni di import Unreal;
- warning del log;
- esito reimport;
- tempo necessario e passaggi manuali;
- commit e percorso degli asset di prova.

## Criterio di uscita

Blender 5.2.2 diventa versione di produzione soltanto quando Gate A e superato. Il Gate B puo seguire prima della prima animazione reale. Se FBX richiede correzioni manuali non ripetibili, confrontare un singolo export glTF per le sole Static Mesh; non installare add-on o cambiare formato per l'intero progetto senza una decisione registrata.
