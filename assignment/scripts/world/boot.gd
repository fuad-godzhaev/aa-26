extends Node

# Tiny bootloader. Switches to the renderer-appropriate reef scene based on the platform feature flag at startup. Desktop build (Forward+) uses reef.tscn; Quest / Android build (Mobile) uses reef_xr.tscn. See ARCHITECTURE.md §5e.

const DESKTOP_SCENE := "res://assignment/scenes/reef.tscn"
const XR_SCENE := "res://assignment/scenes/reef_xr.tscn"


func _ready() -> void:
	var target: String = XR_SCENE if OS.has_feature("mobile") else DESKTOP_SCENE
	# Deferred so we don't change scene during the boot node's own _ready chain.
	get_tree().change_scene_to_file.call_deferred(target)
