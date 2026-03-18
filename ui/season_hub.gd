extends Control

@onready var bg: ColorRect = $ColorRect

var _music_player: AudioStreamPlayer = null
var _ticker_copies: Array = []
var _ticker_copy_width: float = 0.0

var carousel_index: int = 0
var carousel_slides: Array[Callable] = []
var carousel_tabs: Array[Button] = []
var carousel_content: PanelContainer = null
var stats_division_index: int = -1 # Filter for stats leaders, -1 = Player's division
var stats_view_type: String = "individual" # "individual" or "team"
var stats_sort_field: String = "pts"
var stats_sort_asc: bool = false
var standings_view_index: int = -1 # -1 = Player's Division, 0=Gold, 1=Silver, 2=Bronze
var bracket_view_index: int = -1 # -1 = Player's Division, 0=Gold, 1=Silver, 2=Bronze

func _process(delta: float) -> void:
	if _ticker_copies.size() == 2 and _ticker_copy_width > 0:
		for c in _ticker_copies:
			c.position.x -= 80.0 * delta
			if c.position.x + _ticker_copy_width <= 0.0:
				var other = _ticker_copies[1] if c == _ticker_copies[0] else _ticker_copies[0]
				c.position.x = other.position.x + _ticker_copy_width

func _ready() -> void:
	_build_ui()
	
	# Play Season Hub Music (only once; _build_ui reuse keeps this node alive)
	if not _music_player:
		_music_player = AudioStreamPlayer.new()
		var stream = load("res://assets/sounds/Chrome_Circuits.mp3")
		if stream is AudioStreamMP3:
			stream.loop = true
		_music_player.stream = stream
		_music_player.bus = "Music"
		add_child(_music_player)
		_music_player.play()

	SceneManager.notify_scene_ready()

func _build_ui() -> void:
	# Reset ticker so _process stops animating freed nodes
	_ticker_copies = []
	_ticker_copy_width = 0.0

	# Clear previous dynamically added UI elements to prevent stacking
	for c in get_children():
		if c != bg and c != _music_player:
			c.queue_free()

	var team = LeagueManager.player_team
	if not team:
		# Fallback if accessed without a team
		print("Warning: No player team selected for Season Hub.")
		return
	
	# Initialize standings view to player's tier
	var p_div = LeagueManager.get_player_division_name()
	if p_div == "Gold": standings_view_index = 0
	elif p_div == "Silver": standings_view_index = 1
	elif p_div == "Bronze": standings_view_index = 2
	else: standings_view_index = 0
		
	if bracket_view_index == -1: bracket_view_index = standings_view_index
		
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
	main_hbox.set_begin(Vector2(50, 40))
	main_hbox.set_end(Vector2(-50, -60))
	add_child(main_hbox)
	
	# --- LEFT PANEL (Stats & Roster) ---
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.2
	main_hbox.add_child(left_vbox)
	
	var title = Label.new()
	var player_div_name = LeagueManager.get_player_division_name()
	if LeagueManager.is_postseason:
		var pw = LeagueManager.current_week
		var rd = "OFFSEASON"
		if pw == 0: rd = "SEMIFINALS"
		elif pw == 1: rd = "CHAMPIONSHIP"
		title.text = "POSTSEASON  |  %s" % rd
	else:
		var w = min(LeagueManager.current_week + 1, max(1, LeagueManager.schedule.size()))
		var div_tag = (" | %s" % player_div_name.to_upper()) if player_div_name != "" else ""
		title.text = "SEASON %d%s  |  WEEK %d" % [LeagueManager.current_season, div_tag, w]
	title.add_theme_font_size_override("font_size", 38)
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
	# Use secondary color for accent, fall back to gold if secondary isn't meaningful
	var accent = team.color_secondary
	if accent == Color.WHITE or accent == Color(0,0,0):
		accent = Color(1.0, 0.85, 0.2)
	rec_lbl.add_theme_color_override("font_color", accent)
	left_vbox.add_child(rec_lbl)

	var funds_lbl = Label.new()
	funds_lbl.text = "FUNDS:  $%s" % _fmt_funds(team.funds)
	funds_lbl.add_theme_font_size_override("font_size", 22)
	funds_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	left_vbox.add_child(funds_lbl)

	left_vbox.add_child(HSeparator.new())
	
	var split = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 20)
	left_vbox.add_child(split)
	
	# Active Roster
	var roster_vbox = VBoxContainer.new()
	roster_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(roster_vbox)
	
	var r_lbl = Label.new()
	r_lbl.text = "ACTIVE ROSTER"
	r_lbl.add_theme_font_size_override("font_size", 24)
	r_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	roster_vbox.add_child(r_lbl)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_vbox.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	
	var active_count = LeagueManager.season_config.get("team_size", team.roster.size())
	for i in range(min(active_count, team.roster.size())):
		var p = team.roster[i]
		var p_pnl = _create_player_row(p, team)
		var p_capture = p
		var t_capture = team
		p_pnl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p_pnl.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_show_player_stat_modal(p_capture, t_capture)
		)
		grid.add_child(p_pnl)

		
	# --- CAROUSEL ---
	var st_vbox = VBoxContainer.new()
	st_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(st_vbox)
	
	var carousel_header = HBoxContainer.new()
	carousel_header.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel_header.add_theme_constant_override("separation", 8)
	st_vbox.add_child(carousel_header)
	
	var slide_configs = []
	if LeagueManager.is_postseason:
		slide_configs = [
			{"name": "BRACKET", "func": _build_carousel_bracket},
			{"name": "STANDINGS", "func": _build_carousel_standings}
		]
	else:
		slide_configs = [
			{"name": "STANDINGS", "func": _build_carousel_standings},
			{"name": "CALENDAR", "func": _build_carousel_calendar}
		]
	
	carousel_slides.clear()
	carousel_tabs.clear()
	for i in range(slide_configs.size()):
		var cfg = slide_configs[i]
		carousel_slides.append(cfg["func"])
		
		var tab = Button.new()
		tab.text = cfg["name"]
		tab.add_theme_font_size_override("font_size", 14)
		var tidx = i
		tab.pressed.connect(func(): _on_carousel_tab_pressed(tidx))
		carousel_header.add_child(tab)
		carousel_tabs.append(tab)
	
	# Clamp carousel_index in case the slide count changed (prevents silent crash on rebuild)
	carousel_index = clampi(carousel_index, 0, carousel_slides.size() - 1)
	
	carousel_content = PanelContainer.new()
	var msb = StyleBoxFlat.new()
	msb.bg_color = Color(0.1, 0.1, 0.15, 0.7)
	msb.set_corner_radius_all(6)
	msb.content_margin_left = 15; msb.content_margin_right = 15
	msb.content_margin_top = 10; msb.content_margin_bottom = 10
	carousel_content.add_theme_stylebox_override("panel", msb)
	carousel_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	st_vbox.add_child(carousel_content)
	
	_update_carousel_view()
		
	# --- RIGHT PANEL (Logo & Actions) ---
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_vbox.add_theme_constant_override("separation", 25)
	main_hbox.add_child(right_vbox)
	
	# 1. NEXT MATCH CARD (Opponent Info & Branding)
	var opp = LeagueManager.get_next_opponent()
	var champ_name = LeagueManager.get_champion_name()
	var next_match_available = (opp != null)
	
	if next_match_available:
		var card_pnl = PanelContainer.new()
		var csb = StyleBoxFlat.new()
		csb.bg_color = Color(0.12, 0.12, 0.18, 0.9)
		csb.border_color = opp.color_primary.lightened(0.2)
		csb.set_border_width_all(2)
		csb.set_corner_radius_all(10)
		csb.content_margin_left = 20; csb.content_margin_right = 20
		csb.content_margin_top = 30; csb.content_margin_bottom = 30
		card_pnl.add_theme_stylebox_override("panel", csb)
		card_pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_vbox.add_child(card_pnl)
		
		var cvbox = VBoxContainer.new()
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cvbox.add_theme_constant_override("separation", 20)
		card_pnl.add_child(cvbox)
		
		var card_title = Label.new()
		card_title.text = "NEXT MATCH"
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.add_theme_font_size_override("font_size", 14)
		card_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		cvbox.add_child(card_title)
		
		var logo_rect = TextureRect.new()
		logo_rect.texture = opp.logo
		logo_rect.custom_minimum_size = Vector2(280, 280)
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cvbox.add_child(logo_rect)
		
		var opp_name_lbl = Label.new()
		opp_name_lbl.text = opp.name.to_upper()
		opp_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opp_name_lbl.add_theme_font_size_override("font_size", 24)
		opp_name_lbl.add_theme_color_override("font_color", opp.color_primary.lightened(0.4))
		cvbox.add_child(opp_name_lbl)
		
		var rec_str = "%d - %d" % [opp.wins, opp.losses]
		var opp_rec_lbl = Label.new()
		opp_rec_lbl.text = rec_str
		opp_rec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opp_rec_lbl.add_theme_font_size_override("font_size", 18)
		opp_rec_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		cvbox.add_child(opp_rec_lbl)
		
	elif LeagueManager.is_postseason and champ_name != "":
		# Championship state - show celebratory info
		var champ_team = LeagueManager._get_team_by_name(champ_name)
		if champ_team:
			var card_pnl = PanelContainer.new()
			var csb = StyleBoxFlat.new()
			csb.bg_color = Color(0.12, 0.12, 0.18, 0.9)
			csb.border_color = Color(1.0, 0.85, 0.1) # Gold border for champions
			csb.set_border_width_all(3)
			csb.set_corner_radius_all(10)
			csb.content_margin_left = 20; csb.content_margin_right = 20
			csb.content_margin_top = 30; csb.content_margin_bottom = 30
			card_pnl.add_theme_stylebox_override("panel", csb)
			card_pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			right_vbox.add_child(card_pnl)
			
			var cvbox = VBoxContainer.new()
			cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
			cvbox.add_theme_constant_override("separation", 20)
			card_pnl.add_child(cvbox)
			
			var card_title = Label.new()
			card_title.text = "SEASON CHAMPIONS"
			card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_title.add_theme_font_size_override("font_size", 16)
			card_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
			cvbox.add_child(card_title)
			
			var logo_rect = TextureRect.new()
			logo_rect.texture = champ_team.logo
			logo_rect.custom_minimum_size = Vector2(240, 240)
			logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cvbox.add_child(logo_rect)
			
			var champ_name_lbl = Label.new()
			champ_name_lbl.text = champ_team.name.to_upper()
			champ_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			champ_name_lbl.add_theme_font_size_override("font_size", 28)
			champ_name_lbl.add_theme_color_override("font_color", Color.WHITE)
			cvbox.add_child(champ_name_lbl)
	else:
		# Fallback Logo if no match and not offseason
		var logo_rect = TextureRect.new()
		logo_rect.texture = team.logo
		logo_rect.custom_minimum_size = Vector2(280, 280)
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		logo_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_vbox.add_child(logo_rect)

	# 2. ACTION ROW (Preview | Play | Simulate)
	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_child(action_row)
	
	pnl_actions_group = []
	
	var style_main_btn = func(btn: Button, base_col: Color, is_primary: bool):
		var bsb = StyleBoxFlat.new()
		bsb.bg_color = base_col.darkened(0.2) if is_primary else Color(0.15, 0.15, 0.2, 0.8)
		bsb.border_color = base_col.lightened(0.2)
		bsb.set_border_width_all(2)
		bsb.set_corner_radius_all(6)
		bsb.content_margin_top = 12; bsb.content_margin_bottom = 12
		bsb.content_margin_left = 15; bsb.content_margin_right = 15
		btn.add_theme_stylebox_override("normal", bsb)
		
		var bsb_h = bsb.duplicate()
		bsb_h.bg_color = base_col if is_primary else Color(0.2, 0.2, 0.3, 0.9)
		btn.add_theme_stylebox_override("hover", bsb_h)
		
		var bsb_p = bsb.duplicate()
		bsb_p.bg_color = base_col.darkened(0.4) if is_primary else Color(0.1, 0.1, 0.15, 0.9)
		btn.add_theme_stylebox_override("pressed", bsb_p)
		
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# PREVIEW Button
	var btn_preview = Button.new()
	btn_preview.text = "PREVIEW"
	style_main_btn.call(btn_preview, Color(0.4, 0.4, 0.5), false)
	if next_match_available and not LeagueManager.is_postseason:
		var m_data = null
		var w_idx = LeagueManager.current_week
		if w_idx < LeagueManager.schedule.size():
			for m in LeagueManager.schedule[w_idx]:
				if m["home"] == team.name or m["away"] == team.name:
					m_data = m
					break
		if m_data:
			btn_preview.pressed.connect(func(): _show_matchup_preview(m_data, w_idx))
		else:
			btn_preview.disabled = true
	else:
		btn_preview.visible = false
	action_row.add_child(btn_preview)
	
	# PLAY Button
	var btn_play = Button.new()
	if next_match_available:
		btn_play.text = "PLAY"
		btn_play.pressed.connect(_on_play_next_pressed)
		style_main_btn.call(btn_play, team.color_primary, true)
	elif LeagueManager.is_postseason and champ_name != "":
		btn_play.text = "SEASON WRAP-UP"
		btn_play.pressed.connect(func(): _show_season_wrapup(champ_name))
		style_main_btn.call(btn_play, Color(0.2, 0.6, 0.8), true)
	else:
		btn_play.text = "PLAY"
		btn_play.disabled = true
		style_main_btn.call(btn_play, team.color_primary, true)
	action_row.add_child(btn_play)
	
	# SIMULATE Button
	var btn_sim = Button.new()
	btn_sim.text = "SIMULATE"
	style_main_btn.call(btn_sim, Color(0.15, 0.15, 0.25), false)
	btn_sim.pressed.connect(_on_simulate_pressed)
	if LeagueManager.is_postseason:
		if champ_name != "":
			btn_sim.visible = false
		elif LeagueManager.get_next_opponent() == null:
			btn_sim.text = "SIM ROUND"
	if not next_match_available and btn_sim.text != "SIM ROUND":
		btn_sim.disabled = true
	action_row.add_child(btn_sim)

	pnl_actions_group.append(btn_play)
	pnl_actions_group.append(btn_sim)
	
	# Start Next Season (if applicable)
	if LeagueManager.is_postseason and champ_name != "":
		var btn_next = Button.new()
		btn_next.text = "START NEXT SEASON"
		var nsb = StyleBoxFlat.new()
		nsb.bg_color = Color(0.2, 0.7, 0.3, 0.9)
		nsb.border_color = Color(0.4, 0.9, 0.5)
		nsb.set_border_width_all(3)
		nsb.set_corner_radius_all(8)
		nsb.content_margin_top = 15
		nsb.content_margin_bottom = 15
		btn_next.add_theme_stylebox_override("normal", nsb)
		
		var nh_sb = nsb.duplicate()
		nh_sb.bg_color = Color(0.3, 0.8, 0.4)
		btn_next.add_theme_stylebox_override("hover", nh_sb)
		
		btn_next.add_theme_font_size_override("font_size", 22)
		btn_next.add_theme_color_override("font_color", Color.WHITE)
		btn_next.pressed.connect(func():
			LeagueManager.process_season_rollover(champ_name)
			get_tree().change_scene_to_file("res://ui/season_hub.tscn")
		)
		right_vbox.add_child(btn_next)

	# 3. SECONDARY BUTTONS
	var btn_stats = Button.new()
	btn_stats.text = "SEASON STATS"
	_style_side_button(btn_stats)
	btn_stats.pressed.connect(_on_season_stats_pressed)
	right_vbox.add_child(btn_stats)

	var btn_fa = Button.new()
	btn_fa.text = "FREE AGENTS"
	_style_side_button(btn_fa)
	btn_fa.pressed.connect(_on_free_agents_pressed)
	right_vbox.add_child(btn_fa)
	pnl_actions_group.append(btn_fa)

	var btn_main = Button.new()
	btn_main.text = "QUIT TO MAIN MENU"
	_style_side_button(btn_main)
	btn_main.pressed.connect(_on_main_menu_pressed)
	right_vbox.add_child(btn_main)
	
	
	# --- TICKER ---
	_build_ticker()

	btn_play.grab_focus()

