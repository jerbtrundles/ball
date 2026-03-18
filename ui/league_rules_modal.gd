extends Control

var accent_color: Color = Color(0.9, 0.3, 0.5)
var _close_btn: Button = null
var _scroll: ScrollContainer = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background dimmer (click to close)
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.85)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			queue_free()
	)
	add_child(dimmer)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_panel = PanelContainer.new()
	var main_sb = StyleBoxFlat.new()
	main_sb.bg_color = Color(0.04, 0.04, 0.06, 0.98)
	main_sb.border_color = accent_color
	main_sb.set_border_width_all(2)
	main_sb.set_corner_radius_all(20)
	main_sb.content_margin_left = 50
	main_sb.content_margin_right = 50
	main_sb.content_margin_top = 40
	main_sb.content_margin_bottom = 40
	main_sb.shadow_color = Color(0, 0, 0, 0.8)
	main_sb.shadow_size = 40
	main_panel.add_theme_stylebox_override("panel", main_sb)
	main_panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(main_panel)

	var outer_vb = VBoxContainer.new()
	outer_vb.add_theme_constant_override("separation", 20)
	main_panel.add_child(outer_vb)

	# Header
	var header = Label.new()
	header.text = "HOW TO PLAY"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", accent_color.lightened(0.3))
	outer_vb.add_child(header)

	# Scroll area for content
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 500)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vb.add_child(scroll)
	_scroll = scroll

	var content_vb = VBoxContainer.new()
	content_vb.add_theme_constant_override("separation", 16)
	content_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vb)

	var sections = [
		{
			"h": "Controls",
			"accent": Color(0.4, 0.7, 1.0),
			"body": (
				"[b]Move:[/b] %s/%s/%s/%s  /  Left Stick\n" % [_key("move_up"), _key("move_left"), _key("move_down"), _key("move_right")] +
				"[b]Aim:[/b] %s/%s/%s/%s  /  Right Stick\n" % [_key("aim_up"), _key("aim_left"), _key("aim_down"), _key("aim_right")] +
				"[b]Sprint:[/b] %s  /  Left Bumper\n\n" % _key("action_sprint") +
				"[b]With Ball:[/b]\n" +
				"  [color=#ffdd88]%s / A[/color] — Pass\n" % _key("action_pass") +
				"  [color=#ffdd88]%s / B[/color] — Shoot\n\n" % _key("action_shoot") +
				"[b]Without Ball:[/b]\n" +
				"  [color=#ff8888]%s / A[/color] — Call for pass\n" % _key("action_pass") +
				"  [color=#ff8888]%s / B[/color] — Tackle\n" % _key("action_shoot") +
				"  [color=#ff8888]%s / Y[/color] — Punch" % _key("action_punch")
			)
		},
		{
			"h": "Quick Match",
			"accent": Color(0.9, 0.3, 0.5),
			"body": (
				"Jump straight into a single game with custom settings. " +
				"Choose your team, opponent, court, and hazard level — no strings attached. " +
				"Perfect for learning the game or settling scores."
			)
		},
		{
			"h": "Tournament",
			"accent": Color(1.0, 0.5, 0.0),
			"body": (
				"Compete in a single-elimination bracket against AI teams. " +
				"Win every match to claim the championship. " +
				"No saves, no seasons — just pure bracket warfare."
			)
		},
		{
			"h": "Survival",
			"accent": Color(0.15, 0.75, 0.3),
			"body": (
				"Face an endless gauntlet of opponents, one after another. " +
				"Every win advances you; a single loss ends the run. " +
				"How far can you go?"
			)
		},
		{
			"h": "Franchise (Season Mode)",
			"accent": Color(1.0, 0.84, 0.0),
			"body": (
				"Build a dynasty across multiple seasons in a [color=#CD7F32]3-tier league[/color].\n\n" +
				"[b]Promotion:[/b] Win the postseason championship to advance to the next tier — " +
				"[color=#CD7F32]Bronze[/color] -> [color=#C0C0C0]Silver[/color] -> [color=#FFD700]Gold[/color].\n\n" +
				"[b]Relegation:[/b] Finish last in your division to drop a tier. " +
				"Relegated from [color=#CD7F32]Bronze[/color]? Your franchise is [color=#ff4444]dissolved — GAME OVER[/color].\n\n" +
				"Between seasons: sign free agents, manage your roster, and prepare for the next campaign."
			)
		},
	]

	for s in sections:
		var card = PanelContainer.new()
		var card_sb = StyleBoxFlat.new()
		card_sb.bg_color = Color(0.1, 0.1, 0.15, 0.6)
		card_sb.border_color = (s["accent"] as Color).darkened(0.4)
		card_sb.set_border_width_all(1)
		card_sb.set_corner_radius_all(12)
		card_sb.content_margin_left = 25
		card_sb.content_margin_right = 25
		card_sb.content_margin_top = 15
		card_sb.content_margin_bottom = 15
		card.add_theme_stylebox_override("panel", card_sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_vb.add_child(card)

		var r_vb = VBoxContainer.new()
		r_vb.add_theme_constant_override("separation", 8)
		card.add_child(r_vb)

		var h_lbl = Label.new()
		h_lbl.text = (s["h"] as String).to_upper()
		h_lbl.add_theme_font_size_override("font_size", 18)
		h_lbl.add_theme_color_override("font_color", s["accent"])
		r_vb.add_child(h_lbl)

		var t_lbl = RichTextLabel.new()
		t_lbl.bbcode_enabled = true
		t_lbl.text = s["body"]
		t_lbl.fit_content = true
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		t_lbl.add_theme_font_size_override("normal_font_size", 16)
		t_lbl.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
		r_vb.add_child(t_lbl)

	# Close button
	var btn_vb = VBoxContainer.new()
	btn_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_vb.add_child(btn_vb)

	var close_btn = Button.new()
	close_btn.text = " CLOSE "
	close_btn.custom_minimum_size = Vector2(260, 55)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn_sb_n = StyleBoxFlat.new()
	btn_sb_n.bg_color = accent_color.darkened(0.3)
	btn_sb_n.border_color = accent_color
	btn_sb_n.set_border_width_all(2)
	btn_sb_n.set_corner_radius_all(10)

	var btn_sb_h = btn_sb_n.duplicate()
	btn_sb_h.bg_color = accent_color.lightened(0.1)
	btn_sb_h.shadow_color = accent_color
	btn_sb_h.shadow_size = 10

	close_btn.add_theme_stylebox_override("normal", btn_sb_n)
	close_btn.add_theme_stylebox_override("hover", btn_sb_h)
	close_btn.add_theme_stylebox_override("pressed", btn_sb_n)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color.WHITE)

	close_btn.pressed.connect(queue_free)
	btn_vb.add_child(close_btn)
	close_btn.grab_focus()
	_close_btn = close_btn

func _key(action: String) -> String:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.keybinds.has(action):
		return OS.get_keycode_string(sm.keybinds[action])
	return "?"

func _process(delta: float) -> void:
	if not _scroll:
		return
	var axis_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(axis_y) > 0.15:
		_scroll.scroll_vertical += int(axis_y * 600.0 * delta)

func _input(event: InputEvent) -> void:
	# Keep focus inside modal and block events from reaching scenes behind it
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		if _close_btn:
			_close_btn.grab_focus()
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
