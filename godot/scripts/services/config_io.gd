class_name ConfigIO
extends RefCounted
## Scrittura atomica di un ConfigFile (R-12): prima su `<percorso>.tmp`, poi rinomina
## sopra il file vero. Uno spegnimento a meta scrittura lascia il file precedente
## intatto invece di un file troncato che al caricamento azzererebbe tutto.


static func save_atomic(config: ConfigFile, path: String) -> Error:
	var temp := path + ".tmp"
	var error := config.save(temp)
	if error != OK:
		return error
	var base := ProjectSettings.globalize_path(path)
	var temp_abs := ProjectSettings.globalize_path(temp)
	error = DirAccess.rename_absolute(temp_abs, base)
	if error != OK:
		DirAccess.remove_absolute(temp_abs)
	return error
