extends Control
## TournamentHub — graphical bracket display shown between rounds. Auto-saves after each result.

const GOLD     = Color(1.0,  0.82, 0.1)
const ORANGE   = Color(1.0,  0.50, 0.0)
const WIN_COL  = Color(0.25, 0.90, 0.35)
const LOSE_COL = Color(0.90, 0.22, 0.22)
const DIM      = Color(0.45, 0.45, 0.55)
const DARK     = Color(0.05, 0.05, 0.13, 0.95)

# ── Inner class: draws the rounded elbow connectors between bracket rounds ─────
class BracketLines extends Control:
	## connections: Array[Dictionary] — each entry has keys:
	##   pa, pb  : Vector2  exit points of the two source match cards (right-center)
	##   pc      : Vector2  entry point of the destination match card (left-center)
	##   col     : Color    line color
	var connections: Array = []

	func _draw() -> void:
		for conn in connections:
			var pa: Vector2 = conn["pa"]
			var pb: Vector2 = conn["pb"]
			var pc: Vector2 = conn["pc"]
			var col: Color  = conn["col"]
			# Midpoint x sits in the column gap, equidistant from both columns
			var mid_x: float    = (pa.x + pc.x) * 0.5
			var merge_y: float  = (pa.y + pb.y) * 0.5
			# Horizontal stubs from each match exit → midpoint column
			draw_line(pa,                        Vector2(mid_x, pa.y),     col, 2.0, true)
			draw_line(pb,                        Vector2(mid_x, pb.y),     col, 2.0, true)
			# Vertical bar connecting the two stubs
			draw_line(Vector2(mid_x, pa.y),      Vector2(mid_x, pb.y),     col, 2.0, true)
			# Horizontal line from merge point → next match entry
			draw_line(Vector2(mid_x, merge_y),   pc,                       col, 2.0, true)

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	var lm = LeagueManager
	if lm.is_tournament_active and lm.tournament_pending_advance:
		lm.advance_tournament_round()
		lm.save_tournament()
	_build_ui()
	
	var music = AudioStreamPlayer.new()
	music.stream = load("res://assets/sounds/Circuit_Breaker_Championship.mp3")
	music.bus = "Music"
	add_child(music)
	music.play()

