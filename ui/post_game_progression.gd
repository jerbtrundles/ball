extends Control

@onready var grid: HFlowContainer = $MarginContainer/VBoxContainer/ScrollContainer/PlayerGrid
@onready var btn_continue: Button = $MarginContainer/VBoxContainer/BtnContinue

func _ready() -> void:
	btn_continue.pressed.connect(_on_continue)
	_build_ui()
	_apply_styling()
	_play_outcome_music()
	btn_continue.grab_focus()

func _play_outcome_music() -> void:
	var win_bonus: int = 0
	# Check if we have any progression data to determine win/loss
	for pname in LeagueManager.last_match_progression:
		var prog = LeagueManager.last_match_progression[pname]
		win_bonus = prog.get("win_bonus", 0)
		break
	
	var track_path = "res://assets/sounds/Rust_Ruin_Rumble.mp3"
	if win_bonus >= 1000: # Threshold for win bonus
		track_path = "res://assets/sounds/Wasteland_Ascendancy.mp3"
	
	var music = AudioStreamPlayer.new()
	var stream = load(track_path)
	if stream is AudioStreamMP3:
		stream.loop = true
	music.stream = stream
	music.bus = "Music"
	add_child(music)
	music.play()

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://ui/season_hub.tscn")

func _build_ui() -> void:
	for child in grid.get_children():
		child.queue_free()

	var team = LeagueManager.player_team
	if not team:
		return

	# --- Match Earnings Banner ---
	# Grab data from any player's progression entry (all share the same match funds)
	var any_prog: Dictionary = {}
	for pname in LeagueManager.last_match_progression:
		any_prog = LeagueManager.last_match_progression[pname]
		break

	if not any_prog.is_empty() and any_prog.has("funds_earned"):
		var earnings_pnl = _create_earnings_panel(any_prog, team.color_primary)
		# Insert before the grid's parent scroll — find the vbox
		var vbox = grid.get_parent().get_parent()  # grid → ScrollContainer → VBoxContainer
		vbox.add_child(earnings_pnl)
		vbox.move_child(earnings_pnl, 0)

	for p in team.roster:
		if not LeagueManager.last_match_progression.has(p.name):
			continue

		var prog = LeagueManager.last_match_progression[p.name]
		var card = _create_player_card(p, prog, team.color_primary)
		grid.add_child(card)

func _create_earnings_panel(prog: Dictionary, team_color: Color) -> Control:
	var pnl = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.05, 0.9)
	sb.border_color = Color(1.0, 0.80, 0.1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	pnl.add_theme_stylebox_override("panel", sb)
	pnl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pnl.add_child(vbox)

	var title = Label.new()
	title.text = "MATCH EARNINGS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var coin_income = prog.get("coin_funds", 0)
	var win_bonus = prog.get("win_bonus", 0)
	var total = prog.get("funds_earned", 0)

	var rows = [
		["Coin Income", coin_income],
		[("Win Bonus" if win_bonus >= 1000 else "Loss Bonus"), win_bonus],
	]
	for row in rows:
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 40)
		var lbl = Label.new()
		lbl.text = row[0]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
		hb.add_child(lbl)
		var val = Label.new()
		val.text = "$%s" % _fmt_funds(row[1])
		val.add_theme_font_size_override("font_size", 16)
		val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		hb.add_child(val)
		vbox.add_child(hb)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var total_hb = HBoxContainer.new()
	total_hb.add_theme_constant_override("separation", 40)
	var total_lbl = Label.new()
	total_lbl.text = "TOTAL"
	total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_lbl.add_theme_font_size_override("font_size", 18)
	total_lbl.add_theme_color_override("font_color", Color.WHITE)
	total_hb.add_child(total_lbl)
	var total_val = Label.new()
	total_val.text = "$%s" % _fmt_funds(total)
	total_val.add_theme_font_size_override("font_size", 18)
	total_val.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	total_hb.add_child(total_val)
	vbox.add_child(total_hb)

	return pnl

func _fmt_funds(amount: int) -> String:
	# Format as 1,500 etc.
	var s = str(amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

func _create_player_card(p: Resource, prog: Dictionary, team_color: Color) -> Control:
	var pnl = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	sb.border_color = team_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 15
	sb.content_margin_right = 15
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	pnl.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pnl.add_child(vbox)
	
	var hdr = HBoxContainer.new()
	vbox.add_child(hdr)
	
	if p.portrait:
		var tex = TextureRect.new()
		tex.texture = p.portrait
		tex.custom_minimum_size = Vector2(80, 80)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hdr.add_child(tex)
		
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = p.name
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", team_color.lightened(0.3))
	info_vbox.add_child(name_lbl)
	
	var lvl_lbl = Label.new()
	lvl_lbl.text = "Level %d" % p.level
	if prog.get("levels_gained", 0) > 0:
		lvl_lbl.text += " (Level Up!)  ▼"
		lvl_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	info_vbox.add_child(lvl_lbl)
	
	var xp_lbl = Label.new()
	xp_lbl.text = "+%d XP" % prog.get("xp_gained", 0)
	xp_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	xp_lbl.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(xp_lbl)
	
	var stat_grid = GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 20)
	stat_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(stat_grid)
	
	var stats = ["speed", "shot", "pass_skill", "tackle", "strength", "aggression"]
	var labels = ["SPD", "SHT", "PAS", "TCK", "STR", "AGG"]
	var diffs: Dictionary = prog.get("stat_diffs", {})
	
	for i in range(6):
		var k = stats[i]
		var hbox = HBoxContainer.new()
		
		var lbl = Label.new()
		lbl.text = labels[i]
		lbl.custom_minimum_size = Vector2(35, 0)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		hbox.add_child(lbl)
		
		var val = Label.new()
		val.text = str(int(p.get(k)))
		val.custom_minimum_size = Vector2(25, 0)
		val.add_theme_font_size_override("font_size", 14)
		hbox.add_child(val)
		
		if diffs.has(k) and diffs[k] > 0:
			var d_lbl = Label.new()
			d_lbl.text = "+%d" % diffs[k]
			d_lbl.add_theme_font_size_override("font_size", 14)
			d_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
			hbox.add_child(d_lbl)
			
		stat_grid.add_child(hbox)
		
	return pnl

func _apply_styling() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.6, 0.8, 0.9)
	sb.border_color = Color(0.0, 1.0, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	btn_continue.add_theme_stylebox_override("normal", sb)
	
	var h = sb.duplicate()
	h.bg_color = Color(0.0, 0.8, 1.0, 0.9)
	btn_continue.add_theme_stylebox_override("hover", h)
	
	var f = h.duplicate()
	f.border_color = Color.WHITE
	f.set_border_width_all(3)
	btn_continue.add_theme_stylebox_override("focus", f)
