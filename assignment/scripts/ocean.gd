extends Node
## DEVELOPER source of truth for shared world + look constants. NOT player-facing
## (for the player's runtime options see settings.gd). Edit values HERE. They feed:
##   * GDScript  -> read directly: Ocean.SURFACE_Y, Ocean.SEABED_Y, Ocean.DEEP_TINT, ...
##   * Shaders   -> via `global uniform ocean_*` (see ocean_globals.gdshaderinc).
## At boot this pushes the values into Godot's global shader parameters, so the
## running game always matches this file.

# --- world geometry (metres, world Y) ---
const SURFACE_Y := 0.0
const SEABED_Y := -30.0           # deepest point (mostly ~-27)
const ARENA_RADIUS := 27.5        # GDScript-only (spawners); not a shader global

# --- depth-tint band (world Y): vivid at TINT_START, fully cooled by TINT_END ---
const TINT_START := 0.0
const TINT_END := -30.0

# --- palette ---
const WATER_TINT := Color("1a739e")    # shallow / near water + fog colour
const DEEP_TINT := Color("72aab8")     # what materials cool toward at depth
const CAUSTIC_TINT := Color("b3f2ff")  # ground caustic web colour


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_push(&"ocean_surface_y", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, SURFACE_Y)
	_push(&"ocean_seabed_y", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, SEABED_Y)
	_push(&"ocean_tint_start", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, TINT_START)
	_push(&"ocean_tint_end", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, TINT_END)
	_push(&"ocean_water_tint", RenderingServer.GLOBAL_VAR_TYPE_COLOR, WATER_TINT)
	_push(&"ocean_deep_tint", RenderingServer.GLOBAL_VAR_TYPE_COLOR, DEEP_TINT)
	_push(&"ocean_caustic_tint", RenderingServer.GLOBAL_VAR_TYPE_COLOR, CAUSTIC_TINT)


# Convenience for GDScript consumers (same value as the shader global).
func depth_factor(world_y: float) -> float:
	return clampf((TINT_START - world_y) / maxf(TINT_START - TINT_END, 0.001), 0.0, 1.0)


# The ocean_* globals are declared in project.godot [shader_globals], so they
# always exist at runtime — just set our authoritative value. (get_list() is
# editor-only and global_shader_parameter_add() errors if the name already
# exists, so neither is usable here.) `type` is kept for call-site clarity.
func _push(pname: StringName, type: int, value) -> void:
	RenderingServer.global_shader_parameter_set(pname, value)
