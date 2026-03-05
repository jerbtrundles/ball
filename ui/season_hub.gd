extends Control

@onready var bg: ColorRect = $ColorRect

var ticker_scroll_node: ScrollContainer = null
var ticker_content: Control = null
var ticker_pos: float = 0.0

var carousel_index: int = 0
var carousel_slides: Array[Callable] = []
var carousel_tabs: Array[Button] = []
var carousel_content: PanelContainer = null

func _process(delta: float) -> void:
	if ticker_scroll_node and ticker_content:
		ticker_pos += 80.0 * delta
		var max_w = ticker_content.size.x / 3.0
		if max_w > 0:
			if ticker_pos > max_w:
				ticker_pos -= max_w
			ticker_scroll_node.scroll_horizontal = int(ticker_pos)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Clear previous dynamically added UI elements to prevent stacking
	for c in get_children():
		if c != bg:
			c.queue_free()
		
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
	var player_div_name = LeagueManager.get_player_division_name()
	if LeagueManager.is_postseason:
		var pw = min(LeagueManager.current_week + 1, LeagueManager.playoff_schedule.size())
		var rd = "QUARTERFINALS"
		if pw == 2: rd = "SEMIFINALS"
		elif pw == 3: rd = "CHAMPIONSHIP"
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
	rec_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold
	left_vbox.add_child(rec_lbl)
	
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
	roster_vbox.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	
	for p in team.roster:
		var p_pnl = _create_player_row(p)
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
			{"name": "PTS", "func": func(): _build_carousel_stats("PTS", "pts")},
			{"name": "REB", "func": func(): _build_carousel_stats("REB", "reb")},
			{"name": "AST", "func": func(): _build_carousel_stats("AST", "ast")},
			{"name": "BLK", "func": func(): _build_carousel_stats("BLK", "blk")}
		]
	else:
		slide_configs = [
			{"name": "STANDINGS", "func": _build_carousel_standings},
			{"name": "CALENDAR", "func": _build_carousel_calendar},
			{"name": "PTS", "func": func(): _build_carousel_stats("PTS", "pts")},
			{"name": "REB", "func": func(): _build_carousel_stats("REB", "reb")},
			{"name": "AST", "func": func(): _build_carousel_stats("AST", "ast")},
			{"name": "BLK", "func": func(): _build_carousel_stats("BLK", "blk")}
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
	var champ_name = LeagueManager.get_champion_name()
	
	if LeagueManager.is_postseason and champ_name != "":
		btn_play.text = "VIEW SEASON WRAP-UP"
		btn_play.pressed.connect(func():
			_show_season_wrapup(champ_name)
		)
	else:
		var opp = LeagueManager.get_next_opponent()
		if opp:
			btn_play.text = "PLAY NEXT MATCH (vs %s)" % opp.name
			btn_play.pressed.connect(_on_play_next_pressed)
		else:
			btn_play.text = "ELIMINATED"
			btn_play.disabled = true
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.9)
	sb.border_color = col.lightened(0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	btn_play.add_theme_stylebox_override("normal", sb)
	btn_play.add_theme_stylebox_override("disabled", sb)
	
	var sb_h = sb.duplicate()
	sb_h.bg_color = col
	btn_play.add_theme_stylebox_override("hover", sb_h)
	
	var sb_p = sb.duplicate()
	sb_p.bg_color = col.darkened(0.3)
	btn_play.add_theme_stylebox_override("pressed", sb_p)
	
	btn_play.add_theme_font_size_override("font_size", 28)
	btn_play.add_theme_color_override("font_color", Color.WHITE)
	right_vbox.add_child(btn_play)
	
	# Simulate Match Button
	var btn_sim = Button.new()
	btn_sim.text = "SIMULATE MATCH"
	
	var sim_sb = StyleBoxFlat.new()
	sim_sb.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	sim_sb.border_color = Color(0.4, 0.4, 0.6)
	sim_sb.set_border_width_all(2)
	sim_sb.set_corner_radius_all(8)
	sim_sb.content_margin_top = 15
	sim_sb.content_margin_bottom = 15
	btn_sim.add_theme_stylebox_override("normal", sim_sb)
	
	var sim_sb_h = sim_sb.duplicate()
	sim_sb_h.bg_color = Color(0.2, 0.2, 0.35, 1.0)
	btn_sim.add_theme_stylebox_override("hover", sim_sb_h)
	
	var sim_sb_p = sim_sb.duplicate()
	sim_sb_p.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	btn_sim.add_theme_stylebox_override("pressed", sim_sb_p)
	
	btn_sim.add_theme_font_size_override("font_size", 24)
	btn_sim.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	btn_sim.pressed.connect(_on_simulate_pressed)
	if LeagueManager.is_postseason:
		if champ_name != "":
			btn_sim.visible = false
		elif LeagueManager.get_next_opponent() == null:
			btn_sim.text = "SIMULATE ROUND"
	right_vbox.add_child(btn_sim)
	
	pnl_actions_group = [] # Keep track of buttons to disable during loading/sims
	pnl_actions_group.append(btn_play)
	pnl_actions_group.append(btn_sim)
	# Quit Button
	var btn_main = Button.new()
	btn_main.text = "QUIT TO MAIN MENU"
	_style_side_button(btn_main)
	btn_main.pressed.connect(_on_main_menu_pressed)
	right_vbox.add_child(btn_main)
	
	# --- TICKER ---
	var ticker_bg = ColorRect.new()
	ticker_bg.color = Color(0, 0, 0, 0.6)
	ticker_bg.custom_minimum_size = Vector2(0, 40)
	ticker_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ticker_bg.set_anchor(SIDE_TOP, 1.0)
	ticker_bg.set_anchor(SIDE_BOTTOM, 1.0)
	ticker_bg.set_offset(SIDE_TOP, -40)
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
	
	var ts = ScrollContainer.new()
	ts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ts.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ts.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	ts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker_hbox.add_child(ts)
	
	var thb = HBoxContainer.new()
	thb.add_theme_constant_override("separation", 50)
	ts.add_child(thb)
	
	var active_sched = LeagueManager.playoff_schedule if LeagueManager.is_postseason else LeagueManager.schedule
	var match_nodes = []
	
	if LeagueManager.current_week > 0:
		var prev_matches = active_sched[LeagueManager.current_week - 1]
		var curr_matches = active_sched[LeagueManager.current_week] if LeagueManager.current_week < active_sched.size() else []
		
		for m in prev_matches:
			if m.get("played", false):
				match_nodes.append(m)
				
		for m in curr_matches:
			if not m.get("played", false):
				match_nodes.append(m)
	else:
		if active_sched.size() > 0:
			for m in active_sched[0]:
				if not m.get("played", false):
					match_nodes.append(m)
				
	if match_nodes.is_empty():
		var l = Label.new()
		l.text = "+++ PRE-SEASON WARMUPS UNDERWAY +++"
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		thb.add_child(l)
		ticker_content = l
	else:
		# Division badge colors: Bronze=amber, Silver=silver-blue, Gold=gold
		var div_badge_colors = {
			"Bronze": Color(0.8, 0.5, 0.1),
			"Silver": Color(0.7, 0.8, 1.0),
			"Gold":   Color(1.0, 0.85, 0.1)
		}
		for copy in range(3):
			for m in match_nodes:
				var m_hb = HBoxContainer.new()
				m_hb.add_theme_constant_override("separation", 8)
				
				# --- Division badge ---
				var div_name = m.get("div", "")
				if div_name != "":
					var badge = Label.new()
					badge.text = "[%s]" % div_name.to_upper()
					badge.add_theme_font_size_override("font_size", 14)
					var badge_col = div_badge_colors.get(div_name, Color(0.6, 0.6, 0.7))
					badge.add_theme_color_override("font_color", badge_col)
					badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					m_hb.add_child(badge)
				
				if m.get("played", false):
					var a_lbl = Label.new()
					a_lbl.text = "%s %d" % [m["away"], m["away_score"]]
					a_lbl.add_theme_font_size_override("font_size", 20)
					if m["away_score"] > m["home_score"]:
						a_lbl.add_theme_color_override("font_color", Color.YELLOW)
					else:
						a_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
					m_hb.add_child(a_lbl)
					
					var dash = Label.new()
					dash.text = "-"
					dash.add_theme_font_size_override("font_size", 20)
					dash.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
					m_hb.add_child(dash)
					
					var h_lbl = Label.new()
					h_lbl.text = "%d %s" % [m["home_score"], m["home"]]
					h_lbl.add_theme_font_size_override("font_size", 20)
					if m["home_score"] > m["away_score"]:
						h_lbl.add_theme_color_override("font_color", Color.YELLOW)
					else:
						h_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
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
						p_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
						m_hb.add_child(p_lbl)
				else:
					var a_lbl = Label.new()
					var t_away = LeagueManager._get_team_by_name(m["away"])
					var t_home = LeagueManager._get_team_by_name(m["home"])
					
					var a_name = m["away"]
					if t_away: a_name += " (%d-%d)" % [t_away.wins, t_away.losses]
					a_lbl.text = a_name
					a_lbl.add_theme_font_size_override("font_size", 20)
					a_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
					m_hb.add_child(a_lbl)
					
					var dash = Label.new()
					dash.text = " @ "
					dash.add_theme_font_size_override("font_size", 20)
					dash.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
					m_hb.add_child(dash)
					
					var h_lbl = Label.new()
					var h_name = m["home"]
					if t_home: h_name += " (%d-%d)" % [t_home.wins, t_home.losses]
					h_lbl.text = h_name
					h_lbl.add_theme_font_size_override("font_size", 20)
					h_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
					m_hb.add_child(h_lbl)
					
				thb.add_child(m_hb)
				
				if copy < 2 or m != match_nodes.back():
					var dot = Label.new()
					dot.text = "•"
					dot.add_theme_font_size_override("font_size", 20)
					dot.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
					thb.add_child(dot)
					
		ticker_content = thb
	
	ticker_scroll_node = ts
	ticker_pos = 0.0
	
	btn_play.grab_focus()

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
	var scroller = ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	carousel_content.add_child(scroller)
	
	var mini_vbox = VBoxContainer.new()
	mini_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mini_vbox.add_theme_constant_override("separation", 10)
	scroller.add_child(mini_vbox)
	
	var len_lbl = Label.new()
	len_lbl.text = "STANDINGS — %d GAME SEASON" % max(1, LeagueManager.schedule.size())
	len_lbl.add_theme_font_size_override("font_size", 14)
	len_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	len_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mini_vbox.add_child(len_lbl)
	
	# Division display order: Gold (top) → Silver → Bronze (bottom)
	var div_display_order = LeagueManager.divisions.duplicate()
	div_display_order.reverse() # Show highest tier first
	
	var div_header_colors = {
		"Gold":   Color(1.0,  0.85, 0.1),
		"Silver": Color(0.75, 0.85, 1.0),
		"Bronze": Color(0.8,  0.5,  0.15)
	}
	var div_icons = {"Gold": "🥇", "Silver": "🥈", "Bronze": "🥉"}
	
	for div in div_display_order:
		var div_name = div["name"]
		var div_col  = div_header_colors.get(div_name, Color(0.6, 0.6, 0.7))
		var div_icon = div_icons.get(div_name, "")
		
		# --- Division header ---
		var dh_pnl = PanelContainer.new()
		var dh_sb  = StyleBoxFlat.new()
		dh_sb.bg_color    = Color(div_col.r * 0.15, div_col.g * 0.15, div_col.b * 0.15, 0.9)
		dh_sb.border_color = div_col
		dh_sb.set_border_width(SIDE_LEFT, 4)
		dh_sb.set_border_width(SIDE_BOTTOM, 1)
		dh_sb.set_corner_radius_all(4)
		dh_sb.content_margin_left = 12; dh_sb.content_margin_right = 12
		dh_sb.content_margin_top  = 6;  dh_sb.content_margin_bottom = 6
		dh_pnl.add_theme_stylebox_override("panel", dh_sb)
		mini_vbox.add_child(dh_pnl)
		
		var dh_lbl = Label.new()
		dh_lbl.text = "%s %s DIVISION" % [div_icon, div_name.to_upper()]
		dh_lbl.add_theme_font_size_override("font_size", 16)
		dh_lbl.add_theme_color_override("font_color", div_col)
		dh_pnl.add_child(dh_lbl)
		
		# Column headers
		var head_hb = HBoxContainer.new()
		head_hb.add_theme_constant_override("separation", 4)
		var col_defs = [["RK",30],["TEAM",-1],["W-L",55],["PCT",50],["PF",45],["PA",45],["+/-",40],["STRK",40]]
		for cd in col_defs:
			var hl = Label.new()
			hl.text = cd[0]
			if cd[1] > 0: hl.custom_minimum_size = Vector2(cd[1], 0)
			else: hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			hl.add_theme_font_size_override("font_size", 12)
			head_hb.add_child(hl)
		var h_margin = MarginContainer.new()
		h_margin.add_theme_constant_override("margin_left", 12)
		h_margin.add_theme_constant_override("margin_right", 12)
		h_margin.add_child(head_hb)
		mini_vbox.add_child(h_margin)
		
		# Sort teams within this division
		var div_teams = div["teams"].duplicate()
		div_teams.sort_custom(func(a,b): return a.wins > b.wins)
		var n = div_teams.size()
		
		for i in range(n):
			var t = div_teams[i]
			var is_player = (t == LeagueManager.player_team)
			var is_promo  = (i == 0 and div_name != "Gold")   # Top of non-Gold = promo zone
			var is_relgt  = (i == n - 1 and div_name != "Bronze") # Bottom of non-Bronze = relegate zone
			
			var row_bg = PanelContainer.new()
			var r_sb   = StyleBoxFlat.new()
			r_sb.bg_color = Color(0.12, 0.12, 0.18, 0.9) if i % 2 == 0 else Color(0.15, 0.15, 0.22, 0.9)
			if is_player:
				r_sb.bg_color    = Color(0.2,  0.3,  0.4,  0.9)
				r_sb.border_color = Color(0.0,  0.9,  1.0,  0.6)
				r_sb.set_border_width_all(1)
			elif is_promo:
				r_sb.border_color = Color(0.2, 0.9, 0.2, 0.5)
				r_sb.set_border_width(SIDE_LEFT, 3)
			elif is_relgt:
				r_sb.border_color = Color(0.9, 0.2, 0.2, 0.5)
				r_sb.set_border_width(SIDE_LEFT, 3)
			r_sb.set_corner_radius_all(4)
			r_sb.content_margin_left = 12; r_sb.content_margin_right = 12
			r_sb.content_margin_top  = 7;  r_sb.content_margin_bottom = 7
			row_bg.add_theme_stylebox_override("panel", r_sb)
			
			var hb = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 4)
			row_bg.add_child(hb)
			
			var rank = Label.new()
			rank.text = str(i + 1) + "."
			rank.custom_minimum_size = Vector2(30, 0)
			rank.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			hb.add_child(rank)
			
			var nam = Label.new()
			nam.text = t.name
			nam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if is_player: nam.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			if is_promo:  nam.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			if is_relgt:  nam.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			hb.add_child(nam)
			
			# Zone indicator appended to name
			if is_promo and not is_player:
				var zone = Label.new()
				zone.text = " ↑"
				zone.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
				zone.add_theme_font_size_override("font_size", 14)
				hb.add_child(zone)
			elif is_relgt and not is_player:
				var zone = Label.new()
				zone.text = " ↓"
				zone.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				zone.add_theme_font_size_override("font_size", 14)
				hb.add_child(zone)
			
			var wl = Label.new()
			wl.text = "%d-%d" % [t.wins, t.losses]
			wl.custom_minimum_size = Vector2(55, 0)
			wl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
			hb.add_child(wl)
			
			var pct_lbl = Label.new()
			var pct = float(t.wins) / float(max(1, t.wins + t.losses))
			if t.wins + t.losses == 0: pct = 0.0
			var pct_str = "%.3f" % pct
			if pct_str.begins_with("0."): pct_str = pct_str.substr(1)
			pct_lbl.text = pct_str
			pct_lbl.custom_minimum_size = Vector2(50, 0)
			pct_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			hb.add_child(pct_lbl)
			
			var pf = Label.new()
			pf.text = str(t.pf)
			pf.custom_minimum_size = Vector2(45, 0)
			pf.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			hb.add_child(pf)
			
			var pa = Label.new()
			pa.text = str(t.pa)
			pa.custom_minimum_size = Vector2(45, 0)
			pa.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
			hb.add_child(pa)
			
			var diff = Label.new()
			var p_diff = t.pf - t.pa
			diff.text = ("+" if p_diff > 0 else "") + str(p_diff)
			diff.custom_minimum_size = Vector2(40, 0)
			diff.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
			hb.add_child(diff)
			
			var strk = Label.new()
			var s_val = t.streak
			if s_val > 0:  strk.text = "W" + str(s_val)
			elif s_val < 0: strk.text = "L" + str(abs(s_val))
			else: strk.text = "-"
			strk.custom_minimum_size = Vector2(40, 0)
			strk.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6) if s_val > 0 else Color(0.9, 0.6, 0.6) if s_val < 0 else Color(0.8, 0.8, 0.8))
			hb.add_child(strk)
			
			mini_vbox.add_child(row_bg)