func _build_ticker() -> void:
	var ticker_bg = ColorRect.new()
	ticker_bg.color = Color(0, 0, 0, 0.6)
	ticker_bg.custom_minimum_size = Vector2(0, 40)
	ticker_bg.set_anchor(SIDE_LEFT, 0.0)
	ticker_bg.set_anchor(SIDE_TOP, 1.0)
	ticker_bg.set_anchor(SIDE_RIGHT, 1.0)
	ticker_bg.set_anchor(SIDE_BOTTOM, 1.0)
	ticker_bg.set_offset(SIDE_LEFT, 0)
	ticker_bg.set_offset(SIDE_TOP, -40)
	ticker_bg.set_offset(SIDE_RIGHT, 0)
	ticker_bg.set_offset(SIDE_BOTTOM, 0)
	add_child(ticker_bg)

	var ticker_hbox = HBoxContainer.new()
	ticker_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	ticker_bg.add_child(ticker_hbox)

	var header_pnl = PanelContainer.new()
	var h_sb = StyleBoxFlat.new()
	h_sb.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	h_sb.border_color = Color(0.0, 0.9, 1.0, 0.6)
	h_sb.set_border_width(SIDE_RIGHT, 2)
	h_sb.content_margin_left = 20; h_sb.content_margin_right = 20
	header_pnl.add_theme_stylebox_override("panel", h_sb)
	ticker_hbox.add_child(header_pnl)

	var header_lbl = Label.new()
	header_lbl.text = "AROUND THE LEAGUE"
	header_lbl.add_theme_font_size_override("font_size", 20)
	header_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	header_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_pnl.add_child(header_lbl)

	var ticker_clip = Control.new()
	ticker_clip.clip_contents = true
	ticker_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker_hbox.add_child(ticker_clip)

	# Build match data list
	var active_sched = LeagueManager.playoff_schedule if LeagueManager.is_postseason else LeagueManager.schedule
	var match_nodes = []
	if LeagueManager.current_week > 0:
		var prev_matches = active_sched[LeagueManager.current_week - 1]
		var curr_matches = active_sched[LeagueManager.current_week] if LeagueManager.current_week < active_sched.size() else []
		for m in prev_matches:
			if m.get("played", false): match_nodes.append(m)
		for m in curr_matches:
			if not m.get("played", false): match_nodes.append(m)
	else:
		if active_sched.size() > 0:
			for m in active_sched[0]:
				if not m.get("played", false): match_nodes.append(m)

	var div_badge_colors = {
		"Bronze": Color(0.8, 0.5, 0.1),
		"Silver": Color(0.7, 0.8, 1.0),
		"Gold":   Color(1.0, 0.85, 0.1)
	}

	var _fill_copy = func(target: HBoxContainer):
		if match_nodes.is_empty():
			var l = Label.new()
			l.text = "+++ PRE-SEASON WARMUPS UNDERWAY +++"
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.size_flags_vertical = Control.SIZE_EXPAND_FILL
			target.add_child(l)
			var gap = Label.new()
			gap.text = "   |   "
			gap.add_theme_font_size_override("font_size", 20)
			gap.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			target.add_child(gap)
			return
		for m in match_nodes:
			var m_hb = HBoxContainer.new()
			m_hb.add_theme_constant_override("separation", 8)
			m_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var div_name = m.get("div", m.get("division", ""))
			if div_name != "":
				var badge = Label.new()
				badge.text = "[%s]" % div_name.to_upper()
				badge.add_theme_font_size_override("font_size", 14)
				badge.add_theme_color_override("font_color", div_badge_colors.get(div_name, Color(0.6, 0.6, 0.7)))
				badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				m_hb.add_child(badge)
			if m.get("played", false):
				var a_lbl = Label.new()
				a_lbl.text = "%s %d" % [m["away"], m["away_score"]]
				a_lbl.add_theme_font_size_override("font_size", 20)
				a_lbl.add_theme_color_override("font_color", Color.YELLOW if m["away_score"] > m["home_score"] else Color(0.8, 0.8, 0.9))
				a_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				m_hb.add_child(a_lbl)
				var dash = Label.new()
				dash.text = " - "
				dash.add_theme_font_size_override("font_size", 20)
				dash.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				m_hb.add_child(dash)
				var h_lbl = Label.new()
				h_lbl.text = "%d %s" % [m["home_score"], m["home"]]
				h_lbl.add_theme_font_size_override("font_size", 20)
				h_lbl.add_theme_color_override("font_color", Color.YELLOW if m["home_score"] > m["away_score"] else Color(0.8, 0.8, 0.9))
				h_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				m_hb.add_child(h_lbl)
				var potg_text = ""
				if m.has("top_scorer") and m["top_scorer"] != "Player":
					var pts = m.get("top_scorer_pts", 0)
					var reb = m.get("top_rebounder_reb", 0)
					var ast = m.get("top_assister_ast", 0)
					potg_text = "  |  POTG: %s (%d PTS)" % [m["top_scorer"], pts]
					if m.has("top_rebounder") and m["top_rebounder"] != "Player" and reb > 0:
						potg_text += ", %s (%d REB)" % [m["top_rebounder"], reb]
					if m.has("top_assister") and m["top_assister"] != "Player" and ast > 0:
						potg_text += ", %s (%d AST)" % [m["top_assister"], ast]
				if potg_text != "":
					var p_lbl = Label.new()
					p_lbl.text = potg_text
					p_lbl.add_theme_font_size_override("font_size", 16)
					p_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
					p_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					m_hb.add_child(p_lbl)
			else:
				var t_away = LeagueManager._get_team_by_name(m["away"])
				var t_home = LeagueManager._get_team_by_name(m["home"])
				var a_lbl = Label.new()
				var a_name = m["away"]
				if t_away: a_name += " (%d-%d)" % [t_away.wins, t_away.losses]
				a_lbl.text = a_name
				a_lbl.add_theme_font_size_override("font_size", 20)
				a_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
				a_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				m_hb.add_child(a_lbl)
				var dash = Label.new()
				dash.text = " @ "
				dash.add_theme_font_size_override("font_size", 20)
				dash.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				m_hb.add_child(dash)
				var h_lbl = Label.new()
				var h_name = m["home"]
				if t_home: h_name += " (%d-%d)" % [t_home.wins, t_home.losses]
				h_lbl.text = h_name
				h_lbl.add_theme_font_size_override("font_size", 20)
				h_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
				h_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				m_hb.add_child(h_lbl)
			target.add_child(m_hb)
			var dot = Label.new()
			dot.text = "   |   "
			dot.add_theme_font_size_override("font_size", 20)
			dot.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			target.add_child(dot)

	var copy_a = HBoxContainer.new()
	copy_a.custom_minimum_size.y = 40
	copy_a.add_theme_constant_override("separation", 50)
	ticker_clip.add_child(copy_a)

	var copy_b = HBoxContainer.new()
	copy_b.custom_minimum_size.y = 40
	copy_b.add_theme_constant_override("separation", 50)
	ticker_clip.add_child(copy_b)

	_fill_copy.call(copy_a)

	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(copy_a) or not is_instance_valid(copy_b):
		return

	var raw_w = copy_a.get_minimum_size().x
	var screen_w = get_viewport_rect().size.x
	var reps = max(1, int(ceil(screen_w / raw_w)))

	for _r in range(reps - 1):
		_fill_copy.call(copy_a)
	for _r in range(reps):
		_fill_copy.call(copy_b)

	_ticker_copy_width = copy_a.get_minimum_size().x
	copy_b.position.x = _ticker_copy_width
	_ticker_copies = [copy_a, copy_b]

func _on_carousel_tab_pressed(idx: int) -> void:
	if carousel_index == idx: return
	carousel_index = idx
	_update_carousel_view()

func _update_carousel_view() -> void:
	if carousel_content.get_child_count() > 0:
		for c in carousel_content.get_children():
			c.queue_free()
			
	for i in range(carousel_tabs.size()):
		var tab = carousel_tabs[i]
		var sb = StyleBoxFlat.new()
		
		# Base styling
		sb.bg_color = Color(0.1, 0.1, 0.15, 0.7)
		sb.border_color = Color(0.0, 0.9, 1.0, 0.0)
		sb.set_border_width(SIDE_BOTTOM, 3)
		sb.content_margin_left = 12; sb.content_margin_right = 12
		sb.content_margin_top = 8; sb.content_margin_bottom = 8
		
		if i == carousel_index:
			sb.bg_color = Color(0.2, 0.3, 0.4, 0.9)
			sb.border_color = Color(0.0, 0.9, 1.0, 0.8)
			tab.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		else:
			tab.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			
		tab.add_theme_stylebox_override("normal", sb)
		
		var hsb = sb.duplicate()
		hsb.bg_color = Color(0.2, 0.2, 0.3, 0.9)
		tab.add_theme_stylebox_override("hover", hsb)
		tab.add_theme_stylebox_override("focus", hsb)
		tab.add_theme_stylebox_override("pressed", sb)
	
	var slide_func = carousel_slides[carousel_index]
	slide_func.call()

