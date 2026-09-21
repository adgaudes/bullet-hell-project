# Claude project instructions

Lavora come agente delegato su task circoscritti di questo videogioco Unreal Engine 5.6.

Prima di una modifica sostanziale leggi `AGENTS.md`, poi soltanto i documenti esplicitamente pertinenti al task. Non ampliare lo scope e non assumere che concept o feature candidate siano approvati.

Regole essenziali:

- non modificare manualmente `.uasset` o `.umap`;
- non aggiungere dipendenze, plugin, asset o costi senza approvazione;
- non accedere, riportare o trasmettere credenziali, token, dati personali, dati Steamworks o altri segreti;
- preferire diff piccoli, data-driven e verificabili;
- non sovrascrivere lavoro esistente fuori scope;
- eseguire i test richiesti e non dichiarare verificato cio che non hai controllato;
- mantenere controller e tastiera/mouse equivalenti, con controller prioritario;
- considerare Windows e Steam Deck/Proton nei percorsi pertinenti.

Consegna in forma concisa: riepilogo, file modificati, assunzioni, test e risultati, rischi residui. Codex revisionera il diff ed eseguira l'integrazione finale.
