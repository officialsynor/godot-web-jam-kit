extends Node
## Fade-to-black scene switching.
##
## Lives on its own CanvasLayer at a high layer index so it draws over whatever
## scene is currently loaded, and needs no per-scene wiring.

const FADE_SECONDS := 0.25
const FADE_LAYER := 100

var _veil: ColorRect
var _switching: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer := CanvasLayer.new()
	layer.name = "SceneRouterLayer"
	layer.layer = FADE_LAYER
	add_child(layer)

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(0, 0, 0, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)


## Switches to `scene_path`, fading out and back in. Ignores re-entrant calls
## so a stray double-click cannot start two transitions at once.
func goto(scene_path: String) -> void:
	if _switching:
		return
	_switching = true

	await _fade_to(1.0)

	# A scene change while paused would leave the new scene frozen.
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneRouter: could not load '%s' (error %d)" % [scene_path, error])

	await get_tree().process_frame
	await _fade_to(0.0)

	_switching = false


func _fade_to(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", target_alpha, FADE_SECONDS)
	await tween.finished
