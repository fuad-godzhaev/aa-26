extends Node
## Autoload — register in Project Settings > Autoload with the name "Settings".
## Single source of truth for the player's runtime options. Holds the values,
## applies them to the game, and persists to user://settings.cfg. The menu writes
## here; the camera / underwater shader / player read via the `changed` signal.

signal changed

const CONFIG_PATH := "user://settings.cfg"

# Defaults double as the "Reset to defaults" values.
const DEF_FOV := 75.0
const DEF_VOLUME := 0.9          # 0..1 linear (mapped to dB on the Master bus)
const DEF_DISTORTION := 0.004    # underwater_canvas.gdshader -> distortion_amount
const DEF_SENSITIVITY := 0.0025  # player_fly.gd -> look_sensitivity

var fov: float = DEF_FOV
var master_volume: float = DEF_VOLUME
var distortion_amount: float = DEF_DISTORTION
var look_sensitivity: float = DEF_SENSITIVITY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # usable while the tree is paused
	load_settings()
	_apply_volume()
	changed.emit()


func set_fov(v: float) -> void:
	fov = v
	changed.emit()

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	changed.emit()

func set_distortion(v: float) -> void:
	distortion_amount = v
	changed.emit()

func set_look_sensitivity(v: float) -> void:
	look_sensitivity = v
	changed.emit()

func reset_defaults() -> void:
	fov = DEF_FOV
	master_volume = DEF_VOLUME
	distortion_amount = DEF_DISTORTION
	look_sensitivity = DEF_SENSITIVITY
	_apply_volume()
	changed.emit()
	save_settings()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(master_volume, 0.0001, 1.0)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "distortion_amount", distortion_amount)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("controls", "look_sensitivity", look_sensitivity)
	cfg.save(CONFIG_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return   # no file yet -> keep defaults
	fov = float(cfg.get_value("video", "fov", fov))
	distortion_amount = float(cfg.get_value("video", "distortion_amount", distortion_amount))
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
	look_sensitivity = float(cfg.get_value("controls", "look_sensitivity", look_sensitivity))
