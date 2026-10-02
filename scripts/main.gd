extends Node3D
## Main game controller: builds environment, handles player, UI, and progression

var camera: Camera3D
var player: CharacterBody3D

var player_velocity: Vector3 = Vector3.ZERO
var player_speed: float = 7.0
var gravity: float = 9.8
var mouse_sensitivity: float = 0.003
var player_rotation_y: float = 0.0

var case_file_open: bool = false
var current_case_data: Dictionary = {}
var choice_buttons: Array[Button] = []

var ui_canvas: CanvasLayer
var case_panel: Control
var choice_container: VBoxContainer
var case_title_label: Label
var case_body_label: RichTextLabel
var monologue_label: Label
var impact_ticker: Label
var pen_pal_inbox: Control

var office_root: Node3D
var wall_posters: Array[Node3D] = []
var office_lights: Array[OmniLight3D] = []
var environment_light: DirectionalLight3D
var world_env: WorldEnvironment

var dissonance_target: int = 0

func _ready() -> void:
	setup_world_environment()
	build_office_environment()
	setup_player()
	setup_ui()
	setup_input()

	GameState.case_updated.connect(_on_case_updated)
	GameState.dissonance_changed.connect(_on_dissonance_changed)
	GameState.act_changed.connect(_on_act_changed)
	GameState.ending_reached.connect(_on_ending_reached)

	await get_tree().process_frame
	show_playstyle_selection()

func setup_world_environment() -> void:
	var world_env_obj = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_LIGHT_DISABLED
	world_env_obj.environment = env
	add_child(world_env_obj)
	world_env = world_env_obj