func _build_carousel_standings() -> void:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	carousel_content.add_child(vbox)
	
	# 1. STANDINGS SUB-TABS
	var tab_hb = HBoxContainer.new()
	tab_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hb.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_hb)
	
	var tab_names = ["GOLD", "SILVER", "BRONZE"]
	var tier_colors = [
		Color(1.0, 0.85, 0.1),  # Gold
		Color(0.75, 0.85, 1.0), # Silver
		Color(0.8, 0.5, 0.15)  # Bronze
	]
	
	var player_div_name = LeagueManager.get_player_division_name()
	
	for i in range(tab_names.size()):
		var t_name = tab_names[i]
		var is_player_tier = (t_name.to_pascal_case() == player_div_name)
		var display_text = t_name
		if is_player_tier:
			display_text = "★ " + t_name
			
		var btn = Button.new()
		btn.text = display_text
		btn.add_theme_font_size_override("font_size", 11)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var is_active = (standings_view_index == i)
		var accent_col = tier_colors[i]
		
		var sb = StyleBoxFlat.new()
		if is_active:
			sb.bg_color = Color(accent_col.r * 0.4, accent_col.g * 0.4, accent_col.b * 0.4, 0.6)
			sb.border_color = accent_col
			sb.set_border_width_all(1)
		else:
			sb.bg_color = Color(0.1, 0.1, 0.15, 0.4)
			sb.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.2)
			sb.set_border_width(SIDE_BOTTOM, 2)
			
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 14; sb.content_margin_right = 14
		sb.content_margin_top = 5; sb.content_margin_bottom = 5
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_color_override("font_color", Color.WHITE if is_active else Color(0.7, 0.7, 0.75))
		
		# Hover effect
		var hsb = sb.duplicate()
		hsb.bg_color.a += 0.2
		btn.add_theme_stylebox_override("hover", hsb)
		
		var t_idx = i
		btn.pressed.connect(func():
			standings_view_index = t_idx
			_update_carousel_view()
		)
		tab_hb.add_child(btn)
	
	# 2. Standings Header
	var head_pnl = PanelContainer.new()
	var h_sb = StyleBoxFlat.new()
	h_sb.bg_color = Color(1,1,1, 0.03)
	h_sb.content_margin_left = 12; h_sb.content_margin_right = 12
	h_sb.content_margin_top = 4; h_sb.content_margin_bottom = 4
	head_pnl.add_theme_stylebox_override("panel", h_sb)
	vbox.add_child(head_pnl)
	
	var head_hb = HBoxContainer.new()
	head_hb.add_theme_constant_override("separation", 4)
	head_pnl.add_child(head_hb)
	
	var col_defs = [["RK",30],["TEAM",-1],["W",30],["L",30],["PCT",50]]
	for cd in col_defs:
		var hl = Label.new()
		hl.text = cd[0]
		if cd[1] > 0: hl.custom_minimum_size = Vector2(cd[1], 0)
		else: hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		hl.add_theme_font_size_override("font_size", 11)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if cd[1] > 0 else HORIZONTAL_ALIGNMENT_LEFT
		head_hb.add_child(hl)
	
	# 3. Scrollable List
	var scroller = ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(scroller)
	
	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 1)
	scroller.add_child(list_vbox)
	
	# Determine which division to show
	var tier_name = ["Gold", "Silver", "Bronze"][clampi(standings_view_index, 0, 2)]
	var target_div = null
	for d in LeagueManager.divisions:
		if d["name"] == tier_name:
			target_div = d
			break
				
	if target_div:
		var div_name = target_div["name"]
		var div_col  = tier_colors[standings_view_index]
		
		# Division Label (above teams)
		var div_lbl = Label.new()
		div_lbl.text = div_name.to_upper() + " DIVISION"
		div_lbl.add_theme_font_size_override("font_size", 11)
		div_lbl.add_theme_color_override("font_color", div_col.darkened(0.2))
		div_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_vbox.add_child(div_lbl)

		# Teams
		var teams_list = target_div["teams"].duplicate()
		teams_list.sort_custom(func(a, b):
			if a.wins != b.wins: return a.wins > b.wins
			return a.losses < b.losses
		)
		
		for i in range(teams_list.size()):
			var t = teams_list[i]
			var is_player = (t == LeagueManager.player_team)
			
			var row_pnl = PanelContainer.new()
			var rsb = StyleBoxFlat.new()
			if is_player:
				rsb.bg_color = Color(0, 0.4, 1.0, 0.25)
				rsb.border_color = Color(0, 0.9, 1.0, 0.5)
				rsb.set_border_width(SIDE_LEFT, 4)
			else:
				rsb.bg_color = Color(1, 1, 1, 0.05) if i % 2 == 1 else Color(0, 0, 0, 0)
			
			rsb.content_margin_left = 12; rsb.content_margin_right = 12
			rsb.content_margin_top = 6; rsb.content_margin_bottom = 6
			row_pnl.add_theme_stylebox_override("panel", rsb)
			list_vbox.add_child(row_pnl)
			
			var hb = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 4)
			row_pnl.add_child(hb)
			
			var rank = Label.new()
			rank.text = str(i+1)
			rank.custom_minimum_size = Vector2(30, 0)
			rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rank.add_theme_font_size_override("font_size", 13)
			rank.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			hb.add_child(rank)
			
			var t_name_lbl = Label.new()
			t_name_lbl.text = t.name.to_upper()
			t_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			t_name_lbl.add_theme_font_size_override("font_size", 14)
			var base_col = t.color_primary.lightened(0.2) if is_player else Color(0.85, 0.85, 0.9)
			t_name_lbl.add_theme_color_override("font_color", base_col)
			hb.add_child(t_name_lbl)
			
			var w_lbl = Label.new()
			w_lbl.text = str(t.wins)
			w_lbl.custom_minimum_size = Vector2(30, 0)
			w_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			w_lbl.add_theme_font_size_override("font_size", 13)
			w_lbl.add_theme_color_override("font_color", Color(0.1, 1.0, 0.2) if t.wins > t.losses else Color(0.8, 0.8, 0.8))
			hb.add_child(w_lbl)
			
			var l_lbl = Label.new()
			l_lbl.text = str(t.losses)
			l_lbl.custom_minimum_size = Vector2(30, 0)
			l_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l_lbl.add_theme_font_size_override("font_size", 13)
			l_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1) if t.losses > t.wins else Color(0.7, 0.7, 0.7))
			hb.add_child(l_lbl)
			
			var pct_lbl = Label.new()
			var pct = float(t.wins) / float(max(1, t.wins + t.losses))
			var pct_str = "%.3f" % pct
			if pct_str.begins_with("0."): pct_str = pct_str.substr(1)
			if pct >= 1.0: pct_str = "1.000"
			pct_lbl.text = pct_str
			pct_lbl.custom_minimum_size = Vector2(50, 0)
			pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pct_lbl.add_theme_font_size_override("font_size", 12)
			pct_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			hb.add_child(pct_lbl)

func _show_season_stats_modal() -> void:
	if stats_division_index == -1:
		var p_div_name = LeagueManager.get_player_division_name()
		for i in range(LeagueManager.divisions.size()):
			if LeagueManager.divisions[i]["name"] == p_div_name:
				stats_division_index = i
				break
		if stats_division_index == -1: stats_division_index = 0

	var vbox = _build_generic_modal("LEAGUE STATISTICS", 1100, 650)
	
	# Create a container for the ENTIRE modal content so we can refresh buttons too
	var modal_content = VBoxContainer.new()
	modal_content.name = "ModalContent"
	modal_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_content.add_theme_constant_override("separation", 15)
	vbox.add_child(modal_content)
	
	_build_stats_modal_content(modal_content)

func _build_stats_modal_content(container: VBoxContainer) -> void:
	# 1. Toolbar: Division Switcher + View Type Toggle
	var toolbar = HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", 30)
	container.add_child(toolbar)
	
	# -- Division Buttons --
	var div_hb = HBoxContainer.new()
	div_hb.add_theme_constant_override("separation", 10)
	toolbar.add_child(div_hb)
	for i in range(LeagueManager.divisions.size()):
		var div_name = LeagueManager.divisions[i]["name"]
		var btn = Button.new()
		btn.text = div_name.to_upper()
		btn.add_theme_font_size_override("font_size", 14)
		var active = (i == stats_division_index)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.4, 0.8, 0.5) if active else Color(0.1, 0.1, 0.15, 0.6)
		sb.border_color = Color(0.0, 0.9, 1.0, 0.8) if active else Color(0.3, 0.3, 0.4, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 12; sb.content_margin_right = 12
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_color_override("font_color", Color.WHITE if active else Color(0.6, 0.6, 0.7))
		var idx = i
		btn.pressed.connect(func():
			stats_division_index = idx
			_refresh_stats_modal(container.get_parent())
		)
		div_hb.add_child(btn)
		
	# -- View Type Toggle --
	var view_hb = HBoxContainer.new()
	view_hb.add_theme_constant_override("separation", 10)
	toolbar.add_child(view_hb)
	for vt in ["individual", "team"]:
		var btn = Button.new()
		btn.text = vt.to_upper()
		btn.add_theme_font_size_override("font_size", 14)
		var active = (stats_view_type == vt)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.6, 0.4, 0.5) if active else Color(0.1, 0.1, 0.15, 0.6)
		sb.border_color = Color(0.4, 1.0, 0.6, 0.8) if active else Color(0.3, 0.3, 0.4, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 12; sb.content_margin_right = 12
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_color_override("font_color", Color.WHITE if active else Color(0.6, 0.6, 0.7))
		var type = vt
		btn.pressed.connect(func():
			stats_view_type = type
			_refresh_stats_modal(container.get_parent())
		)
		view_hb.add_child(btn)

	container.add_child(HSeparator.new())
	
	_show_season_stats_table(container)

func _refresh_stats_modal(vbox: VBoxContainer) -> void:
	# Clear the ModalContent and rebuild it (to update button states)
	var content = vbox.get_node("ModalContent")
	for c in content.get_children(): c.queue_free()
	_build_stats_modal_content(content)

func _show_season_stats_table(container: VBoxContainer) -> void:
	var is_indiv = (stats_view_type == "individual")
	
	# 1. Header with styling
	var head_panel = PanelContainer.new()
	var hsb = StyleBoxFlat.new()
	hsb.bg_color = Color(0.15, 0.18, 0.25, 0.9)
	hsb.border_color = Color(0.3, 0.5, 0.8, 0.4)
	hsb.set_border_width_all(1)
	hsb.set_corner_radius_all(4)
	hsb.content_margin_left = 10; hsb.content_margin_right = 10
	head_panel.add_theme_stylebox_override("panel", hsb)
	container.add_child(head_panel)
	
	var head_hbox = HBoxContainer.new()
	head_hbox.add_theme_constant_override("separation", 8)
	head_panel.add_child(head_hbox)
	
	var cols = ["RK", "NAME"]
	if is_indiv: cols.append("TEAM")
	cols.append_array(["PTS", "PPG", "REB", "RPG", "AST", "APG", "BLK", "BPG", "FGM", "FGA", "FG%", "3PM", "3PA", "3P%"])
	
	var fields = ["", "name"]
	if is_indiv: fields.append("team_name")
	fields.append_array(["pts", "ppg", "reb", "rpg", "ast", "apg", "blk", "bpg", "fgm", "fga", "fg_pct", "tpm", "tpa", "tp_pct"])
	
	var ws = [35, 160] # RK, NAME
	if is_indiv: ws.append(100) # TEAM
	ws.append_array([50, 50, 45, 50, 45, 50, 45, 50, 45, 45, 55, 45, 45, 55])
	
	for i in range(cols.size()):
		# Add vertical separator before stats start
		var stats_start_idx = 3 if is_indiv else 2
		if i == stats_start_idx:
			var sep = VSeparator.new()
			sep.add_theme_constant_override("separation", 15)
			head_hbox.add_child(sep)
			
		var btn = Button.new()
		btn.text = cols[i]
		btn.custom_minimum_size = Vector2(ws[i], 0)
		btn.add_theme_font_size_override("font_size", 13)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER if i >= stats_start_idx else HORIZONTAL_ALIGNMENT_LEFT
		if i == 1: btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		var f = fields[i]
		if f != "":
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if f == stats_sort_field:
				btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				btn.text += " " + ("^" if stats_sort_asc else "v")
			else:
				btn.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
			
			btn.pressed.connect(func():
				if stats_sort_field == f:
					stats_sort_asc = !stats_sort_asc
				else:
					stats_sort_field = f
					stats_sort_asc = false
				_refresh_stats_modal(container.get_parent())
			)
		else:
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			btn.disabled = true
			
		head_hbox.add_child(btn)
		
	# 2. Data Gathering
	var div = LeagueManager.divisions[stats_division_index]
	var data_list = []
	
	if is_indiv:
		for t in div["teams"]:
			for p in t.roster:
				var gp = max(1, p.game_log.size())
				var entry = {
					"p": p, "t": t, "name": p.name, "team_name": t.name,
					"pts": p.pts, "ppg": float(p.pts) / gp,
					"reb": p.reb, "rpg": float(p.reb) / gp,
					"ast": p.ast, "apg": float(p.ast) / gp,
					"blk": p.blk, "bpg": float(p.blk) / gp,
					"fgm": p.fgm, "fga": p.fga,
					"fg_pct": float(p.fgm) / max(1.0, float(p.fga)),
					"tpm": p.tpm, "tpa": p.tpa,
					"tp_pct": float(p.tpm) / max(1.0, float(p.tpa))
				}
				data_list.append(entry)
	else:
		# Team Aggregation
		for t in div["teams"]:
			var t_pts = 0; var t_reb = 0; var t_ast = 0; var t_blk = 0
			var t_fgm = 0; var t_fga = 0; var t_tpm = 0; var t_tpa = 0
			var t_gp = 0
			for p in t.roster:
				t_pts += p.pts; t_reb += p.reb; t_ast += p.ast; t_blk += p.blk
				t_fgm += p.fgm; t_fga += p.fga; t_tpm += p.tpm; t_tpa += p.tpa
				t_gp = max(t_gp, p.game_log.size())
			
			t_gp = max(1, t_gp)
			var entry = {
				"t": t, "name": t.name,
				"pts": t_pts, "ppg": float(t_pts) / t_gp,
				"reb": t_reb, "rpg": float(t_reb) / t_gp,
				"ast": t_ast, "apg": float(t_ast) / t_gp,
				"blk": t_blk, "bpg": float(t_blk) / t_gp,
				"fgm": t_fgm, "fga": t_fga,
				"fg_pct": float(t_fgm) / max(1.0, float(t_fga)),
				"tpm": t_tpm, "tpa": t_tpa,
				"tp_pct": float(t_tpm) / max(1.0, float(t_tpa))
			}
			data_list.append(entry)
			
	# 3. Sorting
	data_list.sort_custom(func(a, b):
		var va = a.get(stats_sort_field, 0)
		var vb = b.get(stats_sort_field, 0)
		if va is String or vb is String:
			if stats_sort_asc: return str(va).naturalnocasecmp_to(str(vb)) < 0
			else: return str(va).naturalnocasecmp_to(str(vb)) > 0
		if stats_sort_asc: return va < vb
		else: return va > vb
	)
	
	# 4. Scrollable List
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	container.add_child(scroll)
	
	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(list_vbox)
	
	for i in range(data_list.size()):
		var d = data_list[i]
		var is_player_row = (d["t"] == LeagueManager.player_team)
		
		# Row Panel with Zebra Stripping + Hover
		var row_panel = PanelContainer.new()
		row_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var base_sb = StyleBoxFlat.new()
		if is_player_row: 
			base_sb.bg_color = Color(0.0, 0.4, 0.6, 0.3)
			base_sb.border_color = Color(0.0, 0.9, 1.0, 0.4)
			base_sb.set_border_width_all(1)
		else:
			# Zebra stripping
			if i % 2 == 1: base_sb.bg_color = Color(1, 1, 1, 0.05)
			else: base_sb.bg_color = Color(0, 0, 0, 0)
			
		base_sb.content_margin_left = 10; base_sb.content_margin_right = 10
		base_sb.content_margin_top = 4; base_sb.content_margin_bottom = 4
		row_panel.add_theme_stylebox_override("panel", base_sb)
		
		# Hover logic
		var hover_sb = base_sb.duplicate()
		hover_sb.bg_color = Color(1, 1, 1, 0.12) if not is_player_row else Color(0.0, 0.5, 0.8, 0.4)
		row_panel.mouse_entered.connect(func(): row_panel.add_theme_stylebox_override("panel", hover_sb))
		row_panel.mouse_exited.connect(func(): row_panel.add_theme_stylebox_override("panel", base_sb))
		
		list_vbox.add_child(row_panel)
		
		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 8)
		row_panel.add_child(row_hbox)
		
		var base_col = Color(0.0, 0.9, 1.0) if is_player_row else Color(0.9, 0.9, 0.95)
		var stats_start_idx = 3 if is_indiv else 2
		
		# Rank
		var rk = Label.new()
		rk.text = str(i+1) + "."
		rk.custom_minimum_size = Vector2(ws[0], 0)
		rk.add_theme_font_size_override("font_size", 14)
		rk.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		row_hbox.add_child(rk)
		
		# Name
		var nam = Label.new()
		nam.text = d.name
		nam.custom_minimum_size = Vector2(ws[1], 0)
		nam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nam.add_theme_font_size_override("font_size", 15)
		nam.add_theme_color_override("font_color", base_col)
		# Bolder names
		var font_bold = ThemeDB.fallback_font # Using default but could use dynamic
		nam.add_theme_font_override("font", font_bold)
		row_hbox.add_child(nam)
		
		# Team (Indiv only)
		if is_indiv:
			var t_lbl = Label.new()
			t_lbl.text = d.team_name.to_upper()
			t_lbl.custom_minimum_size = Vector2(ws[2], 0)
			t_lbl.add_theme_font_size_override("font_size", 13)
			var team_col = d.t.color_primary.lightened(0.2)
			t_lbl.add_theme_color_override("font_color", team_col)
			row_hbox.add_child(t_lbl)
			
		# Divider before stats
		var sep = VSeparator.new()
		sep.add_theme_constant_override("separation", 15)
		row_hbox.add_child(sep)
		
		# Stats
		var vals = [
			str(d.pts), "%.1f" % d.ppg, 
			str(d.reb), "%.1f" % d.rpg,
			str(d.ast), "%.1f" % d.apg,
			str(d.blk), "%.1f" % d.bpg,
			str(d.fgm), str(d.fga),
			("%.3f" % d.fg_pct).lstrip("0") if d.fg_pct > 0 else "-",
			str(d.tpm), str(d.tpa),
			("%.3f" % d.tp_pct).lstrip("0") if d.tp_pct > 0 else "-"
		]
		if vals[10] == ".": vals[10] = ".000"
		if d.fg_pct >= 1.0: vals[10] = "1.000"
		if vals[13] == ".": vals[13] = ".000"
		if d.tp_pct >= 1.0: vals[13] = "1.000"
		
		var s_offset = 3 if is_indiv else 2
		
		for j in range(vals.size()):
			var sl = Label.new()
			sl.text = vals[j]
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sl.custom_minimum_size = Vector2(ws[j+s_offset], 0)
			sl.add_theme_font_size_override("font_size", 15)
			
			var cur_f = fields[j+s_offset]
			if cur_f == stats_sort_field:
				sl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			else:
				var is_avg = cur_f in ["ppg", "rpg", "apg", "bpg", "fg_pct", "tp_pct"]
				# Dim totals vs averages
				if is_avg:
					sl.add_theme_color_override("font_color", base_col.lightened(0.1))
				else:
					sl.add_theme_color_override("font_color", base_col.darkened(0.4))
			
			row_hbox.add_child(sl)

