class_name Mission
extends RefCounted
## Mission — a single dreamling's micro-mission data (D21, docs/DECISIONS.md;
## taxonomy per docs/research/v2/structure_progression.md TOP 12 #1). Pure
## data, no autoload references (kept safe to reference statically from
## one-shot `--script` tools -- see tools/props/check_missions.gd header for
## why that matters here). Loaded from data/missions/<world_id>.json by
## MissionRegistry and attached to a matching Dreamling id by
## worlds/common/world_base.gd; the actual archetype BEHAVIOR lives in
## worlds/common/mission_driver.gd, a sibling component, not here.
##
## Archetypes tonight (D21/D23 — every one is celebration-only, nothing
## missable, floor law):
##   open  — classic sitting dreamling. Default when no data entry exists
##           for an id, or the entry's archetype is unrecognized. Attaching
##           NO MissionDriver at all for "open" is what guarantees the
##           zero-behavior-change floor, not a driver that happens to no-op.
##   race  — giggles and zips a short rubber-banded path once a player is
##           close, then settles and lets itself be caught normally.
##   ride  — drifts a slow closed loop forever; magnetism stays on, so a
##           near player pulls the whole loop toward them.
##   shy   — hides (small + dim) until a player stands still nearby for a
##           beat, then peeks out, brightens, and becomes catchable.
##   duet  — wants two players near at once to bloom catchable; a
##           single-player fallback timer guarantees it's never missable
##           solo (mission_driver.gd's own contract, see its header).

const ARCHETYPE_OPEN: String = "open"
const ARCHETYPE_RACE: String = "race"
const ARCHETYPE_RIDE: String = "ride"
const ARCHETYPE_SHY: String = "shy"
const ARCHETYPE_DUET: String = "duet"
const VALID_ARCHETYPES: PackedStringArray = [
	ARCHETYPE_OPEN, ARCHETYPE_RACE, ARCHETYPE_RIDE, ARCHETYPE_SHY, ARCHETYPE_DUET,
]

var id: String = ""
var archetype: String = ARCHETYPE_OPEN
var params: Dictionary = {}
## Mission-author pass (docs/verify/missions-m2-VERIFY.md): mission_driver.gd
## now calls TheMoon.say(mission.moon_line_key) itself, exactly once, at
## each archetype's own bloom/start moment (race: trigger; ride: first
## proximity; shy/duet: reveal/bloom) -- never on every catch, preserving
## the Moon's "rare, structural beats only" law (NARRATION_BIBLE.md). An
## "open" mission gets no driver and stays silent UNLESS params has
## `"speak_on_collect": true` (world_base.gd._wire_open_moon_line()),
## reserved for a genuinely special one-off flourish (bramble's d07,
## already riding a snore geyser) rather than every plain pickup. A
## missing/empty key is always safe: TheMoon.say() falls back to printing
## the key itself rather than erroring, and every call site guards on a
## non-empty key before calling.
var moon_line_key: String = ""


static func from_dict(mission_id: String, data: Dictionary) -> Mission:
	var mission := Mission.new()
	mission.id = mission_id
	var raw_archetype: String = String(data.get("archetype", ARCHETYPE_OPEN))
	if not VALID_ARCHETYPES.has(raw_archetype):
		push_warning("Mission: unknown archetype '%s' for id '%s' -- defaulting to open" % [raw_archetype, mission_id])
		raw_archetype = ARCHETYPE_OPEN
	mission.archetype = raw_archetype
	var raw_params: Variant = data.get("params", {})
	mission.params = (raw_params as Dictionary) if raw_params is Dictionary else {}
	mission.moon_line_key = String(data.get("moon_line_key", ""))
	return mission