func build_office_environment() -> void:
	office_root = Node3D.new()
	office_root.name = "OfficeEnvironment"
	add_child(office_root)

	# Floor
	var floor_mesh = BoxMesh.new()
	floor_mesh.size = Vector3(30, 0.5, 25)
	var floor_mat_instance = MeshInstance3D.new()
	floor_mat_instance.mesh = floor_mesh
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.7, 0.7, 0.7)
	floor_mat_instance.set_surface_override_material(0, floor_material)
	var floor_body = StaticBody3D.new()
	floor_body.position = Vector3(0, 0, 0)
	floor_body.add_child(floor_mat_instance)
	var floor_collision = CollisionShape3D.new()
	floor_collision.shape = BoxShape3D.new()
	floor_collision.shape.size = Vector3(30, 0.5, 25)
	floor_body.add_child(floor_collision)
	office_root.add_child(floor_body)

	# Back wall
	var back_wall_mesh = BoxMesh.new()
	back_wall_mesh.size = Vector3(30, 4, 0.3)
	var back_wall_inst = MeshInstance3D.new()
	back_wall_inst.mesh = back_wall_mesh
	var back_wall_mat = StandardMaterial3D.new()
	back_wall_mat.albedo_color = Color(0.9, 0.85, 0.8)
	back_wall_inst.set_surface_override_material(0, back_wall_mat)
	var back_wall_body = StaticBody3D.new()
	back_wall_body.position = Vector3(0, 2, -12.5)
	back_wall_body.add_child(back_wall_inst)
	var back_wall_collision = CollisionShape3D.new()
	back_wall_collision.shape = BoxShape3D.new()
	back_wall_collision.shape.size = Vector3(30, 4, 0.3)
	back_wall_body.add_child(back_wall_collision)
	office_root.add_child(back_wall_body)

	# Side walls
	for side in [-1, 1]:
		var wall_mesh = BoxMesh.new()
		wall_mesh.size = Vector3(0.3, 4, 25)
		var wall_inst = MeshInstance3D.new()
		wall_inst.mesh = wall_mesh
		var wall_mat = StandardMaterial3D.new()
		wall_mat.albedo_color = Color(0.85, 0.85, 0.8)
		wall_inst.set_surface_override_material(0, wall_mat)
		var wall_body = StaticBody3D.new()
		wall_body.position = Vector3(15 * side, 2, 0)
		wall_body.add_child(wall_inst)
		var wall_collision = CollisionShape3D.new()
		wall_collision.shape = BoxShape3D.new()
		wall_collision.shape.size = Vector3(0.3, 4, 25)
		wall_body.add_child(wall_collision)
		office_root.add_child(wall_body)

	# Ceiling
	var ceiling_mesh = BoxMesh.new()
	ceiling_mesh.size = Vector3(30, 0.3, 25)
	var ceiling_inst = MeshInstance3D.new()
	ceiling_inst.mesh = ceiling_mesh
	var ceiling_mat = StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.95, 0.95, 0.95)
	ceiling_inst.set_surface_override_material(0, ceiling_mat)
	var ceiling_body = StaticBody3D.new()
	ceiling_body.position = Vector3(0, 4.1, 0)
	ceiling_body.add_child(ceiling_inst)
	office_root.add_child(ceiling_body)

	# Ceiling panels (decorative)
	for x in range(-3, 4):
		for z in range(-3, 3):
			var panel_mesh = BoxMesh.new()
			panel_mesh.size = Vector3(4, 0.2, 4)
			var panel_inst = MeshInstance3D.new()
			panel_inst.mesh = panel_mesh
			var panel_mat = StandardMaterial3D.new()
			panel_mat.albedo_color = Color(0.9, 0.9, 0.95)
			panel_inst.set_surface_override_material(0, panel_mat)
			panel_inst.position = Vector3(x * 4.2, 3.95, z * 4.2)
			office_root.add_child(panel_inst)

	# Desks
	for row in range(4):
		for col in range(3):
			var desk_mesh = BoxMesh.new()
			desk_mesh.size = Vector3(2, 0.7, 1.5)
			var desk_inst = MeshInstance3D.new()
			desk_inst.mesh = desk_mesh
			var desk_mat = StandardMaterial3D.new()
			desk_mat.albedo_color = Color(0.6, 0.55, 0.5)
			desk_inst.set_surface_override_material(0, desk_mat)
			var desk_body = StaticBody3D.new()
			desk_body.position = Vector3(-8 + col * 4, 0.35, -8 + row * 4)
			desk_body.add_child(desk_inst)
			var desk_collision = CollisionShape3D.new()
			desk_collision.shape = BoxShape3D.new()
			desk_collision.shape.size = Vector3(2, 0.7, 1.5)
			desk_body.add_child(desk_collision)
			office_root.add_child(desk_body)

	# Monitors on desks
	for row in range(4):
		for col in range(3):
			var monitor_mesh = BoxMesh.new()
			monitor_mesh.size = Vector3(1.2, 0.8, 0.15)
			var monitor_inst = MeshInstance3D.new()
			monitor_inst.mesh = monitor_mesh
			var monitor_mat = StandardMaterial3D.new()
			monitor_mat.albedo_color = Color(0.2, 0.2, 0.25)
			monitor_inst.set_surface_override_material(0, monitor_mat)
			monitor_inst.position = Vector3(-8 + col * 4, 1.2, -8 + row * 4)
			office_root.add_child(monitor_inst)

	# Main terminal (interactive)
	var terminal_mesh = BoxMesh.new()
	terminal_mesh.size = Vector3(1.5, 1.2, 0.5)
	var terminal_inst = MeshInstance3D.new()
	terminal_inst.mesh = terminal_mesh
	var terminal_mat = StandardMaterial3D.new()
	terminal_mat.albedo_color = Color(0.15, 0.15, 0.2)
	terminal_inst.set_surface_override_material(0, terminal_mat)
	var terminal_body = StaticBody3D.new()
	terminal_body.position = Vector3(10, 0.6, -10)
	terminal_body.add_child(terminal_inst)
	var terminal_collision = CollisionShape3D.new()
	terminal_collision.shape = BoxShape3D.new()
	terminal_collision.shape.size = Vector3(1.5, 1.2, 0.5)
	terminal_body.add_child(terminal_collision)
	office_root.add_child(terminal_body)

	# Wall poster
	var poster = Label3D.new()
	poster.text = "IMPACT:\n50,000 LIVES HELPED"
	poster.font_size = 32
	poster.position = Vector3(0, 2.5, -11.9)
	poster.modulate = Color.WHITE
	office_root.add_child(poster)
	wall_posters.append(poster)

	# Lighting
	environment_light = DirectionalLight3D.new()
	environment_light.energy_multiplier = 1.0
	environment_light.rotation = Vector3(-0.5, -0.5, 0)
	office_root.add_child(environment_light)

	# Ambient warm lights
	for x in range(-2, 3):
		for z in range(-2, 3):
			var light = OmniLight3D.new()
			light.position = Vector3(x * 6, 3.5, z * 6)
			light.omni_range = 8
			light.energy_multiplier = 0.6
			light.light_color = Color(1, 0.95, 0.85)
			office_root.add_child(light)
			office_lights.append(light)

func setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 10)
	add_child(player)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 0.6, 0)
	player.add_child(camera)

	var collision = CollisionShape3D.new()
	collision.shape = CapsuleShape3D.new()
	collision.shape.radius = 0.4
	collision.shape.height = 1.8
	player.add_child(collision)

func setup_ui() -> void:
	ui_canvas = CanvasLayer.new()
	add_child(ui_canvas)

	# Main case panel
	case_panel = Control.new()
	case_panel.anchor_left = 0.05
	case_panel.anchor_top = 0.1
	case_panel.anchor_right = 0.95
	case_panel.anchor_bottom = 0.9
	case_panel.visible = false
	ui_canvas.add_child(case_panel)

	var panel_bg = PanelContainer.new()
	panel_bg.anchor_left = 0
	panel_bg.anchor_top = 0
	panel_bg.anchor_right = 1
	panel_bg.anchor_bottom = 1
	var panel_style = StyleBox.new()
	panel_bg.add_theme_stylebox_override("panel", panel_style)
	case_panel.add_child(panel_bg)

	# Title
	case_title_label = Label.new()
	case_title_label.text = "CASE FILE"
	case_title_label.add_theme_font_size_override("font_size", 28)
	case_title_label.modulate = Color.BLACK
	case_title_label.anchor_left = 0.05
	case_title_label.anchor_top = 0.05
	case_panel.add_child(case_title_label)

	# Body text
	case_body_label = RichTextLabel.new()
	case_body_label.text = ""
	case_body_label.anchor_left = 0.05
	case_body_label.anchor_top = 0.15
	case_body_label.anchor_right = 0.95
	case_body_label.anchor_bottom = 0.65
	case_body_label.modulate = Color.BLACK
	case_body_label.scroll_active = true
	case_panel.add_child(case_body_label)

	# Choice buttons container
	choice_container = VBoxContainer.new()
	choice_container.anchor_left = 0.05
	choice_container.anchor_top = 0.68
	choice_container.anchor_right = 0.95
	choice_container.anchor_bottom = 0.88
	case_panel.add_child(choice_container)

	# Impact ticker (top right)
	impact_ticker = Label.new()
	impact_ticker.text = "Impact: 0"
	impact_ticker.add_theme_font_size_override("font_size", 16)
	impact_ticker.modulate = Color.WHITE
	impact_ticker.anchor_left = 0.85
	impact_ticker.anchor_top = 0.02
	impact_ticker.anchor_right = 1
	impact_ticker.anchor_bottom = 0.08
	ui_canvas.add_child(impact_ticker)

	# Monologue line (bottom)
	monologue_label = Label.new()
	monologue_label.text = ""
	monologue_label.add_theme_font_size_override("font_size", 12)
	monologue_label.modulate = Color(0.7, 0.7, 0.7)
	monologue_label.anchor_left = 0.05
	monologue_label.anchor_top = 0.92
	monologue_label.anchor_right = 0.95
	monologue_label.anchor_bottom = 1
	monologue_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui_canvas.add_child(monologue_label)

	# Hint label
	var hint_label = Label.new()
	hint_label.text = "Press E at your terminal"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.modulate = Color(0.6, 0.6, 0.6)
	hint_label.anchor_left = 0.05
	hint_label.anchor_top = 0.02
	hint_label.anchor_right = 0.35
	hint_label.anchor_bottom = 0.08
	ui_canvas.add_child(hint_label)

	# Pen pal inbox placeholder
	pen_pal_inbox = Control.new()
	pen_pal_inbox.visible = false
	ui_canvas.add_child(pen_pal_inbox)

