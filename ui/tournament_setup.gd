extends Control
## TournamentSetup — polished 3-column setup screen: Your Team | Settings | Other Teams.

const GOLD   = Color(1.0,  0.82, 0.1)
const ORANGE = Color(1.0,  0.50, 0.0)
const DIM    = Color(0.45, 0.45, 0.55)
const DARK   = Color(0.06, 0.06, 0.14, 0.92)

# ── State ────────────────────────────────────────────────────────────────────
var _btn_back: Button = null
var _all_teams: Array = []           # All teams available for selection
var _player_idx:  int = 0            # Index into _all_teams for player's team
var _tourn_size:  int = 8            # 4, 8, or 16
var _cpu_slots:   Array = []         # Array[int] — index into _all_teams for each CPU slot
var _selected_slot: int = 0          # Which CPU slot is being edited (0-based)
var _selected_court: int = 0         # Starting court theme ID

# ── Live widget refs ─────────────────────────────────────────────────────────
var _player_name_lbl:  Label = null
var _player_cards_vbox: VBoxContainer = null
var _slot_list_vbox:   VBoxContainer = null
var _slot_detail_panel: Control = null
var _slot_name_lbl:    Label = null
var _slot_cards_vbox:  VBoxContainer = null
var _court_name_lbl:   Label = null
var _size_btns:        Array = []
var _subtitle_lbl:     Label = null
var _player_ovr_lbl:   Label = null
var _slot_ovr_lbl:     Label = null

# --- Settings Widgets ---
const TEAM_SIZE_VALUES: Array = [3, 4, 5]
const TEAM_SIZE_LABELS: Array = ["3v3", "4v4", "5v5"]
const QUARTERS_VALUES:  Array = [15, 30, 60, 120]
const QUARTERS_LABELS:  Array = ["15 Sec", "30 Sec", "1 Min", "2 Min"]
var _team_size_index: int = 0
var _quarters_index:  int = 1
var _sel_team_size: PanelContainer = null
var _sel_quarters:  PanelContainer = null
var _lbl_team_size: Label = null
var _lbl_quarters:  Label = null
var _btn_items:     Button = null
var _items_modal:   PanelContainer = null
var _chk_mine:      CheckBox = null
var _chk_saw:       CheckBox = null
var _chk_missile:   CheckBox = null
var _chk_powerup:   CheckBox = null
var _chk_coin:      CheckBox = null
var _chk_crowd:     CheckBox = null
var _btn_modal_close: Button = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if LeagueManager.divisions.is_empty():
		LeagueManager.generate_default_league()
	for div in LeagueManager.divisions:
		_all_teams.append_array(div["teams"])

	_init_cpu_slots()
	_build_ui()
	_on_team_size_changed(0) # Ensure initial 3v3 roster sizing
	
	var music = AudioStreamPlayer.new()
	music.stream = load("res://assets/sounds/Championship_Circuit.mp3")
	music.bus = "Music"
	add_child(music)
	music.play()
	if _btn_back:
		_btn_back.grab_focus()
	SceneManager.notify_scene_ready()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	var foc = get_viewport().gui_get_focus_owner()
	if foc == _sel_team_size:
		if event.is_action_pressed("ui_left"):
			_team_size_index = (_team_size_index - 1 + TEAM_SIZE_VALUES.size()) % TEAM_SIZE_VALUES.size()
			if _lbl_team_size: _lbl_team_size.text = TEAM_SIZE_LABELS[_team_size_index]
			_on_team_size_changed(_team_size_index)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_team_size_index = (_team_size_index + 1) % TEAM_SIZE_VALUES.size()
			if _lbl_team_size: _lbl_team_size.text = TEAM_SIZE_LABELS[_team_size_index]
			_on_team_size_changed(_team_size_index)
			get_viewport().set_input_as_handled()
	elif foc == _sel_quarters:
		if event.is_action_pressed("ui_left"):
			_quarters_index = (_quarters_index - 1 + QUARTERS_VALUES.size()) % QUARTERS_VALUES.size()
			if _lbl_quarters: _lbl_quarters.text = QUARTERS_LABELS[_quarters_index]
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_quarters_index = (_quarters_index + 1) % QUARTERS_VALUES.size()
			if _lbl_quarters: _lbl_quarters.text = QUARTERS_LABELS[_quarters_index]
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _items_modal and _items_modal.visible:
			_items_modal.visible = false
			if _btn_items:
				_btn_items.grab_focus()
		else:
			get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _init_cpu_slots() -> void:
	_cpu_slots.clear()
	var used = [_player_idx]
	for i in range(_tourn_size - 1):
		var idx = i + 1
		# Wrap around, avoiding player's slot and already-used slots
		var attempts = 0
		while (idx >= _all_teams.size() or used.has(idx)) and attempts < _all_teams.size():
			idx = (idx + 1) % _all_teams.size()
			attempts += 1
		if idx == _player_idx:
			idx = (_player_idx + i + 1) % _all_teams.size()
		_cpu_slots.append(idx)
		used.append(idx)

