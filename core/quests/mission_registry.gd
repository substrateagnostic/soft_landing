class_name MissionRegistry
extends RefCounted
## MissionRegistry — loads data/missions/<world_id>.json into Mission
## objects keyed by dreamling id (D21). Mirrors the_moon.gd's own
## FileAccess-read pattern exactly for consistency across the two "data
## drives content" seams in this repo.
##
## Missing file, unparseable JSON, or an id absent from the file all mean
## the same thing: "open" (worlds/common/world_base.gd attaches no
## MissionDriver at all for an id with no entry here) -- generosity is the
## default, per AGENTS.md's "nothing missable" floor. A world with zero
## dreamlings (pillow_fort) needs no file at all.

const DATA_PATH_FORMAT: String = "res://data/missions/%s.json"


## Returns Dictionary[String, Mission] -- empty if the world has no mission
## file, the file fails to parse, or it parses to something other than the
## documented {"missions": [...]} shape.
static func load_for_world(world_id: String) -> Dictionary:
	var out: Dictionary = {}
	var path: String = DATA_PATH_FORMAT % world_id
	if not FileAccess.file_exists(path):
		return out

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary):
		push_warning("MissionRegistry: %s did not parse to a Dictionary" % path)
		return out

	var list: Variant = (parsed as Dictionary).get("missions", [])
	if not (list is Array):
		push_warning("MissionRegistry: %s has no 'missions' array" % path)
		return out

	for entry: Variant in (list as Array):
		if not (entry is Dictionary):
			continue
		var entry_dict: Dictionary = entry as Dictionary
		var mission_id: String = String(entry_dict.get("id", ""))
		if mission_id.is_empty():
			push_warning("MissionRegistry: %s has an entry with no id -- skipped" % path)
			continue
		out[mission_id] = Mission.from_dict(mission_id, entry_dict)

	return out