func _build_carousel_stats(stat_suffix: String, stat_field: String) -> void:
	
	var scroller = ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	carousel_content.add_child(scroller)
	
	var mini_vbox = VBoxContainer.new()
	mini_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mini_vbox.add_theme_constant_override("separation", 6)
	scroller.add_child(mini_vbox)
	
	var all_players = []
	for div in LeagueManager.divisions:
		for t in div["teams"]:
			for p in t.roster:
				all_players.append({"p": p, "t": t})
				
	all_players.sort_custom(func(a,b): return a["p"].get(stat_field) > b["p"].get(stat_field))
	
	for i in range(min(10, all_players.size())):
		var data = all_players[i]
		var p = data["p"]
		var t = data["t"]
		
		var row_bg = PanelContainer.new()
		var r_sb = StyleBoxFlat.new()
		r_sb.bg_color = Color(0.12, 0.12, 0.18, 0.9) if i % 2 == 0 else Color(0.15, 0.15, 0.22, 0.9)
		if t == LeagueManager.player_team:
			r_sb.bg_color = Color(0.2, 0.3, 0.4, 0.9)
			r_sb.border_color = Color(0.0, 0.9, 1.0, 0.6)
			r_sb.set_border_width_all(1)
		r_sb.set_corner_radius_all(4)
		r_sb.content_margin_left = 12; r_sb.content_margin_right = 12
		r_sb.content_margin_top = 8; r_sb.content_margin_bottom = 8
		row_bg.add_theme_stylebox_override("panel", r_sb)
		
		var hb = HBoxContainer.new()
		row_bg.add_child(hb)
		
		var rank = Label.new()
		rank.text = str(i+1) + "."
		rank.custom_minimum_size = Vector2(30, 0)
		rank.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		hb.add_child(rank)
		
		var nam = Label.new()
		nam.text = p.name
		nam.custom_minimum_size = Vector2(140, 0)
		nam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if t == LeagueManager.player_team: nam.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		hb.add_child(nam)
		
		var team_lbl = Label.new()
		team_lbl.text = t.name
		team_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		team_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team_lbl.add_theme_color_override("font_color", t.color_primary)
		hb.add_child(team_lbl)
		
		var stat = Label.new()
		stat.text = "%d %s" % [p.get(stat_field), stat_suffix]
		stat.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		hb.add_child(stat)
		
		mini_vbox.add_child(row_bg)

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