func _style_side_button(btn: Button) -> void:
	var sm = StyleBoxFlat.new()
	sm.bg_color = Color(0.1, 0.1, 0.2, 0.6)
	sm.border_color = Color(0.4, 0.4, 0.5, 0.5)
	sm.set_border_width_all(2)
	sm.set_corner_radius_all(6)
	sm.content_margin_top = 10
	sm.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", sm)
	
	var sm_h = sm.duplicate()
	sm_h.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	btn.add_theme_stylebox_override("hover", sm_h)
	
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

func _create_player_row(p: Resource, t: Resource = null) -> Control:
	var pnl = PanelContainer.new()
	pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t_color = Color(0.3, 0.3, 0.4, 0.5)
	if t != null and "color_primary" in t:
		t_color = t.color_primary
		
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.12, 0.12, 0.18, 0.8)
	sb_normal.border_color = t_color.darkened(0.2)
	sb_normal.set_border_width_all(2)
	sb_normal.set_corner_radius_all(4)
	sb_normal.content_margin_left = 12
	sb_normal.content_margin_right = 12
	sb_normal.content_margin_top = 8
	sb_normal.content_margin_bottom = 8
	
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(0.18, 0.18, 0.24, 0.95)
	sb_hover.border_color = t_color.lightened(0.2)
	
	pnl.add_theme_stylebox_override("panel", sb_normal)
	pnl.mouse_entered.connect(func(): pnl.add_theme_stylebox_override("panel", sb_hover))
	pnl.mouse_exited.connect(func(): pnl.add_theme_stylebox_override("panel", sb_normal))
	
	var pvbox = VBoxContainer.new()
	pnl.add_child(pvbox)
	
	var header_hbox = HBoxContainer.new()
	pvbox.add_child(header_hbox)
	
	var num_lbl = Label.new()
	num_lbl.text = "#%d " % p.number if "number" in p else ""
	num_lbl.add_theme_font_size_override("font_size", 18)
	num_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	header_hbox.add_child(num_lbl)
	
	if "portrait" in p and p.portrait:
		var pr = TextureRect.new()
		pr.texture = p.portrait
		pr.custom_minimum_size = Vector2(96, 96)
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header_hbox.add_child(pr)
		
	var n_lbl = Label.new()
	n_lbl.text = p.name
	n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n_lbl.add_theme_font_size_override("font_size", 20)
	header_hbox.add_child(n_lbl)
	
	var o_lbl = Label.new()
	if "speed" in p:
		var po = round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0)
		o_lbl.text = "OVR: " + str(int(po))
		o_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		o_lbl.add_theme_font_size_override("font_size", 18)
	else:
		o_lbl.text = "??"
	header_hbox.add_child(o_lbl)
	
	if "speed" in p:
		var stat_panel = PanelContainer.new()
		var stat_bg = StyleBoxFlat.new()
		stat_bg.bg_color = Color(0.08, 0.08, 0.12, 0.7)
		stat_bg.border_color = t_color.darkened(0.4)
		stat_bg.set_border_width_all(1)
		stat_bg.set_corner_radius_all(6)
		stat_bg.set_content_margin_all(8)
		stat_panel.add_theme_stylebox_override("panel", stat_bg)
		pvbox.add_child(stat_panel)

		var stat_grid = GridContainer.new()
		stat_grid.columns = 2
		stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_grid.add_theme_constant_override("h_separation", 20)
		stat_grid.add_theme_constant_override("v_separation", 6)
		stat_panel.add_child(stat_grid)
		
		var stats_keys = ["speed", "shot", "pass_skill", "tackle", "strength", "aggression"]
		var stats_labels = ["Speed", "Shooting", "Passing", "Tackling", "Strength", "Aggression"]
		
		for j in range(6):
			var s_val = float(p.get(stats_keys[j]))
			
			var s_vbox = VBoxContainer.new()
			s_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_vbox.add_theme_constant_override("separation", 2)
			
			var s_lbl = Label.new()
			s_lbl.text = stats_labels[j]
			s_lbl.add_theme_font_size_override("font_size", 12)
			s_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			s_vbox.add_child(s_lbl)
			
			var bar_hbox = HBoxContainer.new()
			bar_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_vbox.add_child(bar_hbox)
			
			var bar = ProgressBar.new()
			bar.min_value = 0
			bar.max_value = 100
			bar.value = s_val
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			var sb_bar_bg = StyleBoxFlat.new()
			sb_bar_bg.bg_color = Color(0.05, 0.05, 0.05, 0.8)
			sb_bar_bg.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("background", sb_bar_bg)
			
			var c = Color.WHITE
			if s_val <= 50.0:
				var pt = s_val / 50.0
				c = Color(0.2, 0.1, 0.4).lerp(Color(0.1, 0.5, 0.9), pt)
			else:
				var pt = (s_val - 50.0) / 50.0
				c = Color(0.1, 0.5, 0.9).lerp(Color(0.5, 1.0, 1.0), pt)
					
			var sb_fill = StyleBoxFlat.new()
			sb_fill.bg_color = c
			sb_fill.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("fill", sb_fill)
			bar_hbox.add_child(bar)
			
			var v_lbl = Label.new()
			v_lbl.text = str(int(s_val))
			v_lbl.custom_minimum_size = Vector2(22, 0)
			v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v_lbl.add_theme_font_size_override("font_size", 12)
			v_lbl.add_theme_color_override("font_color", c)
			bar_hbox.add_child(v_lbl)
			
			stat_grid.add_child(s_vbox)
			
	return pnl

func _on_play_next_pressed() -> void:
	if LeagueManager.current_week >= LeagueManager.schedule.size():
		return # Season over
		
	var opponent = LeagueManager.get_next_opponent()
	var is_home = LeagueManager.get_next_match_is_home()
	if opponent:
		var config = LeagueManager.season_config.duplicate()
		config["is_season_game"] = true
		
		# Set team order based on Home/Away
		var t_a = LeagueManager.player_team if is_home else opponent
		var t_b = opponent if is_home else LeagueManager.player_team
		config["human_team_index"] = 0 if is_home else 1
		config["court_theme_index"] = 0 # 0 means "Home Court" which reads Team A's colors
		
		LeagueManager.start_quick_match(t_a, t_b, config)
	else:
		print("No opponent found!")

var pnl_actions_group = []

func _on_simulate_pressed() -> void:
	for b in pnl_actions_group: b.disabled = true
	
	var player_match = null
	var week_matches = LeagueManager.schedule[LeagueManager.current_week]
	if not week_matches: return
	
	var is_playing = false
	var active_sched = LeagueManager.playoff_schedule if LeagueManager.is_postseason else LeagueManager.schedule
	if LeagueManager.current_week < active_sched.size():
		for m in active_sched[LeagueManager.current_week]:
			if m["home"] == LeagueManager.player_team.name or m["away"] == LeagueManager.player_team.name:
				is_playing = true
				break
	
	if not is_playing and LeagueManager.is_postseason:
		# Fast track complete round simulation for inactive teams
		LeagueManager.simulate_week()
		_show_round_summary(active_sched[LeagueManager.current_week - 1])
		return
		
	var sim_data = LeagueManager.simulate_week()
	var t_home = LeagueManager._get_team_by_name(sim_data.get("home_team_name", ""))
	var t_away = LeagueManager._get_team_by_name(sim_data.get("away_team_name", ""))
	
	# Try to infer teams if detailed missing (will be updated in league_manager)
	if not t_home:
		var active_week_matches = active_sched[LeagueManager.current_week - 1]
		for m in active_week_matches:
			if m["home"] == LeagueManager.player_team.name or m["away"] == LeagueManager.player_team.name:
				t_home = LeagueManager._get_team_by_name(m["home"])
				t_away = LeagueManager._get_team_by_name(m["away"])
				break
				
	_show_simulation_summary(sim_data, t_home, t_away)

func _on_season_stats_pressed() -> void:
	_show_season_stats_modal()

func _show_round_summary(played_matches: Array) -> void:
	var vbox = _build_generic_modal("PLAYOFF ROUND SIMULATED", 600, 750)
	
	var scr = ScrollContainer.new()
	scr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(scr)
	
	var rbox = VBoxContainer.new()
	rbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rbox.add_theme_constant_override("separation", 15)
	scr.add_child(rbox)
	
	# Group by division
	var div_matches = {}
	for m in played_matches:
		if not m["played"]: continue
		var d = m.get("div", m.get("division", "League"))
		if not div_matches.has(d): div_matches[d] = []
		div_matches[d].append(m)
		
	# Division badge colors
	var div_badge_colors = {
		"Bronze": Color(0.8, 0.5, 0.1),
		"Silver": Color(0.7, 0.8, 1.0),
		"Gold":   Color(1.0, 0.85, 0.1)
	}

	for d in div_matches.keys():
		var d_lbl = Label.new()
		d_lbl.text = d.to_upper() + " DIVISION"
		d_lbl.add_theme_font_size_override("font_size", 14)
		var c = div_badge_colors.get(d, Color(0.8, 0.8, 0.9))
		d_lbl.add_theme_color_override("font_color", c)
		rbox.add_child(d_lbl)
		
		for m in div_matches[d]:
			var score_pnl = PanelContainer.new()
			var p_sb = StyleBoxFlat.new()
			p_sb.bg_color = Color(0.12, 0.12, 0.18, 0.9)
			p_sb.set_corner_radius_all(6)
			p_sb.content_margin_left = 15; p_sb.content_margin_right = 15
			p_sb.content_margin_top = 10; p_sb.content_margin_bottom = 10
			score_pnl.add_theme_stylebox_override("panel", p_sb)
			rbox.add_child(score_pnl)
			
			var shb = HBoxContainer.new()
			score_pnl.add_child(shb)
			
			var a_lbl = Label.new()
			a_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			a_lbl.text = "%d %s" % [m["away_score"], m["away"]]
			a_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			a_lbl.add_theme_font_size_override("font_size", 20)
			a_lbl.add_theme_color_override("font_color", Color.YELLOW if m["away_score"] > m["home_score"] else Color(0.6, 0.6, 0.7))
			shb.add_child(a_lbl)
			
			var vs = Label.new()
			vs.text = " - "
			vs.custom_minimum_size = Vector2(40, 0)
			vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vs.add_theme_font_size_override("font_size", 20)
			vs.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			shb.add_child(vs)
			
			var h_lbl = Label.new()
			h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h_lbl.text = "%s %d" % [m["home"], m["home_score"]]
			h_lbl.add_theme_font_size_override("font_size", 20)
			h_lbl.add_theme_color_override("font_color", Color.YELLOW if m["home_score"] > m["away_score"] else Color(0.6, 0.6, 0.7))
			shb.add_child(h_lbl)
		
	var setup_proceed = func():
		var close_btn = vbox.get_child(vbox.get_child_count() - 1) as Button
		if close_btn:
			close_btn.text = "PROCEED"
			var bg_ptr = vbox.get_parent().get_parent()
			if bg_ptr and bg_ptr is CenterContainer: bg_ptr = bg_ptr.get_parent()
			
			var conns = close_btn.get_signal_connection_list("pressed")
			for c in conns: close_btn.pressed.disconnect(c["callable"])
			
			close_btn.pressed.connect(func():
				if bg_ptr: bg_ptr.queue_free()
				_build_ui()
				_update_carousel_view()
			)
			
	Callable(setup_proceed).call_deferred()

