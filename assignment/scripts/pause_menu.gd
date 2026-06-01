extends CanvasLayer
## Boot menu + in-game pause menu in one. Add a CanvasLayer to the game scene and
## attach this script — it builds its own UI in code and enforces its own layer /
## process mode, so no setup beyond "add node + attach script" is needed.
##
##   Boot      -> opaque "own screen", primary button reads "Start Game".
##   In game   -> ESC pauses, frozen game blurred behind, primary reads "Resume".
##
## Owns the mouse mode and ESC (player_fly no longer does). Reads/writes the
## Settings autoload and persists when you leave the Settings panel.

const BLUR_CODE := "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform vec4 boot_color : source_color = vec4(0.03, 0.10, 0.16, 1.0);
uniform float blur_size : hint_range(0.0, 6.0) = 3.0;
uniform float darken : hint_range(0.0, 1.0) = 0.4;
void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_size;
	vec3 c = vec3(0.0);
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0, -1.0) * ps).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0, -1.0) * ps).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0, -1.0) * ps).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0,  0.0) * ps).rgb;
	c += texture(screen_tex, SCREEN_UV).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0,  0.0) * ps).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0,  1.0) * ps).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  1.0) * ps).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0,  1.0) * ps).rgb;
	c /= 9.0;
	c *= (1.0 - darken);
	COLOR = vec4(mix(boot_color.rgb, c, reveal), 1.0);
}"

enum Opt { FOV, VOLUME, DISTORTION, SENSITIVITY }

# UI click / hover SFX (Kenney UI Audio, CC0).
const UI_CLICK := "res://assignment/audio/ui_click.wav"
const UI_HOVER := "res://assignment/audio/ui_hover.wav"

@export var title_text: String = "GEMINI"

var S                              # the Settings autoload (untyped for dynamic access)
var _started := false
var _is_open := true
var _in_settings := false

var _bg_mat: ShaderMaterial
var _root: Control
var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _primary_btn: Button
var _sld_fov: HSlider
var _sld_vol: HSlider
var _sld_dist: HSlider
var _sld_sens: HSlider

var _ui_audio: AudioStreamPlayer
var _click_stream: AudioStream
var _hover_stream: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100                   # above the underwater tint + goggles
	S = get_node_or_null("/root/Settings")
	_setup_ui_audio()
	_build_ui()
	_open(false)                  # boot: opaque own-screen
	get_tree().paused = true


func _setup_ui_audio() -> void:
	_ui_audio = AudioStreamPlayer.new()
	_ui_audio.process_mode = Node.PROCESS_MODE_ALWAYS   # audible while the tree is paused
	_ui_audio.bus = "Master"
	add_child(_ui_audio)
	if ResourceLoader.exists(UI_CLICK):
		_click_stream = load(UI_CLICK)
	if ResourceLoader.exists(UI_HOVER):
		_hover_stream = load(UI_HOVER)


func _play_click() -> void:
	if _ui_audio and _click_stream:
		_ui_audio.stream = _click_stream
		_ui_audio.play()


func _play_hover() -> void:
	if _ui_audio and _hover_stream:
		_ui_audio.stream = _hover_stream
		_ui_audio.play()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		return
	if _is_open:
		if _in_settings:
			_show_settings(false)
		elif _started:
			_resume()
	elif _started:
		_open(true)               # in-game pause: blurred backdrop
	get_viewport().set_input_as_handled()


# --- state transitions -------------------------------------------------------

func _open(in_game: bool) -> void:
	_is_open = true
	_root.visible = true
	_show_settings(false)
	_bg_mat.set_shader_parameter("reveal", 1.0 if in_game else 0.0)
	_primary_btn.text = "Resume" if _started else "Start Game"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
	_started = true
	_is_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_settings(on: bool) -> void:
	_in_settings = on
	_main_box.visible = not on
	_settings_box.visible = on
	if not on and S:
		S.save_settings()         # persist on leaving the panel


# --- button handlers ---------------------------------------------------------

func _on_primary() -> void:
	_resume()

func _on_settings() -> void:
	_show_settings(true)

func _on_back() -> void:
	_show_settings(false)

func _on_exit() -> void:
	get_tree().quit()

func _on_reset() -> void:
	if S:
		S.reset_defaults()
	_sld_fov.value = _get_val(Opt.FOV)
	_sld_vol.value = _get_val(Opt.VOLUME)
	_sld_dist.value = _get_val(Opt.DISTORTION)
	_sld_sens.value = _get_val(Opt.SENSITIVITY)


# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks reaching the game
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = BLUR_CODE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = sh
	bg.material = _bg_mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(_spacer(20))

	# main buttons
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	col.add_child(_main_box)
	_primary_btn = _make_button("Start Game", _on_primary)
	_main_box.add_child(_primary_btn)
	_main_box.add_child(_make_button("Settings", _on_settings))
	_main_box.add_child(_make_button("Exit", _on_exit))

	# settings panel
	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 8)
	_settings_box.visible = false
	col.add_child(_settings_box)

	_sld_fov = _add_slider("Field of View", 60.0, 110.0, 1.0, _get_val(Opt.FOV), Opt.FOV)
	_sld_vol = _add_slider("Master Volume", 0.0, 1.0, 0.01, _get_val(Opt.VOLUME), Opt.VOLUME, true)
	_sld_dist = _add_slider("Underwater Distortion", 0.0, 0.012, 0.0005, _get_val(Opt.DISTORTION), Opt.DISTORTION)
	_sld_sens = _add_slider("Look Sensitivity", 0.0005, 0.006, 0.0001, _get_val(Opt.SENSITIVITY), Opt.SENSITIVITY)

	_settings_box.add_child(_spacer(10))
	_settings_box.add_child(_make_button("Reset to Defaults", _on_reset))
	_settings_box.add_child(_make_button("Back", _on_back))


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	b.mouse_entered.connect(_play_hover)
	return b


func _add_slider(label_text: String, mn: float, mx: float, step: float, value: float, opt: int, as_percent := false) -> HSlider:
	var row := VBoxContainer.new()

	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(340, 0)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(lbl)
	head.add_child(val)
	row.add_child(head)

	var slider := HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(340, 0)
	row.add_child(slider)

	_settings_box.add_child(row)

	val.text = _fmt(value, step, as_percent)
	slider.value_changed.connect(_on_slider_changed.bind(opt, val, step, as_percent))
	return slider


func _on_slider_changed(v: float, opt: int, val_label: Label, step: float, as_percent: bool) -> void:
	val_label.text = _fmt(v, step, as_percent)
	if S == null:
		return
	match opt:
		Opt.FOV: S.set_fov(v)
		Opt.VOLUME: S.set_master_volume(v)
		Opt.DISTORTION: S.set_distortion(v)
		Opt.SENSITIVITY: S.set_look_sensitivity(v)


func _get_val(opt: int) -> float:
	if S != null:
		match opt:
			Opt.FOV: return S.fov
			Opt.VOLUME: return S.master_volume
			Opt.DISTORTION: return S.distortion_amount
			Opt.SENSITIVITY: return S.look_sensitivity
	# fallbacks if the autoload isn't present yet
	match opt:
		Opt.FOV: return 75.0
		Opt.VOLUME: return 0.9
		Opt.DISTORTION: return 0.004
		Opt.SENSITIVITY: return 0.0025
	return 0.0


func _fmt(v: float, step: float, as_percent: bool) -> String:
	if as_percent:
		return "%d%%" % int(round(v * 100.0))
	elif step < 0.001:
		return "%.4f" % v
	elif step < 1.0:
		return "%.2f" % v
	return "%d" % int(round(v))