# ─────────────────────────────────────────────────────────────────────────────
#  UI BUILD
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	for c in get_children():
		if c.name != "Background":
			c.queue_free()

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",  36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top",   24)
	margin.add_theme_constant_override("margin_bottom",20)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# ── Header ────────────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "TOURNAMENT SETUP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GOLD)
	root_vbox.add_child(title)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.add_theme_font_size_override("font_size", 16)
	_subtitle_lbl.add_theme_color_override("font_color", DIM)
	root_vbox.add_child(_subtitle_lbl)

	_build_items_modal(root_vbox)

	root_vbox.add_child(HSeparator.new())

	# ── Three columns ─────────────────────────────────────────────────────
	var cols = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root_vbox.add_child(cols)

	_build_left_panel(cols)
	_build_center_panel(cols)
	_build_right_panel(cols)

	# ── Bottom bar ────────────────────────────────────────────────────────
	root_vbox.add_child(HSeparator.new())
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 18)
	root_vbox.add_child(bottom)

	var btn_back = Button.new()
	btn_back.text = "◀ BACK"
	_style_btn(btn_back, Color(0.2, 0.18, 0.18))
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	bottom.add_child(btn_back)
	_btn_back = btn_back

	var btn_start = Button.new()
	btn_start.text = "START TOURNAMENT"
	btn_start.custom_minimum_size = Vector2(300, 52)
	_style_btn(btn_start, ORANGE.darkened(0.25), GOLD)
	btn_start.pressed.connect(_on_start)
	bottom.add_child(btn_start)

	_refresh_all()

# ── Left column: YOUR TEAM ────────────────────────────────────────────────────
func _build_left_panel(parent: Node) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	_panel_style(panel, DARK, GOLD)
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var hdr = _section_header("YOUR TEAM", GOLD)
	vbox.add_child(hdr)

	# Team cycle row
	var cycle_row = HBoxContainer.new()
	cycle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cycle_row.add_theme_constant_override("separation", 8)
	vbox.add_child(cycle_row)

	var btn_l = _arrow_btn("◀")
	btn_l.pressed.connect(func(): _cycle_player(-1))
	cycle_row.add_child(btn_l)

	_player_name_lbl = Label.new()
	_player_name_lbl.custom_minimum_size = Vector2(200, 0)
	_player_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_name_lbl.add_theme_font_size_override("font_size", 22)
	cycle_row.add_child(_player_name_lbl)

	_player_ovr_lbl = Label.new()
	_player_ovr_lbl.add_theme_font_size_override("font_size", 14)
	_player_ovr_lbl.add_theme_color_override("font_color", DIM)
	vbox.add_child(_player_ovr_lbl)
	vbox.move_child(_player_ovr_lbl, vbox.get_index() + 2) # Below name row

	var btn_r = _arrow_btn("▶")
	btn_r.pressed.connect(func(): _cycle_player(1))
	cycle_row.add_child(btn_r)

	# Player cards
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_player_cards_vbox = VBoxContainer.new()
	_player_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_cards_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(_player_cards_vbox)

	# Regenerate button
	var btn_regen = Button.new()
	btn_regen.text = "REGENERATE TEAM"
	_style_btn(btn_regen, Color(0.15, 0.22, 0.35), Color(0.3, 0.5, 0.9))
	btn_regen.pressed.connect(_regen_player_team)
	vbox.add_child(btn_regen)

