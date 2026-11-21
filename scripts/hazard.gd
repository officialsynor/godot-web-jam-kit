class_name Hazard
extends Area2D
## The pressure. Drifts toward the player and slowly grows, so ignoring it stops
## being an option. Removes the need for a written timer rule — the clock is
## something you can see.

signal caught_player

const BASE_RADIUS := 20.0
const MAX_RADIUS := 46.0
const GROWTH_PER_SECOND := 1.5
const BASE_SPEED := 105.0
const SPEED_GROWTH_PER_SECOND := 3.5

var _radius := BASE_RADIUS
var _speed := BASE_SPEED
var _visual: Polygon2D
var _collider: CollisionShape2D


func _ready() -> void:
	_visual = Polygon2D.new()
	_visual.color = Color("ff5c7a")
	add_child(_visual)

	_collider = CollisionShape2D.new()
	_collider.shape = CircleShape2D.new()
	add_child(_collider)

	_refresh_shape()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_radius = minf(_radius + GROWTH_PER_SECOND * delta, MAX_RADIUS)
	_speed += SPEED_GROWTH_PER_SECOND * delta
	_refresh_shape()

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	position = position.move_toward(player.position, _speed * delta)
	_visual.rotation += delta * 0.6


func _refresh_shape() -> void:
	_visual.polygon = _disc(_radius)
	# Slightly smaller than the drawing so near-misses read as near-misses
	# rather than as unfair hits. Always err on the player's side.
	(_collider.shape as CircleShape2D).radius = _radius * 0.8


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		caught_player.emit()


static func _disc(radius: float, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
