extends Control

@onready var bg: ColorRect = $ColorRect

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Clear the old simple VBox
	var old_vbox = get_node_or_null("VBoxContainer")
	if old_vbox:
		old_vbox.queue_free()
		
	var team = LeagueManager.player_team
	if not team:
		# Fallback if accessed without a team
		print("Warning: No player team selected for Season Hub.")
		return
		
	# 1. Update Background Color
	var col = team.color_primary
	bg.color = Color(col.r * 0.15, col.g * 0.15, col.b * 0.15)
	
	# Add a cool radial gradient overlay
	var overlay = TextureRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad_tex = GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	var grad = Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.2))
	grad.set_color(1, Color(0, 0, 0, 0.6))
	grad_tex.gradient = grad
	overlay.texture = grad_tex
	add_child(overlay)
	
	# 2. Main Layout (Left: Stats & Roster | Right: Logo & Buttons)
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 40)
	main_hbox.set_begin(Vector2(50, 50))
	main_hbox.set_end(Vector2(-50, -50))
	add_child(main_hbox)
	
	# --- LEFT PANEL (Stats & Roster) ---
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.2
	main_hbox.add_child(left_vbox)
	
	var title = Label.new()
	title.text = "SEASON %d" % LeagueManager.current_season
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	left_vbox.add_child(title)
	
	var team_lbl = Label.new()
	team_lbl.text = team.name
	team_lbl.add_theme_font_size_override("font_size", 64)
	team_lbl.add_theme_color_override("font_color", col.lightened(0.2))
	left_vbox.add_child(team_lbl)
	
	# Calculate Team OVR
	var ovr = 0
	for p in team.roster:
		if "speed" in p:
			ovr += round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0)
	if team.roster.size() > 0:
		ovr = round(ovr / float(team.roster.size()))
		
	var rec_lbl = Label.new()
	rec_lbl.text = "RECORD: %d - %d  |  TEAM OVR: %d" % [team.wins, team.losses, ovr]
	rec_lbl.add_theme_font_size_override("font_size", 28)
	rec_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold
	left_vbox.add_child(rec_lbl)
	
	left_vbox.add_child(HSeparator.new())
	
	var r_lbl = Label.new()
	r_lbl.text = "ACTIVE ROSTER"
	r_lbl.add_theme_font_size_override("font_size", 24)
	r_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	left_vbox.add_child(r_lbl)
	
	# Scroll area for roster
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(grid)
	
	for p in team.roster:
		var p_pnl = _create_player_row(p)
		grid.add_child(p_pnl)
		
	# --- RIGHT PANEL (Logo & Actions) ---
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 30)
	main_hbox.add_child(right_vbox)
	
	# BIG Logo
	var logo_rect = TextureRect.new()
	logo_rect.texture = team.logo
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.custom_minimum_size = Vector2(300, 300)
	logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_vbox.add_child(logo_rect)
	
	# Play Next Match Button
	var btn_play = Button.new()
	var opp = LeagueManager.get_next_opponent()
	if opp:
		btn_play.text = "PLAY NEXT MATCH (vs %s)" % opp.name
	else:
		btn_play.text = "PLAY NEXT MATCH"
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.9)
	sb.border_color = col.lightened(0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	btn_play.add_theme_stylebox_override("normal", sb)
	
	var sb_h = sb.duplicate()
	sb_h.bg_color = col
	btn_play.add_theme_stylebox_override("hover", sb_h)
	
	var sb_p = sb.duplicate()
	sb_p.bg_color = col.darkened(0.3)
	btn_play.add_theme_stylebox_override("pressed", sb_p)
	
	btn_play.add_theme_font_size_override("font_size", 28)
	btn_play.add_theme_color_override("font_color", Color.WHITE)
	btn_play.pressed.connect(_on_play_next_pressed)
	right_vbox.add_child(btn_play)
	
	# Main Menu Button
	var btn_main = Button.new()
	btn_main.text = "MAIN MENU"
	var sm = StyleBoxFlat.new()
	sm.bg_color = Color(0.1, 0.1, 0.2, 0.6)
	sm.border_color = Color(0.4, 0.4, 0.5, 0.5)
	sm.set_border_width_all(2)
	sm.set_corner_radius_all(6)
	sm.content_margin_top = 10
	sm.content_margin_bottom = 10
	btn_main.add_theme_stylebox_override("normal", sm)
	
	var sm_h = sm.duplicate()
	sm_h.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	btn_main.add_theme_stylebox_override("hover", sm_h)
	
	btn_main.add_theme_font_size_override("font_size", 20)
	btn_main.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	btn_main.pressed.connect(_on_main_menu_pressed)
	right_vbox.add_child(btn_main)
	
	btn_play.grab_focus()

func _create_player_row(p: Resource) -> Control:
	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(250, 40)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	pnl.add_theme_stylebox_override("panel", sb)
	
	var hb = HBoxContainer.new()
	pnl.add_child(hb)
	
	var n_lbl = Label.new()
	n_lbl.text = p.name
	n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(n_lbl)
	
	var o_lbl = Label.new()
	if "speed" in p:
		var po = round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0)
		o_lbl.text = "OVR " + str(int(po))
		o_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		o_lbl.text = "??"
	hb.add_child(o_lbl)
	
	return pnl

func _on_play_next_pressed() -> void:
	var opponent = LeagueManager.get_next_opponent()
	if opponent:
		# Use default config for now, or fetch from season settings once we have them
		var config = {
			"quarter_duration": 60.0,
			"team_size": 3,
			"court_theme_index": 0,
			"items_enabled": true,
			"enabled_items": {
				"mine": true, "cyclone": true, "missile": true,
				"power_up": true, "coin": true, "crowd_throw": true
			},
			"human_team_index": 0
		}
		LeagueManager.start_quick_match(LeagueManager.player_team, opponent, config)
	else:
		print("No opponent found!")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