# ── Center column: SETTINGS ───────────────────────────────────────────────────
func _build_center_panel(parent: Node) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	_panel_style(panel, DARK, Color(0.3, 0.3, 0.5, 0.7))
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(vbox)

	vbox.add_child(_section_header("OPPONENT TEAMS", Color(0.8, 0.6, 0.2)))

	# Slot list
	var slot_scroll = ScrollContainer.new()
	slot_scroll.custom_minimum_size.y = 180
	slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(slot_scroll)

	_slot_list_vbox = VBoxContainer.new()
	_slot_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_list_vbox.add_theme_constant_override("separation", 3)
	slot_scroll.add_child(_slot_list_vbox)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_section_header("SETTINGS", Color(0.7, 0.7, 0.9)))

	# Tournament size
	var sz_lbl = Label.new()
	sz_lbl.text = "Tournament Size"
	sz_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sz_lbl.add_theme_font_size_override("font_size", 14)
	sz_lbl.add_theme_color_override("font_color", DIM)
	vbox.add_child(sz_lbl)

	var sz_row = HBoxContainer.new()
	sz_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sz_row.add_theme_constant_override("separation", 6)
	vbox.add_child(sz_row)

	_size_btns.clear()
	for sz in [4, 8, 16, 32]:
		var btn = Button.new()
		btn.text = str(sz)
		btn.custom_minimum_size = Vector2(52, 40)
		btn.pressed.connect(_on_size_pressed.bind(sz))
		sz_row.add_child(btn)
		_size_btns.append({"btn": btn, "size": sz})

	# Court
	vbox.add_child(HSeparator.new())
	var court_lbl = Label.new()
	court_lbl.text = "Starting Court"
	court_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	court_lbl.add_theme_font_size_override("font_size", 14)
	court_lbl.add_theme_color_override("font_color", DIM)
	vbox.add_child(court_lbl)

	var court_row = HBoxContainer.new()
	court_row.alignment = BoxContainer.ALIGNMENT_CENTER
	court_row.add_theme_constant_override("separation", 6)
	vbox.add_child(court_row)

	var btn_cp = _arrow_btn("◀")
	btn_cp.pressed.connect(func(): _cycle_court(-1))
	court_row.add_child(btn_cp)

	_court_name_lbl = Label.new()
	_court_name_lbl.custom_minimum_size = Vector2(130, 0)
	_court_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_court_name_lbl.add_theme_font_size_override("font_size", 14)
	court_row.add_child(_court_name_lbl)

	var btn_cn = _arrow_btn("▶")
	btn_cn.pressed.connect(func(): _cycle_court(1))
	court_row.add_child(btn_cn)

	# --- Team Size & Quarters ---
	vbox.add_child(HSeparator.new())

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	# Team Size
	var ts_lbl = Label.new()
	ts_lbl.text = "Team Size"
	ts_lbl.add_theme_font_size_override("font_size", 14)
	ts_lbl.add_theme_color_override("font_color", DIM)
	grid.add_child(ts_lbl)

	var ts_hb = HBoxContainer.new()
	ts_hb.add_theme_constant_override("separation", 0)
	var res_sz = _build_arrow_selector(ts_hb, TEAM_SIZE_LABELS, _team_size_index,
		func(i): _team_size_index = i; _on_team_size_changed(i))
	_sel_team_size = res_sz[0]; _lbl_team_size = res_sz[1]
	grid.add_child(ts_hb)

	# Quarters
	var q_lbl = Label.new()
	q_lbl.text = "Quarter Length"
	q_lbl.add_theme_font_size_override("font_size", 14)
	q_lbl.add_theme_color_override("font_color", DIM)
	grid.add_child(q_lbl)

	var q_hb = HBoxContainer.new()
	q_hb.add_theme_constant_override("separation", 0)
	var res_q = _build_arrow_selector(q_hb, QUARTERS_LABELS, _quarters_index,
		func(i): _quarters_index = i)
	_sel_quarters = res_q[0]; _lbl_quarters = res_q[1]
	grid.add_child(q_hb)

	# Items
	var i_lbl = Label.new()
	i_lbl.text = "Hazardous Items"
	i_lbl.add_theme_font_size_override("font_size", 14)
	i_lbl.add_theme_color_override("font_color", DIM)
	grid.add_child(i_lbl)

	_btn_items = Button.new()
	_btn_items.text = "All Enabled ▶"
	_btn_items.custom_minimum_size = Vector2(160, 0)
	_btn_items.pressed.connect(_open_items_modal)
	_style_btn(_btn_items, Color(0.12, 0.12, 0.2, 0.6))
	grid.add_child(_btn_items)

