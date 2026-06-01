extends ColorRect

# Toggles the underwater screen post-process on when the active camera drops below
# the water surface, and feeds the shader a 0..1 depth factor (0 at the surface,
# 1 at the seabed) so the blue shift + vignette deepen as you descend.
# Pulls surface/seabed from the Ocean autoload and distortion from Settings.

@export var water_level: float = 0.0      # Y of the water surface (Ocean overrides)
@export var seabed_y: float = -30.0       # Y of the seabed (Ocean overrides)

var _mat: ShaderMaterial
var _settings


func _ready() -> void:
	_mat = material as ShaderMaterial
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat input
	visible = false
	var ocean = get_node_or_null("/root/Ocean")
	if ocean:
		water_level = ocean.SURFACE_Y
		seabed_y = ocean.SEABED_Y
	_settings = get_node_or_null("/root/Settings")
	if _settings:
		_settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	if _settings and _mat:
		_mat.set_shader_parameter("distortion_amount", _settings.distortion_amount)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var below := cam.global_position.y < water_level
	visible = below
	if below and _mat != null:
		var span: float = max(water_level - seabed_y, 0.001)
		var amt: float = clampf((water_level - cam.global_position.y) / span, 0.0, 1.0)
		_mat.set_shader_parameter("depth_amount", amt)