func _create_player_row(p: Resource) -> Control:
	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(320, 80)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	sb.border_color = Color(0.3, 0.3, 0.4, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pnl.add_theme_stylebox_override("panel", sb)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	pnl.add_child(main_vbox)
	
	# Top HBox for Name and OVR
	var hb = HBoxContainer.new()
	main_vbox.add_child(hb)
	
	var n_lbl = Label.new()
	n_lbl.text = p.name
	n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n_lbl.add_theme_font_size_override("font_size", 20)
	hb.add_child(n_lbl)
	
	var o_lbl = Label.new()
	if "speed" in p:
		var po = round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0)
		o_lbl.text = "OVR " + str(int(po))
		o_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		o_lbl.add_theme_font_size_override("font_size", 20)
	else:
		o_lbl.text = "??"
	hb.add_child(o_lbl)
	
	# Bottom Grid for Individual Stats
	if "speed" in p:
		var stat_grid = GridContainer.new()
		stat_grid.columns = 6
		stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_grid.add_theme_constant_override("h_separation", 15)
		main_vbox.add_child(stat_grid)
		
		var stats = ["speed", "shot", "pass_skill", "tackle", "strength", "aggression"]
		var labels = ["SPD", "SHT", "PAS", "TCK", "STR", "AGG"]
		
		for i in range(stats.size()):
			var s_val = p.get(stats[i])
			var s_vbox = VBoxContainer.new()
			s_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_vbox.add_theme_constant_override("separation", 2)
			
			var s_lbl = Label.new()
			s_lbl.text = labels[i]
			s_lbl.add_theme_font_size_override("font_size", 12)
			s_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_vbox.add_child(s_lbl)
			
			var v_lbl = Label.new()
			v_lbl.text = str(int(s_val))
			v_lbl.add_theme_font_size_override("font_size", 16)
			
			# Color code based on tier (0-10)
			var c = Color.WHITE
			if s_val >= 8: c = Color.GREEN_YELLOW
			elif s_val >= 5: c = Color.WHITE
			else: c = Color(1.0, 0.5, 0.5)
			
			v_lbl.add_theme_color_override("font_color", c)
			v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_vbox.add_child(v_lbl)
			
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

