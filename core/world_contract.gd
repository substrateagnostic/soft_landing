class_name WorldContract
extends Node3D
## WorldContract — the contract every world/hub scene implements (SPEC.md,
## Phase 5). A world never reaches into another world's internals, the hub,
## or autoload internals beyond this documented surface; the hub instantiates
## worlds via this contract only. Subclass and override the four methods
## below; emit the three signals at the documented moments.

signal objective_collected(id: String)
signal objective_returned(id: String)
signal exit_requested()


func world_id() -> String:
	push_error("WorldContract.world_id() not overridden by " + str(get_script()))
	return ""


func spawn_points() -> Dictionary: # {"pip": Transform3D, "otto": Transform3D}
	push_error("WorldContract.spawn_points() not overridden by " + str(get_script()))
	return {}


func objective_ids() -> Array[String]: # dreamling ids, stable, order-free
	push_error("WorldContract.objective_ids() not overridden by " + str(get_script()))
	return []


func rescue_floor_y() -> float:
	push_error("WorldContract.rescue_floor_y() not overridden by " + str(get_script()))
	return -10.0
