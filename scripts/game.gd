extends Node2D
## Reference game — one screen, one verb: grab the diamonds, do not let the
## blob touch you. Everything here exists to prove one full loop works end to
## end (input -> movement -> collision -> score -> death -> restart -> sound)
## so that on theme-reveal day you only have to change *what it looks like*,
## not *whether it runs*.
##
## Visuals are Polygon2D and audio is the vendored CC0 Kenney pack plus one
## synthesised arpeggio, so there is no licensing risk and no dangling asset.

const ARENA_MARGIN := 48.0
const TARGET_SCORE := 12
const STARTING_COLLECTIBLES := 6

# --- theme slot ------------------------------------------------------------
# On theme-reveal day change these four lines and nothing else.
const GAME_TITLE := "REFERENCE GAME"
const FONT_PATH := "res://fonts/PressStart2P-Regular.ttf"
const SFX_DIR := "res://audio/kenney_interface_sounds/"
# ---------------------------------------------------------------------------

# Juice tuning. Cheapest perceived-quality-per-minute wins, in this order.
const SHAKE_ON_HIT := 14.0
const SHAKE_DECAY := 52.0
const HIT_PAUSE_SECONDS := 0.07

var _arena := Rect2()
var _started := false
var _over := false

var _player: Player
var _hazard: Hazard
var _font: Font
var _score_label: Label
var _hint_label: Label
var _start_overlay: Control

var _sfx_start: AudioStream
var _sfx_pickup: AudioStream
var _sfx_hit: AudioStream
var _sfx_win: AudioStream
var _music: AudioStream

var _shake := 0.0


func _ready() -> void:
	randomize()
	_font = load(FONT_PATH) as Font

	_arena = Rect2(
		Vector2(ARENA_MARGIN, ARENA_MARGIN),
		get_viewport_rect().size - Vector2(ARENA_MARGIN, ARENA_MARGIN) * 2.0)

	_build_audio()
	_build_ui()
	_draw_arena()

	# Connect BEFORE reset_run(), otherwise the initial "SCORE 0 / 12" emit
	# happens with nobody listening and the HUD stays blank until first pickup.
	GameState.score_changed.connect(_on_score_changed)
	GameState.reset_run()

	_spawn_player()
	_spawn_hazard()
	for i in STARTING_COLLECTIBLES:
		_spawn_collectible()

	# Nothing moves until the player actually starts. This is also what gives
	# the browser its first user gesture, which is what unblocks audio.
	_player.set_physics_process(false)
	_hazard.set_process(false)


func _exit_tree() -> void:
	# A scene change or reload landing inside hit-pause would otherwise leave
	# the whole engine frozen at time_scale 0.
	Engine.time_scale = 1.0


# --- setup -----------------------------------------------------------------

func _build_audio() -> void:
	# Hand-made CC0 sounds (Kenney interface pack) rather than synthesised
	# tones — audio is 20% of the peer-voting score.
	_sfx_start = load(SFX_DIR + "confirmation_002.wav") as AudioStream
	_sfx_pickup = load(SFX_DIR + "pluck_001.wav") as AudioStream
	_sfx_hit = load(SFX_DIR + "error_005.wav") as AudioStream
	_sfx_win = load(SFX_DIR + "confirmation_001.wav") as AudioStream
	_music = _build_music()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)

	_score_label = Label.new()
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_score_label.offset_left = ARENA_MARGIN
	_score_label.offset_top = 20.0
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_score_label.add_theme_font_override("font", _font)
	_score_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(_score_label)

	_hint_label = Label.new()
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint_label.offset_bottom = -20.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.add_theme_font_override("font", _font)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.text = "PRESS ANY KEY OR CLICK TO START"
	layer.add_child(_hint_label)

	# Title card. It deliberately does NOT capture mouse input: the start
	# gesture is read in _input(), which runs before GUI handling, so a click
	# or tap anywhere starts the game and unlocks audio. A MOUSE_FILTER_STOP
	# overlay here swallows the click and the card silently stops working.
	_start_overlay = ColorRect.new()
	_start_overlay.color = Color(0.04, 0.04, 0.06, 0.94)
	_start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_start_overlay)

	var title := Label.new()
	title.text = "%s\n\nPRESS ANY KEY OR CLICK TO START" % GAME_TITLE
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 40)
	_start_overlay.add_child(title)


func _draw_arena() -> void:
	var border := Line2D.new()
	border.points = PackedVector2Array([
		_arena.position, Vector2(_arena.end.x, _arena.position.y),
		_arena.end, Vector2(_arena.position.x, _arena.end.y), _arena.position,
	])
	border.width = 3.0
	border.default_color = Color(1, 1, 1, 0.14)
	add_child(border)


# --- spawning --------------------------------------------------------------

func _spawn_player() -> void:
	_player = Player.new()
	_player.position = get_viewport_rect().size * 0.5
	add_child(_player)


func _spawn_hazard() -> void:
	_hazard = Hazard.new()
	_hazard.position = Vector2(_arena.position.x + 70.0, _arena.end.y - 70.0)
	add_child(_hazard)
	_hazard.caught_player.connect(_on_caught)


