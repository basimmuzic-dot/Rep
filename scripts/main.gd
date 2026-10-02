extends Node3D
## World, player, interaction and story flow.

const UI := preload("res://scripts/ui.gd")
const WALK := 3.6
const SPRINT := 5.6
const TERMINAL_POS := Vector3(9.0, 1.0, -6.6)

const COOLER_LINES := [
	"The water is very cold and very clean. Somewhere in Kessara, a family walks two hours for this.",
	"You fill a paper cup. The cooler gurgles like it's trying to say something. Probably not.",
	"You hold the cup and don't drink. You are thinking about who paid for the pipe.",
]

var ui: CanvasLayer
var player: CharacterBody3D
var cam: Camera3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var lights: Array[OmniLight3D] = []
var ceiling_panels: Array[MeshInstance3D] = []
var posters: Array[Label3D] = []
var npcs: Dictionary = {}          # name -> Node3D
var npc_talks: Dictionary = {}     # name -> times talked
var interactables: Array[Dictionary] = []
var mats: Dictionary = {}
var terminal_light: OmniLight3D

var locked := true
var game_over := false
var current: Dictionary = {}
var vis := 0.0            # smoothed 0..1 visual dissonance
var yaw := 0.0
var pitch := 0.0
var muzak: AudioStreamPlayer
var muzak_t := 0.0
var autotest := false

func _ready() -> void:
	autotest = "--autotest" in OS.get_cmdline_user_args()
	_build_environment()
	_build_office()
	_build_player()
	ui = UI.new()
	add_child(ui)
	_build_muzak()
	GameState.phase_changed.connect(_on_phase_changed)
	if autotest:
		_run_autotest.call_deferred()
	elif "--tour" in OS.get_cmdline_user_args():
		_run_tour.call_deferred()
	_start.call_deferred()

# ───────────────────────── story flow ─────────────────────────