func _show_round_summary(played_matches: Array) -> void:
	var vbox = _build_generic_modal("PLAYOFF ROUND SIMULATED", 600, 450)
	
	var scr = ScrollContainer.new()
	scr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(scr)
	
	var rbox = VBoxContainer.new()
	rbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rbox.add_theme_constant_override("separation", 15)
	scr.add_child(rbox)
	
	for m in played_matches:
		if not m["played"]: continue
		
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
	var vbox = _build_generic_modal("SEASON WRAP-UP", 750, 500)
	
	var scr = ScrollContainer.new()
	scr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(scr)
	
	var rbox = VBoxContainer.new()
	rbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rbox.add_theme_constant_override("separation", 20)
	scr.add_child(rbox)
	
	# Champion Banner
	var champ = LeagueManager._get_team_by_name(champ_name)
	if champ:
		var c_pnl = PanelContainer.new()
		var c_sb = StyleBoxFlat.new()
		c_sb.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		c_sb.border_color = Color(0.9, 0.8, 0.0, 0.8)
		c_sb.set_border_width_all(2)
		c_sb.set_corner_radius_all(8)
		c_sb.content_margin_top = 20; c_sb.content_margin_bottom = 20
		c_pnl.add_theme_stylebox_override("panel", c_sb)
		rbox.add_child(c_pnl)
		
		var c_hb = HBoxContainer.new()
		c_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		c_hb.add_theme_constant_override("separation", 30)
		c_pnl.add_child(c_hb)
		
		if champ.logo:
			var logo = TextureRect.new()
			logo.texture = champ.logo
			logo.custom_minimum_size = Vector2(80, 80)
			logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			c_hb.add_child(logo)
			
		var c_lbl = Label.new()
		c_lbl.text = "LEAGUE CHAMPIONS\n%s" % champ.name.to_upper()
		c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_lbl.add_theme_font_size_override("font_size", 28)
		c_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		c_hb.add_child(c_lbl)
		
	# Analyze promotions/relegations silently
	var moves = []
	var sim_divs = LeagueManager.divisions
	
	for i in range(1, sim_divs.size()):
		var div = sim_divs[i]
		if div["teams"].size() > 0:
			var div_teams = div["teams"].duplicate()
			div_teams.sort_custom(func(a,b): return a.wins > b.wins)
			var lowest = div_teams[-1]
			if lowest.name != champ_name:
				moves.append({"name": lowest.name, "type": "RELEGATED", "color": Color(0.9, 0.3, 0.3), "from": div["name"], "to": sim_divs[i-1]["name"]})
				
	var champ_div_idx = -1
	for i in range(sim_divs.size()):
		if champ in sim_divs[i]["teams"]:
			champ_div_idx = i
			break
			
	if champ_div_idx >= 0 and champ_div_idx < sim_divs.size() - 1:
		moves.append({"name": champ.name, "type": "PROMOTED", "color": Color(0.3, 0.9, 0.3), "from": sim_divs[champ_div_idx]["name"], "to": sim_divs[champ_div_idx+1]["name"]})

	if moves.size() > 0:
		var m_lbl = Label.new()
		m_lbl.text = "LEAGUE TIER ADJUSTMENTS"
		m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m_lbl.add_theme_font_size_override("font_size", 16)
		m_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		rbox.add_child(m_lbl)
		
		for m in moves:
			var m_pnl = PanelContainer.new()
			var m_sb = StyleBoxFlat.new()
			m_sb.bg_color = Color(0.12, 0.12, 0.18, 0.9)
			m_sb.border_color = m["color"]
			m_sb.set_border_width(SIDE_LEFT, 4)
			m_sb.set_corner_radius_all(4)
			m_sb.content_margin_left = 15; m_sb.content_margin_right = 15
			m_sb.content_margin_top = 10; m_sb.content_margin_bottom = 10
			m_pnl.add_theme_stylebox_override("panel", m_sb)
			rbox.add_child(m_pnl)
			
			var m_hb = HBoxContainer.new()
			m_pnl.add_child(m_hb)
			
			var n_lbl = Label.new()
			n_lbl.text = m["name"]
			n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n_lbl.add_theme_font_size_override("font_size", 20)
			m_hb.add_child(n_lbl)
			
			var t_lbl = Label.new()
			t_lbl.text = "%s TO %s" % [m["type"], m["to"].to_upper()]
			t_lbl.add_theme_font_size_override("font_size", 16)
			t_lbl.add_theme_color_override("font_color", m["color"])
			t_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			m_hb.add_child(t_lbl)
			
	var setup_proceed = func():
		var close_btn = vbox.get_child(vbox.get_child_count() - 1) as Button
		if close_btn:
			close_btn.text = "START NEXT SEASON"
			var conns = close_btn.get_signal_connection_list("pressed")
			for c in conns: close_btn.pressed.disconnect(c["callable"])
			
			close_btn.pressed.connect(func():
				LeagueManager.process_season_rollover(champ_name)
				get_tree().change_scene_to_file("res://ui/season_hub.tscn")
			)
			
	Callable(setup_proceed).call_deferred()

