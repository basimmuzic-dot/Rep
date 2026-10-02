extends Node
## Global run state and rules. Content lives in StoryData.

signal dissonance_changed(value: int)
signal phase_changed(phase: int)
signal act_changed(act: int)

var playstyle := "pragmatist"
var case_index := 0
var dissonance := 0.0
var lives_helped := 0
var investigated := 0
var denied := 0
var escalated := 0
var approvals := 0
var route := ""
var playthroughs := 0   # survives scene reloads: drives replay hints

func reset(style: String) -> void:
	playstyle = style
	case_index = 0
	dissonance = float(StoryData.STYLE_START[style])
	lives_helped = 0
	investigated = 0
	denied = 0
	escalated = 0
	approvals = 0
	route = ""

func phase() -> int:
	return 0 if dissonance < 25.0 else (1 if dissonance < 55.0 else 2)

func is_final() -> bool:
	return case_index >= StoryData.CASES.size()

func current_case() -> Dictionary:
	return StoryData.FINAL if is_final() else StoryData.CASES[case_index]

func current_act() -> int:
	return 3 if is_final() else int(StoryData.CASES[case_index]["act"])

func progress_label() -> String:
	return "File %d of %d" % [mini(case_index + 1, StoryData.CASES.size() + 1), StoryData.CASES.size() + 1]

## Applies an option, advances, returns {text, narration, helped}.
func resolve(option_index: int) -> Dictionary:
	var case: Dictionary = StoryData.CASES[case_index]
	var opt: Dictionary = case["options"][option_index]
	var before_phase := phase()
	var before_act := current_act()

	var helped: int = case["helped"]
	lives_helped += helped
	match opt["k"]:
		"investigate": investigated += 1
		"accept": denied += 1
		"escalate": escalated += 1
		"approve", "decline": approvals += 1
		"review": investigated += 1
	_add_dissonance(float(opt["dis"]) * StoryData.STYLE_RATE[playstyle])

	case_index += 1
	if phase() != before_phase:
		phase_changed.emit(phase())
	if current_act() != before_act:
		act_changed.emit(current_act())
	return {"text": opt["res"], "narration": narration(), "helped": helped}

func choose_route(k: String) -> void:
	route = k
	case_index += 1
	_add_dissonance(25.0)

func _add_dissonance(amount: float) -> void:
	dissonance = clampf(dissonance + amount, 0.0, 100.0)
	dissonance_changed.emit(int(dissonance))

func narration() -> String:
	var lines: Array = StoryData.NARRATOR[playstyle][phase()]
	return lines[randi() % lines.size()]

func survivors_summary() -> String:
	if investigated >= 8:
		return "You looked at every door and walked through it anyway. You cannot say you did not know."
	if denied >= 3:
		return "You chose, again and again, not to look. Not looking has a weight, and it is exactly the weight you carried."
	return "You looked when you could bear to, and you looked away when you couldn't. That is not unusual. That is the point."
