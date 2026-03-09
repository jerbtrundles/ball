extends Control

@onready var team_name: Label = $MarginContainer/MainStack/MainHBox/VBoxContainer/VBox_Team/VBox_TeamDetails/TeamName
@onready var team_rating: Label = $MarginContainer/MainStack/MainHBox/VBoxContainer/VBox_Team/VBox_TeamDetails/TeamRating
@onready var team_logo: TextureRect = $MarginContainer/MainStack/MainHBox/VBoxContainer/VBox_Team/VBox_TeamDetails/LogoRect
@onready var team_container: Control = $MarginContainer/MainStack/MainHBox/VBoxContainer/VBox_Team
@onready var btn_left: Button = $MarginContainer/MainStack/MainHBox/VBoxContainer/VBox_Team/BtnLeft
@onready var btn_right: Button = $MarginContainer/MainStack/MainHBox/VBoxContainer/VBox_Team/BtnRight

@onready var opt_quarters: OptionButton = $MarginContainer/MainStack/MainHBox/VBoxContainer/OptionsPanel/OptionsGrid/HBox_Quarters/OptionButton
@onready var opt_team_size: OptionButton = $MarginContainer/MainStack/MainHBox/VBoxContainer/OptionsPanel/OptionsGrid/HBox_TeamSize/OptionButton
@onready var opt_lsize: OptionButton = $MarginContainer/MainStack/MainHBox/VBoxContainer/OptionsPanel/OptionsGrid/HBox_LeagueSize/OptLeagueSize
@onready var opt_gpo: OptionButton = $MarginContainer/MainStack/MainHBox/VBoxContainer/OptionsPanel/OptionsGrid/HBox_GPO/OptGPO
@onready var btn_items: Button = $MarginContainer/MainStack/MainHBox/VBoxContainer/OptionsPanel/OptionsGrid/HBox_Items/BtnItems

@onready var btn_start: Button = $MarginContainer/MainStack/MainHBox/VBoxContainer/ActionHBox/BtnStart
@onready var btn_back: Button = $MarginContainer/MainStack/MainHBox/VBoxContainer/ActionHBox/BtnBack
@onready var info_panel: PanelContainer = $MarginContainer/MainStack/InfoPanel

@onready var roster_list: VBoxContainer = $MarginContainer/MainStack/MainHBox/RosterFrame/RosterVBox/ScrollContainer/PlayerList

# --- Items modal ---
@onready var items_modal: PanelContainer = $ItemsModal
@onready var chk_mine: CheckBox = $ItemsModal/VBox/Chk_Mine
@onready var chk_saw: CheckBox = $ItemsModal/VBox/Chk_Cyclone
@onready var chk_missile: CheckBox = $ItemsModal/VBox/Chk_Missile
@onready var chk_powerup: CheckBox = $ItemsModal/VBox/Chk_PowerUp
@onready var chk_coin: CheckBox = $ItemsModal/VBox/Chk_Coin
@onready var chk_crowd: CheckBox = $ItemsModal/VBox/Chk_CrowdThrow
@onready var btn_modal_close: Button = $ItemsModal/VBox/BtnClose

var available_teams: Array = []
var current_team_index: int = 0
var selected_color_index: int = 0

# Curated sports color palette — (primary, secondary hint)
const TEAM_COLORS: Array = [
	{"name": "Crimson",  "color": Color(0.85, 0.1,  0.1 )},
	{"name": "Flame",    "color": Color(0.95, 0.4,  0.05)},
	{"name": "Gold",     "color": Color(0.95, 0.8,  0.05)},
	{"name": "Lime",     "color": Color(0.35, 0.82, 0.1 )},
	{"name": "Forest",   "color": Color(0.05, 0.55, 0.25)},
	{"name": "Sky",      "color": Color(0.15, 0.6,  0.95)},
	{"name": "Indigo",   "color": Color(0.3,  0.1,  0.8 )},
	{"name": "Violet",   "color": Color(0.65, 0.1,  0.85)},
	{"name": "Magenta",  "color": Color(0.9,  0.1,  0.6 )},
	{"name": "Silver",   "color": Color(0.6,  0.65, 0.75)},
	{"name": "Black",    "color": Color(0.15, 0.15, 0.15)},
	{"name": "White",    "color": Color(0.95, 0.95, 0.95)},
]

var _color_swatch_buttons: Array = []