# ── Right column: OTHER TEAMS ─────────────────────────────────────────────────
func _build_right_panel(parent: Node) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	_panel_style(panel, DARK, Color(0.3, 0.6, 0.9, 0.7))
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	vbox.add_child(_section_header("SLOT DETAIL", Color(0.3, 0.6, 0.9)))

	_slot_name_lbl = Label.new()
	_slot_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_name_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_slot_name_lbl)

	_slot_ovr_lbl = Label.new()
	_slot_ovr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_ovr_lbl.add_theme_font_size_override("font_size", 14)
	_slot_ovr_lbl.add_theme_color_override("font_color", DIM)
	vbox.add_child(_slot_ovr_lbl)

	# Slot detail section
	_slot_detail_panel = PanelContainer.new()
	_slot_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_style(_slot_detail_panel, Color(0.04, 0.04, 0.10, 0.8), Color(0.3, 0.6, 0.9, 0.4))
	vbox.add_child(_slot_detail_panel)
	
	var slot_scroll = ScrollContainer.new()
	slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_detail_panel.add_child(slot_scroll)

	_slot_cards_vbox = VBoxContainer.new()
	_slot_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_cards_vbox.add_theme_constant_override("separation", 5)
	slot_scroll.add_child(_slot_cards_vbox)

	# Regenerate button
	var btn_regen = Button.new()
	btn_regen.text = "REGENERATE TEAM"
	btn_regen.custom_minimum_size.y = 44
	_style_btn(btn_regen, Color(0.15, 0.22, 0.35), Color(0.3, 0.5, 0.9))
	btn_regen.pressed.connect(_regen_slot_team)
	vbox.add_child(btn_regen)

# ─────────────────────────────────────────────────────────────────────────────
#  REFRESH / UPDATE
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_all() -> void:
	_refresh_player_column()
	_refresh_size_buttons()
	_refresh_court()
	_refresh_slot_list()
	_refresh_slot_detail()
	_refresh_subtitle()

func _refresh_player_column() -> void:
	if _all_teams.is_empty():
		return
	var team = _all_teams[_player_idx]
	if _player_name_lbl:
		_player_name_lbl.text = team.name
		_player_name_lbl.add_theme_color_override("font_color", team.color_primary)
	if _player_ovr_lbl:
		_player_ovr_lbl.text = "TEAM OVERALL: %d" % _team_ovr(team)
		_player_ovr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _player_cards_vbox:
		_rebuild_player_cards(_player_cards_vbox, team)

func _refresh_size_buttons() -> void:
	for entry in _size_btns:
		var btn: Button = entry["btn"]
		var sz: int     = entry["size"]
		var active = (sz == _tourn_size)
		var sb = StyleBoxFlat.new()
		sb.bg_color     = GOLD.darkened(0.3) if active else Color(0.16, 0.16, 0.25)
		sb.border_color = GOLD if active else Color(0.3, 0.3, 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", Color.WHITE if active else Color(0.7, 0.7, 0.8))
		btn.add_theme_font_size_override("font_size", 18)

func _refresh_court() -> void:
	if _court_name_lbl:
		var theme = CourtThemes.get_preset(_selected_court)
		_court_name_lbl.text = "%s  %s" % [CourtThemes.PRESET_ICONS[_selected_court], CourtThemes.PRESET_NAMES[_selected_court]]
		_court_name_lbl.add_theme_color_override("font_color", theme.swatch_color.lightened(0.2))

func _refresh_slot_list() -> void:
	if not _slot_list_vbox:
		return
	for c in _slot_list_vbox.get_children():
		c.queue_free()
	for i in range(_cpu_slots.size()):
		var team = _all_teams[_cpu_slots[i]]
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var is_sel = (i == _selected_slot)
		var sb = StyleBoxFlat.new()
		sb.bg_color     = team.color_primary.darkened(0.55) if is_sel else Color(0.08, 0.08, 0.14)
		sb.border_color = team.color_primary if is_sel else Color(0.2, 0.2, 0.3, 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h = sb.duplicate()
		sb_h.bg_color = team.color_primary.darkened(0.45)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("pressed", sb)
		# Build label with color swatch
		var hb = HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mc = MarginContainer.new()
		mc.set_anchors_preset(Control.PRESET_FULL_RECT)
		mc.add_theme_constant_override("margin_left", 8)
		mc.add_theme_constant_override("margin_right", 8)
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(mc)
		mc.add_child(hb)
		var swatch = ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = team.color_primary
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(swatch)
		var slot_lbl = Label.new()
		slot_lbl.text = "  %d.  %s" % [i + 1, team.name]
		slot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_lbl.add_theme_font_size_override("font_size", 14)
		slot_lbl.add_theme_color_override("font_color", team.color_primary.lightened(0.2) if is_sel else Color(0.7, 0.7, 0.8))
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(slot_lbl)
		var ovr_lbl = Label.new()
		ovr_lbl.text = "OVR %d" % _team_ovr(team)
		ovr_lbl.add_theme_font_size_override("font_size", 12)
		ovr_lbl.add_theme_color_override("font_color", DIM)
		ovr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ovr_lbl)
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_slot_selected.bind(i))
		_slot_list_vbox.add_child(btn)