func _start() -> void:
	locked = true
	game_over = false
	ui.set_hud_visible(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var style: String = await ui.title_screen()
	GameState.reset(style)
	vis = GameState.dissonance / 100.0
	_update_posters()
	_update_ticker()
	await ui.card("MERIDIAN CONCORD", "Kessara Regional Desk\nMonday, 8:52")
	ui.set_hud_visible(true)
	_unlock()
	ui.toast("Your terminal glows at the far end of the floor, by the window. Take your time.", 8.0)

func _unlock() -> void:
	locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _lock() -> void:
	locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _use_terminal() -> void:
	_lock()
	if GameState.is_final():
		await _run_final()
	else:
		await _run_case()
	if not game_over:
		_unlock()

func _run_case() -> void:
	var c := GameState.current_case()
	var m: Array = c["msg"]
	var r: int = await ui.page("New message · %s" % m[0], "From %s, Kessara" % m[0],
		"[i]%s[/i]" % m[1], ["Open today's file"], GameState.progress_label())
	if r < 0:
		return
	var fine: String
	if GameState.playthroughs > 0:
		fine = "[color=#e5654f][font_size=16]▸ %s[/font_size][/color]\n[color=#9a9fa8][i]You scrolled past this the first time.[/i][/color]" % c["fine"]
	else:
		fine = "[color=#6b7078][font_size=13]%s[/font_size][/color]" % c["fine"]
	var labels: Array = []
	for o in c["options"]:
		labels.append(o["label"])
	var pick: int = await ui.page(c["from"], c["title"], "%s\n\n%s" % [c["body"], fine], labels,
		GameState.progress_label() + "   ·   Esc: step away from the terminal")
	if pick < 0:
		return
	var act_before := GameState.current_act()
	var res := GameState.resolve(pick)
	var text: String = res["text"]
	if res["helped"] > 0:
		text += "\n\n[color=#f0b45a]Impact recorded: +%s lives helped.[/color]" % _fmt(res["helped"])
	text += "\n\n[color=#8f98a6][i]%s[/i][/color]" % res["narration"]
	_update_ticker()
	await ui.page("Filed", "Decision recorded", text, ["Continue"], GameState.progress_label())
	var act_after := GameState.current_act()
	if act_after != act_before:
		var t: Array = StoryData.ACT_TITLES[act_after]
		_lock()
		await ui.card(t[0], t[1])
	elif GameState.is_final():
		pass

func _run_final() -> void:
	var f: Dictionary = StoryData.FINAL
	var labels: Array = []
	for o in f["options"]:
		labels.append(o["label"])
	var pick: int = await ui.page("Eyes only · Meridian Concord Board", f["title"], f["body"], labels,
		"There is no fourth option.   ·   Esc: step away")
	if pick < 0:
		return
	var key: String = f["options"][pick]["k"]
	GameState.choose_route(key)
	game_over = true
	await ui.card("", "You pick up the pen.", 2.0)
	var fates := ""
	for pal in ["Amara", "Dr. Teo", "Jun"]:
		fates += "[b]%s[/b]  %s\n\n" % [pal, StoryData.LAST_MESSAGES[key][pal]]
	var e: Dictionary = StoryData.ENDINGS[key]
	var stats := "Lives helped on paper: %s.  Files you looked into: %d.  Files you accepted without looking: %d.\n%s" % [
		_fmt(GameState.lives_helped), GameState.investigated, GameState.denied, GameState.survivors_summary()]
	await ui.ending_screen(e["title"], e["text"], fates, stats, StoryData.CODA)
	GameState.playthroughs += 1
	get_tree().reload_current_scene()

func _talk(npc_name: String) -> void:
	_lock()
	var n := int(npc_talks.get(npc_name, 0))
	npc_talks[npc_name] = n + 1
	var data: Dictionary = StoryData.COLLEAGUES[npc_name]
	var lines: Array = data["lines"][GameState.phase()]
	await ui.say(npc_name, data["role"], lines[n % lines.size()])
	_unlock()

func _on_phase_changed(_p: int) -> void:
	_update_posters()
	_update_ticker()

func _update_posters() -> void:
	var ph := GameState.phase()
	for i in posters.size():
		posters[i].text = StoryData.POSTERS[i][ph].replace("{n}", _fmt(maxi(GameState.lives_helped, 50000)))

func _update_ticker() -> void:
	var ph := GameState.phase()
	var line: String = StoryData.POSTERS[0][ph].replace("{n}", _fmt(GameState.lives_helped)).replace("\n", ": ")
	ui.set_ticker(line)

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out

# ───────────────────────── player ─────────────────────────

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.95, 8.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	player.add_child(cs)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0.7, 0)
	cam.fov = 72.0
	cam.current = true
	player.add_child(cam)
	add_child(player)
	yaw = 0.0

func _input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0028
		pitch = clampf(pitch - event.relative.y * 0.0028, -1.35, 1.35)
		player.rotation.y = yaw
		cam.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("interact"):
		var t := _nearest_interactable()
		if not t.is_empty():
			t["call"].call()

func _physics_process(delta: float) -> void:
	if locked:
		ui.set_prompt("")
		return
	var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := player.global_transform.basis
	var wish := (basis.x * dir.x + basis.z * dir.y)
	wish.y = 0.0
	var spd := SPRINT if Input.is_key_pressed(KEY_SHIFT) else WALK
	var v := player.velocity
	v.x = wish.x * spd
	v.z = wish.z * spd
	v.y = 0.0 if player.is_on_floor() else v.y - 20.0 * delta
	player.velocity = v
	player.move_and_slide()
	var t := _nearest_interactable()
	ui.set_prompt("" if t.is_empty() else "[E]  " + t["prompt"])

func _nearest_interactable() -> Dictionary:
	var best := {}
	var best_d := 1e9
	for it in interactables:
		var p: Vector3 = it["pos"]
		var d := Vector2(p.x - player.position.x, p.z - player.position.z).length()
		if d < it["r"] and d < best_d:
			best_d = d
			best = it
	return best