func _ready() -> void:
	# Build preview stubs for ALL 36 possible team names so the player
	# can choose any franchise identity before the real league is generated.
	available_teams = LeagueManager.build_all_team_stubs()
	
	# Default to the index of whatever was previously the player_team name, if any
	var prev_name = LeagueManager.player_team.name if LeagueManager.player_team else ""
	current_team_index = 0
	for i in range(available_teams.size()):
		if available_teams[i].name == prev_name:
			current_team_index = i
			break
		
	# Quarter Options
	opt_quarters.add_item("15 Seconds", 15)
	opt_quarters.add_item("30 Seconds", 30)
	opt_quarters.add_item("1 Minute", 60)
	opt_quarters.add_item("2 Minutes", 120)
	opt_quarters.select(1)
	
	# Team Size Options
	opt_team_size.add_item("3v3", 3)
	opt_team_size.add_item("4v4", 4)
	opt_team_size.add_item("5v5", 5)
	opt_team_size.select(0)
	
	for n in range(4, 13):
		opt_lsize.add_item("%d Teams" % n, n)
	opt_lsize.select(4) # Default 8 Teams (index 4 in 4..12)
	
	opt_lsize.item_selected.connect(func(_idx): _update_season_length_options())
	_update_season_length_options()
	
	# Connect interaction
	btn_start.pressed.connect(_on_start_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_left.pressed.connect(func(): _cycle_team(-1))
	btn_right.pressed.connect(func(): _cycle_team(1))
	opt_team_size.item_selected.connect(_on_team_size_changed)
	
	# Color swatch — insert below team picker (above OptionsPanel)
	var swatch_hbox = HBoxContainer.new()
	swatch_hbox.name = "SwatchRow"
	swatch_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	swatch_hbox.add_theme_constant_override("separation", 8)
	team_container.get_parent().add_child(swatch_hbox)
	team_container.get_parent().move_child(swatch_hbox, team_container.get_index() + 1)
	
	var swatch_label = Label.new()
	swatch_label.text = "Team Color:"
	swatch_label.add_theme_font_size_override("font_size", 16)
	swatch_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	swatch_hbox.add_child(swatch_label)
	
	_color_swatch_buttons.clear()
	for ci in range(TEAM_COLORS.size()):
		var c_data = TEAM_COLORS[ci]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(32, 32)
		btn.tooltip_text = c_data["name"]
		var idx_capture = ci
		btn.pressed.connect(func(): _select_color(idx_capture))
		swatch_hbox.add_child(btn)
		_color_swatch_buttons.append(btn)
	_apply_swatch_styles()
	
	# Info Panel explaining bottom league & promo/relegation styling
	var i_sb = StyleBoxFlat.new()
	i_sb.bg_color = Color(0.1, 0.1, 0.15, 0.7)
	i_sb.border_color = Color(0.0, 0.9, 1.0, 0.4)
	i_sb.set_border_width_all(1)
	i_sb.set_corner_radius_all(6)
	i_sb.content_margin_left = 15; i_sb.content_margin_right = 15
	i_sb.content_margin_top = 10; i_sb.content_margin_bottom = 10
	info_panel.add_theme_stylebox_override("panel", i_sb)
	
	# Items Modal Binding
	btn_items.pressed.connect(_open_items_modal)
	btn_modal_close.pressed.connect(_close_items_modal)
	chk_mine.pressed.connect(_update_items_button_text)
	chk_saw.pressed.connect(_update_items_button_text)
	chk_missile.pressed.connect(_update_items_button_text)
	chk_powerup.pressed.connect(_update_items_button_text)
	chk_coin.pressed.connect(_update_items_button_text)
	chk_crowd.pressed.connect(_update_items_button_text)
	
	var btn_reset = $MarginContainer/MainStack/MainHBox/RosterFrame/RosterVBox/BtnResetTeam
	btn_reset.pressed.connect(_on_reset_pressed)
	
	# Keyboard / Gamepad binding
	team_container.focus_mode = Control.FOCUS_ALL
	team_container.gui_input.connect(_on_team_input)
	team_container.focus_entered.connect(_update_team_border)
	team_container.focus_exited.connect(_update_team_border)
	
	_apply_styling()
	_on_team_size_changed(0)
	_update_ui()
	team_container.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not items_modal.visible:
		_on_start_pressed()

func _on_team_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_cycle_team(-1); accept_event()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_cycle_team(1); accept_event()

func _cycle_team(dir: int) -> void:
	current_team_index = (current_team_index + dir) % available_teams.size()
	if current_team_index < 0: current_team_index = available_teams.size() - 1
	_update_ui()

func _on_team_size_changed(_idx: int) -> void:
	var t_size = opt_team_size.get_selected_id()
	for t in available_teams:
		# Adjust roster size to match selection
		if t.roster.size() < t_size:
			# Add missing players
			for i in range(t_size - t.roster.size()):
				var f_name = LeagueManager.FIRST_NAMES[randi() % LeagueManager.FIRST_NAMES.size()]
				var l_name = LeagueManager.LAST_NAMES[randi() % LeagueManager.LAST_NAMES.size()]
				var p = LeagueManager.PlayerDataScript.new("%s %s" % [f_name, l_name], 100)
				p.number = randi_range(0, 99)
				p.randomize_stats(1)
				t.add_player(p)
		elif t.roster.size() > t_size:
			# Truncate roster
			t.roster = t.roster.slice(0, t_size)
	_update_ui()

func _select_color(ci: int) -> void:
	selected_color_index = ci
	_apply_swatch_styles()
	_update_ui()

# Returns the currently-chosen primary color.
func _get_chosen_color() -> Color:
	if TEAM_COLORS.size() == 0: return Color(0.55, 0.55, 0.7)
	return TEAM_COLORS[selected_color_index]["color"]

# Styles all swatch buttons: selected one gets bright white border.
func _apply_swatch_styles() -> void:
	for i in range(_color_swatch_buttons.size()):
		var btn = _color_swatch_buttons[i]
		var c: Color = TEAM_COLORS[i]["color"]
		var is_sel = (i == selected_color_index)
		var sb = StyleBoxFlat.new()
		sb.bg_color = c
		sb.border_color = Color.WHITE if is_sel else c.darkened(0.3)
		sb.set_border_width_all(3 if is_sel else 1)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(0)
		btn.add_theme_stylebox_override("normal", sb)
		var h = sb.duplicate()
		h.bg_color = c.lightened(0.15)
		btn.add_theme_stylebox_override("hover", h)

func _update_team_border() -> void:
	if not team_container.is_connected("draw", _draw_team_border):
		team_container.connect("draw", _draw_team_border)
	team_container.queue_redraw()

func _draw_team_border() -> void:
	var rect = Rect2(Vector2.ZERO, team_container.size)
	var color = Color(0.2, 0.2, 0.35, 0.25)
	
	if available_teams.size() > current_team_index:
		color = available_teams[current_team_index].color_primary
		
	if team_container.has_focus():
		team_container.draw_rect(rect, color, false, 2.5)
		var inner = Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6))
		var fill = color
		fill.a = 0.5
		team_container.draw_rect(inner, fill, true)
	else:
		var fill = color
		fill.a = 0.2
		team_container.draw_rect(rect, fill, true)
		team_container.draw_rect(rect, color.darkened(0.5), false, 1.0)

