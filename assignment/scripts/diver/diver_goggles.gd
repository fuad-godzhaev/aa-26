class_name DiverGoggles
extends CanvasLayer

# Full-screen diver-mask vignette. Tuning props are set by PlayerFly. See ARCHITECTURE.md §5d.

const GOGGLES_SHADER := preload("res://assignment/materials/goggles.gdshader")

@export var mask_color: Color = Color(0.012, 0.018, 0.022, 1.0)
@export var lens_offset: float = 0.32
@export var lens_size: Vector2 = Vector2(0.56, 0.66)
@export var feather: float = 0.06

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	# Layer 32 sits above the default HUD CanvasLayer (1).
	layer = 32
	_mat = ShaderMaterial.new()
	_mat.shader = GOGGLES_SHADER
	_push_params()

	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)

	_push_aspect()
	get_tree().root.size_changed.connect(_push_aspect)


# Re-push shader params; called by PlayerFly when its goggles exports change at runtime.
func refresh() -> void:
	if _mat:
		_push_params()


func _push_params() -> void:
	_mat.set_shader_parameter("mask_color", mask_color)
	_mat.set_shader_parameter("lens_offset", lens_offset)
	_mat.set_shader_parameter("lens_size", lens_size)
	_mat.set_shader_parameter("feather", feather)


# Push viewport aspect so lenses stay circular at any resolution.
func _push_aspect() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = sz.x / maxf(sz.y, 1.0)
	if _mat:
		_mat.set_shader_parameter("aspect", aspect)
