class_name Collectible
extends Area2D
## A pickup. Bobs, spins, and reports where it was taken so the game can throw
## a particle burst at that exact spot.

signal picked_up(at: Vector2)

const RADIUS := 11.0

var _visual: Polygon2D
var _phase := 0.0


func _ready() -> void:
	# Random start phase so a field of these does not bob in lockstep.
	_phase = randf() * TAU

	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(0.0, -RADIUS), Vector2(RADIUS, 0.0),
		Vector2(0.0, RADIUS), Vector2(-RADIUS, 0.0),
	])
	_visual.color = Color("ffd166")
	add_child(_visual)

	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	collider.shape = circle
	add_child(collider)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_phase += delta * 3.4
	_visual.position = Vector2(0.0, sin(_phase) * 3.5)
	_visual.rotation += delta * 0.9


func _on_body_entered(body: Node2D) -> void:
	# Only the player collects things. Area2D fires for any PhysicsBody2D.
	if body is Player:
		picked_up.emit(global_position)
		queue_free()