func _update_ui() -> void:
	if available_teams.is_empty(): return
	var t = available_teams[current_team_index]
	
	# Apply the player's chosen color to this stub team
	var chosen = _get_chosen_color()
	t.color_primary = chosen
	t.color_secondary = TeamData.derive_secondary(chosen)
	
	team_name.text = t.name
	team_name.add_theme_color_override("font_color", chosen)
	team_rating.text = "OVR: %d" % _get_team_rating(t)
	team_rating.add_theme_color_override("font_color", chosen.lightened(0.2))
	team_logo.texture = t.logo
	
	for btn in [btn_left, btn_right]:
		btn.add_theme_color_override("font_color", chosen.darkened(0.3))
		btn.add_theme_color_override("font_hover_color", chosen.lightened(0.2))
		
	_update_team_border()
	
	# Populate Roster List
	for c in roster_list.get_children():
		c.queue_free()
		
	for i in range(t.roster.size()):
		var p = t.roster[i]
		var pnl = PanelContainer.new()
		var p_ref = p # Capture iteration variable
		pnl.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_show_player_card(p_ref, t.color_primary)
		)
		var sb_normal = StyleBoxFlat.new()
		sb_normal.bg_color = Color(0.12, 0.12, 0.18, 0.8)
		sb_normal.border_color = t.color_primary.darkened(0.2)
		sb_normal.set_border_width_all(2)
		sb_normal.set_corner_radius_all(4)
		sb_normal.content_margin_left = 12
		sb_normal.content_margin_right = 12
		sb_normal.content_margin_top = 8
		sb_normal.content_margin_bottom = 8
		
		var sb_hover = sb_normal.duplicate()
		sb_hover.bg_color = Color(0.18, 0.18, 0.24, 0.95)
		sb_hover.border_color = t.color_primary.lightened(0.2)
		
		pnl.add_theme_stylebox_override("panel", sb_normal)
		pnl.mouse_entered.connect(func(): pnl.add_theme_stylebox_override("panel", sb_hover))
		pnl.mouse_exited.connect(func(): pnl.add_theme_stylebox_override("panel", sb_normal))
		
		var pvbox = VBoxContainer.new()
		pnl.add_child(pvbox)
		
		var header_hbox = HBoxContainer.new()
		header_hbox.add_theme_constant_override("separation", 20)
		pvbox.add_child(header_hbox)
		
		if p.portrait:
			var pr = TextureRect.new()
			pr.texture = p.portrait
			pr.custom_minimum_size = Vector2(96, 96)
			pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			header_hbox.add_child(pr)
			
		var num_lbl = Label.new()
		num_lbl.text = "#%d " % p.number
		num_lbl.add_theme_font_size_override("font_size", 18)
		num_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		header_hbox.add_child(num_lbl)
		
		var name_lbl = LineEdit.new()
		name_lbl.text = p.name
		name_lbl.placeholder_text = "Player Name"
		name_lbl.max_length = 20
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		
		var sb_line_n = StyleBoxFlat.new()
		sb_line_n.bg_color = Color(0, 0, 0, 0)
		sb_line_n.border_color = Color(0, 0, 0, 0)
		sb_line_n.content_margin_left = 12
		sb_line_n.content_margin_right = 12
		sb_line_n.content_margin_top = 4
		sb_line_n.content_margin_bottom = 4
		
		var sb_line_f = StyleBoxFlat.new()
		sb_line_f.bg_color = Color(0.1, 0.1, 0.15, 0.8)
		sb_line_f.border_color = t.color_primary
		sb_line_f.set_border_width_all(1)
		sb_line_f.content_margin_left = 12
		sb_line_f.content_margin_right = 12
		sb_line_f.content_margin_top = 4
		sb_line_f.content_margin_bottom = 4
		
		name_lbl.add_theme_stylebox_override("normal", sb_line_n)
		name_lbl.add_theme_stylebox_override("focus", sb_line_f)
		name_lbl.text_changed.connect(func(new_text): p.name = new_text)
		header_hbox.add_child(name_lbl)
		
		var edit_btn = Button.new()
		edit_btn.text = "✎"
		edit_btn.add_theme_font_size_override("font_size", 14)
		var btn_sb = StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.15, 0.15, 0.2, 0.6)
		btn_sb.set_corner_radius_all(4)
		btn_sb.content_margin_left = 6
		btn_sb.content_margin_right = 6
		edit_btn.add_theme_stylebox_override("normal", btn_sb)
		edit_btn.add_theme_stylebox_override("hover", btn_sb)
		edit_btn.pressed.connect(func(): name_lbl.grab_focus())
		header_hbox.add_child(edit_btn)
		
		var ovr_lbl = Label.new()
		var p_ovr = int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))
		ovr_lbl.text = "OVR: %d" % p_ovr
		ovr_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		header_hbox.add_child(ovr_lbl)
		
		var stat_panel = PanelContainer.new()
		var stat_bg = StyleBoxFlat.new()
		stat_bg.bg_color = Color(0.08, 0.08, 0.12, 0.7)
		stat_bg.border_color = t.color_primary.darkened(0.4)
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
			s_lbl.add_theme_font_size_override("font_size", 16)
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
			bar.custom_minimum_size = Vector2(0, 14)
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
			v_lbl.custom_minimum_size = Vector2(24, 0)
			v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v_lbl.add_theme_font_size_override("font_size", 15)
			v_lbl.add_theme_color_override("font_color", c)
			bar_hbox.add_child(v_lbl)
			
			stat_grid.add_child(s_vbox)
		
		var actions_hbox = HBoxContainer.new()
		actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		actions_hbox.add_theme_constant_override("separation", 15)
		pvbox.add_child(actions_hbox)
		
		var btn_rand = Button.new()
		btn_rand.text = " 🎲 New Player "
		btn_rand.custom_minimum_size = Vector2(40, 40)
		btn_rand.add_theme_font_size_override("font_size", 14)
		var rand_click_idx = i
		btn_rand.pressed.connect(func(): _on_roster_card_randomize(rand_click_idx))
		actions_hbox.add_child(btn_rand)
		
		# Swap button removed
		
		roster_list.add_child(pnl)

