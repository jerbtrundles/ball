extends Control
## SurvivalSetup — player picks their team, then starts survival mode.

const GREEN  = Color(0.2, 0.9,  0.3)
const YELLOW = Color(1.0, 0.85, 0.1)
const ORANGE = Color(1.0, 0.5,  0.0)

var _available_teams: Array = []
var _selected_index: int = 0
var _btn_back: Button = null
var _team_name_lbl: Label = null
var _team_color_rect: ColorRect = null
var _roster_list: VBoxContainer = null

func _ready() -> void:
	if LeagueManager.divisions.is_empty():
		LeagueManager.generate_default_league()
	for div in LeagueManager.divisions:
		_available_teams.append_array(div["teams"])

	_build_ui()
	SceneManager.notify_scene_ready()

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",  60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top",   40)
	margin.add_theme_constant_override("margin_bottom",40)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# ── Title ──────────────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "SURVIVAL MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", GREEN)
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Endless waves of opponents  ·  Escalating difficulty  ·  Pick your squad"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	vbox.add_child(sub)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# ── How it works ───────────────────────────────────────────────────────
	var info_panel = PanelContainer.new()
	var info_sb = StyleBoxFlat.new()
	info_sb.bg_color = Color(0.04, 0.08, 0.04, 0.8)
	info_sb.border_color = Color(0.2, 0.5, 0.2, 0.6)
	info_sb.set_border_width_all(1)
	info_sb.set_corner_radius_all(8)
	info_sb.set_content_margin_all(14)
	info_panel.add_theme_stylebox_override("panel", info_sb)
	vbox.add_child(info_panel)

	var info_hbox = HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_theme_constant_override("separation", 40)
	info_panel.add_child(info_hbox)

	_add_info_col(info_hbox, "WAVE 1", "2v2  ·  60s", GREEN)
	_add_info_col(info_hbox, "WAVE 3", "3v3  ·  90s", YELLOW)
	_add_info_col(info_hbox, "WAVE 5+", "5v5  ·  110s+", ORANGE)

	# ── Team picker ────────────────────────────────────────────────────────
	var picker_row = HBoxContainer.new()
	picker_row.alignment = BoxContainer.ALIGNMENT_CENTER
	picker_row.add_theme_constant_override("separation", 12)
	vbox.add_child(picker_row)

	var btn_prev = Button.new()
	btn_prev.text = "◀"
	btn_prev.add_theme_font_size_override("font_size", 22)
	_style_btn(btn_prev, Color(0.2, 0.3, 0.2))
	btn_prev.pressed.connect(func(): _cycle(-1))
	picker_row.add_child(btn_prev)

	var team_card = PanelContainer.new()
	team_card.custom_minimum_size = Vector2(320, 90)
	var tc_sb = StyleBoxFlat.new()
	tc_sb.bg_color    = Color(0.06, 0.10, 0.06, 0.9)
	tc_sb.border_color= GREEN
	tc_sb.set_border_width_all(2)
	tc_sb.set_corner_radius_all(12)
	tc_sb.set_content_margin_all(14)
	team_card.add_theme_stylebox_override("panel", tc_sb)
	picker_row.add_child(team_card)

	var tc_vbox = VBoxContainer.new()
	tc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	team_card.add_child(tc_vbox)

	_team_name_lbl = Label.new()
	_team_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_name_lbl.add_theme_font_size_override("font_size", 26)
	tc_vbox.add_child(_team_name_lbl)

	_team_color_rect = ColorRect.new()
	_team_color_rect.custom_minimum_size = Vector2(0, 8)
	_team_color_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc_vbox.add_child(_team_color_rect)

	var btn_next = Button.new()
	btn_next.text = "▶"
	btn_next.add_theme_font_size_override("font_size", 22)
	_style_btn(btn_next, Color(0.2, 0.3, 0.2))
	btn_next.pressed.connect(func(): _cycle(1))
	picker_row.add_child(btn_next)

	# ── Roster preview ─────────────────────────────────────────────────────
	var roster_panel = PanelContainer.new()
	roster_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rp_sb = StyleBoxFlat.new()
	rp_sb.bg_color    = Color(0.04, 0.07, 0.04, 0.7)
	rp_sb.border_color= Color(0.15, 0.35, 0.15, 0.5)
	rp_sb.set_border_width_all(1)
	rp_sb.set_corner_radius_all(8)
	rp_sb.set_content_margin_all(12)
	roster_panel.add_theme_stylebox_override("panel", rp_sb)
	vbox.add_child(roster_panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_panel.add_child(scroll)

	_roster_list = VBoxContainer.new()
	_roster_list.add_theme_constant_override("separation", 6)
	_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_list)

	# ── Bottom buttons ─────────────────────────────────────────────────────
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back = Button.new()
	btn_back.text = "◀ BACK"
	_style_btn(btn_back, Color(0.2, 0.25, 0.2))
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	btn_row.add_child(btn_back)
	_btn_back = btn_back

	var btn_start = Button.new()
	btn_start.text = "START SURVIVAL"
	btn_start.custom_minimum_size = Vector2(280, 54)
	_style_btn(btn_start, GREEN.darkened(0.35), GREEN)
	btn_start.pressed.connect(_on_start)
	btn_row.add_child(btn_start)

	_update_ui()
	if _btn_back:
		_btn_back.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _add_info_col(parent: Node, wave: String, details: String, col: Color) -> void:
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	var w = Label.new()
	w.text = wave
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.add_theme_font_size_override("font_size", 16)
	w.add_theme_color_override("font_color", col)
	v.add_child(w)
	var d = Label.new()
	d.text = details
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	v.add_child(d)

func _cycle(dir: int) -> void:
	_selected_index = (_selected_index + dir + _available_teams.size()) % _available_teams.size()
	_update_ui()

func _update_ui() -> void:
	if _available_teams.is_empty():
		return
	var team = _available_teams[_selected_index]
	if _team_name_lbl:
		_team_name_lbl.text = team.name
		_team_name_lbl.add_theme_color_override("font_color", team.color_primary)
	if _team_color_rect:
		_team_color_rect.color = team.color_primary
	if _roster_list:
		for c in _roster_list.get_children():
			c.queue_free()
		for p in team.roster:
			var lbl = Label.new()
			var ovr = int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))
			lbl.text = "  #%d  %s  — OVR %d" % [p.number, p.name, ovr]
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", team.color_primary.lightened(0.25))
			_roster_list.add_child(lbl)

func _on_start() -> void:
	var team = _available_teams[_selected_index]
	LeagueManager.start_survival(team)
	get_tree().change_scene_to_file("res://ui/survival_hub.tscn")

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
	var p2 = sb.duplicate()
	p2.bg_color = bg.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", p2)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)