func _build_carousel_bracket() -> void:
	
	var scroller = ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel_content.add_child(scroller)
	
	var bracket_hbox = HBoxContainer.new()
	bracket_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bracket_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bracket_hbox.add_theme_constant_override("separation", 20)
	scroller.add_child(bracket_hbox)
	
	var qf_vbox = VBoxContainer.new()
	qf_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qf_vbox.add_theme_constant_override("separation", 10)
	bracket_hbox.add_child(qf_vbox)
	
	var sf_vbox = VBoxContainer.new()
	sf_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sf_vbox.add_theme_constant_override("separation", 60)
	bracket_hbox.add_child(sf_vbox)
	
	var champ_vbox = VBoxContainer.new()
	champ_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bracket_hbox.add_child(champ_vbox)
	
	var sched = LeagueManager.playoff_schedule
	if sched.size() == 3:
		for m in sched[0]:
			qf_vbox.add_child(_create_bracket_match_panel(m))
		for m in sched[1]:
			sf_vbox.add_child(_create_bracket_match_panel(m))
		for m in sched[2]:
			champ_vbox.add_child(_create_bracket_match_panel(m))
			
func _create_bracket_match_panel(m: Dictionary) -> Control:
	var pnl = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	if m["home"] == LeagueManager.player_team.name or m["away"] == LeagueManager.player_team.name:
		sb.bg_color = Color(0.2, 0.3, 0.4, 0.9)
		sb.border_color = Color(0.0, 0.9, 1.0, 0.6)
		sb.set_border_width_all(1)
		
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	pnl.add_theme_stylebox_override("panel", sb)
	
	var vb = VBoxContainer.new()
	pnl.add_child(vb)
	
	var l1 = Label.new()
	l1.text = m["home"]
	var home_win = m.get("played", false) and m.get("home_score", 0) > m.get("away_score", 0)
	var away_win = m.get("played", false) and m.get("away_score", 0) > m.get("home_score", 0)
	
	if home_win:
		l1.text = "» " + l1.text
		l1.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	elif "TBD" not in l1.text:
		l1.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	else:
		l1.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vb.add_child(l1)
	
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	vb.add_child(sep)
	
	var l2 = Label.new()
	l2.text = m["away"]
	if away_win:
		l2.text = "» " + l2.text
		l2.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	elif "TBD" not in l2.text:
		l2.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	else:
		l2.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vb.add_child(l2)
	
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
	var vbox = _build_generic_modal("WEEK %d PREVIEW" % (week + 1), 700, 500)
	
	var hb = HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 20)
	vbox.add_child(hb)
	
	var t_home = LeagueManager._get_team_by_name(match_data["home"])
	var t_away = LeagueManager._get_team_by_name(match_data["away"])
	
	var left = _build_team_preview_col(t_home, "HOME", match_data["played"] and match_data["home_score"] > match_data["away_score"])
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	
	var mid = VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.custom_minimum_size = Vector2(80, 0)
	hb.add_child(mid)
	
	var vs_lbl = Label.new()
	vs_lbl.text = "VS"
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_size_override("font_size", 36)
	vs_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	mid.add_child(vs_lbl)
	
	if match_data["played"]:
		var score_lbl = Label.new()
		score_lbl.text = "%d - %d" % [match_data["home_score"], match_data["away_score"]]
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_lbl.add_theme_font_size_override("font_size", 28)
		mid.add_child(score_lbl)
	
	var right = _build_team_preview_col(t_away, "AWAY", match_data["played"] and match_data["away_score"] > match_data["home_score"])
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)