func _process(delta: float) -> void:
	# Smooth the world's dissonance look.
	var target := GameState.dissonance / 100.0
	vis = lerpf(vis, target, minf(delta * 0.6, 1.0))
	_apply_look(delta)
	# Colleagues turn to face you when you are near.
	for n in npcs.values():
		var d: Vector3 = player.position - n.position
		if Vector2(d.x, d.z).length() < 6.0:
			var want := atan2(d.x, d.z)
			n.rotation.y = lerp_angle(n.rotation.y, want, minf(delta * 4.0, 1.0))
		n.get_child(0).scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.002 + n.position.x) * 0.012
	if terminal_light:
		terminal_light.light_energy = 1.1 + sin(Time.get_ticks_msec() * 0.004) * 0.35
	_fill_muzak()

func _apply_look(_delta: float) -> void:
	var warm := Color(1.0, 0.94, 0.82)
	var cold := Color(0.62, 0.76, 1.0)
	var c := warm.lerp(cold, vis)
	var flicker := 1.0
	if vis > 0.55 and randf() < 0.01:
		flicker = 0.35
	for i in lights.size():
		lights[i].light_color = c
		var f := flicker if i == (int(Time.get_ticks_msec() / 400) % lights.size()) else 1.0
		lights[i].light_energy = lerpf(1.0, 0.55, vis) * f
	env.ambient_light_color = Color(0.55, 0.52, 0.48).lerp(Color(0.30, 0.38, 0.52), vis)
	env.adjustment_saturation = lerpf(1.0, 0.35, vis)
	sky_mat.sky_top_color = Color(0.16, 0.20, 0.36).lerp(Color(0.05, 0.06, 0.10), vis)
	sky_mat.sky_horizon_color = Color(0.92, 0.55, 0.38).lerp(Color(0.25, 0.28, 0.36), vis)
	for p in posters:
		p.modulate = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.45, 0.38), clampf(vis * 1.4 - 0.2, 0.0, 1.0))

# ───────────────────────── audio ─────────────────────────

func _build_muzak() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	muzak = AudioStreamPlayer.new()
	muzak.stream = gen
	muzak.volume_db = -12.0
	add_child(muzak)
	muzak.play()

## Cheerful elevator music that sours as dissonance rises: the third drifts
## minor, the pitch wobbles, and the arpeggio slows.
func _fill_muzak() -> void:
	var pb := muzak.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n := pb.get_frames_available()
	if n <= 0:
		return
	var rate := 22050.0
	var minor := clampf((vis - 0.2) / 0.4, 0.0, 1.0)
	var wob := clampf((vis - 0.45) / 0.55, 0.0, 1.0)
	var step := 0.30 + 0.25 * wob
	var roots := [0, -3, -7, -5]
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		muzak_t += 1.0 / rate
		var beat := int(muzak_t / step)
		var chord := int(beat / 8) % 4
		var tone := beat % 4
		var third := 4.0 - minor
		var semis: Array = [0.0, third, 7.0, 12.0]
		var note := float(roots[chord]) + float(semis[tone])
		var f := 261.63 * pow(2.0, note / 12.0) * (1.0 + 0.025 * wob * sin(muzak_t * 0.9))
		var env_amp := exp(-3.0 * fmod(muzak_t, step) / step)
		var s := sin(TAU * f * muzak_t) * env_amp * 0.35
		s += sin(TAU * f * 0.5 * muzak_t) * 0.12
		s += sin(TAU * 55.0 * pow(2.0, float(roots[chord]) / 12.0) * muzak_t) * 0.18
		if wob > 0.4:
			s += sin(TAU * 277.18 * muzak_t) * 0.07 * wob   # tritone against the root
		s *= 0.5
		buf[i] = Vector2(s, s)
	pb.push_buffer(buf)

# ───────────────────────── world building ─────────────────────────

func _mat(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color, emission, alpha]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[key] = m
	return m

func _box(pos: Vector3, size: Vector3, color: Color, solid := true, emission := 0.0, alpha := 1.0) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, emission, alpha)
	if not solid:
		mi.position = pos
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body