func _show_simulation_summary(sim_data: Dictionary, t_home: Resource, t_away: Resource) -> void:
	var vbox = _build_generic_modal("MATCH SIMULATED", 700, 500)
	
	var hb = HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 20)
	vbox.add_child(hb)
	
	var left = _build_team_preview_col(t_home, "HOME", sim_data["home_score"] > sim_data["away_score"])
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	
	var mid = VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.custom_minimum_size = Vector2(150, 0)
	mid.add_theme_constant_override("separation", 10)
	hb.add_child(mid)
	
	var s_lbl = Label.new()
	s_lbl.text = "FINAL SCORE"
	s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	mid.add_child(s_lbl)
	
	var score_lbl = Label.new()
	score_lbl.text = "%d - %d" % [sim_data["home_score"], sim_data["away_score"]]
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 42)
	mid.add_child(score_lbl)
	
	# Quarters
	var q_pnl = PanelContainer.new()
	var q_sb = StyleBoxFlat.new()
	q_sb.bg_color = Color(0.1, 0.1, 0.15, 0.6)
	q_sb.set_corner_radius_all(4)
	q_sb.content_margin_left = 10; q_sb.content_margin_right = 10
	q_sb.content_margin_top = 5; q_sb.content_margin_bottom = 5
	q_pnl.add_theme_stylebox_override("panel", q_sb)
	mid.add_child(q_pnl)
	
	var qbox = VBoxContainer.new()
	qbox.add_theme_constant_override("separation", 5)
	q_pnl.add_child(qbox)
	
	var q_grid = GridContainer.new()
	q_grid.columns = 6
	q_grid.add_theme_constant_override("h_separation", 15)
	q_grid.add_theme_constant_override("v_separation", 5)
	qbox.add_child(q_grid)
	
	# Header Row
	var headers = ["TEAM", "Q1", "Q2", "Q3", "Q4", "TOT"]
	for h in headers:
		var hl = Label.new()
		hl.text = h
		hl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		hl.add_theme_font_size_override("font_size", 12)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_grid.add_child(hl)
		
	# Away Row
	var hq = sim_data.get("home_quarters", [0,0,0,0])
	var aq = sim_data.get("away_quarters", [0,0,0,0])
	
	var a_lbl = Label.new()
	a_lbl.text = t_away.name.left(5).to_upper()
	a_lbl.add_theme_font_size_override("font_size", 14)
	q_grid.add_child(a_lbl)
	for qt in aq:
		var qv = Label.new()
		qv.text = str(qt)
		qv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_grid.add_child(qv)
	var a_tot = Label.new()
	a_tot.text = str(sim_data["away_score"])
	a_tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a_tot.add_theme_color_override("font_color", Color.WHITE)
	q_grid.add_child(a_tot)
	
	# Home Row
	var h_lbl = Label.new()
	h_lbl.text = t_home.name.left(5).to_upper()
	h_lbl.add_theme_font_size_override("font_size", 14)
	q_grid.add_child(h_lbl)
	for qt in hq:
		var qv = Label.new()
		qv.text = str(qt)
		qv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_grid.add_child(qv)
	var h_tot = Label.new()
	h_tot.text = str(sim_data["home_score"])
	h_tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_tot.add_theme_color_override("font_color", Color.WHITE)
	q_grid.add_child(h_tot)
		
	var hseq = HSeparator.new()
	mid.add_child(hseq)
	
	var p_lbl = Label.new()
	var mvp_str = sim_data.get("top_scorer", "Player")
	var mvp_pts = sim_data.get("top_scorer_pts", 0)
	var mvp_reb = sim_data.get("top_rebounder_reb", 0)
	var mvp_ast = sim_data.get("top_assister_ast", 0)
	p_lbl.text = "MVP: %s\n(%d PTS, %d REB, %d AST)" % [mvp_str, mvp_pts, mvp_reb, mvp_ast]
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.add_theme_font_size_override("font_size", 12)
	p_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	mid.add_child(p_lbl)
	
	if LeagueManager.last_match_progression.size() > 0:
		var pseq = HSeparator.new()
		mid.add_child(pseq)
		
		var prog_lbl = Label.new()
		prog_lbl.text = "PLAYER PROGRESSION"
		prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prog_lbl.add_theme_font_size_override("font_size", 12)
		prog_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		mid.add_child(prog_lbl)
		
		var prog_vb = VBoxContainer.new()
		mid.add_child(prog_vb)
		
		for p_name in LeagueManager.last_match_progression.keys():
			var prog = LeagueManager.last_match_progression[p_name]
			var levels = prog.get("levels_gained", 0)
			var pl = Label.new()
			if levels > 0:
				pl.text = "%s : Level Up! (+%d XP)" % [p_name.left(10), prog.get("xp_gained", 0)]
				pl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
			else:
				pl.text = "%s : +%d XP" % [p_name.left(10), prog.get("xp_gained", 0)]
				pl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.add_theme_font_size_override("font_size", 12)
			prog_vb.add_child(pl)
	
	var right = _build_team_preview_col(t_away, "AWAY", sim_data["away_score"] > sim_data["home_score"])
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	
	# We defer this so the modal has time to attach its deferred close button
	var setup_proceed = func():
		var close_btn = vbox.get_child(vbox.get_child_count() - 1) as Button # assumed last is close
		if close_btn:
			close_btn.text = "PROCEED"
			# Find the background overlay to kill it, but also rebuild UI
			var bg_ptr = vbox.get_parent().get_parent() # Vbox -> PanelContainer -> CenterContainer -> Bg
			if bg_ptr and bg_ptr is CenterContainer: bg_ptr = bg_ptr.get_parent()
			
			# Clear existing connections safely
			var conns = close_btn.get_signal_connection_list("pressed")
			for c in conns: close_btn.pressed.disconnect(c["callable"])
			
			close_btn.pressed.connect(func():
				if bg_ptr: bg_ptr.queue_free()
				_build_ui()
			)
			
	Callable(setup_proceed).call_deferred()

func _show_season_wrapup(champ_name: String) -> void:
	var vbox = _build_generic_modal("SEASON WRAP-UP", 1000, 750)
	
	var scr = ScrollContainer.new()
	scr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(scr)
	
	var rbox = VBoxContainer.new()
	rbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rbox.add_theme_constant_override("separation", 20)
	scr.add_child(rbox)
	
	# --- ALL CHAMPIONS BANNER ---
	var champs_map = LeagueManager.get_all_champions()
	var champs_hbox = HBoxContainer.new()
	champs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	champs_hbox.add_theme_constant_override("separation", 20)
	rbox.add_child(champs_hbox)
	
	var tier_colors = {
		"Gold": Color(1.0, 0.85, 0.1),
		"Silver": Color(0.75, 0.85, 1.0),
		"Bronze": Color(0.8, 0.5, 0.15)
	}
	
	for tier in ["Gold", "Silver", "Bronze"]:
		if not champs_map.has(tier): continue
		var c_name = champs_map[tier]
		var c_team = LeagueManager._get_team_by_name(c_name)
		if c_team:
			var c_pnl = PanelContainer.new()
			c_pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var c_sb = StyleBoxFlat.new()
			c_sb.bg_color = Color(0.1, 0.1, 0.15, 0.9)
			c_sb.border_color = tier_colors.get(tier, Color(0.8, 0.8, 0.8))
			c_sb.set_border_width_all(2)
			c_sb.set_corner_radius_all(8)
			c_sb.content_margin_top = 15; c_sb.content_margin_bottom = 15
			c_pnl.add_theme_stylebox_override("panel", c_sb)
			champs_hbox.add_child(c_pnl)
			
			var c_vb = VBoxContainer.new()
			c_vb.alignment = BoxContainer.ALIGNMENT_CENTER
			c_vb.add_theme_constant_override("separation", 10)
			c_pnl.add_child(c_vb)
			
			var l_tier = Label.new()
			l_tier.text = tier.to_upper() + " CHAMPION"
			l_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l_tier.add_theme_font_size_override("font_size", 14)
			l_tier.add_theme_color_override("font_color", tier_colors.get(tier, Color(0.8, 0.8, 0.8)).darkened(0.2))
			c_vb.add_child(l_tier)
			
			if c_team.logo:
				var logo = TextureRect.new()
				logo.texture = c_team.logo
				logo.custom_minimum_size = Vector2(80, 80)
				logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				c_vb.add_child(logo)
				
			var c_lbl = Label.new()
			c_lbl.text = c_team.name.to_upper()
			c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c_lbl.add_theme_font_size_override("font_size", 22)
			c_lbl.add_theme_color_override("font_color", tier_colors.get(tier, Color(0.8, 0.8, 0.8)))
			c_vb.add_child(c_lbl)
			
	# --- Player Team Wrap-Up ---
	var pt = LeagueManager.player_team
	if pt:
		var pt_pnl = PanelContainer.new()
		var pt_sb = StyleBoxFlat.new()
		pt_sb.bg_color = Color(0.12, 0.12, 0.18, 0.9)
		pt_sb.border_color = pt.color_primary.darkened(0.2)
		pt_sb.set_border_width_all(2)
		pt_sb.set_corner_radius_all(8)
		pt_sb.content_margin_top = 15; pt_sb.content_margin_bottom = 15
		pt_pnl.add_theme_stylebox_override("panel", pt_sb)
		rbox.add_child(pt_pnl)
		
		var pt_hb = HBoxContainer.new()
		pt_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		pt_hb.add_theme_constant_override("separation", 50)
		pt_pnl.add_child(pt_hb)
		
		# Record Box
		var rec_vb = VBoxContainer.new()
		rec_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		pt_hb.add_child(rec_vb)
		
		var rec_head = Label.new()
		rec_head.text = "YOUR SEASON RECORD"
		rec_head.add_theme_font_size_override("font_size", 14)
		rec_head.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		rec_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec_vb.add_child(rec_head)
		
		var rec_val = Label.new()
		rec_val.text = "%d W - %d L" % [pt.wins, pt.losses]
		rec_val.add_theme_font_size_override("font_size", 28)
		rec_val.add_theme_color_override("font_color", pt.color_primary.lightened(0.2))
		rec_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec_vb.add_child(rec_val)
		
		# Playoff Outcome
		var playoff_outcome = "DID NOT QUALIFY"
		var prize_money = 0
		if LeagueManager.is_postseason:
			var p_div = LeagueManager.get_player_division_name()
			var is_champ = champs_map.get(p_div) == pt.name
			if is_champ:
				playoff_outcome = "DIVISION CHAMPION"
				prize_money = 5000
			else:
				var in_finals = false
				var in_semis = false
				for w_idx in range(LeagueManager.playoff_schedule.size()):
					for m in LeagueManager.playoff_schedule[w_idx]:
						if m["home"] == pt.name or m["away"] == pt.name:
							if w_idx == 0: in_semis = true
							if w_idx == 1: in_finals = true
				if in_finals:
					playoff_outcome = "LOST IN FINALS"
				elif in_semis:
					playoff_outcome = "LOST IN SEMIFINALS"
					
		var out_vb = VBoxContainer.new()
		out_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		pt_hb.add_child(out_vb)
		
		var out_head = Label.new()
		out_head.text = "PLAYOFF OUTCOME"
		out_head.add_theme_font_size_override("font_size", 14)
		out_head.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		out_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		out_vb.add_child(out_head)
		
		var out_val = Label.new()
		out_val.text = playoff_outcome
		out_val.add_theme_font_size_override("font_size", 20)
		if "CHAMPION" in playoff_outcome:
			out_val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		elif "LOST" in playoff_outcome:
			out_val.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		else:
			out_val.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		out_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		out_vb.add_child(out_val)
		
		if prize_money > 0:
			var prize_lbl = Label.new()
			prize_lbl.text = "CHAMPIONSHIP PRIZE: +$5,000"
			prize_lbl.add_theme_font_size_override("font_size", 16)
			prize_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
			prize_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			out_vb.add_child(prize_lbl)
		
		# Team MVP
		var mvp = null
		var max_pts = -1
		for p in pt.roster:
			if p.pts > max_pts:
				max_pts = p.pts
				mvp = p
				
		if mvp:
			var mvp_vb = VBoxContainer.new()
			mvp_vb.alignment = BoxContainer.ALIGNMENT_CENTER
			pt_hb.add_child(mvp_vb)
			
			var mvp_head = Label.new()
			mvp_head.text = "TEAM MVP: %s" % mvp.name.to_upper()
			mvp_head.add_theme_font_size_override("font_size", 14)
			mvp_head.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			mvp_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mvp_vb.add_child(mvp_head)
			
			var mvp_stat = Label.new()
			mvp_stat.text = "%d PTS | %d REB | %d AST" % [mvp.pts, mvp.reb, mvp.ast]
			mvp_stat.add_theme_font_size_override("font_size", 24)
			mvp_stat.add_theme_color_override("font_color", Color.WHITE)
			mvp_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mvp_vb.add_child(mvp_stat)
			
	# --- Analyze promotions/relegations ---
	var moves = []
	var sim_divs = LeagueManager.divisions
	
	for i in range(sim_divs.size() - 1):
		var div = sim_divs[i]
		var c_name = champs_map.get(div["name"], "")
		if c_name != "":
			moves.append({"name": c_name, "type": "PROMOTED", "color": Color(0.3, 0.9, 0.3), "from": div["name"], "to": sim_divs[i+1]["name"], "icon": "▲"})
			
	for i in range(1, sim_divs.size()):
		var div = sim_divs[i]
		if div["teams"].size() > 0:
			var div_teams = div["teams"].duplicate()
			div_teams.sort_custom(func(a,b): return a.wins > b.wins)
			var lowest = div_teams[-1]
			var c_name = champs_map.get(div["name"], "")
			if lowest.name != c_name:
				moves.append({"name": lowest.name, "type": "RELEGATED", "color": Color(0.9, 0.3, 0.3), "from": div["name"], "to": sim_divs[i-1]["name"], "icon": "▼"})
			
	if moves.size() > 0:
		var m_lbl = Label.new()
		m_lbl.text = "LEAGUE TIER ADJUSTMENTS"
		m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m_lbl.add_theme_font_size_override("font_size", 16)
		m_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		rbox.add_child(m_lbl)
		
		# Grid for moves to look more polished
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 15)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rbox.add_child(grid)
		
		for m in moves:
			var m_pnl = PanelContainer.new()
			m_pnl.custom_minimum_size = Vector2(400, 0)
			var m_sb = StyleBoxFlat.new()
			m_sb.bg_color = Color(0.12, 0.12, 0.18, 0.9)
			m_sb.border_color = Color(m["color"].r, m["color"].g, m["color"].b, 0.5)
			m_sb.set_border_width(SIDE_LEFT, 6)
			m_sb.set_corner_radius_all(4)
			m_sb.content_margin_left = 15; m_sb.content_margin_right = 15
			m_sb.content_margin_top = 10; m_sb.content_margin_bottom = 10
			m_pnl.add_theme_stylebox_override("panel", m_sb)
			grid.add_child(m_pnl)
			
			var m_hb = HBoxContainer.new()
			m_pnl.add_child(m_hb)
			
			var n_lbl = Label.new()
			n_lbl.text = m["name"]
			n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n_lbl.add_theme_font_size_override("font_size", 20)
			m_hb.add_child(n_lbl)
			
			var t_lbl = Label.new()
			t_lbl.text = "%s %s TO %s" % [m["icon"], m["type"], m["to"].to_upper()]
			t_lbl.add_theme_font_size_override("font_size", 16)
			t_lbl.add_theme_color_override("font_color", m["color"])
			t_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			m_hb.add_child(t_lbl)
			
	var sep = HSeparator.new()
	rbox.add_child(sep)
	
	var final_stand_lbl = Label.new()
	final_stand_lbl.text = "FINAL LEAGUE STANDINGS"
	final_stand_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_stand_lbl.add_theme_font_size_override("font_size", 22)
	final_stand_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	rbox.add_child(final_stand_lbl)
	
	var standings_box = VBoxContainer.new()
	standings_box.add_theme_constant_override("separation", 30)
	rbox.add_child(standings_box)

	for d in sim_divs:
		var d_pnl = VBoxContainer.new()
		standings_box.add_child(d_pnl)
		
		var d_lbl = Label.new()
		d_lbl.text = d["name"].to_upper() + " DIVISION"
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var d_col = tier_colors.get(d["name"], Color(0.8, 0.8, 0.9))
		d_lbl.add_theme_color_override("font_color", d_col)
		d_lbl.add_theme_font_size_override("font_size", 18)
		d_pnl.add_child(d_lbl)
		
		var head_pnl = PanelContainer.new()
		var h_sb = StyleBoxFlat.new()
		h_sb.bg_color = Color(1,1,1, 0.05)
		h_sb.content_margin_left = 12; h_sb.content_margin_right = 12
		h_sb.content_margin_top = 6; h_sb.content_margin_bottom = 6
		head_pnl.add_theme_stylebox_override("panel", h_sb)
		d_pnl.add_child(head_pnl)
		
		var head_hb = HBoxContainer.new()
		head_hb.add_theme_constant_override("separation", 4)
		head_pnl.add_child(head_hb)
		
		for cd in [["RK",30],["TEAM",-1],["W",30],["L",30],["PCT",50]]:
			var hl = Label.new()
			hl.text = cd[0]
			if cd[1] > 0: hl.custom_minimum_size = Vector2(cd[1], 0)
			else: hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			hl.add_theme_font_size_override("font_size", 12)
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if cd[1] > 0 else HORIZONTAL_ALIGNMENT_LEFT
			head_hb.add_child(hl)
			
		var teams_list = d["teams"].duplicate()
		teams_list.sort_custom(func(a, b):
			if a.wins != b.wins: return a.wins > b.wins
			return a.losses < b.losses
		)
		
		for i in range(teams_list.size()):
			var t = teams_list[i]
			var is_player = (pt != null and t == pt)
			
			var row_pnl = PanelContainer.new()
			var rsb = StyleBoxFlat.new()
			if is_player:
				rsb.bg_color = Color(0, 0.4, 1.0, 0.25)
				rsb.border_color = Color(0, 0.9, 1.0, 0.5)
				rsb.set_border_width(SIDE_LEFT, 4)
			else:
				rsb.bg_color = Color(1, 1, 1, 0.05) if i % 2 == 1 else Color(0, 0, 0, 0)
				
			rsb.content_margin_left = 12; rsb.content_margin_right = 12
			rsb.content_margin_top = 6; rsb.content_margin_bottom = 6
			row_pnl.add_theme_stylebox_override("panel", rsb)
			d_pnl.add_child(row_pnl)
			
			var hb = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 4)
			row_pnl.add_child(hb)
			
			var rank = Label.new()
			rank.text = str(i+1)
			rank.custom_minimum_size = Vector2(30, 0)
			rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rank.add_theme_font_size_override("font_size", 14)
			rank.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			hb.add_child(rank)
			
			var t_name_lbl = Label.new()
			t_name_lbl.text = t.name.to_upper()
			t_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			t_name_lbl.add_theme_font_size_override("font_size", 16)
			var base_col = t.color_primary.lightened(0.2) if is_player else Color(0.85, 0.85, 0.9)
			t_name_lbl.add_theme_color_override("font_color", base_col)
			hb.add_child(t_name_lbl)
			
			var w_lbl = Label.new()
			w_lbl.text = str(t.wins)
			w_lbl.custom_minimum_size = Vector2(30, 0)
			w_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			w_lbl.add_theme_font_size_override("font_size", 14)
			w_lbl.add_theme_color_override("font_color", Color(0.1, 1.0, 0.2) if t.wins > t.losses else Color(0.8, 0.8, 0.8))
			hb.add_child(w_lbl)
			
			var l_lbl = Label.new()
			l_lbl.text = str(t.losses)
			l_lbl.custom_minimum_size = Vector2(30, 0)
			l_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l_lbl.add_theme_font_size_override("font_size", 14)
			l_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1) if t.losses > t.wins else Color(0.7, 0.7, 0.7))
			hb.add_child(l_lbl)
			
			var pct_lbl = Label.new()
			var pct = float(t.wins) / float(max(1, t.wins + t.losses))
			var pct_str = "%.3f" % pct
			if pct_str.begins_with("0."): pct_str = pct_str.substr(1)
			if pct >= 1.0: pct_str = "1.000"
			pct_lbl.text = pct_str
			pct_lbl.custom_minimum_size = Vector2(50, 0)
			pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pct_lbl.add_theme_font_size_override("font_size", 13)
			pct_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			hb.add_child(pct_lbl)
			
	var setup_proceed = func():
		var close_btn = vbox.get_child(vbox.get_child_count() - 1) as Button
		if close_btn:
			close_btn.text = "CLOSE WRAP-UP"
			
	Callable(setup_proceed).call_deferred()