func _build_team_preview_col(t: Resource, subtitle: String, is_winner: bool) -> VBoxContainer:
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 5)
	
	var sub = Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(sub)
	
	var logo = TextureRect.new()
	logo.texture = t.logo
	logo.custom_minimum_size = Vector2(300, 300)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(logo)
	
	var n_lbl = Label.new()
	n_lbl.text = t.name
	n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_lbl.add_theme_font_size_override("font_size", 24)
	if is_winner:
		n_lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	elif t == LeagueManager.player_team:
		n_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb.add_child(n_lbl)
	
	var r_lbl = Label.new()
	r_lbl.text = "%d-%d" % [t.wins, t.losses]
	r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	
	var headers = ["NAME", "PTS", "REB", "AST", "STL"]
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
	var max_stl = 0
	for p in players:
		var pts = p.get("pts") if "pts" in p else 0
		var reb = p.get("reb") if "reb" in p else 0
		var ast = p.get("ast") if "ast" in p else 0
		var stl = p.get("stl") if "stl" in p else 0
		if pts > max_pts: max_pts = pts
		if reb > max_reb: max_reb = reb
		if ast > max_ast: max_ast = ast
		if stl > max_stl: max_stl = stl
	
	for p in players:
		var nl = Label.new()
		var p_name = p.name.split(" ")
		nl.text = p_name[p_name.size() - 1].left(8) if p_name.size() > 0 else p.name.left(8)
		nl.add_theme_font_size_override("font_size", 17)
		nl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_grid.add_child(nl)
		
		# PTS
		var pts_val = p.get("pts") if "pts" in p else 0
		var s_pts = Label.new() 
		s_pts.text = str(pts_val)
		s_pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_pts.add_theme_font_size_override("font_size", 18)
		if pts_val > 0 and pts_val == max_pts: s_pts.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stat_grid.add_child(s_pts)
		
		# REB
		var reb_val = p.get("reb") if "reb" in p else 0
		var s_reb = Label.new() 
		s_reb.text = str(reb_val)
		s_reb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_reb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_reb.add_theme_font_size_override("font_size", 18)
		if reb_val > 0 and reb_val == max_reb: s_reb.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stat_grid.add_child(s_reb)
		
		# AST
		var ast_val = p.get("ast") if "ast" in p else 0
		var s_ast = Label.new() 
		s_ast.text = str(ast_val)
		s_ast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_ast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_ast.add_theme_font_size_override("font_size", 18)
		if ast_val > 0 and ast_val == max_ast: s_ast.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stat_grid.add_child(s_ast)
		
		# STL
		var stl_val = p.get("stl") if "stl" in p else 0
		var s_stl = Label.new() 
		s_stl.text = str(stl_val)
		s_stl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_stl.add_theme_font_size_override("font_size", 18)
		if stl_val > 0 and stl_val == max_stl: s_stl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stat_grid.add_child(s_stl)
		
	return vb

func _get_p_rating(p: Resource) -> int:
	if "speed" in p:
		return int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))
	return 0

func _attach_close_btn(parent: VBoxContainer, btn: Button):
	parent.add_child(btn)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