func _refresh_slot_detail() -> void:
	if _cpu_slots.is_empty():
		return
	var team = _all_teams[_cpu_slots[_selected_slot]]
	if _slot_name_lbl:
		_slot_name_lbl.text = team.name
		_slot_name_lbl.add_theme_color_override("font_color", team.color_primary)
	if _slot_ovr_lbl:
		_slot_ovr_lbl.text = "TEAM OVERALL: %d" % _team_ovr(team)
	if _slot_cards_vbox:
		_rebuild_player_cards(_slot_cards_vbox, team)

func _refresh_subtitle() -> void:
	if _subtitle_lbl:
		_subtitle_lbl.text = "%d-Team Single-Elimination  ·  %d CPU opponents  ·  Pick your squad" % [_tourn_size, _tourn_size - 1]

# ─────────────────────────────────────────────────────────────────────────────
#  PLAYER CARDS
# ─────────────────────────────────────────────────────────────────────────────
func _rebuild_player_cards(container: VBoxContainer, team: Resource) -> void:
	for c in container.get_children():
		c.queue_free()
	for i in range(team.roster.size()):
		var p = team.roster[i]
		container.add_child(_make_player_card(p, team.color_primary, team, i))

func _make_player_card(p: Resource, team_color: Color, team: Resource, p_idx: int) -> PanelContainer:
	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color          = Color(team_color.r * 0.12 + 0.03,
								 team_color.g * 0.12 + 0.03,
								 team_color.b * 0.14 + 0.04, 0.96)
	sb.border_color      = team_color.darkened(0.05)
	sb.border_width_left = 4
	sb.border_width_top  = 1
	sb.border_width_right  = 1
	sb.border_width_bottom = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(8)
	sb.content_margin_left   = 12
	sb.content_margin_right  = 12
	sb.content_margin_top    = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	card.add_child(hbox)

	# ── Portrait column ─────────────────────────────────────────────────────
	var portrait_container = Control.new()
	portrait_container.custom_minimum_size = Vector2(60, 60)
	hbox.add_child(portrait_container)

	if p.portrait:
		var pr = TextureRect.new()
		pr.texture = p.portrait
		pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_container.add_child(pr)
	else:
		var portrait_bg = ColorRect.new()
		portrait_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait_bg.color = team_color.darkened(0.38)
		portrait_container.add_child(portrait_bg)

		var init_lbl = Label.new()
		init_lbl.text = p.name.left(1).to_upper()
		init_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		init_lbl.add_theme_font_size_override("font_size", 22)
		init_lbl.add_theme_color_override("font_color", team_color.lightened(0.55))
		init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_bg.add_child(init_lbl)

	# Gap spacer
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(9, 0)
	hbox.add_child(gap)

	# ── Right side: name row + stat bars ────────────────────────────────────
	var rvbox = VBoxContainer.new()
	rvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rvbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	rvbox.add_theme_constant_override("separation", 3)
	hbox.add_child(rvbox)

	# Name + number + OVR badge row
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	rvbox.add_child(name_row)

	var num_lbl = Label.new()
	num_lbl.text = "#%02d" % p.number
	num_lbl.add_theme_font_size_override("font_size", 10)
	num_lbl.add_theme_color_override("font_color", team_color.lightened(0.1))
	num_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(num_lbl)

	var name_lbl = Label.new()
	name_lbl.text = p.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(name_lbl)

	# OVR pill badge
	var ovr_panel = PanelContainer.new()
	var ovr_sb = StyleBoxFlat.new()
	ovr_sb.bg_color     = team_color.darkened(0.52)
	ovr_sb.border_color = team_color.lightened(0.28)
	ovr_sb.set_border_width_all(1)
	ovr_sb.set_corner_radius_all(9)
	ovr_sb.content_margin_left   = 7
	ovr_sb.content_margin_right  = 7
	ovr_sb.content_margin_top    = 1
	ovr_sb.content_margin_bottom = 1
	ovr_panel.add_theme_stylebox_override("panel", ovr_sb)
	name_row.add_child(ovr_panel)

	var ovr_lbl = Label.new()
	ovr_lbl.text = "OVERALL %d" % _player_ovr(p)
	ovr_lbl.add_theme_font_size_override("font_size", 11)
	ovr_lbl.add_theme_color_override("font_color", team_color.lightened(0.5))
	ovr_panel.add_child(ovr_lbl)

	# Regen button (individual)
	var btn_regen = Button.new()
	btn_regen.text = "🎲"
	btn_regen.tooltip_text = "Regenerate Player"
	btn_regen.custom_minimum_size = Vector2(30,30)
	var sb_r = StyleBoxFlat.new()
	sb_r.bg_color = Color(0,0,0,0)
	btn_regen.add_theme_stylebox_override("normal", sb_r)
	btn_regen.pressed.connect(func(): _regen_individual_player(team, p_idx))
	name_row.add_child(btn_regen)

	# Stat bars (2-column layout with full names)
	var stat_grid = GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 15)
	stat_grid.add_theme_constant_override("v_separation", 2)
	rvbox.add_child(stat_grid)

	var stats = [
		["Speed", p.speed], ["Shooting", p.shot], 
		["Passing", p.pass_skill], ["Tackle", p.tackle],
		["Strength", p.strength], ["Aggression", p.aggression]
	]
	for s in stats:
		stat_grid.add_child(_stat_bar_row(s[0], s[1], team_color))

	return card