func setup_input() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not case_file_open:
		var motion = event as InputEventMouseMotion
		player_rotation_y -= motion.relative.x * mouse_sensitivity
		var rotation_x = camera.rotation.x - motion.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, -PI/2, PI/2)
		camera.rotation.x = rotation_x
		player.rotation.y = player_rotation_y

	if event.is_action_pressed("interact"):
		check_terminal_interaction()

func check_terminal_interaction() -> void:
	var terminal_pos = Vector3(10, 0.6, -10)
	var distance = player.position.distance_to(terminal_pos)
	if distance < 3:
		open_case_file()

func open_case_file() -> void:
	if case_file_open:
		close_case_file()
		return

	case_file_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	current_case_data = GameState.get_current_case()
	if current_case_data.is_empty():
		case_file_open = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	case_title_label.text = current_case_data.get("title", "")
	case_body_label.text = current_case_data.get("body", "")

	# Clear old buttons
	for button in choice_buttons:
		button.queue_free()
	choice_buttons.clear()

	var choices = current_case_data.get("choices", [])
	for i in range(choices.size()):
		var choice_text = choices[i]
		var button = Button.new()
		button.text = choice_text
		button.custom_minimum_size = Vector2(400, 40)
		button.modulate = Color.BLACK
		button.pressed.connect(func(): _on_choice_pressed(i, choice_text))
		choice_container.add_child(button)
		choice_buttons.append(button)

	case_panel.visible = true
	update_monologue()

func _on_choice_pressed(choice_index: int, choice_text: String) -> void:
	var case_data = current_case_data
	var is_investigating = "[Investigate]" in choice_text
	var is_accepting = "[Accept Talking Points]" in choice_text or "Approve" in choice_text

	if is_investigating:
		GameState.record_investigation()
		GameState.modify_dissonance(case_data.get("dissonance_delta", [0, 0])[1])
	elif is_accepting:
		GameState.record_ignored()
		GameState.modify_dissonance(case_data.get("dissonance_delta", [0, 0])[0])

	if case_data.get("id") == "final_authorization":
		var ending_key = "refuse"
		if "SIGN" in choice_text:
			ending_key = "sign"
		elif "LEAK" in choice_text:
			ending_key = "leak"
		GameState.set_ending_route(ending_key)
		GameState.trigger_ending()
	else:
		# Update pen pals
		for pal_name in GameState.pen_pal_states:
			GameState.update_pen_pal_message(pal_name)

	GameState.advance_case()
	close_case_file()

func close_case_file() -> void:
	case_file_open = false
	case_panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func update_monologue() -> void:
	var narrator_keys = ["pragmatist_early", "idealist_early", "cynic_early"]
	var key_prefix = GameState.playstyle

	if GameState.dissonance > 50:
		key_prefix += "_late"
	else:
		key_prefix += "_early"

	var lines = StoryData.NARRATOR_LINES.get(key_prefix, [])
	if lines.size() > 0:
		var idx = randi() % lines.size()
		monologue_label.text = ">> " + lines[idx]

func _on_case_updated() -> void:
	pass

func _on_dissonance_changed(value: int) -> void:
	update_office_aesthetics()

func _on_act_changed(new_act: int) -> void:
	update_office_aesthetics()

func update_office_aesthetics() -> void:
	var dissonance = GameState.dissonance
	var intensity = float(dissonance) / 100.0

	# Shift lighting from warm to cold
	for light in office_lights:
		var warm_color = Color(1, 0.95, 0.85)
		var cold_color = Color(0.7, 0.8, 1)
		light.light_color = warm_color.lerp(cold_color, intensity)
		light.energy_multiplier = 0.6 * (1 - intensity * 0.5)

	# Update wall poster text
	for poster in wall_posters:
		var original_text = "IMPACT:\n50,000 LIVES HELPED"
		if dissonance > 50:
			var text_variants = [
				"EXTRACTION:\n50,000 DEPENDENCIES CREATED",
				"CONTROL:\n50,000 SUBJECTS ACQUIRED",
				"PROFIT:\n50,000 RESOURCES SECURED"
			]
			var idx = randi() % text_variants.size()
			poster.text = text_variants[idx]
		else:
			poster.text = original_text

