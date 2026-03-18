extends Control
## SurvivalHub — shown between survival waves; lets the player continue or quit.

const GREEN     = Color(0.2, 0.9, 0.3)
const YELLOW    = Color(1.0, 0.85, 0.1)
const ORANGE    = Color(1.0, 0.5,  0.0)
const RED_COL   = Color(0.9, 0.2,  0.2)
const DIM       = Color(0.45, 0.45, 0.55)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		if c.name != "Background":
			c.queue_free()

	var lm = LeagueManager

	# ── Outer margin ───────────────────────────────────────────────────────
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",  60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top",   50)
	margin.add_theme_constant_override("margin_bottom",50)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 28)
	margin.add_child(vbox)

	# ── Mode header ────────────────────────────────────────────────────────
	var mode_lbl = Label.new()
	mode_lbl.text = "SURVIVAL MODE"
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_font_size_override("font_size", 22)
	mode_lbl.add_theme_color_override("font_color", DIM)
	vbox.add_child(mode_lbl)

	# ── Main status panel ──────────────────────────────────────────────────
	var status_panel = PanelContainer.new()
	_apply_panel_style(status_panel, Color(0.04, 0.08, 0.04, 0.92), GREEN)
	vbox.add_child(status_panel)

	var status_vbox = VBoxContainer.new()
	status_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_vbox.add_theme_constant_override("separation", 20)
	status_panel.add_child(status_vbox)

	# is_survival_active=true + round=0 → pre-match (initial launch)
	# is_survival_active=true + round>0 → wave just cleared
	# is_survival_active=false           → player was eliminated
	var is_active    = lm.is_survival_active
	var is_pre_match = is_active and lm.survival_round == 0

	if is_pre_match:
		# Pre-match: about to start wave 1
		var ready_lbl = Label.new()
		ready_lbl.text = "GET READY!"
		ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ready_lbl.add_theme_font_size_override("font_size", 52)
		ready_lbl.add_theme_color_override("font_color", GREEN)
		status_vbox.add_child(ready_lbl)

		var wave_lbl = Label.new()
		wave_lbl.text = "Starting: Wave 1"
		wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wave_lbl.add_theme_font_size_override("font_size", 28)
		wave_lbl.add_theme_color_override("font_color", YELLOW)
		status_vbox.add_child(wave_lbl)

		var preview_lbl = Label.new()
		preview_lbl.text = "vs 2 opponents  ·  60s match"
		preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_lbl.add_theme_font_size_override("font_size", 17)
		preview_lbl.add_theme_color_override("font_color", DIM)
		status_vbox.add_child(preview_lbl)

	elif is_active:
		# Wave cleared!
		var cleared_lbl = Label.new()
		cleared_lbl.text = "WAVE %d CLEARED!" % lm.survival_round
		cleared_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cleared_lbl.add_theme_font_size_override("font_size", 52)
		cleared_lbl.add_theme_color_override("font_color", GREEN)
		status_vbox.add_child(cleared_lbl)

		var next_lbl = Label.new()
		next_lbl.text = "Next: Wave %d" % (lm.survival_round + 1)
		next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_lbl.add_theme_font_size_override("font_size", 28)
		next_lbl.add_theme_color_override("font_color", YELLOW)
		status_vbox.add_child(next_lbl)

		var preview_lbl = Label.new()
		var next_sz = clampi(2 + (lm.survival_round) / 2, 2, 5)
		var next_dur = 60.0 + lm.survival_round * 10.0
		preview_lbl.text = "vs %d opponents  ·  %ds match" % [next_sz, int(next_dur)]
		preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_lbl.add_theme_font_size_override("font_size", 17)
		preview_lbl.add_theme_color_override("font_color", DIM)
		status_vbox.add_child(preview_lbl)
	else:
		# Game over
		_apply_panel_style(status_panel, Color(0.10, 0.03, 0.03, 0.92), RED_COL)

		var over_lbl = Label.new()
		over_lbl.text = "ELIMINATED"
		over_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		over_lbl.add_theme_font_size_override("font_size", 52)
		over_lbl.add_theme_color_override("font_color", RED_COL)
		status_vbox.add_child(over_lbl)

		var waves_survived = lm.survival_round
		var survived_lbl = Label.new()
		survived_lbl.text = "Survived %d wave%s" % [waves_survived, "s" if waves_survived != 1 else ""]
		survived_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		survived_lbl.add_theme_font_size_override("font_size", 26)
		survived_lbl.add_theme_color_override("font_color", DIM)
		status_vbox.add_child(survived_lbl)

	# ── Stats row ──────────────────────────────────────────────────────────
	var stats_panel = PanelContainer.new()
	_apply_panel_style(stats_panel, Color(0.06, 0.06, 0.10, 0.8))
	vbox.add_child(stats_panel)

	var stats_hbox = HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 60)
	stats_panel.add_child(stats_hbox)

	var display_wave = lm.survival_round + 1 if is_active else lm.survival_round
	_add_stat(stats_hbox, "CURRENT WAVE", str(display_wave), YELLOW)
	_add_stat(stats_hbox, "BEST WAVE", str(lm.survival_best_round), GREEN if display_wave > lm.survival_best_round else DIM)

	if lm.survival_player_team:
		_add_stat(stats_hbox, "YOUR TEAM", lm.survival_player_team.name, lm.survival_player_team.color_primary)

	# ── Buttons ────────────────────────────────────────────────────────────
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_menu = Button.new()
	btn_menu.text = "MAIN MENU"
	btn_menu.custom_minimum_size = Vector2(200, 50)
	_style_btn(btn_menu, Color(0.2, 0.2, 0.35))
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	btn_row.add_child(btn_menu)

	if not is_active:
		# Eliminated — offer retry
		var btn_retry = Button.new()
		btn_retry.text = "TRY AGAIN"
		btn_retry.custom_minimum_size = Vector2(220, 50)
		_style_btn(btn_retry, ORANGE, YELLOW)
		btn_retry.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/survival_setup.tscn"))
		btn_row.add_child(btn_retry)
	else:
		# Active — continue to next (or first) wave
		var next_wave = lm.survival_round + 1
		var btn_cont = Button.new()
		btn_cont.text = "WAVE %d" % next_wave
		btn_cont.custom_minimum_size = Vector2(260, 56)
		_style_btn(btn_cont, GREEN.darkened(0.3), GREEN)
		btn_cont.pressed.connect(_on_continue_pressed)
		btn_row.add_child(btn_cont)
		btn_cont.grab_focus()

func _add_stat(parent: Node, title: String, value: String, val_color: Color) -> void:
	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	parent.add_child(col)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", DIM)
	col.add_child(title_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 30)
	val_lbl.add_theme_color_override("font_color", val_color)
	col.add_child(val_lbl)

func _on_continue_pressed() -> void:
	var courts = [CourtThemes.ID_DEFAULT, CourtThemes.ID_CAGE, CourtThemes.ID_ROOFTOP, CourtThemes.ID_GARAGE]
	var court_idx = courts[LeagueManager.survival_round % courts.size()]
	LeagueManager.start_survival_match(court_idx)

func _apply_panel_style(panel: PanelContainer, bg: Color, border: Color = Color(0.2, 0.2, 0.3, 0.5)) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)

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
	btn.add_theme_font_size_override("font_size", 20)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
