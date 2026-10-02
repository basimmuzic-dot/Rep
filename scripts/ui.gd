extends CanvasLayer
## All 2D interface, built in code. Screens are coroutines: `await` them.

signal answered(index: int)   # page() result; -1 = dismissed with Esc
signal _skip

const BG := Color(0.06, 0.07, 0.09, 0.95)
const INK := Color(0.90, 0.91, 0.92)
const DIM := Color(0.58, 0.61, 0.66)
const ACCENT := Color(0.95, 0.72, 0.35)

var prompt_label: Label
var ticker: Label
var toast_label: Label
var hud: Control
var panel_root: Control
var header_label: Label
var title_label: Label
var body: RichTextLabel
var options_box: VBoxContainer
var footer: RichTextLabel
var dialog: PanelContainer
var dialog_name: Label
var dialog_text: Label
var fade: ColorRect
var card_label: Label

var buttons: Array[Button] = []
var revealing := false
var reveal_tween: Tween
var page_active := false
var dialog_active := false

func _ready() -> void:
	layer = 10
	_build_hud()
	_build_panel()
	_build_dialog()
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	add_child(fade)
	card_label = _label("", 34, INK)
	card_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_label.modulate.a = 0.0
	add_child(card_label)

# ───────────── builders ─────────────

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _box(color: Color, border := Color(1, 1, 1, 0.12)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(1)
	s.border_color = border
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _box(Color(0.13, 0.15, 0.19)))
	b.add_theme_stylebox_override("hover", _box(Color(0.20, 0.23, 0.30), ACCENT))
	b.add_theme_stylebox_override("pressed", _box(Color(0.25, 0.28, 0.36), ACCENT))
	b.add_theme_stylebox_override("disabled", _box(Color(0.10, 0.11, 0.13), Color(1, 1, 1, 0.05)))
	b.add_theme_stylebox_override("focus", _box(Color(0.20, 0.23, 0.30), ACCENT))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.46))
	b.add_theme_font_size_override("font_size", 17)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 44)

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var dot := _label("+", 20, Color(1, 1, 1, 0.55))   # crosshair
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-6, -14)
	hud.add_child(dot)

	prompt_label = _label("", 20, ACCENT)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.custom_minimum_size = Vector2(700, 0)
	prompt_label.position = Vector2(-350, -160)
	hud.add_child(prompt_label)

	ticker = _label("", 17, INK)
	ticker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ticker.custom_minimum_size = Vector2(420, 0)
	ticker.position = Vector2(-440, 16)
	hud.add_child(ticker)

	toast_label = _label("", 18, DIM)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.custom_minimum_size = Vector2(900, 0)
	toast_label.position = Vector2(-450, -90)
	toast_label.modulate.a = 0.0
	hud.add_child(toast_label)

func _build_panel() -> void:
	panel_root = Control.new()
	panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_root.visible = false
	add_child(panel_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.93
	panel.add_theme_stylebox_override("panel", _box(BG, Color(0.95, 0.72, 0.35, 0.35)))
	panel_root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	header_label = _label("", 13, ACCENT)
	v.add_child(header_label)
	title_label = _label("", 26, Color.WHITE)
	v.add_child(title_label)
	v.add_child(HSeparator.new())

	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 19)
	body.add_theme_font_size_override("bold_font_size", 19)
	body.add_theme_color_override("default_color", INK)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(body)

	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 8)
	v.add_child(options_box)

	footer = RichTextLabel.new()
	footer.bbcode_enabled = true
	footer.fit_content = true
	footer.scroll_active = false
	footer.add_theme_font_size_override("normal_font_size", 14)
	footer.add_theme_color_override("default_color", DIM)
	v.add_child(footer)

func _build_dialog() -> void:
	dialog = PanelContainer.new()
	dialog.anchor_left = 0.2
	dialog.anchor_right = 0.8
	dialog.anchor_top = 0.72
	dialog.anchor_bottom = 0.92
	dialog.add_theme_stylebox_override("panel", _box(BG, Color(1, 1, 1, 0.2)))
	dialog.visible = false
	add_child(dialog)
	var v := VBoxContainer.new()
	dialog.add_child(v)
	dialog_name = _label("", 17, ACCENT)
	v.add_child(dialog_name)
	dialog_text = _label("", 20, INK)
	dialog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(dialog_text)
	var hint := _label("[E] continue", 13, DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)

# ───────────── HUD ─────────────

func set_prompt(text: String) -> void:
	prompt_label.text = text

func set_ticker(text: String) -> void:
	ticker.text = text

func set_hud_visible(v: bool) -> void:
	hud.visible = v

func toast(text: String, seconds := 6.0) -> void:
	toast_label.text = text
	var t := create_tween()
	t.tween_property(toast_label, "modulate:a", 1.0, 0.6)
	t.tween_interval(seconds)
	t.tween_property(toast_label, "modulate:a", 0.0, 1.2)

# ───────────── screens ─────────────