func _build_ui() -> void:
	for c in get_children():
		if c.name != "Background":
			c.queue_free()

	var lm = LeagueManager

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",  36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top",   24)
	margin.add_theme_constant_override("margin_bottom",20)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# ── Header row ─────────────────────────────────────────────────────────
	var hdr_row = HBoxContainer.new()
	root_vbox.add_child(hdr_row)

	var btn_menu = Button.new()
	btn_menu.text = "◀ MENU"
	btn_menu.custom_minimum_size = Vector2(110, 36)
	_style_btn(btn_menu, Color(0.18, 0.18, 0.28))
	btn_menu.pressed.connect(func():
		lm.save_tournament()
		get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	hdr_row.add_child(btn_menu)

	var title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var round_names = lm.get_tournament_round_names()
	var r_idx = clampi(lm.tournament_round, 0, round_names.size() - 1)
	if lm.is_tournament_active:
		title.text = "TOURNAMENT  —  %s" % round_names[r_idx]
	else:
		title.text = "TOURNAMENT  —  FINAL RESULTS"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	hdr_row.add_child(title)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(110, 0)
	hdr_row.add_child(spacer)

	root_vbox.add_child(HSeparator.new())

	if not lm.is_tournament_active:
		_build_results_screen(root_vbox)
		return

	# ── Graphical Bracket ──────────────────────────────────────────────────
	_build_graphical_bracket(root_vbox, lm)

	# ── Play button row ────────────────────────────────────────────────────
	root_vbox.add_child(HSeparator.new())
	var play_row = HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(play_row)

	var info_lbl = Label.new()
	var player_match = lm.get_player_tournament_match()
	if player_match.is_empty():
		info_lbl.text = "You have been eliminated."
		info_lbl.add_theme_color_override("font_color", LOSE_COL)
	else:
		var ta = lm.tournament_teams[player_match[0]]
		var tb = lm.tournament_teams[player_match[1]]
		info_lbl.text = "Your match:  %s  vs  %s" % [ta.name, tb.name]
		info_lbl.add_theme_color_override("font_color", GOLD)
	info_lbl.add_theme_font_size_override("font_size", 17)
	play_row.add_child(info_lbl)

	if not player_match.is_empty():
		var btn_play = Button.new()
		btn_play.text = "PLAY MATCH"
		btn_play.custom_minimum_size = Vector2(220, 48)
		_style_btn(btn_play, ORANGE.darkened(0.2), GOLD)
		btn_play.pressed.connect(_on_play_pressed)
		play_row.add_child(btn_play)
		btn_play.grab_focus()

# ─────────────────────────────────────────────────────────────────────────────
#  GRAPHICAL BRACKET
# ─────────────────────────────────────────────────────────────────────────────
func _build_graphical_bracket(parent: Node, lm: Node) -> void:
	var n: int = lm.tournament_teams.size()
	if n <= 0:
		return

	# Count rounds (log2 of team count)
	var total_rounds: int = 0
	var tmp: int = n
	while tmp > 1:
		total_rounds += 1
		tmp >>= 1

	# Layout constants
	const CARD_W: float   = 214.0
	const CARD_H: float   = 72.0
	const COL_GAP: float  = 72.0   # column gap (where lines are drawn)
	const VERT_PAD: float = 16.0   # vertical gap between cards in the same column
	const MARGIN: float   = 12.0   # canvas margin

	var slot_h: float   = CARD_H + VERT_PAD
	var n_r0: int       = n >> 1
	var total_h: float  = float(n_r0) * slot_h
	var total_w: float  = float(total_rounds) * (CARD_W + COL_GAP) - COL_GAP

	# ── Scroll wrapper ──────────────────────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	# Fixed-size canvas (absolute child positioning)
	var canvas = Control.new()
	canvas.custom_minimum_size = Vector2(total_w + MARGIN * 2.0, total_h + MARGIN * 2.0)
	scroll.add_child(canvas)

	# Lines node drawn first so cards appear on top
	var lines_node = BracketLines.new()
	lines_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(lines_node)

	# ── Build structured match data ─────────────────────────────────────────
	var matches_data: Array = _build_matches_data(lm, total_rounds, n)

	# card_rects[r][i] = Rect2  (used to compute connector endpoints after layout)
	var card_rects: Array = []
	for r in range(total_rounds):
		card_rects.append([])

	var player_idx: int = lm.tournament_player_team_idx

	# ── Place cards ─────────────────────────────────────────────────────────
	for r in range(total_rounds):
		var n_matches: int       = n >> (r + 1)
		var match_spacing: float = slot_h * float(1 << r)   # doubles each round
		var first_center_y: float = match_spacing * 0.5     # vertically centered
		var col_x: float         = float(r) * (CARD_W + COL_GAP) + MARGIN

		for i in range(n_matches):
			var center_y: float = first_center_y + float(i) * match_spacing + MARGIN
			var card_y: float   = center_y - CARD_H * 0.5
			var rect = Rect2(col_x, card_y, CARD_W, CARD_H)
			card_rects[r].append(rect)

			var m: Dictionary = matches_data[r][i] if i < matches_data[r].size() else {}
			var card_node = _make_bracket_card(m, lm)
			card_node.position = rect.position
			card_node.size     = rect.size
			canvas.add_child(card_node)

	# ── Build connector data ─────────────────────────────────────────────────
	var connections: Array = []
	for r in range(total_rounds - 1):
		var n_next: int = n >> (r + 2)
		for j in range(n_next):
			var i_a: int = 2 * j
			var i_b: int = 2 * j + 1
			if i_a >= card_rects[r].size() or i_b >= card_rects[r].size():
				continue
			if j >= card_rects[r + 1].size():
				continue

			var ra: Rect2 = card_rects[r][i_a]
			var rb: Rect2 = card_rects[r][i_b]
			var rd: Rect2 = card_rects[r + 1][j]

			# Choose line color based on player involvement and completion
			var m_a: Dictionary = matches_data[r][i_a] if i_a < matches_data[r].size() else {}
			var m_b: Dictionary = matches_data[r][i_b] if i_b < matches_data[r].size() else {}
			var inv_a: bool = (m_a.get("team_a", -1) == player_idx or m_a.get("team_b", -1) == player_idx)
			var inv_b: bool = (m_b.get("team_a", -1) == player_idx or m_b.get("team_b", -1) == player_idx)
			var is_past: bool = (m_a.get("status", "future") == "past")

			var line_col: Color
			if inv_a or inv_b:
				line_col = GOLD
				line_col.a = 0.75 if is_past else 0.40
			else:
				line_col = Color(0.28, 0.28, 0.48, 0.50 if is_past else 0.30)

			connections.append({
				"pa":  Vector2(ra.position.x + ra.size.x,       ra.position.y + ra.size.y * 0.5),
				"pb":  Vector2(rb.position.x + rb.size.x,       rb.position.y + rb.size.y * 0.5),
				"pc":  Vector2(rd.position.x,                   rd.position.y + rd.size.y * 0.5),
				"col": line_col,
			})

	lines_node.connections = connections
	lines_node.queue_redraw()

# ── Build a structured array of match dictionaries for every round ─────────────
func _build_matches_data(lm: Node, total_rounds: int, n: int) -> Array:
	var result: Array = []
	for r in range(total_rounds):
		var round_arr: Array = []
		if r < lm.tournament_match_history.size():
			# Past round — full history available
			for m in lm.tournament_match_history[r]:
				round_arr.append({
					"team_a": m["team_a"], "team_b": m["team_b"],
					"winner": m["winner"], "status": "past",
				})
		elif r == lm.tournament_round and lm.is_tournament_active:
			# Current round (no winner yet)
			for pair in lm.tournament_bracket:
				round_arr.append({
					"team_a": pair[0], "team_b": pair[1],
					"winner": -1, "status": "current",
				})
		else:
			# Future TBD
			var n_matches: int = n >> (r + 1)
			for _i in range(n_matches):
				round_arr.append({
					"team_a": -1, "team_b": -1,
					"winner": -1, "status": "future",
				})
		result.append(round_arr)
	return result

# ── Build a single match card (absolute-positioned PanelContainer) ─────────────
func _make_bracket_card(m: Dictionary, lm: Node) -> PanelContainer:
	var card = PanelContainer.new()
	var player_idx: int = lm.tournament_player_team_idx
	var status: String  = m.get("status", "future")
	var ta_idx: int     = m.get("team_a", -1)
	var tb_idx: int     = m.get("team_b", -1)
	var winner: int     = m.get("winner", -1)
	var is_player: bool = (ta_idx == player_idx or tb_idx == player_idx)

	var sb = StyleBoxFlat.new()
	match status:
		"current":
			if is_player:
				sb.bg_color     = Color(0.17, 0.13, 0.03, 0.97)
				sb.border_color = GOLD
				sb.set_border_width_all(2)
			else:
				sb.bg_color     = Color(0.10, 0.10, 0.18, 0.92)
				sb.border_color = Color(0.30, 0.30, 0.50, 0.8)
				sb.set_border_width_all(1)
		"past":
			sb.bg_color     = Color(0.07, 0.10, 0.07, 0.88)
			sb.border_color = WIN_COL.darkened(0.45) if is_player else Color(0.18, 0.28, 0.18, 0.5)
			sb.set_border_width_all(1)
		_:  # future
			sb.bg_color     = Color(0.05, 0.05, 0.09, 0.40)
			sb.border_color = Color(0.13, 0.13, 0.22, 0.30)
			sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left   = 10
	sb.content_margin_right  = 10
	sb.content_margin_top    = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)

	# Click interaction
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var m_capture = m
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_show_matchup_preview(m_capture)
	)

	# Hover style
	var hsb = sb.duplicate()
	hsb.bg_color = hsb.bg_color.lightened(0.05)
	if is_player and status == "current":
		hsb.border_color = GOLD.lightened(0.2)
	else:
		hsb.border_color = hsb.border_color.lightened(0.1)
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hsb))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", sb))

	# ── Future: single centered TBD label ──────────────────────────────────
	if status == "future":
		var tbd = Label.new()
		tbd.text = "TBD  vs  TBD"
		tbd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tbd.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		tbd.add_theme_font_size_override("font_size", 13)
		tbd.add_theme_color_override("font_color", Color(0.25, 0.25, 0.35))
		card.add_child(tbd)
		return card

	# ── Past / current: two team rows with separator ────────────────────────
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var ta = lm.tournament_teams[ta_idx] if ta_idx >= 0 and ta_idx < lm.tournament_teams.size() else null
	var tb = lm.tournament_teams[tb_idx] if tb_idx >= 0 and tb_idx < lm.tournament_teams.size() else null

	if ta:
		var ta_won  = status == "past" and winner == ta_idx
		var ta_lost = status == "past" and winner != ta_idx and winner >= 0
		vbox.add_child(_bracket_team_row(ta, ta_idx, player_idx, ta_won, ta_lost))

	var sep = HSeparator.new()
	vbox.add_child(sep)

	if tb:
		var tb_won  = status == "past" and winner == tb_idx
		var tb_lost = status == "past" and winner != tb_idx and winner >= 0
		vbox.add_child(_bracket_team_row(tb, tb_idx, player_idx, tb_won, tb_lost))

	return card