func _spawn_collectible() -> void:
	var collectible := Collectible.new()
	collectible.position = _random_arena_point()
	collectible.picked_up.connect(_on_picked_up)
	add_child(collectible)


func _random_arena_point() -> Vector2:
	# Keep spawns a little away from the player so a pickup can never appear
	# already overlapping them.
	for attempt in 12:
		var point := Vector2(
			randf_range(_arena.position.x, _arena.end.x),
			randf_range(_arena.position.y, _arena.end.y))
		if _player == null or point.distance_to(_player.position) > 150.0:
			return point
	return _arena.get_center()


# --- input -----------------------------------------------------------------

# _input() rather than _unhandled_input(): it runs before GUI handling, so the
# full-screen title card cannot eat the click that is supposed to start the
# game. A swallowed first click is the single easiest way to look broken.
func _input(event: InputEvent) -> void:
	# Browsers refuse to start an AudioContext before a real gesture. Every
	# input is a candidate; unlock() is idempotent.
	if not AudioDirector.is_unlocked() and _is_gesture(event):
		AudioDirector.unlock()

	if not _started and _is_gesture(event):
		_start()
		get_viewport().set_input_as_handled()
		return

	if _over:
		if event.is_action_pressed("restart"):
			_restart()
		return

	# Real touch only. Mouse drag is deliberately not movement, so a desktop
	# click-to-start never leaves the player drifting toward the cursor.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_player.set_move_target(touch.position)
		else:
			_player.clear_move_target()
	elif event is InputEventScreenDrag:
		_player.set_move_target((event as InputEventScreenDrag).position)


func _is_gesture(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func _start() -> void:
	if _started:
		return
	_started = true
	_start_overlay.hide()
	_hint_label.text = "WASD / ARROWS OR DRAG TO MOVE   |   R TO RESTART"
	_player.set_physics_process(true)
	_hazard.set_process(true)
	AudioDirector.play_sfx(_sfx_start, -2.0)
	AudioDirector.play_music(_music)


func _restart() -> void:
	# Hit-pause must never survive the reload, or the fresh scene inherits a
	# frozen clock and nothing moves.
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# --- game rules ------------------------------------------------------------

func _on_score_changed(new_score: int) -> void:
	_score_label.text = "SCORE %d / %d" % [new_score, TARGET_SCORE]


func _on_picked_up(at: Vector2) -> void:
	if _over:
		return
	GameState.add_score(1)
	_burst(at)
	if GameState.score >= TARGET_SCORE:
		AudioDirector.play_sfx(_sfx_win, 0.0)
		_finish("YOU WIN - %d POINTS. PRESS R TO PLAY AGAIN." % GameState.score)
	else:
		AudioDirector.play_sfx(_sfx_pickup, -4.0)
		_spawn_collectible()


func _on_caught() -> void:
	if _over or not _started:
		return
	_burst(_player.global_position)
	AudioDirector.play_sfx(_sfx_hit, 0.0)
	_finish("CAUGHT - PRESS R TO TRY AGAIN")
	_shake = SHAKE_ON_HIT
	_hit_pause()


func _finish(message: String) -> void:
	_over = true
	_player.set_physics_process(false)
	_player.clear_move_target()
	_hazard.set_process(false)
	_hint_label.text = message


# --- juice -----------------------------------------------------------------

func _process(delta: float) -> void:
	# The shake moves this Node2D only, so the world rattles while the HUD —
	# which lives on its own CanvasLayer — stays perfectly still.
	if _shake <= 0.0:
		if position != Vector2.ZERO:
			position = Vector2.ZERO
		return
	_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake


## Freezes the clock for a few frames on impact. `ignore_time_scale` is what
## lets the timer still fire while time_scale is 0.
func _hit_pause() -> void:
	Engine.time_scale = 0.0
	var timer := get_tree().create_timer(HIT_PAUSE_SECONDS, true, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


## A one-shot particle burst. Cheapest visible reward you can add: the player
## sees a number change, but the burst is what makes it feel like it counted.
func _burst(at: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 16
	particles.lifetime = 0.5
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 260.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color("ffd166")
	particles.global_position = at
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


## A short looping arpeggio, synthesised in code. Exists so the audio path
## (unlock -> stream -> loop) is proven in the browser before you need it.
func _build_music() -> AudioStreamWAV:
	var mix_rate := 22050
	var note_seconds := 0.22
	var notes := [220.0, 277.18, 329.63, 440.0, 329.63, 277.18]
	var frames_per_note := int(mix_rate * note_seconds)
	var data := PackedByteArray()
	data.resize(frames_per_note * notes.size() * 2)

	for n in notes.size():
		var frequency: float = notes[n]
		for i in frames_per_note:
			var t := float(i) / float(mix_rate)
			var envelope := 1.0 - (t / note_seconds)
			var sample := sin(TAU * frequency * t) * envelope * envelope * 0.14
			data.encode_s16((n * frames_per_note + i) * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames_per_note * notes.size()
	return wav