func _on_roster_card_randomize(idx: int) -> void:
	var t = available_teams[current_team_index]
	var first_names = ["John", "Alex", "Chris", "Sam", "Pat", "Mike", "David", "James", "Robert", "William", "Joseph", "Thomas", "Charles", "Daniel", "Matthew", "Anthony", "Mark", "Steven", "Paul", "Andrew", "Kevin", "Brian", "George", "Edward", "Ronald", "Timothy", "Jason", "Jeffrey", "Ryan", "Jacob"]
	var last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark"]
	var p_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	
	var PlayerDataScript = load("res://scripts/data/player_data.gd")
	var p = PlayerDataScript.new(p_name, 100 * 1) # Tier 1 (Bronze)
	p.number = randi_range(0, 99)
	p.randomize_with_archetype(1) # Tier 1
	
	t.roster[idx] = p
	_update_ui()

# Swap modal logic removed

func _show_player_card(player: Resource, theme_color: Color) -> void:
	var m_scene = load("res://ui/player_card_modal.tscn")
	var m_inst = m_scene.instantiate()
	add_child(m_inst)
	m_inst.setup(player, theme_color)

func _on_reset_pressed() -> void:
	if available_teams.is_empty(): return
	var t = available_teams[current_team_index]
	var t_size = opt_team_size.get_selected_id()
	LeagueManager.reset_team_roster(t, t_size)
	_update_ui()

