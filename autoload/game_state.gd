extends Node
## Global run state. Kept deliberately small — at jam scale, anything that
## needs to survive a scene change lives here and nowhere else.

signal score_changed(new_score: int)

var score: int = 0

## Every action the game understands, with the key(s) bound to it.
## Registering in code instead of via the editor's Input Map panel means the
## keymap is readable, diffable, and impossible to lose to a merge conflict in
## a .godot binary cache.
const KEYMAP := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"action": [KEY_SPACE, KEY_J],
	"restart": [KEY_R],
}


func _ready() -> void:
	_register_actions()


func _register_actions() -> void:
	for action_name in KEYMAP:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		# Guard against double-registration if an autoload is ever reloaded.
		InputMap.action_erase_events(action_name)
		for keycode in KEYMAP[action_name]:
			var event := InputEventKey.new()
			# physical_keycode keeps WASD in the same physical spot on AZERTY
			# and QWERTZ layouts, which matters when judges play your build.
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func reset_run() -> void:
	score = 0
	score_changed.emit(score)