func _bracket_team_row(team: Resource, t_idx: int, player_idx: int,
		is_winner: bool, is_loser: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	# Team color swatch strip
	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(5, 0)
	swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	swatch.color               = team.color_primary
	row.add_child(swatch)

	var name_lbl = Label.new()
	name_lbl.text                  = ("🎮 " if t_idx == player_idx else "") + team.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text             = true
	name_lbl.add_theme_font_size_override("font_size", 13)
	if is_winner:
		name_lbl.add_theme_color_override("font_color", WIN_COL)
	elif is_loser:
		name_lbl.add_theme_color_override("font_color", DIM)
	elif t_idx == player_idx:
		name_lbl.add_theme_color_override("font_color", GOLD)
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.93))
	row.add_child(name_lbl)

	if is_winner:
		var ico = Label.new()
		ico.text = "✓"
		ico.add_theme_color_override("font_color", WIN_COL)
		ico.add_theme_font_size_override("font_size", 13)
		row.add_child(ico)
	elif is_loser:
		var ico = Label.new()
		ico.text = "✕"
		ico.add_theme_color_override("font_color", LOSE_COL)
		ico.add_theme_font_size_override("font_size", 13)
		row.add_child(ico)

	return row

# ─────────────────────────────────────────────────────────────────────────────
#  RESULTS SCREEN
# ─────────────────────────────────────────────────────────────────────────────
func _build_results_screen(root: VBoxContainer) -> void:
	var lm = LeagueManager
	var player_team = lm.tournament_teams[lm.tournament_player_team_idx] if lm.tournament_teams.size() > 0 else null

	var player_is_champion = false
	if lm.tournament_results.size() == 1 and lm.tournament_results[0] == lm.tournament_player_team_idx:
		player_is_champion = true

	var result_panel = PanelContainer.new()
	result_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rp_sb = StyleBoxFlat.new()
	rp_sb.bg_color     = Color(0.18, 0.15, 0.04, 0.95) if player_is_champion else Color(0.06, 0.06, 0.14, 0.92)
	rp_sb.border_color = GOLD if player_is_champion else Color(0.2, 0.2, 0.3, 0.5)
	rp_sb.set_border_width_all(2)
	rp_sb.set_corner_radius_all(12)
	rp_sb.set_content_margin_all(30)
	result_panel.add_theme_stylebox_override("panel", rp_sb)
	root.add_child(result_panel)

	var rvbox = VBoxContainer.new()
	rvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rvbox.add_theme_constant_override("separation", 18)
	result_panel.add_child(rvbox)

	var result_lbl = Label.new()
	result_lbl.text = "CHAMPION!" if player_is_champion else "ELIMINATED"
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 56)
	result_lbl.add_theme_color_override("font_color", GOLD if player_is_champion else LOSE_COL)
	rvbox.add_child(result_lbl)

	if player_team:
		var team_lbl = Label.new()
		team_lbl.text = player_team.name
		team_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		team_lbl.add_theme_font_size_override("font_size", 30)
		team_lbl.add_theme_color_override("font_color", player_team.color_primary)
		rvbox.add_child(team_lbl)

	var round_names = lm.get_tournament_round_names()
	var reached = "Round 1"
	if lm.tournament_round > 0 and lm.tournament_round <= round_names.size():
		reached = round_names[lm.tournament_round - 1]
	var reach_lbl = Label.new()
	reach_lbl.text = "Reached: %s" % reached
	reach_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reach_lbl.add_theme_font_size_override("font_size", 20)
	reach_lbl.add_theme_color_override("font_color", DIM)
	rvbox.add_child(reach_lbl)

	if not lm.tournament_match_history.is_empty():
		rvbox.add_child(HSeparator.new())
		var hist_lbl = Label.new()
		hist_lbl.text = "BRACKET RECAP"
		hist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hist_lbl.add_theme_font_size_override("font_size", 13)
		hist_lbl.add_theme_color_override("font_color", DIM)
		rvbox.add_child(hist_lbl)

		var rn = lm.get_tournament_round_names()
		for r in range(lm.tournament_match_history.size()):
			var rname = rn[clampi(r, 0, rn.size() - 1)]
			var r_lbl = Label.new()
			r_lbl.text = "— %s —" % rname
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r_lbl.add_theme_font_size_override("font_size", 12)
			r_lbl.add_theme_color_override("font_color", GOLD.darkened(0.3))
			rvbox.add_child(r_lbl)
			for mh in lm.tournament_match_history[r]:
				var ta = lm.tournament_teams[mh["team_a"]]
				var tb = lm.tournament_teams[mh["team_b"]]
				var wt = lm.tournament_teams[mh["winner"]]
				var m_lbl = Label.new()
				m_lbl.text = "%s vs %s  → %s" % [ta.name, tb.name, wt.name]
				m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				m_lbl.add_theme_font_size_override("font_size", 13)
				m_lbl.add_theme_color_override("font_color", DIM)
				rvbox.add_child(m_lbl)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	rvbox.add_child(btn_row)

	var btn_menu = Button.new()
	btn_menu.text = "MAIN MENU"
	btn_menu.custom_minimum_size = Vector2(200, 48)
	_style_btn(btn_menu, Color(0.2, 0.2, 0.35))
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	btn_row.add_child(btn_menu)

	var btn_again = Button.new()
	btn_again.text = "NEW TOURNAMENT"
	btn_again.custom_minimum_size = Vector2(230, 48)
	_style_btn(btn_again, ORANGE.darkened(0.25), GOLD)
	btn_again.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/tournament_setup.tscn"))
	btn_row.add_child(btn_again)