func _get_team_rating(team: Resource) -> int:
	if team.roster.is_empty(): return 0
	var total = 0.0
	for p in team.roster:
		var p_rating = (p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0
		total += p_rating
	return int(round(total / team.roster.size()))

func _open_items_modal() -> void:
	items_modal.visible = true
	btn_modal_close.grab_focus()

func _close_items_modal() -> void:
	items_modal.visible = false
	_update_items_button_text()
	btn_items.grab_focus()

func _get_enabled_items() -> Dictionary:
	return {
		"mine": chk_mine.button_pressed,
		"cyclone": chk_saw.button_pressed,
		"missile": chk_missile.button_pressed,
		"power_up": chk_powerup.button_pressed,
		"coin": chk_coin.button_pressed,
		"crowd_throw": chk_crowd.button_pressed,
	}

func _update_items_button_text() -> void:
	var items = _get_enabled_items()
	var enabled_count = 0
	for v in items.values():
		if v: enabled_count += 1
	if enabled_count == items.size(): btn_items.text = "All Enabled ▸"
	elif enabled_count == 0: btn_items.text = "All Disabled ▸"
	else: btn_items.text = "%d / %d Enabled ▸" % [enabled_count, items.size()]

func _update_season_length_options() -> void:
	if not opt_gpo: return
	
	var league_size = 8
	if opt_lsize and opt_lsize.get_selected_id() > 0:
		league_size = opt_lsize.get_selected_id()
		
	# league_size = teams per division; games_per_cycle = round-robin = league_size - 1
	var games_per_cycle = league_size - 1
	var current_selected = opt_gpo.get_selected_id()
	if current_selected <= 0: current_selected = 1
	
	opt_gpo.clear()
	opt_gpo.add_item("%d Games (1x)" % (games_per_cycle * 1), 1)
	opt_gpo.add_item("%d Games (2x)" % (games_per_cycle * 2), 2)
	opt_gpo.add_item("%d Games (3x)" % (games_per_cycle * 3), 3)
	opt_gpo.add_item("%d Games (4x)" % (games_per_cycle * 4), 4)
	
	opt_gpo.select(clamp(current_selected - 1, 0, 3))

func _on_start_pressed() -> void:
	var t = available_teams[current_team_index]
	# Apply the selected color permanently to the stub before handing off
	var chosen = _get_chosen_color()
	t.color_primary = chosen
	t.color_secondary = TeamData.derive_secondary(chosen)
	
	var q_len = opt_quarters.get_selected_id()
	if q_len <= 0: q_len = 30
	var t_size = opt_team_size.get_selected_id()
	if t_size <= 0: t_size = 3
	
	var enabled_items = _get_enabled_items()
	var any_items = false
	for v in enabled_items.values():
		if v: any_items = true; break
		
	var gpo = 1
	if opt_gpo: gpo = opt_gpo.get_selected_id()
	
	var l_size = 8
	if opt_lsize and opt_lsize.get_selected_id() > 0: l_size = opt_lsize.get_selected_id()
	
	# Pass chosen colors so generate_default_league preserves the player's pick
	LeagueManager.generate_default_league(l_size, t.name, chosen, t.color_secondary, t_size)
	
	var config = {
		"quarter_duration": float(q_len),
		"team_size": int(t_size),
		"items_enabled": any_items,
		"allowed_items": enabled_items,
		"games_per_opponent": int(gpo),
		"league_size": int(l_size)
	}
	
	LeagueManager.start_new_season(t, config)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

# --- STYLING MACROS ---
func _apply_styling() -> void:
	var bg = $Background
	var shader_mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float t = UV.y; 
	vec3 top = vec3(0.04, 0.04, 0.12);
	vec3 mid = vec3(0.06, 0.02, 0.14);
	vec3 bot = vec3(0.03, 0.03, 0.08);
	vec3 col = mix(top, mid, smoothstep(0.0, 0.5, t));
	col = mix(col, bot, smoothstep(0.5, 1.0, t));
	vec2 center = vec2(0.5, 0.35);
	float glow = 1.0 - smoothstep(0.0, 0.6, distance(UV, center));
	col += vec3(0.0, 0.04, 0.08) * glow;
	COLOR = vec4(col, 1.0);
}
"""
	shader_mat.shader = shader
	bg.material = shader_mat
	
	$MarginContainer/MainStack/MainHBox/VBoxContainer/Title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	$MarginContainer/MainStack/MainHBox/VBoxContainer/Title.add_theme_color_override("font_outline_color", Color(0.0, 0.4, 0.6))
	$MarginContainer/MainStack/MainHBox/VBoxContainer/Title.add_theme_constant_override("outline_size", 4)
	
	var arrow_dim = Color(0.45, 0.45, 0.6)
	for btn in [btn_left, btn_right]:
		btn.add_theme_color_override("font_color", arrow_dim)
		btn.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.9))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.focus_mode = Control.FOCUS_NONE
		
	_style_button_neon(btn_start, Color(0.0, 0.6, 0.8), Color(0.0, 1.0, 1.0))
	btn_start.add_theme_color_override("font_color", Color.WHITE)
	_style_button_subtle(btn_back)
	_style_button_subtle(btn_items)
	
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.06, 0.12, 0.7)
	panel_sb.border_color = Color(0.15, 0.15, 0.3, 0.5)
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(10)
	panel_sb.set_content_margin_all(20)
	$MarginContainer/MainStack/MainHBox/VBoxContainer/OptionsPanel.add_theme_stylebox_override("panel", panel_sb)
	
	var modal_sb = StyleBoxFlat.new()
	modal_sb.bg_color = Color(0.06, 0.06, 0.14, 0.95)
	modal_sb.border_color = Color(0.0, 0.8, 1.0, 0.6)
	modal_sb.set_border_width_all(2)
	modal_sb.set_corner_radius_all(12)
	modal_sb.set_content_margin_all(20)
	items_modal.add_theme_stylebox_override("panel", modal_sb)
	$ItemsModal/VBox/ModalTitle.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	_style_button_neon(btn_modal_close, Color(0.0, 0.5, 0.6), Color(0.0, 0.8, 1.0))

func _style_button_neon(btn: Button, bg_col: Color, border_col: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(bg_col.r, bg_col.g, bg_col.b, 0.9)
	sb.border_color = Color(border_col.r, border_col.g, border_col.b, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate(); h.bg_color = bg_col.lightened(0.1)
	btn.add_theme_stylebox_override("hover", h)
	var p = sb.duplicate(); p.bg_color = bg_col.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", p)
	var f = sb.duplicate(); f.border_color = border_col; f.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", f)

func _style_button_subtle(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.2, 0.6)
	sb.border_color = Color(0.3, 0.3, 0.5, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate(); h.bg_color = Color(0.15, 0.15, 0.25, 0.8)
	btn.add_theme_stylebox_override("hover", h)
	var f = sb.duplicate(); f.border_color = Color(0.5, 0.5, 0.7, 0.6); f.set_border_width_all(2)
	btn.add_theme_stylebox_override("focus", f)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.9))