func _poster(pos: Vector3, yaw_deg: float, idx: int) -> void:
	var wide_x := int(round(yaw_deg)) % 180 == 0
	_box(pos, Vector3(3.8, 1.8, 0.08) if wide_x else Vector3(0.08, 1.8, 3.8), Color(0.10, 0.10, 0.12), false)
	var l := Label3D.new()
	l.font_size = 72
	l.pixel_size = 0.0034
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.rotation_degrees.y = yaw_deg
	var fwd := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	l.position = pos + fwd * 0.06
	add_child(l)
	posters.append(l)

func _add_interactable(pos: Vector3, r: float, prompt: String, call: Callable) -> void:
	interactables.append({"pos": pos, "r": r, "prompt": prompt, "call": call})

func _build_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.5, 0.55)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_office() -> void:
	var carpet := Color(0.30, 0.34, 0.40)
	var wall := Color(0.82, 0.80, 0.76)
	_box(Vector3(0, -0.2, 0), Vector3(30, 0.4, 22), carpet)
	_box(Vector3(0, 3.55, 0), Vector3(30, 0.3, 22), Color(0.92, 0.92, 0.94))
	# South wall with elevator, west and east walls.
	_box(Vector3(0, 1.7, 10.15), Vector3(30, 3.4, 0.3), wall)
	_box(Vector3(-14.9, 1.7, 0), Vector3(0.3, 3.4, 22), wall)
	_box(Vector3(14.9, 1.7, 0), Vector3(0.3, 3.4, 22), wall)
	_box(Vector3(0, 1.3, 9.95), Vector3(2.4, 2.6, 0.1), Color(0.55, 0.57, 0.6), false)
	_box(Vector3(0, 1.3, 9.9), Vector3(0.04, 2.6, 0.12), Color(0.15, 0.15, 0.17), false)
	# North wall: low wall, glass window, soffit, pillars.
	_box(Vector3(0, 0.5, -10.15), Vector3(30, 1.0, 0.3), wall)
	_box(Vector3(0, 3.0, -10.15), Vector3(30, 0.9, 0.3), wall)
	_box(Vector3(0, 1.75, -10.15), Vector3(30, 1.5, 0.06), Color(0.6, 0.75, 0.9), true, 0.0, 0.14)
	for x in [-14.5, -7.0, 0.0, 7.0, 14.5]:
		_box(Vector3(x, 1.7, -10.15), Vector3(0.5, 3.4, 0.4), Color(0.75, 0.73, 0.70))
	_build_skyline()
	# Ceiling light panels, each with a real light.
	for x in [-10.5, -3.5, 3.5, 10.5]:
		for z in [-6.0, 0.0, 6.0]:
			_box(Vector3(x, 3.38, z), Vector3(2.4, 0.06, 1.2), Color(1, 0.97, 0.9), false, 1.6)
			var l := OmniLight3D.new()
			l.position = Vector3(x, 2.9, z)
			l.omni_range = 9.0
			l.light_energy = 1.0
			add_child(l)
			lights.append(l)
	# Cubicle pods facing north.
	for row_z in [3.0, -2.5]:
		for x in [-10.0, -5.0, 0.0]:
			_build_pod(Vector3(x, 0, row_z))
	_build_player_desk()
	_build_break_room()
	_build_glass_office()
	_poster(Vector3(-7.5, 2.0, 9.95), 180.0, 0)
	_poster(Vector3(7.5, 2.0, 9.95), 180.0, 1)
	_poster(Vector3(-14.75, 2.0, -2.0), 90.0, 2)
	_poster(Vector3(14.75, 2.0, 2.0), -90.0, 3)
	_update_posters()
	# Window interactions.
	for wx in [-7.0, 3.0]:
		_add_interactable(Vector3(wx, 1.0, -9.0), 2.6, "Look out the window", _look_out)
	_add_interactable(Vector3(-13.0, 1.0, 8.4), 1.8, "Get some water", _cooler)

func _look_out() -> void:
	ui.toast(StoryData.WINDOW_NOTES[GameState.phase()], 7.0)

func _cooler() -> void:
	ui.toast(COOLER_LINES[GameState.phase()], 7.0)

