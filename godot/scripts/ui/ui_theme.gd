extends Node
## Autoload UiTheme (D-080): applica il tema di UiPalette alla radice prima che
## qualunque scena (compreso l'autoload PauseMenu) costruisca i suoi Control.


func _enter_tree() -> void:
	get_tree().root.theme = UiPalette.build_theme()