func _on_ending_reached(ending_type: String) -> void:
	close_case_file()
	show_ending_screen(ending_type)

func show_ending_screen(ending_type: String) -> void:
	var ending_data = StoryData.ENDINGS.get(ending_type, {})

	var ending_panel = Control.new()
	ending_panel.anchor_left = 0
	ending_panel.anchor_top = 0
	ending_panel.anchor_right = 1
	ending_panel.anchor_bottom = 1
	ui_canvas.add_child(ending_panel)

	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	ending_panel.add_child(bg)

	var title = Label.new()
	title.text = ending_data.get("title", "THE END")
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color.WHITE
	title.anchor_left = 0.1
	title.anchor_top = 0.1
	title.anchor_right = 0.9
	title.anchor_bottom = 0.3
	ending_panel.add_child(title)

	var epilogue = RichTextLabel.new()
	epilogue.text = ending_data.get("epilogue", "")
	epilogue.anchor_left = 0.1
	epilogue.anchor_top = 0.3
	epilogue.anchor_right = 0.9
	epilogue.anchor_bottom = 0.85
	epilogue.modulate = Color.WHITE
	ending_panel.add_child(epilogue)

	var replay_button = Button.new()
	replay_button.text = "PLAY AGAIN"
	replay_button.anchor_left = 0.35
	replay_button.anchor_top = 0.88
	replay_button.anchor_right = 0.65
	replay_button.anchor_bottom = 0.95
	replay_button.modulate = Color.WHITE
	replay_button.pressed.connect(_on_replay_pressed)
	ending_panel.add_child(replay_button)

func _on_replay_pressed() -> void:
	GameState.replay = true
	get_tree().reload_current_scene()

func show_playstyle_selection() -> void:
	var selection_panel = Control.new()
	selection_panel.anchor_left = 0
	selection_panel.anchor_top = 0
	selection_panel.anchor_right = 1
	selection_panel.anchor_bottom = 1
	ui_canvas.add_child(selection_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	selection_panel.add_child(bg)

	var title = Label.new()
	title.text = "CHOOSE YOUR PHILOSOPHY"
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color.WHITE
	title.anchor_left = 0.1
	title.anchor_top = 0.15
	title.anchor_right = 0.9
	title.anchor_bottom = 0.3
	selection_panel.add_child(title)

	var desc = Label.new()
	desc.text = "Your mindset shapes how you rationalize difficult choices"
	desc.add_theme_font_size_override("font_size", 14)
	desc.modulate = Color(0.8, 0.8, 0.8)
	desc.anchor_left = 0.1
	desc.anchor_top = 0.32
	desc.anchor_right = 0.9
	desc.anchor_bottom = 0.4
	selection_panel.add_child(desc)

	var playstyles = ["pragmatist", "idealist", "cynic"]
	var descriptions = [
		"Results matter. Good intentions alone change nothing.",
		"Humanity first. Systems can be fixed from within.",
		"Everything is extraction. Play honestly."
	]

	for i in range(playstyles.size()):
		var button = Button.new()
		button.text = playstyles[i].to_upper() + "\n" + descriptions[i]
		button.custom_minimum_size = Vector2(300, 80)
		button.anchor_left = 0.2 + i * 0.25
		button.anchor_top = 0.5
		button.anchor_right = 0.4 + i * 0.25
		button.anchor_bottom = 0.7
		button.modulate = Color.WHITE
		button.pressed.connect(func(): _on_playstyle_selected(playstyles[i], selection_panel))
		selection_panel.add_child(button)

func _on_playstyle_selected(style: String, panel: Control) -> void:
	GameState.set_playstyle(style)
	panel.queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	if case_file_open:
		return

	# Player movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward = -player.transform.basis.z
	var right = player.transform.basis.x
	var move_dir = (forward * input_dir.y + right * input_dir.x).normalized()

	player_velocity.x = move_dir.x * player_speed
	player_velocity.z = move_dir.z * player_speed
	player_velocity.y -= gravity * delta

	player.velocity = player_velocity
	player.move_and_slide()

	# Update ticker
	impact_ticker.text = "Dissonance: %d" % GameState.dissonance
