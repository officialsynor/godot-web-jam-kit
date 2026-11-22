class_name Player
extends CharacterBody2D
## The core verb. Everything about how movement *feels* lives in this file:
## acceleration, friction, and the squash on the square.
##
## The single most valuable idea here: movement does NOT snap to the target
## velocity. Reaching top speed takes a moment, and stopping takes a moment.
## That lag is most of what "weight" means, and it is the cheapest feel upgrade
## you can make in a jam.

const SPEED := 330.0
const ACCELERATION := 2400.0
const FRICTION := 2000.0
const HALF_SIZE := 14.0
## Name of the group the hazard uses to find the player. Declared once here and
## referenced as Player.GROUP from the other side, so the two ends of that link
## cannot drift apart into a silent no-op.
const GROUP := "player"
## Close enough to the drag point that chasing it further would look like jitter.
const TOUCH_DEADZONE := 6.0

var _visual: Polygon2D

# Touch/drag steering. Set by the game from InputEventScreenTouch/Drag so the
# game is playable on a phone, where there is no keyboard to reach for.
var _move_target := Vector2.ZERO
var _has_move_target := false


func _ready() -> void:
	# The hazard finds the player through this group.
	add_to_group(GROUP)

	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-HALF_SIZE, -HALF_SIZE), Vector2(HALF_SIZE, -HALF_SIZE),
		Vector2(HALF_SIZE, HALF_SIZE), Vector2(-HALF_SIZE, HALF_SIZE),
	])
	_visual.color = Color("5ee7c4")
	add_child(_visual)

	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HALF_SIZE
	collider.shape = circle
	add_child(collider)


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Keyboard wins if a key is held; otherwise steer toward the last touch
	# point. Same speed and same lag, so both control paths feel identical.
	if direction == Vector2.ZERO and _has_move_target:
		var to_target := _move_target - global_position
		if to_target.length() > TOUCH_DEADZONE:
			direction = to_target.normalized()

	var wanted := direction * SPEED
	var rate := ACCELERATION if direction != Vector2.ZERO else FRICTION
	velocity = velocity.move_toward(wanted, rate * delta)
	move_and_slide()
	_squash(direction, delta)


## Called on touch press and on every drag update.
func set_move_target(target: Vector2) -> void:
	_move_target = target
	_has_move_target = true


func clear_move_target() -> void:
	_has_move_target = false


func _squash(direction: Vector2, delta: float) -> void:
	var speed_ratio := clampf(velocity.length() / SPEED, 0.0, 1.0)
	var stretch := 1.0 + 0.18 * speed_ratio

	# Stretch along the direction of travel, squash across it.
	var target := Vector2.ONE
	if absf(direction.x) > absf(direction.y):
		target = Vector2(stretch, 1.0 / stretch)
	elif direction != Vector2.ZERO:
		target = Vector2(1.0 / stretch, stretch)

	# Framerate-independent smoothing. A plain lerp() here would visibly change
	# behaviour between 60 Hz and 144 Hz monitors.
	_visual.scale = _visual.scale.lerp(target, 1.0 - exp(-14.0 * delta))