func _stat_bar_row(label: String, val: int, col: Color) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var lbl = Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(70, 0)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", DIM)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)

	# ProgressBar with custom fill and background styling
	var pb = ProgressBar.new()
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.custom_minimum_size   = Vector2(0, 9)
	pb.min_value             = 0
	pb.max_value             = 100
	pb.value                 = val
	pb.show_percentage       = false

	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.10, 0.10, 0.16)
	bg_sb.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("background", bg_sb)

	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = col.lerp(Color.WHITE, 0.18)
	fill_sb.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("fill", fill_sb)

	row.add_child(pb)

	var val_lbl = Label.new()
	val_lbl.text = str(val)
	val_lbl.custom_minimum_size = Vector2(22, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.82))
	val_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(val_lbl)

	return row

# ─────────────────────────────────────────────────────────────────────────────
#  ACTIONS
# ─────────────────────────────────────────────────────────────────────────────
func _cycle_player(dir: int) -> void:
	_player_idx = (_player_idx + dir + _all_teams.size()) % _all_teams.size()
	# Swap any CPU slot that was using the player's team
	for i in range(_cpu_slots.size()):
		if _cpu_slots[i] == _player_idx:
			# Give them the old player slot
			_cpu_slots[i] = (_player_idx - dir + _all_teams.size()) % _all_teams.size()
			break
	_refresh_player_column()
	_refresh_slot_list()
	_refresh_slot_detail()

func _cycle_slot_team(dir: int) -> void:
	if _cpu_slots.is_empty():
		return
	var old = _cpu_slots[_selected_slot]
	var next = (old + dir + _all_teams.size()) % _all_teams.size()
	# Skip player's own team and other occupied slots
	var tries = 0
	while (next == _player_idx or (_cpu_slots.has(next) and next != old)) and tries < _all_teams.size():
		next = (next + dir + _all_teams.size()) % _all_teams.size()
		tries += 1
	_cpu_slots[_selected_slot] = next
	_refresh_slot_list()
	_refresh_slot_detail()

func _on_slot_selected(idx: int) -> void:
	_selected_slot = idx
	_refresh_slot_list()
	_refresh_slot_detail()

func _on_size_pressed(sz: int) -> void:
	_tourn_size = sz
	_init_cpu_slots()
	_selected_slot = clampi(_selected_slot, 0, max(0, _cpu_slots.size() - 1))
	_refresh_all()

func _cycle_court(dir: int) -> void:
	_selected_court = (_selected_court + dir + CourtThemes.PRESET_COUNT) % CourtThemes.PRESET_COUNT
	_refresh_court()

func _regen_player_team() -> void:
	var new_team = LeagueManager.generate_random_team()
	_all_teams[_player_idx] = new_team
	_refresh_player_column()

func _regen_slot_team() -> void:
	if _cpu_slots.is_empty():
		return
	var new_team = LeagueManager.generate_random_team()
	_all_teams[_cpu_slots[_selected_slot]] = new_team
	_refresh_slot_list()
	_refresh_slot_detail()

func _regen_individual_player(team: Resource, idx: int) -> void:
	if team.roster.size() <= idx: return
	
	var first_names = ["John", "Alex", "Chris", "Sam", "Pat", "Mike", "David", "James", "Robert", "William", "Joseph", "Thomas", "Charles", "Daniel", "Matthew", "Anthony", "Mark", "Steven", "Paul", "Andrew", "Kevin", "Brian", "George", "Edward", "Ronald", "Timothy", "Jason", "Jeffrey", "Ryan", "Jacob"]
	var last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark"]
	var p_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

	var PlayerDataScript = load("res://scripts/data/player_data.gd")
	var p = PlayerDataScript.new(p_name, 100)
	p.number = randi_range(0, 99)
	p.randomize_with_archetype(1) # Tier 1
	
	team.roster[idx] = p
	_refresh_player_column()
	_refresh_slot_detail()

