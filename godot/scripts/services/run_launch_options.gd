class_name RunLaunchOptions
extends RefCounted
## Opzioni della riga di comando dopo `--`, lette in un solo posto (R-23): menu
## iniziale, run e sonda di smoke test leggono tutte da qui. Una nuova opzione va
## aggiunta qui e, se deve saltare il menu, in AUTOSTART_PREFIXES.

## Opzioni che fanno saltare il menu iniziale e avviano subito il livello.
const AUTOSTART_PREFIXES: Array[String] = ["--autostart", "--seed=", "--boss-at=", "--capture="]


static func wants_autostart(args: PackedStringArray = OS.get_cmdline_user_args()) -> bool:
	for arg in args:
		for prefix in AUTOSTART_PREFIXES:
			if arg.begins_with(prefix):
				return true
	return false


## Seme della run: `--seed=N`, altrimenti casuale.
static func run_seed(args: PackedStringArray = OS.get_cmdline_user_args()) -> int:
	var value := _value_of("--seed=", args)
	if not value.is_empty():
		return value.to_int()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & 0x7fffffff


## Secondi alla chiamata del boss: `--boss-at=S`, altrimenti il tuning.
static func boss_call_seconds(default_seconds: float, args: PackedStringArray = OS.get_cmdline_user_args()) -> float:
	var value := _value_of("--boss-at=", args)
	return value.to_float() if not value.is_empty() else default_seconds


## Percorso del PNG da salvare al primo frame utile (`--capture=<file>`), o vuoto.
static func capture_path(args: PackedStringArray = OS.get_cmdline_user_args()) -> String:
	return _value_of("--capture=", args)


static func _value_of(prefix: String, args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""