func _build_carousel_bracket() -> void:
	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	carousel_content.add_child(root_vbox)

	var tab_hb = HBoxContainer.new()
	tab_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hb.add_theme_constant_override("separation", 4)
	root_vbox.add_child(tab_hb)
	
	var tab_names = ["GOLD", "SILVER", "BRONZE"]
	var tier_colors = [
		Color(1.0, 0.85, 0.1),  # Gold
		Color(0.75, 0.85, 1.0), # Silver
		Color(0.8, 0.5, 0.15)  # Bronze
	]
	
	var player_div_name = LeagueManager.get_player_division_name()
	
	for i in range(tab_names.size()):
		var t_name = tab_names[i]
		var is_player_tier = (t_name.to_pascal_case() == player_div_name)
		var display_text = t_name
		if is_player_tier:
			display_text = "★ " + t_name
			
		var btn = Button.new()
		btn.text = display_text
		btn.add_theme_font_size_override("font_size", 11)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var is_active = (bracket_view_index == i)
		var accent_col = tier_colors[i]
		
		var sb = StyleBoxFlat.new()
		if is_active:
			sb.bg_color = Color(accent_col.r * 0.4, accent_col.g * 0.4, accent_col.b * 0.4, 0.6)
			sb.border_color = accent_col
			sb.set_border_width_all(1)
		else:
			sb.bg_color = Color(0.1, 0.1, 0.15, 0.4)
			sb.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.2)
			sb.set_border_width(SIDE_BOTTOM, 2)
			
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 14; sb.content_margin_right = 14
		sb.content_margin_top = 5; sb.content_margin_bottom = 5
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_color_override("font_color", Color.WHITE if is_active else Color(0.7, 0.7, 0.75))
		
		var hsb = sb.duplicate()
		hsb.bg_color.a += 0.2
		btn.add_theme_stylebox_override("hover", hsb)
		
		var t_idx = i
		btn.pressed.connect(func():
			bracket_view_index = t_idx
			_update_carousel_view()
		)
		tab_hb.add_child(btn)

	var scroller = ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(scroller)
	
	var scroller_vbox = VBoxContainer.new()
	scroller_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller_vbox.add_theme_constant_override("separation", 40)
	scroller.add_child(scroller_vbox)
	
	var sched = LeagueManager.playoff_schedule
	if sched.size() == 2:
		var target_tier = ["Gold", "Silver", "Bronze"][clampi(bracket_view_index, 0, 2)]
		var div_col = tier_colors[clampi(bracket_view_index, 0, 2)]
		
		var team_seeds = {}
		for d in LeagueManager.divisions:
			var teams_list = d["teams"].duplicate()
			teams_list.sort_custom(func(a, b):
				if a.wins != b.wins: return a.wins > b.wins
				return a.losses < b.losses
			)
			for j in range(teams_list.size()):
				team_seeds[teams_list[j].name] = j + 1
				
		var div_name = target_tier
		
		var div_lbl = Label.new()
		div_lbl.text = div_name.to_upper() + " DIVISION PLAYOFFS"
		div_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		div_lbl.add_theme_font_size_override("font_size", 18)
		div_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		scroller_vbox.add_child(div_lbl)
		
		var bracket_wrapper = MarginContainer.new()
		bracket_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller_vbox.add_child(bracket_wrapper)
		
		# Connectors rendering container
		var lines_bg = Control.new()
		lines_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		lines_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bracket_wrapper.add_child(lines_bg)
		
		var bracket_hbox = HBoxContainer.new()
		bracket_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bracket_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		bracket_hbox.add_theme_constant_override("separation", 20)
		bracket_wrapper.add_child(bracket_hbox)
		
		var sf_vbox = VBoxContainer.new()
		sf_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		sf_vbox.add_theme_constant_override("separation", 20)
		bracket_hbox.add_child(sf_vbox)
		
		var champ_vbox = VBoxContainer.new()
		champ_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		bracket_hbox.add_child(champ_vbox)

		var sf_nodes = []
		var cp_nodes = []
		
		for m in sched[0]:
			if m.get("division", "") == div_name:
				var pnl = _create_bracket_match_panel(m, team_seeds, div_col)
				sf_vbox.add_child(pnl)
				sf_nodes.append(pnl)
		for m in sched[1]:
			if m.get("division", "") == div_name:
				var pnl = _create_bracket_match_panel(m, team_seeds, div_col)
				champ_vbox.add_child(pnl)
				cp_nodes.append(pnl)

		lines_bg.draw.connect(func():
			var line_col = Color(0.4, 0.4, 0.5, 0.6)
			var w = 3.0
			for i in range(2):
				if i < sf_nodes.size() and cp_nodes.size() > 0:
					var n1 = sf_nodes[i]
					var n2 = cp_nodes[0]
					
					var r1 = n1.get_global_rect()
					var p1 = Vector2(r1.position.x + r1.size.x, r1.position.y + r1.size.y / 2.0) - lines_bg.global_position
					
					var r2 = n2.get_global_rect()
					var p2 = Vector2(r2.position.x, r2.position.y + r2.size.y / 2.0) - lines_bg.global_position
					
					var mid_x = p1.x + (p2.x - p1.x) / 2.0
					lines_bg.draw_line(p1, Vector2(mid_x, p1.y), line_col, w)
					lines_bg.draw_line(Vector2(mid_x, p1.y), Vector2(mid_x, p2.y), line_col, w)
					lines_bg.draw_line(Vector2(mid_x, p2.y), p2, line_col, w)
		)
		bracket_wrapper.item_rect_changed.connect(func(): lines_bg.queue_redraw())
			
func _create_bracket_match_panel(m: Dictionary, team_seeds: Dictionary, div_color: Color) -> Control:
	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(180, 0)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	if m["home"] == LeagueManager.player_team.name or m["away"] == LeagueManager.player_team.name:
		sb.bg_color = Color(0.2, 0.3, 0.4, 0.9)
		sb.border_color = Color(0.0, 0.9, 1.0, 0.6)
		sb.set_border_width_all(1)
	else:
		sb.border_color = Color(div_color.r, div_color.g, div_color.b, 0.3)
		sb.set_border_width_all(1)
		
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	pnl.add_theme_stylebox_override("panel", sb)
	
	var vb = VBoxContainer.new()
	pnl.add_child(vb)
	
	var home_win = m.get("played", false) and m.get("home_score", 0) > m.get("away_score", 0)
	var away_win = m.get("played", false) and m.get("away_score", 0) > m.get("home_score", 0)
	
	# Home Row
	var hb1 = HBoxContainer.new()
	vb.add_child(hb1)
	var l1 = Label.new()
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h_seed = team_seeds.get(m["home"], "?")
	if "TBD" in m["home"]: l1.text = m["home"]
	else: l1.text = "%s. %s" % [h_seed, m["home"]]
	
	var h_team = LeagueManager._get_team_by_name(m["home"])
	var h_color = h_team.color_primary.lightened(0.2) if h_team else Color(0.8, 0.8, 0.8)
	if home_win:
		l1.text = "» " + l1.text
		l1.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	elif "TBD" not in m["home"]:
		l1.add_theme_color_override("font_color", h_color)
	else:
		l1.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hb1.add_child(l1)
	
	if m.get("played", false):
		var s1 = Label.new()
		s1.text = str(m.get("home_score", 0))
		s1.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if home_win else Color(0.6, 0.6, 0.6))
		hb1.add_child(s1)
	
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 5)
	var sep_sb = StyleBoxLine.new()
	sep_sb.color = Color(1, 1, 1, 0.1)
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	vb.add_child(sep)
	
	# Away Row
	var hb2 = HBoxContainer.new()
	vb.add_child(hb2)
	var l2 = Label.new()
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var a_seed = team_seeds.get(m["away"], "?")
	if "TBD" in m["away"]: l2.text = m["away"]
	else: l2.text = "%s. %s" % [a_seed, m["away"]]

	var a_team = LeagueManager._get_team_by_name(m["away"])
	var a_color = a_team.color_primary.lightened(0.2) if a_team else Color(0.8, 0.8, 0.8)
	if away_win:
		l2.text = "» " + l2.text
		l2.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	elif "TBD" not in m["away"]:
		l2.add_theme_color_override("font_color", a_color)
	else:
		l2.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hb2.add_child(l2)
	
	if m.get("played", false):
		var s2 = Label.new()
		s2.text = str(m.get("away_score", 0))
		s2.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if away_win else Color(0.6, 0.6, 0.6))
		hb2.add_child(s2)
	
	return pnl

