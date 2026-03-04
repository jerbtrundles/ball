extends Control

@onready var team_name: Label = $MainHBox/VBoxContainer/VBox_Team/TeamName
@onready var team_rating: Label = $MainHBox/VBoxContainer/VBox_Team/TeamRating
@onready var team_logo: TextureRect = $MainHBox/VBoxContainer/VBox_Team/LogoRect
@onready var team_container: Control = $MainHBox/VBoxContainer/VBox_Team
@onready var btn_up: Button = $MainHBox/VBoxContainer/VBox_Team/BtnUp
@onready var btn_down: Button = $MainHBox/VBoxContainer/VBox_Team/BtnDown

@onready var opt_quarters: OptionButton = $MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Quarters/OptionButton
@onready var opt_team_size: OptionButton = $MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_TeamSize/OptionButton
@onready var btn_items: Button = $MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Items/BtnItems

@onready var btn_start: Button = $MainHBox/VBoxContainer/BtnStart
@onready var btn_back: Button = $MainHBox/VBoxContainer/BtnBack

@onready var roster_list: VBoxContainer = $MainHBox/RosterFrame/RosterVBox/ScrollContainer/PlayerList

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

func _ready() -> void:
	# Ensure there's a league available to pick from, even transiently generated
	if LeagueManager.divisions.is_empty():
		LeagueManager.generate_default_league()
		
	# Unflatten the generated league structure
	for div in LeagueManager.divisions:
		available_teams.append_array(div["teams"])
		
	# Find our current specific team visually to default to
	current_team_index = available_teams.find(LeagueManager.player_team)
	if current_team_index < 0:
		current_team_index = 0
		
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
	
	# Dynamically insert Games Per Opponent
	var h_gpo = HBoxContainer.new()
	h_gpo.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl = Label.new()
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.text = "Season Length"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", 18)
	var opt_gpo = OptionButton.new()
	opt_gpo.name = "OptGPO"
	opt_gpo.custom_minimum_size = Vector2(220, 0)
	opt_gpo.add_item("11 Games (1x)", 1)
	opt_gpo.add_item("22 Games (2x)", 2)
	opt_gpo.add_item("33 Games (3x)", 3)
	opt_gpo.add_item("44 Games (4x)", 4)
	opt_gpo.select(0)
	h_gpo.add_child(lbl)
	h_gpo.add_child(opt_gpo)
	$MainHBox/VBoxContainer/OptionsPanel/OptionsVBox.add_child(h_gpo)
	$MainHBox/VBoxContainer/OptionsPanel/OptionsVBox.move_child(h_gpo, 2)
	
	# Connect interaction
	btn_start.pressed.connect(_on_start_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_up.pressed.connect(func(): _cycle_team(-1))
	btn_down.pressed.connect(func(): _cycle_team(1))
	opt_team_size.item_selected.connect(func(_idx): _update_ui())
	
	# Items Modal Binding
	btn_items.pressed.connect(_open_items_modal)
	btn_modal_close.pressed.connect(_close_items_modal)
	chk_mine.pressed.connect(_update_items_button_text)
	chk_saw.pressed.connect(_update_items_button_text)
	chk_missile.pressed.connect(_update_items_button_text)
	chk_powerup.pressed.connect(_update_items_button_text)
	chk_coin.pressed.connect(_update_items_button_text)
	chk_crowd.pressed.connect(_update_items_button_text)
	
	var btn_reset = $MainHBox/RosterFrame/RosterVBox/BtnResetTeam
	btn_reset.pressed.connect(_on_reset_pressed)
	
	# Keyboard / Gamepad binding
	team_container.focus_mode = Control.FOCUS_ALL
	team_container.gui_input.connect(_on_team_input)
	team_container.focus_entered.connect(_update_team_border)
	team_container.focus_exited.connect(_update_team_border)
	
	_apply_styling()
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
	
	team_name.text = t.name
	team_name.add_theme_color_override("font_color", t.color_primary)
	team_rating.text = "OVR: %d" % _get_team_rating(t)
	team_rating.add_theme_color_override("font_color", t.color_primary.lightened(0.2))
	team_logo.texture = t.logo
	
	for btn in [btn_up, btn_down]:
		btn.add_theme_color_override("font_color", t.color_primary.darkened(0.3))
		btn.add_theme_color_override("font_hover_color", t.color_primary.lightened(0.2))
		
	_update_team_border()
	
	# Populate Roster List
	for c in roster_list.get_children():
		c.queue_free()
		

	var t_size = opt_team_size.get_selected_id()
	if t_size <= 0: t_size = 5
	var display_count = min(t.roster.size(), t_size)
	
	for i in range(display_count):
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
		pvbox.add_child(header_hbox)
		
		var name_lbl = Label.new()
		name_lbl.text = " #%d %s" % [(i+1)*11, p.name] # Dummy numbers for now
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 18)
		header_hbox.add_child(name_lbl)
		
		var ovr_lbl = Label.new()
		var p_ovr = int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))
		ovr_lbl.text = "OVR: %d" % p_ovr
		ovr_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		header_hbox.add_child(ovr_lbl)
		
		var stat_grid = GridContainer.new()
		stat_grid.columns = 6
		stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_grid.add_theme_constant_override("h_separation", 15)
		pvbox.add_child(stat_grid)
		
		var stats_keys = ["speed", "shot", "pass_skill", "tackle", "strength", "aggression"]
		var stats_labels = ["SPD", "SHT", "PAS", "TCK", "STR", "AGG"]
		
		for j in range(6):
			var s_val = p.get(stats_keys[j])
			var s_vbox = VBoxContainer.new()
			s_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_vbox.add_theme_constant_override("separation", 0)
			
			var s_lbl = Label.new()
			s_lbl.text = stats_labels[j]
			s_lbl.add_theme_font_size_override("font_size", 11)
			s_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_vbox.add_child(s_lbl)
			
			var v_lbl = Label.new()
			v_lbl.text = str(int(s_val))
			v_lbl.add_theme_font_size_override("font_size", 14)
			
			var c = Color.WHITE
			if s_val >= 80: c = Color.GREEN_YELLOW
			elif s_val >= 50: c = Color.WHITE
			else: c = Color(1.0, 0.5, 0.5)
			
			v_lbl.add_theme_color_override("font_color", c)
			v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_vbox.add_child(v_lbl)
			
			stat_grid.add_child(s_vbox)
		
		if not LeagueManager.custom_players.is_empty():
			var btn_swap = Button.new()
			btn_swap.text = "SWAP WITH CUSTOM"
			btn_swap.custom_minimum_size = Vector2(0, 30)
			btn_swap.add_theme_font_size_override("font_size", 12)
			btn_swap.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 0.8))
			var click_idx = i # Ensure local capture
			btn_swap.pressed.connect(func(): _on_roster_card_clicked(click_idx))
			pvbox.add_child(btn_swap)
		
		roster_list.add_child(pnl)