# ── MATCHUP PREVIEW MODAL ──────────────────────────────────────────────────
func _show_matchup_preview(match_data: Dictionary) -> void:
	# Round detection for header
	var lm = LeagueManager
	var round_names = lm.get_tournament_round_names()
	var r_name = "MATCHUP PREVIEW"
	
	var vbox = _build_generic_modal(r_name, 960, 560)

	var hb = HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 16)
	vbox.add_child(hb)

	var t_home = lm.tournament_teams[match_data["team_a"]] if match_data["team_a"] >= 0 else null
	var t_away = lm.tournament_teams[match_data["team_b"]] if match_data["team_b"] >= 0 else null
	
	if not t_home or not t_away:
		var lbl = Label.new()
		lbl.text = "Matchup TBD"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)
		return

	var home_avgs = _get_team_avgs(t_home)
	var away_avgs = _get_team_avgs(t_away)
	var home_ovr  = _preview_team_ovr(t_home)
	var away_ovr  = _preview_team_ovr(t_away)

	var left = _build_team_preview_col(t_home, "HOME",
		match_data["status"] == "past" and match_data["winner"] == match_data["team_a"],
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

	if match_data["status"] == "past":
		var score_lbl = Label.new()
		score_lbl.text = "MATCH COMPLETE"
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_lbl.add_theme_font_size_override("font_size", 14)
		score_lbl.add_theme_color_override("font_color", WIN_COL)
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
		match_data["status"] == "past" and match_data["winner"] == match_data["team_b"],
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
		n_lbl.add_theme_color_override("font_color", WIN_COL)
	elif t == LeagueManager.player_team:
		n_lbl.add_theme_color_override("font_color", GOLD)
	vb.add_child(n_lbl)

	# OVR badge
	if ovr > 0:
		var ovr_lbl = Label.new()
		ovr_lbl.text = "OVR  %d" % ovr
		ovr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ovr_lbl.add_theme_font_size_override("font_size", 18)
		ovr_lbl.add_theme_color_override("font_color", GOLD)
		vb.add_child(ovr_lbl)

	var r_lbl = Label.new()
	r_lbl.text = "%d-%d" % [t.wins, t.losses]
	r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vb.add_child(r_lbl)
	
	var h_sep = HSeparator.new()
	h_sep.add_theme_constant_override("separation", 15)
	vb.add_child(h_sep)
	
	# Tabular Player Stats (Simplified for Tournament)
	var stat_grid = GridContainer.new()
	stat_grid.columns = 3
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_grid.add_theme_constant_override("h_separation", 15)
	stat_grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(stat_grid)
	
	var headers = ["NAME", "OVR", "ROLE"]
	for h in headers:
		var hl = Label.new()
		hl.text = h
		hl.add_theme_font_size_override("font_size", 15)
		hl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if h != "NAME": hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_grid.add_child(hl)
		
	for p in t.roster:
		var nl = Label.new()
		nl.text = p.name.left(12)
		nl.add_theme_font_size_override("font_size", 17)
		nl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_grid.add_child(nl)
		
		var p_ovr = int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))
		var ol = Label.new()
		ol.text = str(p_ovr)
		ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ol.add_theme_font_size_override("font_size", 17)
		ol.add_theme_color_override("font_color", GOLD if p_ovr >= 80 else Color(0.7, 0.7, 0.7))
		stat_grid.add_child(ol)
		
		var rl = Label.new()
		rl.text = p.get("position", "G")
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rl.add_theme_font_size_override("font_size", 17)
		rl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		stat_grid.add_child(rl)
		
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
	_style_btn(btn_close, Color(0.1, 0.1, 0.2, 0.6))
	btn_close.pressed.connect(func(): bg.queue_free())
	
	var shortcut = Shortcut.new()
	var ev = InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	shortcut.events.append(ev)
	btn_close.shortcut = shortcut
	
	_attach_close_btn(vbox, btn_close)
	btn_close.call_deferred("grab_focus")
	
	return vbox

func _attach_close_btn(parent: VBoxContainer, btn: Button):
	parent.add_child(btn)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_main_menu_pressed()

# ─────────────────────────────────────────────────────────────────────────────
func _on_play_pressed() -> void:
	var lm = LeagueManager
	var courts = [lm.tournament_court_theme, CourtThemes.ID_CAGE, CourtThemes.ID_ROOFTOP, CourtThemes.ID_GARAGE]
	var court_idx = courts[lm.tournament_round % courts.size()]
	lm.start_tournament_match(court_idx)

func _style_btn(btn: Button, bg: Color, border: Color = Color.TRANSPARENT) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border if border != Color.TRANSPARENT else bg.lightened(0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate()
	h.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)
