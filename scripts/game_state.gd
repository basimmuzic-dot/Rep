extends Node
## Global game state and progression tracking

signal case_updated
signal dissonance_changed(value: int)
signal act_changed(new_act: int)
signal ending_reached(ending_type: String)

var current_act: int = 1
var current_case_index: int = 0
var dissonance: int = 0
var lives_helped: int = 0
var playstyle: String = "pragmatist"
var ending_route: String = ""
var replay: bool = false

var investigated_count: int = 0
var ignored_count: int = 0

var pen_pal_states: Dictionary = {
	"Amara": {"alive": true, "message_index": 0},
	"Dr. Teo": {"alive": true, "message_index": 0},
	"Jun": {"alive": true, "message_index": 0},
}

func _ready() -> void:
	pass

func get_current_case() -> Dictionary:
	if current_act <= 0 or current_act > StoryData.ACTS.size():
		return {}

	var act_cases = StoryData.ACTS[current_act]["cases"]
	if current_case_index < 0 or current_case_index >= act_cases.size():
		return {}

	return act_cases[current_case_index]

func advance_case() -> void:
	var act_cases = StoryData.ACTS[current_act]["cases"]
	current_case_index += 1

	if current_case_index >= act_cases.size():
		advance_act()
	else:
		case_updated.emit()

func advance_act() -> void:
	current_act += 1
	current_case_index = 0

	if current_act > 4:
		trigger_ending()
	else:
		act_changed.emit(current_act)
		case_updated.emit()

func set_dissonance(value: int) -> void:
	dissonance = clampi(value, 0, 100)
	dissonance_changed.emit(dissonance)

func modify_dissonance(delta: int) -> void:
	set_dissonance(dissonance + delta)

func record_investigation() -> void:
	investigated_count += 1

func record_ignored() -> void:
	ignored_count += 1

func trigger_ending() -> void:
	ending_reached.emit(ending_route)

func set_playstyle(style: String) -> void:
	playstyle = style

func set_ending_route(route: String) -> void:
	ending_route = route

func update_pen_pal_message(name: String) -> void:
	if name in pen_pal_states:
		var current_index = pen_pal_states[name]["message_index"]
		if current_index < StoryData.PEN_PALS[name]["messages"].size() - 1:
			pen_pal_states[name]["message_index"] += 1

func get_pen_pal_message(name: String) -> String:
	if name not in pen_pal_states:
		return ""

	var msg_index = pen_pal_states[name]["message_index"]
	var messages = StoryData.PEN_PALS[name]["messages"]

	if msg_index < messages.size():
		return messages[msg_index]
	return ""

func silence_pen_pal(name: String) -> void:
	if name in pen_pal_states:
		pen_pal_states[name]["alive"] = false
