# Struttura di campagna — specifica

**Stato:** proposta dell'agente (5 ottobre 2026) su indicazioni del proprietario (D-040, D-041). Il proprietario conferma, modifica o scarta le parti marcate *proposta*; le parti marcate *deciso* vengono da lui.

## 1. Cosa e deciso

- **Campagne** (*deciso*, D-040): il gioco e diviso in campagne; ogni campagna e un **percorso a livelli**: si sblocca il livello successivo finendo quello corrente.
- **Livello** (*deciso*): una run in un'**arena molto grande** (riferimento: Vampire Survivors, Deep Rock Galactic: Survivor), chiusa da **uno o piu boss di fine livello**.
- **Due tipi di upgrade** (*deciso*, D-041): alcuni **si perdono a fine livello**, altri sono **permanenti**.
- La firma resta D-033: terreno e macchine vivono nel mondo, ogni soluzione crea l'opportunita e il pericolo successivi. Vale per i livelli, i boss e per entrambi i tipi di upgrade.

## 2. Vocabolario

| Termine | Significato |
|---|---|
| Campagna | Sequenza ordinata di livelli con un tema (ambiente, nemici, boss finale). |
| Livello | Una run: arena grande, ondate, obiettivi, boss, uscita. Si vince battendo il boss; si perde morendo. |
| Upgrade di livello | Carta scelta al level-up **dentro** il livello (D-035). Svanisce a fine livello, vinto o perso. |
| Upgrade permanente | Miglioramento che resta per sempre, acquistato o sbloccato **fra** i livelli. |
| Officina | Schermata fra un livello e l'altro dove si spendono i rottami in upgrade permanenti e si prepara la carovana. |

## 3. I due tipi di upgrade (*proposta*)

| | Upgrade di livello | Upgrade permanente |
|---|---|---|
| Quando | al level-up, tre carte, dentro il livello | nell'Officina, fra i livelli |
| Valuta | esperienza (nemici abbattuti) | **rottami** portati fuori dal livello |
| Cosa | armi e loro potenziamenti, pezzi temporanei del compagno, effetti del tool (scavo esplosivo, terrapieni spinati), statistiche | **nuove capacita** del tool (portata, seconda modalita, celle per colpo), **pezzi fissi** del compagno e nuovi compagni, slot arma, vita base, tempo di invulnerabilita, sblocchi del pool di carte |
| Perche due | la build di livello e improvvisata e cambia ogni run: e il "con quello che trovi" della promessa | la crescita permanente e la carovana (promessa B) e la macchina sempre piu assurda (promessa C) |
| Visibile nel mondo | si: pezzi sul compagno, colori delle mura, effetti del tool | si: il compagno parte gia con i pezzi fissi; la silhouette della carovana cresce campagna dopo campagna |

Regola di separazione: una cosa che **cambia come leggi il campo** (portata del tool, numero di compagni, modalita del tool) e permanente; una cosa che **cambia quanto fai male o quanto resisti** puo essere di livello. I rottami sono la valuta permanente perche vengono dal terreno: scavare nel livello costruisce anche il futuro.

Cosa esce dal livello: i rottami che il compagno porta al momento della vittoria (piu un bonus dal boss); in caso di morte una **frazione** (proposta: meta), cosi perdere non azzera il progresso ma vincere conviene.

## 4. Anatomia di un livello (*proposta*)

Durata target di un livello: **12-15 minuti** (al posto dei 25 di D-034: una campagna di 4-5 livelli dura una serata).

1. **Ingresso**: il giocatore e la carovana arrivano in un punto dell'arena; l'arena ha **punti di interesse** (cortili con mura, depositi di rottami, strettoie naturali, rovine) sparsi su almeno 200x200 m.
2. **Pressione crescente**: ondate ad anello attorno al giocatore (D-039), con composizione che cambia nel tempo; eventi che deformano l'arena (`FEATURE_IDEAS.md`, idea 2) come variante per livello.
3. **Obiettivi di livello** (opzionali, uno o due per livello): raggiungere e tenere un deposito di rottami, aprire un passaggio, salvare un compagno in panne. Danno rottami extra e varieta senza cambiare le regole.
4. **Chiamata del boss**: a tempo scaduto (o a obiettivi completati) il boss arriva **da una direzione annunciata**, con telegraph leggibile. Il giocatore ha qualche secondo per preparare il terreno: e qui che la firma si vede di piu.
5. **Boss**: vedi sezione 5. Alla sua morte l'orda si ritira, si contano i rottami, si passa all'Officina.

