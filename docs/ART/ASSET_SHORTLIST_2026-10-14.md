# Asset grafici gratuiti: rosa per terreno, erba e rovine (14 ottobre 2026)

Per il blocco grafica del playtest del 14 ottobre (O-08, O-09, O-10). Licenze lette sulle pagine il 14 ottobre 2026; **nulla scaricato**. Il tiling e stimato da descrizioni e misure, va provato con una cattura.

**Licenze:** Poly Haven ([polyhaven.com/license](https://polyhaven.com/license)) e ambientCG ([docs.ambientcg.com/license](https://docs.ambientcg.com/license/)) sono CC0, uso commerciale libero senza attribuzione. Kenney, Quaternius e KayKit: i pacchetti citati sono CC0.

## Texture del terreno (Terrain3D: albedo+altezza, normal OpenGL+roughness, stessa dimensione per tutti; 1-2K bastano)

| Uso | Primo candidato | Alternative |
|---|---|---|
| Asfalto rovinato | [Poly Haven asphalt_02](https://polyhaven.com/a/asphalt_02) (3x3 m, omogeneo) | [ambientCG Road012B](https://ambientcg.com/view?id=Road012B) (procedurale, ripetizione probabile), Road008B |
| Lastricato rotto | [ambientCG PavingStones149](https://ambientcg.com/view?id=PavingStones149) (fotogrammetria, crepe e muschio) | griglia di blocchi: la ripetizione si nota |
| Macerie | [Poly Haven concrete_debris](https://polyhaven.com/a/concrete_debris) (~2 m) | [ambientCG Ground111](https://ambientcg.com/view?id=Ground111), Ground107 |
| Terra, fango, scavato | [Poly Haven brown_mud_leaves_01](https://polyhaven.com/a/brown_mud_leaves_01) (~1,3 m) | [ambientCG Ground104](https://ambientcg.com/view?id=Ground104), Ground106 |
| Ghiaia, massicciata | [ambientCG Gravel040](https://ambientcg.com/view?id=Gravel040) | Poly Haven rocky_trail, gravel_road |
| Terreno erboso | [ambientCG Ground037](https://ambientcg.com/view?id=Ground037) (2,1 m) | Poly Haven forest_floor, grass_path_2 |
| Fondo a grande scala | [Poly Haven aerial_ground_rock](https://polyhaven.com/a/aerial_ground_rock) (20x20 m), [aerial_grass_rock](https://polyhaven.com/a/aerial_grass_rock) (15x15 m) | il tiling meno visibile |

Contro la ripetizione, Terrain3D 1.0.2 ha gia `macro_variation`, `dual_scaling` e detiling per texture. Il channel packer e in `godot/addons/terrain_3d/menu/channel_packer.gd`.

## Erba

- **Shader a particelle d'esempio di Terrain3D**, gia nel repo (`godot/addons/terrain_3d/extras/particle_example/`): erba piazzata dalla GPU attorno alla camera, filtro per strato di texture e per pendenza, macchie da rumore, colore dalla color map, vento. Punto di partenza, non prodotto finito ("hard coded things"). Secondo la documentazione piu efficiente dell'instancer.
- **Terrain3DInstancer**: MultiMesh a celle da 32 m, LOD, importatore da SimpleGrassTextured; niente vento integrato.
- **SimpleGrassTextured 2.1.0** (MIT), gia nel repo e spento: interazione col giocatore, vento.
- Texture e modelli CC0: Poly Haven grass_medium_01/02, weed_plant_02, nettle_plant, dandelion_01 (troppi poligoni per istanziarli: se ne ricavano card). Quaternius Stylized Nature MegaKit (CC0, ma lo shader col vento e a pagamento e lo stile e cartoon).

Steam Deck: prestazioni di instancer e particelle non documentate, da misurare.

## Rovine e oggetti

- **Indicazione:** pochi moduli semplici fatti in Blender (muri spezzati, solai, pilastri) rivestiti con texture CC0 di Poly Haven (broken_wall, castle_brick_broken_06, concrete_floor_damaged_01, brick_moss_001, chipped_concrete), piu oggetti Poly Haven ottimizzati e decal. Coerente col terreno, meglio che mischiare pacchetti low-poly.
- Oggetti Poly Haven (CC0, da decimare): modular_factory_facade (175k poligoni), modular_chainlink_fence, modular_pipes, modular_electricity_poles, modular_fire_escape, concrete_road_barrier, barrel_01-03, old_tyre, covered_car, street_lamp_01/02, utility_box, water_manhole_cover, wooden_crate_02, overhead_crane.
- Pacchetti CC0 di riserva: [Destroyed City Assets (Fleurman)](https://opengameart.org/node/71246) (pesanti, da decimare), [3D Apocalyptic Building (Majadroid)](https://opengameart.org/node/122405) (grattacieli low-poly), [Kenney Train Kit](https://kenney.nl/assets/train-kit), Kenney City Kit Industrial, Quaternius Downtown City / Zombie Apocalypse (stile giocattolo, scartati come prima scelta).

## Addon

| Addon | Licenza | Esito |
|---|---|---|
| [ProtonScatter](https://github.com/HungryProton/scatter) | MIT, compatibile con 4.7 (luglio 2026) | utile per spargere macerie, rifiuti, erbacce con esclusioni; da proporre |
| [Sky3D](https://github.com/TokisanGames/Sky3D) | MIT | non serve: il ciclo giorno/notte c'e gia |
| Post-processing di terze parti | — | valutato, non serve: Godot 4.7 ha SSAO, SSIL, glow, LUT e CompositorEffect |
| Decal | — | nodo nativo; da provare sul terreno Terrain3D |