func _build_carousel_calendar() -> void:
	
	var scroller = ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	carousel_content.add_child(scroller)
	
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroller.add_child(list)
	
	var sched = LeagueManager.schedule
	for w in range(sched.size()):
		var week_matches = sched[w]
		var my_match = null
		for m in week_matches:
			if m["home"] == LeagueManager.player_team.name or m["away"] == LeagueManager.player_team.name:
				my_match = m
				break
				
		if my_match:
			var row_bg = PanelContainer.new()
			var r_sb = StyleBoxFlat.new()
			r_sb.bg_color = Color(0.12, 0.12, 0.18, 0.9) if w % 2 == 0 else Color(0.15, 0.15, 0.22, 0.9)
			if w == LeagueManager.current_week:
				r_sb.bg_color = Color(0.2, 0.3, 0.4, 0.9)
				r_sb.border_color = Color(0.0, 0.9, 1.0, 0.6)
				r_sb.set_border_width_all(1)
			r_sb.set_corner_radius_all(4)
			r_sb.content_margin_left = 12; r_sb.content_margin_right = 12
			r_sb.content_margin_top = 8; r_sb.content_margin_bottom = 8
			row_bg.add_theme_stylebox_override("panel", r_sb)
			
			var inner_hb = HBoxContainer.new()
			inner_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_bg.add_child(inner_hb)
			
			var w_lbl = Label.new()
			w_lbl.text = "Week %d" % (w + 1)
			w_lbl.custom_minimum_size = Vector2(100, 0)
			w_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			w_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner_hb.add_child(w_lbl)
			
			var m_lbl = Label.new()
			m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var is_home = my_match["home"] == LeagueManager.player_team.name
			var vs_name = my_match["away"] if is_home else my_match["home"]
			m_lbl.text = ("vs " if is_home else "@ ") + vs_name
			m_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if w == LeagueManager.current_week: m_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			inner_hb.add_child(m_lbl)
			
			var s_lbl = Label.new()
			s_lbl.custom_minimum_size = Vector2(100, 0)
			s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if my_match["played"]:
				var my_score = my_match["home_score"] if is_home else my_match["away_score"]
				var op_score = my_match["away_score"] if is_home else my_match["home_score"]
				if my_score > op_score:
					s_lbl.text = "W %d - %d" % [my_score, op_score]
					s_lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
				elif my_score < op_score:
					s_lbl.text = "L %d - %d" % [my_score, op_score]
					s_lbl.add_theme_color_override("font_color", Color.INDIAN_RED)
				else:
					s_lbl.text = "T %d - %d" % [my_score, op_score]
					s_lbl.add_theme_color_override("font_color", Color.WHITE)
			else:
				s_lbl.text = "- / -"
				s_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			inner_hb.add_child(s_lbl)
			
			var btn = Button.new()
			var b_sb = StyleBoxEmpty.new()
			btn.add_theme_stylebox_override("normal", b_sb)
			var h_sb = StyleBoxFlat.new()
			h_sb.bg_color = Color(1.0, 1.0, 1.0, 0.05)
			btn.add_theme_stylebox_override("hover", h_sb)
			btn.add_theme_stylebox_override("focus", h_sb)
			btn.add_theme_stylebox_override("pressed", h_sb)
			
			var week_idx: int = w
			var md: Dictionary = my_match
			btn.pressed.connect(func(): _show_matchup_preview(md, week_idx))
			row_bg.add_child(btn)
			
			list.add_child(row_bg)

func _show_player_stat_modal(p: Resource, team: Resource) -> void:
	var ovr = 0
	if "speed" in p:
		ovr = int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))

	var vbox = _build_generic_modal("#%d  %s" % [p.number, p.name], 620, 500)

	# ── Pre-compute season FG/3P percentages (used across all rows) ─────
	var games_played = p.game_log.size() if "game_log" in p else 0
	var gp_div = max(1, games_played)

	var s_fg_pct = float(p.fgm) / float(max(1, p.fga)) if p.fga > 0 else 0.0
	var s_tp_pct = float(p.tpm) / float(max(1, p.tpa)) if p.tpa > 0 else 0.0
	var s_fg_pct_str = ("%.3f" % s_fg_pct).lstrip("0") if p.fga > 0 else "-"
	if s_fg_pct_str == ".": s_fg_pct_str = ".000"
	if s_fg_pct >= 1.0: s_fg_pct_str = "1.000"
	var s_tp_pct_str = ("%.3f" % s_tp_pct).lstrip("0") if p.tpa > 0 else "-"
	if s_tp_pct_str == ".0": s_tp_pct_str = ".000"
	if s_tp_pct >= 1.0: s_tp_pct_str = "1.000"

	var stats_pnl = PanelContainer.new()
	var sp_sb = StyleBoxFlat.new()
	sp_sb.bg_color = Color(0.1, 0.1, 0.16, 0.8)
	sp_sb.border_color = Color(0.0, 0.9, 1.0, 0.4)
	sp_sb.set_border_width_all(1)
	sp_sb.set_corner_radius_all(6)
	sp_sb.content_margin_left = 16; sp_sb.content_margin_right = 16
	sp_sb.content_margin_top = 12; sp_sb.content_margin_bottom = 12
	stats_pnl.add_theme_stylebox_override("panel", sp_sb)
	vbox.add_child(stats_pnl)

	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	stats_pnl.add_child(stats_vbox)

	# Shared column layout: label col + RES col + 10 stat cols
	# New Order: PTS | REB | AST | BLK | FGM | FGA | FG% | 3PM | 3PA | 3P%
	var STAT_COLS = ["PTS", "REB", "AST", "BLK", "FGM", "FGA", "FG%", "3PM", "3PA", "3P%"]
	const LABEL_MIN_W = 90
	const RES_MIN_W = 90

	# ── Column headers ────────────────────────────────────────────────────
	var hdr_grid = GridContainer.new()
	hdr_grid.columns = 12
	hdr_grid.add_theme_constant_override("h_separation", 4)
	hdr_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_vbox.add_child(hdr_grid)

	var hdr_corner1 = Label.new()
	hdr_corner1.custom_minimum_size = Vector2(LABEL_MIN_W, 0)
	hdr_grid.add_child(hdr_corner1)
	var hdr_corner2 = Label.new()
	hdr_corner2.custom_minimum_size = Vector2(RES_MIN_W, 0)
	hdr_grid.add_child(hdr_corner2)
	
	for col_name in STAT_COLS:
		var ch = Label.new()
		ch.text = col_name
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch.add_theme_font_size_override("font_size", 13)
		ch.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		hdr_grid.add_child(ch)

	stats_vbox.add_child(HSeparator.new())

	# ── Per-game averages row (first) ─────────────────────────────────────
	var avg_grid = GridContainer.new()
	avg_grid.columns = 12
	avg_grid.add_theme_constant_override("h_separation", 4)
	avg_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_vbox.add_child(avg_grid)

	var avg_lbl = Label.new()
	avg_lbl.text = "Per Game"
	avg_lbl.custom_minimum_size = Vector2(LABEL_MIN_W, 0)
	avg_lbl.add_theme_font_size_override("font_size", 14)
	avg_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	avg_grid.add_child(avg_lbl)
	
	var avg_spacer = Control.new()
	avg_spacer.custom_minimum_size = Vector2(RES_MIN_W, 0)
	avg_grid.add_child(avg_spacer)
	
	for av_text in [
		"%.1f" % (float(p.pts) / gp_div),
		"%.1f" % (float(p.reb) / gp_div),
		"%.1f" % (float(p.ast) / gp_div),
		"%.1f" % (float(p.blk) / gp_div),
		"%.1f" % (float(p.fgm) / gp_div),
		"%.1f" % (float(p.fga) / gp_div),
		s_fg_pct_str,
		"%.1f" % (float(p.tpm) / gp_div),
		"%.1f" % (float(p.tpa) / gp_div),
		s_tp_pct_str,
	]:
		var av = Label.new()
		av.text = av_text
		av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		av.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		av.add_theme_font_size_override("font_size", 15)
		av.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
		avg_grid.add_child(av)

	var gp_note = Label.new()
	gp_note.text = "(%d game%s)" % [games_played, "" if games_played == 1 else "s"]
	gp_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gp_note.add_theme_font_size_override("font_size", 12)
	gp_note.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	stats_vbox.add_child(gp_note)

	# ── Individual game rows ──────────────────────────────────────────────
	var has_log = "game_log" in p and p.game_log.size() > 0
	if has_log:
		stats_vbox.add_child(HSeparator.new())

		var log_scroll = ScrollContainer.new()
		log_scroll.custom_minimum_size = Vector2(0, 180)
		log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		stats_vbox.add_child(log_scroll)

		var log_grid = GridContainer.new()
		log_grid.columns = 12
		log_grid.add_theme_constant_override("h_separation", 4)
		log_grid.add_theme_constant_override("v_separation", 4)
		log_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		log_scroll.add_child(log_grid)

		# Header: OPP | RES | PTS | REB | AST | BLK | FGM | FGA | FG% | 3PM | 3PA | 3P%
		for lh in ["OPP", "RES"] + STAT_COLS:
			var lbl = Label.new()
			lbl.text = lh
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if lh == "OPP":
				lbl.custom_minimum_size = Vector2(LABEL_MIN_W, 0)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			elif lh == "RES":
				lbl.custom_minimum_size = Vector2(RES_MIN_W, 0)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			log_grid.add_child(lbl)

		for g in p.game_log:
			# OPP
			var opp_lbl = Label.new()
			opp_lbl.text = "vs " + g.get("opp", "???").left(6).to_upper()
			opp_lbl.add_theme_font_size_override("font_size", 16)
			opp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opp_lbl.custom_minimum_size = Vector2(LABEL_MIN_W, 0)
			log_grid.add_child(opp_lbl)

			# RES with score
			var is_win = g.get("win", false)
			var res_lbl = Label.new()
			var t_sc = g.get("team_score", -1)
			var o_sc = g.get("opp_score", -1)
			res_lbl.text = ("%s (%d-%d)" % ["W" if is_win else "L", t_sc, o_sc]) if t_sc >= 0 else ("W" if is_win else "L")
			res_lbl.add_theme_font_size_override("font_size", 16)
			res_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if is_win else Color(1.0, 0.4, 0.4))
			res_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			res_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			res_lbl.custom_minimum_size = Vector2(RES_MIN_W, 0)
			log_grid.add_child(res_lbl)

			# PTS
			var pts_lbl = Label.new()
			pts_lbl.text = str(g.get("pts", 0))
			pts_lbl.add_theme_font_size_override("font_size", 16)
			pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pts_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			log_grid.add_child(pts_lbl)

			# REB | AST | BLK
			for stat in ["reb", "ast", "blk"]:
				var sl = Label.new()
				sl.text = str(g.get(stat, 0))
				sl.add_theme_font_size_override("font_size", 16)
				sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				log_grid.add_child(sl)

			# FGM | FGA | FG%
			var l_fgm = g.get("fgm", 0); var l_fga = g.get("fga", 0)
			var fg_pct_val = float(l_fgm) / float(max(1, l_fga)) if l_fga > 0 else 0.0
			var fg_pct_str = ("%.3f" % fg_pct_val).lstrip("0") if l_fga > 0 else "-"
			if fg_pct_str == ".": fg_pct_str = ".000"
			if fg_pct_val >= 1.0: fg_pct_str = "1.000"
			for cell_val in [str(l_fgm), str(l_fga), fg_pct_str]:
				var cl = Label.new()
				cl.text = cell_val
				cl.add_theme_font_size_override("font_size", 16)
				cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
				log_grid.add_child(cl)

			# 3PM | 3PA | 3P%
			var l_tpm = g.get("tpm", 0); var l_tpa = g.get("tpa", 0)
			var tp_pct_val = float(l_tpm) / float(max(1, l_tpa)) if l_tpa > 0 else 0.0
			var tp_pct_str = ("%.3f" % tp_pct_val).lstrip("0") if l_tpa > 0 else "-"
			if tp_pct_str == ".": tp_pct_str = ".000"
			if tp_pct_val >= 1.0: tp_pct_str = "1.000"
			for cell_val in [str(l_tpm), str(l_tpa), tp_pct_str]:
				var cl = Label.new()
				cl.text = cell_val
				cl.add_theme_font_size_override("font_size", 16)
				cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
				log_grid.add_child(cl)

		# ── Season totals row (pinned below individual games) ─────────────
		stats_vbox.add_child(HSeparator.new())

		# Headers for totals
		var tot_hdr_grid = GridContainer.new()
		tot_hdr_grid.columns = 12
		tot_hdr_grid.add_theme_constant_override("h_separation", 4)
		tot_hdr_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_vbox.add_child(tot_hdr_grid)
		
		for th in ["", "REC"] + STAT_COLS:
			var lbl = Label.new()
			lbl.text = th
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if th == "":
				lbl.custom_minimum_size = Vector2(LABEL_MIN_W, 0)
			elif th == "REC":
				lbl.custom_minimum_size = Vector2(RES_MIN_W, 0)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tot_hdr_grid.add_child(lbl)

		var totals_grid = GridContainer.new()
		totals_grid.columns = 12
		totals_grid.add_theme_constant_override("h_separation", 4)
		totals_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_vbox.add_child(totals_grid)

		var tot_lbl = Label.new()
		tot_lbl.text = "Season Totals"
		tot_lbl.custom_minimum_size = Vector2(LABEL_MIN_W, 0)
		tot_lbl.add_theme_font_size_override("font_size", 14)
		tot_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		totals_grid.add_child(tot_lbl)
		
		var rec_val = Label.new()
		rec_val.text = "%d-%d" % [team.wins, team.losses]
		rec_val.custom_minimum_size = Vector2(RES_MIN_W, 0)
		rec_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec_val.add_theme_font_size_override("font_size", 16)
		rec_val.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		totals_grid.add_child(rec_val)
		
		for sv_text in [
			str(p.pts), str(p.reb), str(p.ast), str(p.blk),
			str(p.fgm), str(p.fga), s_fg_pct_str,
			str(p.tpm), str(p.tpa), s_tp_pct_str
		]:
			var sv = Label.new()
			sv.text = sv_text
			sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sv.add_theme_font_size_override("font_size", 16)
			sv.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
			totals_grid.add_child(sv)

	# ── Attribute bars ────────────────────────────────────────────────────
	if "speed" in p:
		var attr_pnl = PanelContainer.new()
		var ap_sb = StyleBoxFlat.new()
		ap_sb.bg_color = Color(0.08, 0.08, 0.12, 0.8)
		ap_sb.border_color = Color(0.2, 0.2, 0.3, 0.6)
		ap_sb.set_border_width_all(1)
		ap_sb.set_corner_radius_all(6)
		ap_sb.content_margin_left = 16; ap_sb.content_margin_right = 16
		ap_sb.content_margin_top = 12; ap_sb.content_margin_bottom = 12
		attr_pnl.add_theme_stylebox_override("panel", ap_sb)
		vbox.add_child(attr_pnl)

		var attr_vbox = VBoxContainer.new()
		attr_vbox.add_theme_constant_override("separation", 10)
		attr_pnl.add_child(attr_vbox)

		var attr_hdr = Label.new()
		attr_hdr.text = "PLAYER ATTRIBUTES"
		attr_hdr.add_theme_font_size_override("font_size", 12)
		attr_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		attr_vbox.add_child(attr_hdr)

		var attr_grid = GridContainer.new()
		attr_grid.columns = 3
		attr_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attr_grid.add_theme_constant_override("h_separation", 20)
		attr_grid.add_theme_constant_override("v_separation", 8)
		attr_vbox.add_child(attr_grid)

		var attr_defs = [
			["OVERALL", ovr],
			["SPEED", p.speed], ["SHOOTING", p.shot], ["PASSING", p.pass_skill],
			["TACKLING", p.tackle], ["STRENGTH", p.strength], ["AGGRESSION", p.aggression]
		]
		for ad in attr_defs:
			var a_vbox = VBoxContainer.new()
			a_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			a_vbox.add_theme_constant_override("separation", 3)

			var a_hb = HBoxContainer.new()
			var a_name = Label.new()
			a_name.text = ad[0]
			a_name.add_theme_font_size_override("font_size", 11)
			a_name.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			a_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			a_hb.add_child(a_name)
			var a_val = Label.new()
			a_val.text = str(int(ad[1]))
			a_val.add_theme_font_size_override("font_size", 13)
			var av_col = Color(0.4, 0.7, 1.0)
			if ad[0] == "OVERALL":
				av_col = Color(1.0, 0.85, 0.2)
			elif ad[1] >= 80: av_col = Color(0.4, 1.0, 0.5)
			elif ad[1] <= 35: av_col = Color(1.0, 0.4, 0.4)
			a_val.add_theme_color_override("font_color", av_col)
			a_hb.add_child(a_val)
			a_vbox.add_child(a_hb)

			var bar = ProgressBar.new()
			bar.min_value = 0; bar.max_value = 99; bar.value = ad[1]
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 7)
			var bg_sb = StyleBoxFlat.new()
			bg_sb.bg_color = Color(0.05, 0.05, 0.08)
			bg_sb.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("background", bg_sb)
			var fill_sb = StyleBoxFlat.new()
			fill_sb.bg_color = av_col
			fill_sb.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("fill", fill_sb)
			a_vbox.add_child(bar)

			attr_grid.add_child(a_vbox)