## 5. Cosa e un boss in questo gioco (*proposta*)

Un boss non e una barra di vita grande: e **una pressione che il terreno puo risolvere in piu modi**. Ogni boss ha una regola di interazione col terreno, leggibile al primo incontro:

| Boss | Regola col terreno | Soluzioni che il campo offre |
|---|---|---|
| **Demolitore** (prima campagna) | smonta i terrapieni e porta i rottami ai suoi rottamatori, che costruiscono barricate (idea 1 di `FEATURE_IDEAS.md`) | fossati lo rallentano; mura a sacrificio lo attirano dove la chiodatrice lo colpisce; scavare sotto le sue barricate le fa crollare |
| **Trivella** | avanza in linea retta e scava da sola un solco che diventa una corsia per l'orda | rialzare celle davanti la devia; usare il suo solco come fossato contro gli altri |
| **Gru** | solleva e lascia cadere blocchi che diventano celle Raised permanenti | le sue mura si possono usare come copertura o scavare per rottami |

**Implementato il 6 ottobre 2026 (D-043)**; dallo stesso giorno i rottami delle mura smontate li portano i rottamatori al cantiere della barricata (D-045); dettagli in `PROMISE_A_PROTOTYPE_SPEC.md`, sezione Boss. Il primo boss da prototipare e il Demolitore: usa i sistemi gia esistenti (mura, rottami, campo di percorso) e risponde al "secondo nemico che mette alla prova le mura" della roadmap.

## 6. Prima campagna minima (*proposta*)

Per il primo playtest completo: **una campagna di 3 livelli**, stessa ambientazione (rovine riconquistate, D-036), arene diverse per disposizione dei punti di interesse:

| Livello | Arena | Novita | Boss |
|---|---|---|---|
| 1 | piazza e cortili (200x200 m) | rottamatori, cortile con mura come tutorial implicito | Demolitore |
| 2 | ferrovia (stretta e lunga, 120x320 m) | secondo nemico veloce; il treno arrugginito come evento che spiana i binari | Trivella |
| 3 | cantiere (260x260 m) | due Demolitori insieme o Gru | Gru |

Fra i livelli: Officina con 6-8 upgrade permanenti. Dopo il livello 3: schermata di fine campagna con la mappa scolpita (idea 7) e i rottami totali.

## 7. Cosa persiste e cosa no (riepilogo)

| Cosa | Dentro il livello | Fra i livelli | Fra le campagne |
|---|---|---|---|
| Upgrade di livello (carte) | si | **no** | no |
| Upgrade permanenti | si | si | si |
| Rottami | nel compagno | portati in Officina | si |
| Terreno modificato | si | no (arena nuova) | no |
| Vita | si | ripristinata | ripristinata |
| Livelli sbloccati | | si | si (per campagna) |

## 8. Domande al proprietario

1. Rottami come valuta permanente: va bene, o preferisci una valuta separata?
2. Morte: metà dei rottami e ripartire dal livello corrente, o perdere tutto il livello?
3. Durata 12-15 minuti per livello, 3 livelli per la prima campagna: giusto per un primo playtest?
4. I tre boss proposti: il Demolitore come primo va bene?

Senza risposta, l'agente procede con le proposte cosi come sono.

## 9. Conseguenze tecniche

- `RunProgression` resta per gli upgrade di livello; serve un **profilo permanente** salvato su disco (`user://`), con gli upgrade permanenti e i livelli sbloccati, separato dalle impostazioni gia salvate.
- `ArenaRun` diventa `Level`: riceve il profilo, applica gli upgrade permanenti all'avvio, consegna i rottami all'uscita.
- Una scena per livello, piu una scena Officina e una mappa di campagna.
- Il catalogo upgrade (`upgrade_catalog.gd`) prende un campo `permanent: bool`.