func _build_pod(p: Vector3) -> void:
	_box(p + Vector3(0, 0.38, 0), Vector3(1.9, 0.76, 0.9), Color(0.62, 0.52, 0.42))
	_box(p + Vector3(0, 1.08, -0.25), Vector3(0.7, 0.45, 0.04), Color(0.55, 0.75, 1.0), false, 0.9)
	_box(p + Vector3(0, 0.80, 0.15), Vector3(0.5, 0.03, 0.18), Color(0.2, 0.2, 0.22), false)
	_box(p + Vector3(1.1, 0.7, 0.0), Vector3(0.05, 1.4, 1.5), Color(0.45, 0.50, 0.55))
	_box(p + Vector3(0, 0.30, 0.95), Vector3(0.5, 0.06, 0.5), Color(0.15, 0.17, 0.22), false)
	_box(p + Vector3(0, 0.62, 1.15), Vector3(0.5, 0.5, 0.06), Color(0.15, 0.17, 0.22), false)

func _build_player_desk() -> void:
	var p := Vector3(9.0, 0, -8.2)
	_box(p + Vector3(0, 0.38, 0), Vector3(2.6, 0.76, 1.1), Color(0.55, 0.43, 0.33))
	_box(p + Vector3(0, 1.1, -0.2), Vector3(0.95, 0.6, 0.05), Color(1.0, 0.72, 0.30), false, 1.2)
	_box(p + Vector3(0, 0.80, 0.25), Vector3(0.55, 0.03, 0.2), Color(0.2, 0.2, 0.22), false)
	_box(p + Vector3(-1.0, 0.88, 0.1), Vector3(0.22, 0.28, 0.04), Color(0.9, 0.85, 0.7), false)   # framed drawing
	_box(p + Vector3(0, 0.30, 1.4), Vector3(0.55, 0.06, 0.55), Color(0.15, 0.17, 0.22), false)
	_box(p + Vector3(0, 0.65, 1.65), Vector3(0.55, 0.55, 0.06), Color(0.15, 0.17, 0.22), false)
	terminal_light = OmniLight3D.new()
	terminal_light.position = Vector3(9.0, 1.6, -7.2)
	terminal_light.light_color = Color(1.0, 0.72, 0.3)
	terminal_light.omni_range = 4.5
	add_child(terminal_light)
	_add_interactable(TERMINAL_POS, 2.3, "Use your terminal", _use_terminal)

func _build_break_room() -> void:
	_box(Vector3(-12.2, 0.45, 9.55), Vector3(3.4, 0.9, 0.6), Color(0.85, 0.85, 0.88))
	_box(Vector3(-13.0, 0.55, 8.9), Vector3(0.4, 1.1, 0.4), Color(0.7, 0.85, 0.95), true, 0.35)
	_box(Vector3(-11.0, 0.5, 8.0), Vector3(0.9, 0.04, 0.9), Color(0.20, 0.22, 0.26), false)
	_spawn_npc("Sol", Vector3(-11.4, 0, 6.8))

func _build_glass_office() -> void:
	var g := Color(0.7, 0.85, 1.0)
	_box(Vector3(12.0, 1.3, 3.0), Vector3(6.0, 2.6, 0.05), g, true, 0.0, 0.18)
	_box(Vector3(9.0, 1.3, 3.9), Vector3(0.05, 2.6, 1.8), g, true, 0.0, 0.18)
	_box(Vector3(9.0, 1.3, 7.9), Vector3(0.05, 2.6, 4.0), g, true, 0.0, 0.18)
	_box(Vector3(12.3, 0.38, 7.9), Vector3(2.4, 0.76, 1.0), Color(0.25, 0.22, 0.20))
	_spawn_npc("Hollis", Vector3(12.0, 0, 5.4))
	_spawn_npc("Dana", Vector3(-2.5, 0, 8.2))
	_spawn_npc("Pritch", Vector3(-4.0, 0, -4.4))