func _on_start() -> void:
	var player_team = _all_teams[_player_idx]
	var cpu_teams: Array = []
	for slot_idx in _cpu_slots:
		cpu_teams.append(_all_teams[slot_idx])
	
	var config = {
		"quarter_duration": float(QUARTERS_VALUES[_quarters_index]),
		"team_size": int(TEAM_SIZE_VALUES[_team_size_index]),
		"items_enabled": _get_any_items_enabled(),
		"enabled_items": _get_enabled_items_map()
	}
	
	LeagueManager.start_tournament(player_team, cpu_teams, _tourn_size, config)
	LeagueManager.tournament_court_theme = _selected_court
	get_tree().change_scene_to_file("res://ui/tournament_hub.tscn")

func _on_team_size_changed(_idx: int) -> void:
	var t_size = TEAM_SIZE_VALUES[_team_size_index]
	for t in _all_teams:
		# Add or remove players to match selection
		if t.roster.size() < t_size:
			for i in range(t_size - t.roster.size()):
				var f_name = LeagueManager.FIRST_NAMES[randi() % LeagueManager.FIRST_NAMES.size()]
				var l_name = LeagueManager.LAST_NAMES[randi() % LeagueManager.LAST_NAMES.size()]
				var p = LeagueManager.PlayerDataScript.new("%s %s" % [f_name, l_name], 100)
				p.number = randi_range(0, 99)
				p.randomize_stats(1)
				t.add_player(p)
		elif t.roster.size() > t_size:
			t.roster = t.roster.slice(0, t_size)
	
	_refresh_player_column()
	if not _cpu_slots.is_empty():
		_refresh_slot_detail()
	_refresh_slot_list()

# ── Items Modal ─────────────────────────────────────────────────────────────
func _build_items_modal(parent: Node) -> void:
	_items_modal = PanelContainer.new()
	_items_modal.visible = false
	_items_modal.custom_minimum_size = Vector2(340, 320)
	# Center it
	_items_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	var modal_sb = StyleBoxFlat.new()
	modal_sb.bg_color = Color(0.06, 0.06, 0.14, 0.98)
	modal_sb.border_color = Color(0.0, 0.8, 1.0, 0.6)
	modal_sb.set_border_width_all(2)
	modal_sb.set_corner_radius_all(12)
	modal_sb.set_content_margin_all(20)
	_items_modal.add_theme_stylebox_override("panel", modal_sb)
	
	parent.get_parent().add_child(_items_modal) # Add to margin or root? Let's add to root-level for overlay

	var mvbox = VBoxContainer.new()
	mvbox.add_theme_constant_override("separation", 20)
	_items_modal.add_child(mvbox)

	var mtitle = Label.new()
	mtitle.text = "HAZARDOUS ITEMS"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 24)
	mtitle.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	mvbox.add_child(mtitle)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 14)
	mvbox.add_child(grid)

	_chk_mine = _make_item_chk("Land Mines", grid)
	_chk_saw = _make_item_chk("Cyclone Saws", grid)
	_chk_missile = _make_item_chk("Homing Missiles", grid)
	_chk_powerup = _make_item_chk("Power-Ups", grid)
	_chk_coin = _make_item_chk("Bonus Coins", grid)
	_chk_crowd = _make_item_chk("Crowd Throw", grid)

	mvbox.add_child(Control.new()) # Spacer

	_btn_modal_close = Button.new()
	_btn_modal_close.text = "CLOSE"
	_btn_modal_close.custom_minimum_size.y = 44
	_style_btn(_btn_modal_close, Color(0.0, 0.5, 0.6), Color(0.0, 0.8, 1.0))
	_btn_modal_close.pressed.connect(_close_items_modal)
	mvbox.add_child(_btn_modal_close)

func _make_item_chk(txt: String, parent: Node) -> CheckBox:
	var chk = CheckBox.new()
	chk.text = " " + txt
	chk.button_pressed = true
	chk.add_theme_font_size_override("font_size", 14)
	chk.pressed.connect(_update_items_btn_text)
	parent.add_child(chk)
	return chk

func _open_items_modal() -> void:
	_items_modal.visible = true
	_btn_modal_close.grab_focus()

func _close_items_modal() -> void:
	_items_modal.visible = false
	_btn_items.grab_focus()