func _on_roster_card_clicked(idx: int) -> void:
	if LeagueManager.custom_players.is_empty():
		return # No custom players available to swap
		
	var m_scene = load("res://ui/player_swap_modal.tscn")
	var m_inst = m_scene.instantiate()
	m_inst.player_selected.connect(func(p: PlayerData):
		var t = available_teams[current_team_index]
		t.roster[idx] = p
		_update_ui()
	)
	add_child(m_inst)

func _show_player_card(player: Resource, theme_color: Color) -> void:
	var m_scene = load("res://ui/player_card_modal.tscn")
	var m_inst = m_scene.instantiate()
	add_child(m_inst)
	m_inst.setup(player, theme_color)

func _on_reset_pressed() -> void:
	if available_teams.is_empty(): return
	var t = available_teams[current_team_index]
	LeagueManager.reset_team_roster(t)
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

func _on_start_pressed() -> void:
	var t = available_teams[current_team_index]
	
	var q_len = opt_quarters.get_selected_id()
	if q_len <= 0: q_len = 30
	var t_size = opt_team_size.get_selected_id()
	if t_size <= 0: t_size = 3
	
	var enabled_items = _get_enabled_items()
	var any_items = false
	for v in enabled_items.values():
		if v: any_items = true; break
		
	var opt_gpo = $MainHBox/VBoxContainer/OptionsPanel/OptionsVBox.find_child("OptGPO", true, false) as OptionButton
	var gpo = 1
	if opt_gpo: gpo = opt_gpo.get_selected_id()
	
	var config = {
		"quarter_duration": float(q_len),
		"team_size": int(t_size),
		"items_enabled": any_items,
		"enabled_items": enabled_items,
		"games_per_opponent": gpo
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
	
	$MainHBox/VBoxContainer/Title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	$MainHBox/VBoxContainer/Title.add_theme_color_override("font_outline_color", Color(0.0, 0.4, 0.6))
	$MainHBox/VBoxContainer/Title.add_theme_constant_override("outline_size", 4)
	
	var arrow_dim = Color(0.45, 0.45, 0.6)
	for btn in [btn_up, btn_down]:
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
	$MainHBox/VBoxContainer/OptionsPanel.add_theme_stylebox_override("panel", panel_sb)
	
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