func _spawn_npc(npc_name: String, pos: Vector3) -> void:
	var data: Dictionary = StoryData.COLLEAGUES[npc_name]
	var root := Node3D.new()
	root.position = pos
	var vis_root := Node3D.new()
	root.add_child(vis_root)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.5
	body.mesh = cm
	body.position.y = 0.75
	body.material_override = _mat(data["color"])
	vis_root.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	head.mesh = sm
	head.position.y = 1.72
	head.material_override = _mat(Color(0.86, 0.68, 0.55))
	vis_root.add_child(head)
	for ex in [-0.07, 0.07]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.03
		es.height = 0.06
		eye.mesh = es
		eye.position = Vector3(ex, 1.75, 0.17)
		eye.material_override = _mat(Color(0.05, 0.05, 0.06))
		vis_root.add_child(eye)
	var tag := Label3D.new()
	tag.text = npc_name
	tag.font_size = 40
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 2.15
	tag.no_depth_test = true
	root.add_child(tag)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.8
	cs.shape = shape
	cs.position.y = 0.9
	sb.add_child(cs)
	root.add_child(sb)
	add_child(root)
	npcs[npc_name] = root
	_add_interactable(pos, 2.4, "Talk to %s" % npc_name, _talk.bind(npc_name))

func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		var w := rng.randf_range(3.0, 7.0)
		var h := rng.randf_range(8.0, 34.0)
		var x := -60.0 + i * 4.2 + rng.randf_range(-1.0, 1.0)
		var z := rng.randf_range(-45.0, -22.0)
		_box(Vector3(x, h / 2.0 - 2.0, z), Vector3(w, h, w), Color(0.05, 0.06, 0.09), false)
		for k in rng.randi_range(2, 5):
			var wy := rng.randf_range(0.0, h - 3.0)
			_box(Vector3(x + rng.randf_range(-w / 3.0, w / 3.0), wy - 1.5, z + w / 2.0 + 0.05),
				Vector3(rng.randf_range(0.6, 1.8), 0.5, 0.05), Color(1.0, 0.85, 0.5), false, 1.5)

# ───────────────────────── automated smoke test ─────────────────────────

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "/tmp"
	img.save_png("%s/%s.png" % [dir, name])

## `godot --path . -- --autotest` plays the whole game and prints a transcript.
func _run_autotest() -> void:
	await get_tree().create_timer(1.0).timeout
	await _shot("00_title")
	(get_tree().get_nodes_in_group("style_buttons")[1] as Button).pressed.emit()
	await get_tree().create_timer(5.5).timeout
	await _shot("01_office")
	player.position = Vector3(2.5, 0.95, 7.0)
	player.rotation.y = 0.5
	yaw = 0.5
	await get_tree().create_timer(0.3).timeout
	await _shot("02_posters")
	player.position = Vector3(8.0, 0.95, -5.0)
	player.rotation.y = 0.0
	yaw = 0.0
	var step := 0
	while not GameState.is_final():
		var c := GameState.current_case()
		_use_terminal.call_deferred()
		await get_tree().create_timer(0.3).timeout
		ui.answered.emit(0)            # message
		await get_tree().create_timer(0.3).timeout
		if step == 2:
			await _shot("03_case")
		ui.answered.emit(0 if GameState.current_act() == 1 else (step % 3))
		await get_tree().create_timer(0.3).timeout
		if step == 7:
			await _shot("04_result")
		ui.answered.emit(0)            # continue
		await get_tree().create_timer(4.0).timeout
		print("case %s -> dissonance %.0f phase %d" % [c["id"], GameState.dissonance, GameState.phase()])
		step += 1
	await get_tree().create_timer(3.0).timeout
	await _shot("05_late_office")
	_use_terminal.call_deferred()
	await get_tree().create_timer(0.3).timeout
	await _shot("06_final")
	ui.answered.emit(2)
	await get_tree().create_timer(9.0).timeout
	await _shot("07_ending")
	print("AUTOTEST OK  route=%s lives=%d investigated=%d" % [GameState.route, GameState.lives_helped, GameState.investigated])
	get_tree().quit()

