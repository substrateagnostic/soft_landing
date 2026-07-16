extends Node
## Harness — STUB. Parses CLI flags so boot/main can route (--skipmenu,
## --world=<id>, --quitafter=<seconds>, ...) before the full autoplay
## harness (input-playback scripts, --shots, --write-movie) exists.
## The harness agent owns and rewrites this file.

var flags: Dictionary = {}


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var key: String = arg.trim_prefix("--")
		var value: Variant = true
		if key.contains("="):
			var parts: PackedStringArray = key.split("=", true, 1)
			key = parts[0]
			value = parts[1]
		flags[key] = value
	print("HARNESS_FLAGS %s" % JSON.stringify(flags))


func flag(flag_name: String, default: Variant = null) -> Variant:
	return flags.get(flag_name, default)
