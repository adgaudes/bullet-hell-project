"""
Crea o sovrascrive la mappa vuota /Game/Maps/SmokeTest per lo smoke test Prototype01.

Eseguire dall'Unreal Editor (5.6.1), ad esempio tramite:
  Window > Developer Tools > Output Log > Cmd: py Scripts/CreateSmokeMap.py
oppure con l'opzione -ExecutePythonScript sulla riga di comando dell'Editor.

Richiede i plugin PythonScriptPlugin e EditorScriptingUtilities abilitati.
"""

import unreal

MAP_PACKAGE_PATH = "/Game/Maps/SmokeTest"


def create_smoke_map():
    editor_asset_lib = unreal.EditorAssetLibrary
    level_editor = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)

    if editor_asset_lib.does_asset_exist(MAP_PACKAGE_PATH):
        editor_asset_lib.delete_asset(MAP_PACKAGE_PATH)

    created = level_editor.new_level(MAP_PACKAGE_PATH, False)
    if not created:
        raise RuntimeError("Creazione della mappa SmokeTest fallita: " + MAP_PACKAGE_PATH)

    saved = level_editor.save_current_level()
    if not saved:
        raise RuntimeError("Salvataggio della mappa SmokeTest fallito: " + MAP_PACKAGE_PATH)

    unreal.log("PROTOTYPE01_SMOKE_MAP_CREATED: " + MAP_PACKAGE_PATH)


if __name__ == "__main__":
    create_smoke_map()
