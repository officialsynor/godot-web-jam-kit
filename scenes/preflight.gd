extends Control
## Throwaway smoke-test scene — replace it on theme-reveal day.
##
## Run this in the browser before writing a line of game code. It proves the
## four things a web export breaks quietly: rendering, input, audio, and
## cross-origin isolation. Point application/run/main_scene somewhere else once
## your real scene exists.

const TONE_HZ := 440.0
const TONE_SECONDS := 0.14
const PROBE_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "action", "restart"]

var _report: Label
var _input_line: Label
var _tone: AudioStreamWAV


func _ready() -> void:
	_tone = AudioDirector.make_tone(TONE_HZ, TONE_SECONDS)
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0d0e13")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "WEB EXPORT OK"
	heading.add_theme_font_size_override("font_size", 36)
	column.add_child(heading)

	var subheading := Label.new()
	subheading.text = "Rendering, input, and audio all reached the browser."
	column.add_child(subheading)

	_report = Label.new()
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_report)

	_input_line = Label.new()
	column.add_child(_input_line)

	var tone_button := Button.new()
	tone_button.text = "Play test tone"
	tone_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tone_button.pressed.connect(_on_tone_pressed)
	column.add_child(tone_button)

	var hint := Label.new()
	hint.text = "Click the canvas first — that click is what unlocks audio — then hold W/A/S/D."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)

	_refresh_report()
	_refresh_input_line()


func _input(event: InputEvent) -> void:
	# The first real input is the browser's cue that it may start audio.
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		AudioDirector.unlock()


func _process(_delta: float) -> void:
	_refresh_input_line()


func _on_tone_pressed() -> void:
	AudioDirector.unlock()
	AudioDirector.play_sfx(_tone)
	_refresh_report()


func _refresh_report() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var audio_state := "yes" if AudioDirector.is_unlocked() else "not yet — click the canvas"
	var lines := PackedStringArray([
		"Godot %s" % Engine.get_version_info().string,
		"Platform: %s" % OS.get_name(),
		"Renderer: %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"Viewport: %d x %d" % [int(viewport_size.x), int(viewport_size.y)],
		"Audio unlocked: %s" % audio_state,
	])
	if OS.has_feature("web"):
		# Without cross-origin isolation the browser withholds SharedArrayBuffer,
		# which is exactly what a threaded web build needs. This is the single
		# most useful line on the page when a build loads but will not run.
		lines.append("crossOriginIsolated: %s" % JavaScriptBridge.eval("String(self.crossOriginIsolated)"))
	_report.text = "\n".join(lines)


func _refresh_input_line() -> void:
	var held := PackedStringArray()
	for action_name in PROBE_ACTIONS:
		if Input.is_action_pressed(action_name):
			held.append(action_name)
	_input_line.text = "Input: nothing held" if held.is_empty() else "Input: " + ", ".join(held)