func _build_generic_modal(title_text: String, w: int, h: int) -> Control:

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	
	var pnl = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	sb.border_color = Color(0.2, 0.2, 0.3, 1.0)
	sb.set_border_width_all(2); sb.set_corner_radius_all(8)
	sb.content_margin_left = 20; sb.content_margin_right = 20
	sb.content_margin_top = 20; sb.content_margin_bottom = 20
	pnl.add_theme_stylebox_override("panel", sb)
	
	pnl.custom_minimum_size = Vector2(w, h)
	center.add_child(pnl)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 15)
	pnl.add_child(vbox)
	
	var t = Label.new()
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(t)
	
	vbox.add_child(HSeparator.new())
	
	var btn_close = Button.new()
	btn_close.text = "CLOSE"
	btn_close.custom_minimum_size = Vector2(250, 60)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sm = StyleBoxFlat.new()
	sm.bg_color = Color(0.1, 0.1, 0.2, 0.6)
	sm.set_corner_radius_all(6)
	btn_close.add_theme_stylebox_override("normal", sm)
	btn_close.pressed.connect(func(): bg.queue_free())
	
	var shortcut = Shortcut.new()
	var ev = InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	shortcut.events.append(ev)
	btn_close.shortcut = shortcut
	
	pnl.tree_exited.connect(func(): pass) # cleanup logic handled by tree
	
	call_deferred("_attach_close_btn", vbox, btn_close)
	btn_close.call_deferred("grab_focus")
	
	return vbox

func _show_matchup_preview(match_data: Dictionary, week: int) -> void:
	var vbox = _build_generic_modal("WEEK %d PREVIEW" % (week + 1), 960, 560)

	var hb = HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 16)
	vbox.add_child(hb)

	var t_home = LeagueManager._get_team_by_name(match_data["home"])
	var t_away = LeagueManager._get_team_by_name(match_data["away"])
	var home_avgs = _get_team_avgs(t_home)
	var away_avgs = _get_team_avgs(t_away)
	var home_ovr  = _preview_team_ovr(t_home)
	var away_ovr  = _preview_team_ovr(t_away)

	var left = _build_team_preview_col(t_home, "HOME",
		match_data["played"] and match_data["home_score"] > match_data["away_score"],
		home_ovr)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)

	# --- Center: VS + score (if played) + OVR + stat comparison ---
	var mid = VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 6)
	mid.custom_minimum_size = Vector2(240, 0)
	hb.add_child(mid)

	var vs_lbl = Label.new()
	vs_lbl.text = "VS"
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_size_override("font_size", 28)
	vs_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	mid.add_child(vs_lbl)

	if match_data["played"]:
		var score_lbl = Label.new()
		score_lbl.text = "%d  –  %d" % [match_data["home_score"], match_data["away_score"]]
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_lbl.add_theme_font_size_override("font_size", 22)
		mid.add_child(score_lbl)

	var sep0 = HSeparator.new()
	mid.add_child(sep0)

	# OVR row
	_add_stat_compare_row(mid, home_ovr, "OVR", away_ovr, true)

	var sep1 = HSeparator.new()
	mid.add_child(sep1)

	# Per-stat rows
	var stat_keys   = ["speed", "shot", "pass_skill", "tackle", "strength", "aggression"]
	var stat_labels = ["SPD",   "SHT",  "PAS",        "TCK",    "STR",      "AGG"]
	for i in range(stat_keys.size()):
		_add_stat_compare_row(mid,
			int(home_avgs.get(stat_keys[i], 0.0)),
			stat_labels[i],
			int(away_avgs.get(stat_keys[i], 0.0)),
			false)

	var right = _build_team_preview_col(t_away, "AWAY",
		match_data["played"] and match_data["away_score"] > match_data["home_score"],
		away_ovr)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)

func _build_team_preview_col(t: Resource, subtitle: String, is_winner: bool, ovr: int = 0) -> VBoxContainer:
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)

	var sub = Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(sub)

	var logo = TextureRect.new()
	logo.texture = t.logo
	logo.custom_minimum_size = Vector2(220, 220)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(logo)

	var n_lbl = Label.new()
	n_lbl.text = t.name
	n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_lbl.add_theme_font_size_override("font_size", 22)
	if is_winner:
		n_lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	elif t == LeagueManager.player_team:
		n_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb.add_child(n_lbl)

	# OVR badge
	if ovr > 0:
		var ovr_lbl = Label.new()
		ovr_lbl.text = "OVR  %d" % ovr
		ovr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ovr_lbl.add_theme_font_size_override("font_size", 18)
		ovr_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		vb.add_child(ovr_lbl)

	var r_lbl = Label.new()
	r_lbl.text = "%d-%d" % [t.wins, t.losses]
	r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(r_lbl)
	
	var h_sep = HSeparator.new()
	h_sep.add_theme_constant_override("separation", 15)
	vb.add_child(h_sep)
	
	# Tabular Player Stats
	var stat_grid = GridContainer.new()
	stat_grid.columns = 5
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_grid.add_theme_constant_override("h_separation", 15)
	stat_grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(stat_grid)
	
	var headers = ["NAME", "PTS", "REB", "AST", "BLK"]
	for h in headers:
		var hl = Label.new()
		hl.text = h
		hl.add_theme_font_size_override("font_size", 15)
		hl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if h != "NAME": hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_grid.add_child(hl)
		
	var players = t.roster.duplicate()
	
	var max_pts = 0
	var max_reb = 0
	var max_ast = 0
	var max_blk = 0
	for p in players:
		var pts = 0; var reb = 0; var ast = 0; var blk = 0
		if "game_log" in p and p.game_log.size() > 0:
			var g = p.game_log.back()
			pts = g.get("pts", 0)
			reb = g.get("reb", 0)
			ast = g.get("ast", 0)
			blk = g.get("blk", 0)
		if pts > max_pts: max_pts = pts
		if reb > max_reb: max_reb = reb
		if ast > max_ast: max_ast = ast
		if blk > max_blk: max_blk = blk
	
	for p in players:
		var nl = Label.new()
		var p_name = p.name.split(" ")
		nl.text = p_name[p_name.size() - 1].left(8) if p_name.size() > 0 else p.name.left(8)
		nl.add_theme_font_size_override("font_size", 17)
		nl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_grid.add_child(nl)
		
		var pts = 0; var reb = 0; var ast = 0; var blk = 0
		if "game_log" in p and p.game_log.size() > 0:
			var g = p.game_log.back()
			pts = g.get("pts", 0)
			reb = g.get("reb", 0)
			ast = g.get("ast", 0)
			blk = g.get("blk", 0)
			
		# PTS
		var s_pts = Label.new() 
		s_pts.text = str(pts)
		s_pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_pts.add_theme_font_size_override("font_size", 18)
		if pts > 0 and pts == max_pts: s_pts.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stat_grid.add_child(s_pts)
		
		# REB
		var s_reb = Label.new() 
		s_reb.text = str(reb)
		s_reb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_reb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_reb.add_theme_font_size_override("font_size", 18)
		if reb > 0 and reb == max_reb: s_reb.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stat_grid.add_child(s_reb)
		
		# AST
		var s_ast = Label.new() 
		s_ast.text = str(ast)
		s_ast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_ast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_ast.add_theme_font_size_override("font_size", 18)
		if ast > 0 and ast == max_ast: s_ast.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stat_grid.add_child(s_ast)
		
		# BLK
		var s_blk = Label.new() 
		s_blk.text = str(blk)
		s_blk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_blk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_blk.add_theme_font_size_override("font_size", 18)
		if blk > 0 and blk == max_blk: s_blk.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stat_grid.add_child(s_blk)
		
		
	return vb

func _preview_team_ovr(t: Resource) -> int:
	if not t or t.roster.is_empty(): return 0
	var total = 0.0
	for p in t.roster:
		total += (p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0
	return int(round(total / t.roster.size()))

func _get_team_avgs(t: Resource) -> Dictionary:
	var zero = {"speed": 0.0, "shot": 0.0, "pass_skill": 0.0, "tackle": 0.0, "strength": 0.0, "aggression": 0.0}
	if not t or t.roster.is_empty(): return zero
	var totals = zero.duplicate()
	for p in t.roster:
		for k in totals:
			var v = p.get(k)
			totals[k] += float(v) if v != null else 0.0
	var n = float(t.roster.size())
	for k in totals: totals[k] /= n
	return totals

func _add_stat_compare_row(parent: VBoxContainer, home_val: int, label: String, away_val: int, is_ovr: bool) -> void:
	const WIN_C  = Color(0.2, 1.0, 0.45)
	const LOSE_C = Color(0.45, 0.45, 0.55)
	const TIE_C  = Color(0.7, 0.7, 0.8)
	var fs = 18 if is_ovr else 15

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	var h_lbl = Label.new()
	h_lbl.text = str(home_val)
	h_lbl.custom_minimum_size.x = 32
	h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_lbl.add_theme_font_size_override("font_size", fs)
	h_lbl.add_theme_color_override("font_color",
		WIN_C if home_val > away_val else (LOSE_C if home_val < away_val else TIE_C))
	row.add_child(h_lbl)

	var h_arr = Label.new()
	h_arr.text = "◀" if home_val > away_val else "  "
	h_arr.add_theme_font_size_override("font_size", 11)
	h_arr.add_theme_color_override("font_color", WIN_C)
	h_arr.custom_minimum_size.x = 12
	row.add_child(h_arr)

	var s_lbl = Label.new()
	s_lbl.text = label
	s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_lbl.custom_minimum_size.x = 52
	s_lbl.add_theme_font_size_override("font_size", 12 if not is_ovr else 15)
	s_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0) if is_ovr else Color(0.55, 0.55, 0.65))
	row.add_child(s_lbl)

	var a_arr = Label.new()
	a_arr.text = "▶" if away_val > home_val else "  "
	a_arr.add_theme_font_size_override("font_size", 11)
	a_arr.add_theme_color_override("font_color", WIN_C)
	a_arr.custom_minimum_size.x = 12
	row.add_child(a_arr)

	var a_lbl = Label.new()
	a_lbl.text = str(away_val)
	a_lbl.custom_minimum_size.x = 32
	a_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_lbl.add_theme_font_size_override("font_size", fs)
	a_lbl.add_theme_color_override("font_color",
		WIN_C if away_val > home_val else (LOSE_C if away_val < home_val else TIE_C))
	row.add_child(a_lbl)

func _get_p_rating(p: Resource) -> int:
	if "speed" in p:
		return int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))
	return 0

func _attach_close_btn(parent: VBoxContainer, btn: Button):
	parent.add_child(btn)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_main_menu_pressed()

func _on_free_agents_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/free_agent_market.tscn")

func _fmt_funds(amount: int) -> String:
	var s = str(amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