## Shows a full-screen black fade, then a title card, then fades back.
func card(line1: String, line2: String, hold := 2.2) -> void:
	card_label.text = "%s\n\n%s" % [line1, line2]
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.8)
	t.tween_property(card_label, "modulate:a", 1.0, 0.8)
	t.tween_interval(hold)
	t.tween_property(card_label, "modulate:a", 0.0, 0.8)
	t.tween_property(fade, "modulate:a", 0.0, 0.9)
	await t.finished

## Generic text page with buttons. Returns the chosen index (-1 = Esc).
func page(header: String, title: String, text: String, options: Array, foot := "", reveal := true) -> int:
	header_label.text = header.to_upper()
	title_label.text = title
	body.text = text
	footer.text = foot
	for b in buttons:
		b.queue_free()
	buttons.clear()
	for i in options.size():
		var b := Button.new()
		b.text = "%d   %s" % [i + 1, options[i]]
		_style_button(b)
		b.disabled = true
		b.pressed.connect(_pick.bind(i))
		options_box.add_child(b)
		buttons.append(b)
	panel_root.visible = true
	page_active = true
	revealing = reveal
	body.visible_ratio = 0.0 if reveal else 1.0
	if reveal:
		var plain := body.get_parsed_text().length()
		var dur := clampf(plain * 0.012, 0.8, 4.5)
		reveal_tween = create_tween()
		reveal_tween.tween_property(body, "visible_ratio", 1.0, dur)
		reveal_tween.finished.connect(_enable_buttons)
	else:
		_enable_buttons()
	var idx: int = await answered
	page_active = false
	panel_root.visible = false
	return idx

func _enable_buttons() -> void:
	revealing = false
	body.visible_ratio = 1.0
	for b in buttons:
		b.disabled = false
	if not buttons.is_empty():
		buttons[0].grab_focus()

func _pick(i: int) -> void:
	if page_active and not revealing:
		answered.emit(i)

func _unhandled_input(event: InputEvent) -> void:
	if page_active:
		if event.is_action_pressed("ui_cancel"):
			answered.emit(-1)
			get_viewport().set_input_as_handled()
		elif revealing and (event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed)):
			if reveal_tween:
				reveal_tween.kill()
			_enable_buttons()
			get_viewport().set_input_as_handled()
		elif not revealing and event is InputEventKey and event.pressed and not event.echo:
			var n: int = int(event.keycode) - int(KEY_1)
			if n >= 0 and n < buttons.size():
				_pick(n)
				get_viewport().set_input_as_handled()
	elif dialog_active and event.is_action_pressed("interact"):
		_skip.emit()
		get_viewport().set_input_as_handled()

## Colleague speech bubble. Blocks until the player presses E.
func say(speaker: String, role: String, line: String) -> void:
	dialog_name.text = "%s  ·  %s" % [speaker, role]
	dialog_text.text = line
	dialog.visible = true
	dialog_active = true
	await get_tree().create_timer(0.15).timeout
	await _skip
	dialog_active = false
	dialog.visible = false

## Title screen; returns the chosen playstyle key.
func title_screen() -> String:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.anchor_left = 0.2
	v.anchor_right = 0.8
	v.anchor_top = 0.12
	v.anchor_bottom = 0.92
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var t := _label("ECHOES OF COMPLICITY", 54, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("A game about being helpful.", 20, DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	v.add_child(sp)
	var intro := _label("You are a mid-level administrator at Meridian Concord, a humanitarian enterprise. You approve loans, shipments and contracts for a region called Kessara. Walk the office. Use your terminal. Read everything, or don't.\n\nNo one will shout at you. Nothing will jump out. Choose how you see yourself:", 18, INK)
	v.add_child(intro)
	var chosen := [""]
	for key in StoryData.STYLES:
		var b := Button.new()
		b.text = "%s\n%s" % [StoryData.STYLES[key]["name"], StoryData.STYLES[key]["blurb"]]
		_style_button(b)
		b.custom_minimum_size = Vector2(0, 62)
		b.pressed.connect(func():
			chosen[0] = key
			_skip.emit())
		b.add_to_group("style_buttons")
		v.add_child(b)
	var ctrl := _label("WASD move · Mouse look · E interact · Esc releases the terminal", 14, DIM)
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ctrl)
	while chosen[0] == "":
		await _skip
	root.queue_free()
	return chosen[0]

## Final screen. Returns when the player picks "play again".
func ending_screen(title: String, text: String, fates: String, stats: String, coda: String) -> void:
	hud.visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.anchor_left = 0.15
	v.anchor_right = 0.85
	v.anchor_top = 0.06
	v.anchor_bottom = 0.95
	v.add_theme_constant_override("separation", 12)
	root.add_child(v)
	var t := _label(title, 40, Color.WHITE)
	v.add_child(t)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 18)
	rt.add_theme_font_size_override("italics_font_size", 18)
	rt.add_theme_color_override("default_color", INK)
	rt.text = "%s\n\n[color=#999][i]— Last messages —[/i][/color]\n%s\n\n[color=#999]%s[/color]\n\n[b]%s[/b]" % [text, fates, stats, coda]
	v.add_child(rt)
	var b := Button.new()
	b.text = "Play again"
	_style_button(b)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func(): _skip.emit())
	v.add_child(b)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	create_tween().tween_property(root, "modulate:a", 1.0, 2.0)
	await _skip