# ───────────────────────── scripted tour (screenshots + video) ─────────────────────────
# godot --path . --write-movie tour.avi --fixed-fps 30 -- --tour

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _walk(pos: Vector3, yaw_t: float, pitch_t: float, secs: float) -> void:
	var p0 := player.position
	var y0 := yaw
	var x0 := pitch
	var t := create_tween()
	t.tween_method(func(k: float):
		player.position = p0.lerp(pos, k)
		yaw = lerp_angle(y0, yaw_t, k)
		pitch = lerpf(x0, pitch_t, k)
		player.rotation.y = yaw
		cam.rotation.x = pitch, 0.0, 1.0, secs)
	await t.finished

func _answer(idx: int, hold: float) -> void:
	while not ui.page_active:
		await get_tree().process_frame
	while ui.revealing:
		await get_tree().process_frame
	await _wait(hold)
	ui.answered.emit(idx)
	await _wait(0.4)

func _tour_case(picks: Array, holds: Array) -> void:
	_use_terminal.call_deferred()
	await _answer(0, holds[0])
	await _answer(picks[0], holds[1])
	await _answer(0, holds[2])
	await _wait(0.5)

func _run_tour() -> void:
	await _wait(2.5)
	await _shot("t01_title")
	await _wait(1.0)
	(get_tree().get_nodes_in_group("style_buttons")[1] as Button).pressed.emit()
	await _wait(5.5)
	player.position = Vector3(0, 0.95, 8.2)
	yaw = 0.0
	await _shot("t02_arrival")
	await _walk(Vector3(-0.5, 0.95, 4.0), 0.5, -0.05, 4.0)
	await _shot("t03_pods")
	await _walk(Vector3(-2.5, 0.95, 6.2), PI + 0.4, 0.0, 3.5)     # to Dana and the poster wall
	await _shot("t04_dana_poster")
	_talk.call_deferred("Dana")
	await _wait(1.0)
	await _shot("t05_dana_dialog")
	await _wait(2.5)
	ui._skip.emit()
	await _wait(0.6)
	await _walk(Vector3(-11.0, 0.95, 5.5), PI + 1.2, 0.0, 4.5)    # break room
	await _shot("t06_breakroom")
	_cooler()
	await _wait(2.0)
	await _shot("t07_cooler_toast")
	await _walk(Vector3(8.2, 0.95, -4.8), -0.3, -0.1, 7.0)        # to the terminal
	await _shot("t08_terminal_approach")
	await _tour_case([0], [2.5, 4.5, 3.5])
	await _shot("t09_after_case1")
	for i in 5:                                                   # rest of Act I, quickly
		await _tour_case([i % 3], [0.5, 1.2, 1.5])
	await _wait(3.0)                                              # Act II card passes
	await _shot("t10_act2_office")
	await _tour_case([0], [2.0, 5.0, 4.5])                        # famine: investigate
	await _shot("t11_after_famine")
	for i in 4:
		await _tour_case([[0, 2, 0, 0][i]], [0.5, 1.5, 3.0])
	await _wait(3.5)
	await _shot("t12_late_terminal")
	await _walk(Vector3(5.0, 0.95, -6.5), 0.3, 0.05, 3.0)
	_look_out()
	await _wait(2.0)
	await _shot("t13_window_late")
	await _walk(Vector3(2.0, 0.95, 4.5), PI - 0.3, 0.05, 5.0)    # back past the mutated posters
	await _shot("t14_posters_late")
	await _walk(Vector3(-2.0, 0.95, 0.5), 0.9, -0.05, 4.0)
	await _shot("t15_pods_late")
	_talk.call_deferred("Hollis")
	player.position = Vector3(10.5, 0.95, 4.5)
	await _wait(1.0)
	await _shot("t16_hollis_late")
	await _wait(2.5)
	ui._skip.emit()
	await _wait(0.6)
	await _walk(Vector3(8.2, 0.95, -4.8), 0.0, -0.1, 4.0)
	_use_terminal.call_deferred()
	await _wait(0.8)
	await _shot("t17_final_prompt")
	while ui.revealing:
		await get_tree().process_frame
	await _shot("t18_final_options")
	await _wait(2.5)
	ui.answered.emit(0)                                           # sign
	await _wait(9.0)
	await _shot("t19_ending")
	await _wait(5.0)
	print("TOUR OK")
	get_tree().quit()