func _update_items_btn_text() -> void:
	var count = 0
	var total = 6
	if _chk_mine.button_pressed: count += 1
	if _chk_saw.button_pressed: count += 1
	if _chk_missile.button_pressed: count += 1
	if _chk_powerup.button_pressed: count += 1
	if _chk_coin.button_pressed: count += 1
	if _chk_crowd.button_pressed: count += 1
	
	if count == total: _btn_items.text = "All Enabled ▶"
	elif count == 0: _btn_items.text = "All Disabled ▶"
	else: _btn_items.text = "%d / %d Enabled ▶" % [count, total]

func _get_any_items_enabled() -> bool:
	return _chk_mine.button_pressed or _chk_saw.button_pressed or _chk_missile.button_pressed or \
		   _chk_powerup.button_pressed or _chk_coin.button_pressed or _chk_crowd.button_pressed

func _get_enabled_items_map() -> Dictionary:
	return {
		"mine": _chk_mine.button_pressed,
		"cyclone": _chk_saw.button_pressed,
		"missile": _chk_missile.button_pressed,
		"power_up": _chk_powerup.button_pressed,
		"coin": _chk_coin.button_pressed,
		"crowd_throw": _chk_crowd.button_pressed
	}

func _build_arrow_selector(parent: HBoxContainer, labels: Array, initial_idx: int, on_change: Callable) -> Array:
	var panel = PanelContainer.new()
	panel.focus_mode = Control.FOCUS_ALL
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_selector_panel(panel, false)
	panel.focus_entered.connect(func(): _style_selector_panel(panel, true))
	panel.focus_exited.connect(func(): _style_selector_panel(panel, false))

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	panel.add_child(hbox)

	var arrow_l = Button.new()
	arrow_l.text = "◀"
	arrow_l.flat = true
	arrow_l.focus_mode = Control.FOCUS_NONE
	arrow_l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
	arrow_l.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 1.0))
	hbox.add_child(arrow_l)

	var lbl = Label.new()
	lbl.text = labels[initial_idx]
	lbl.custom_minimum_size = Vector2(54, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.focus_mode = Control.FOCUS_NONE
	hbox.add_child(lbl)

	var arrow_r = Button.new()
	arrow_r.text = "▶"
	arrow_r.flat = true
	arrow_r.focus_mode = Control.FOCUS_NONE
	arrow_r.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
	arrow_r.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 1.0))
	hbox.add_child(arrow_r)

	arrow_l.pressed.connect(func():
		var cur = labels.find(lbl.text)
		var new_i = (cur - 1 + labels.size()) % labels.size()
		lbl.text = labels[new_i]
		on_change.call(new_i)
	)
	arrow_r.pressed.connect(func():
		var cur = labels.find(lbl.text)
		var new_i = (cur + 1) % labels.size()
		lbl.text = labels[new_i]
		on_change.call(new_i)
	)

	parent.add_child(panel)
	return [panel, lbl]

func _style_selector_panel(panel: PanelContainer, focused: bool) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color     = Color(0.10, 0.10, 0.18, 0.9) if focused else Color(0.07, 0.07, 0.13, 0.75)
	sb.border_color = Color(0.45, 0.65, 1.0, 0.9)  if focused else Color(0.25, 0.25, 0.45, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)

# ─────────────────────────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _player_ovr(p: Resource) -> int:
	return int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))

func _team_ovr(team: Resource) -> int:
	if team.roster.is_empty():
		return 0
	var total = 0
	for p in team.roster:
		total += _player_ovr(p)
	return int(total / team.roster.size())

func _section_header(text: String, col: Color) -> PanelContainer:
	var container = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color          = col.darkened(0.82)
	sb.border_color      = col.darkened(0.25)
	sb.border_width_bottom = 2
	sb.border_width_left   = 0
	sb.border_width_top    = 0
	sb.border_width_right  = 0
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left   = 12
	sb.content_margin_right  = 12
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	container.add_theme_stylebox_override("panel", sb)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	container.add_child(hb)

	var accent = ColorRect.new()
	accent.custom_minimum_size = Vector2(4, 18)
	accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accent.color = col
	hb.add_child(accent)

	var lbl = Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", col.lightened(0.18))
	hb.add_child(lbl)

	return container

func _arrow_btn(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(32, 32)
	_style_btn(btn, Color(0.18, 0.18, 0.28))
	return btn

func _panel_style(panel: PanelContainer, bg: Color, border: Color = Color(0.2, 0.2, 0.3, 0.5)) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)

func _style_btn(btn: Button, bg: Color, border: Color = Color.TRANSPARENT) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border if border != Color.TRANSPARENT else bg.lightened(0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(7)
	sb.set_content_margin_all(9)
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate()
	h.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", h)
	var p2 = sb.duplicate()
	p2.bg_color = bg.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", p2)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 16)
