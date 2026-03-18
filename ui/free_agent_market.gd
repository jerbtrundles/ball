extends Control
## Free Agent Market — click a roster player + a free agent to stage a trade.

const STAT_KEYS = ["speed", "shot", "pass_skill", "tackle", "strength", "aggression"]
const STAT_LABELS = ["Speed", "Shooting", "Passing", "Tackling", "Strength", "Aggression"]

var _funds_label: Label = null
var _roster_title: Label = null
var _roster_vbox: VBoxContainer = null
var _fa_vbox: VBoxContainer = null
var _trade_inner: VBoxContainer = null
var _selected_roster: Resource = null
var _selected_fa: Resource = null
var _roster_cards: Dictionary = {}
var _fa_cards: Dictionary = {}
var _team_color: Color = Color(0.2, 0.5, 1.0)
var _back_btn: Button = null

func _ready() -> void:
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/season_hub.tscn")

func _build_ui() -> void:
	var team = LeagueManager.player_team
	if not team:
		get_tree().change_scene_to_file("res://ui/season_hub.tscn")
		return
	_team_color = team.color_primary
	var col = _team_color

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# --- Header ---
	var header = PanelContainer.new()
	var hsb = StyleBoxFlat.new()
	hsb.bg_color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.95)
	hsb.border_color = col.lightened(0.2)
	hsb.border_width_bottom = 2
	hsb.content_margin_left = 24; hsb.content_margin_right = 24
	hsb.content_margin_top = 12; hsb.content_margin_bottom = 12
	header.add_theme_stylebox_override("panel", hsb)
	root_vbox.add_child(header)

	var header_hb = HBoxContainer.new()
	header.add_child(header_hb)

	var title_lbl = Label.new()
	title_lbl.text = "FREE AGENT MARKET  —  WEEK %d" % (LeagueManager.current_week + 1)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(title_lbl)

	_funds_label = Label.new()
	_funds_label.add_theme_font_size_override("font_size", 24)
	_funds_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_funds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_hb.add_child(_funds_label)

	# --- Main panels ---
	var main_margin = MarginContainer.new()
	main_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_margin.add_theme_constant_override("margin_left", 350)
	main_margin.add_theme_constant_override("margin_right", 350)
	main_margin.add_theme_constant_override("margin_top", 12)
	main_margin.add_theme_constant_override("margin_bottom", 4)
	root_vbox.add_child(main_margin)

	var main_hb = HBoxContainer.new()
	main_hb.add_theme_constant_override("separation", 0)
	main_margin.add_child(main_hb)

	# Left: Roster
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.5
	left_vbox.add_theme_constant_override("separation", 8)
	main_hb.add_child(left_vbox)

	_roster_title = Label.new()
	_roster_title.add_theme_font_size_override("font_size", 18)
	_roster_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	left_vbox.add_child(_roster_title)

	var roster_scroll = ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(roster_scroll)

	_roster_vbox = VBoxContainer.new()
	_roster_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_vbox.add_theme_constant_override("separation", 8)
	roster_scroll.add_child(_roster_vbox)

	# Divider
	var div = ColorRect.new()
	div.color = col.darkened(0.4)
	div.custom_minimum_size = Vector2(2, 0)
	div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hb.add_child(div)

	# Right: Free Agents
	var right_margin = MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_stretch_ratio = 0.5
	right_margin.add_theme_constant_override("margin_left", 12)
	main_hb.add_child(right_margin)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_vbox)

	var fa_title = Label.new()
	fa_title.text = "AVAILABLE THIS WEEK"
	fa_title.add_theme_font_size_override("font_size", 18)
	fa_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	right_vbox.add_child(fa_title)

	var fa_scroll = ScrollContainer.new()
	fa_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fa_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(fa_scroll)

	_fa_vbox = VBoxContainer.new()
	_fa_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fa_vbox.add_theme_constant_override("separation", 8)
	fa_scroll.add_child(_fa_vbox)

	# --- Trade Staging Panel ---
	var trade_pnl = PanelContainer.new()
	trade_pnl.custom_minimum_size = Vector2(0, 190)
	var tsb = StyleBoxFlat.new()
	tsb.bg_color = Color(0.07, 0.06, 0.11, 0.97)
	tsb.border_color = col.darkened(0.1)
	tsb.border_width_top = 2
	tsb.content_margin_left = 20; tsb.content_margin_right = 20
	tsb.content_margin_top = 12; tsb.content_margin_bottom = 12
	trade_pnl.add_theme_stylebox_override("panel", tsb)
	root_vbox.add_child(trade_pnl)

	_trade_inner = VBoxContainer.new()
	_trade_inner.add_theme_constant_override("separation", 8)
	trade_pnl.add_child(_trade_inner)

	# --- Footer ---
	var footer = PanelContainer.new()
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = Color(0.07, 0.07, 0.1, 0.95)
	fsb.border_color = col.darkened(0.3)
	fsb.border_width_top = 2
	fsb.content_margin_left = 20; fsb.content_margin_right = 20
	fsb.content_margin_top = 10; fsb.content_margin_bottom = 10
	footer.add_theme_stylebox_override("panel", fsb)
	root_vbox.add_child(footer)

	var back_btn = Button.new()
	back_btn.text = "◀ BACK TO SEASON HUB"
	back_btn.add_theme_font_size_override("font_size", 20)
	_style_button(back_btn, Color(0.15, 0.15, 0.25, 0.9), Color(0.4, 0.4, 0.65))
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/season_hub.tscn"))
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	footer.add_child(back_btn)
	_back_btn = back_btn

	_refresh_panels()
	back_btn.grab_focus()

# ---------------------------------------------------------------------------
# Panel refresh
# ---------------------------------------------------------------------------

func _refresh_panels() -> void:
	_refresh_funds_label()
	_refresh_roster_panel()
	_refresh_fa_panel()
	_refresh_trade_panel()

func _refresh_funds_label() -> void:
	var team = LeagueManager.player_team
	if _funds_label and team:
		_funds_label.text = "FUNDS:  $%s" % _fmt_funds(team.funds)

func _refresh_roster_panel() -> void:
	if not _roster_vbox: return
	for c in _roster_vbox.get_children(): c.queue_free()
	_roster_cards.clear()
	var team = LeagueManager.player_team
	if not team: return
	_roster_title.text = "YOUR ROSTER"
	for p in team.roster:
		var card = _create_player_card(p, false)
		_roster_cards[p] = card
		_roster_vbox.add_child(card)

func _refresh_fa_panel() -> void:
	if not _fa_vbox: return
	for c in _fa_vbox.get_children(): c.queue_free()
	_fa_cards.clear()
	if LeagueManager.free_agents.is_empty():
		var lbl = Label.new()
		lbl.text = "No free agents available.\nSimulate or play a week to refresh."
		lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		_fa_vbox.add_child(lbl)
		return
	for p in LeagueManager.free_agents:
		var card = _create_player_card(p, true)
		_fa_cards[p] = card
		_fa_vbox.add_child(card)

# ---------------------------------------------------------------------------
# Trade panel
# ---------------------------------------------------------------------------

func _refresh_trade_panel() -> void:
	if not _trade_inner: return
	for c in _trade_inner.get_children(): c.queue_free()
	_update_card_highlights()

	var has_roster = _selected_roster != null and _roster_cards.has(_selected_roster)
	var has_fa = _selected_fa != null and _fa_cards.has(_selected_fa)

	var title_lbl = Label.new()
	title_lbl.text = "PENDING TRADE"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_inner.add_child(title_lbl)

	var content_hb = HBoxContainer.new()
	content_hb.add_theme_constant_override("separation", 12)
	content_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trade_inner.add_child(content_hb)

	# Left: releasing
	var left_wrap = VBoxContainer.new()
	left_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_wrap.size_flags_stretch_ratio = 0.28
	content_hb.add_child(left_wrap)

	if has_roster:
		_build_trade_slot(left_wrap, _selected_roster, false)
	else:
		_build_trade_placeholder(left_wrap, "Select Player", "RELEASING")

	# Center: comparison
	var center_wrap = VBoxContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_wrap.size_flags_stretch_ratio = 0.44
	center_wrap.add_theme_constant_override("separation", 6)
	content_hb.add_child(center_wrap)

	if has_roster and has_fa:
		_build_trade_comparison(center_wrap, _selected_roster, _selected_fa)
	else:
		_build_comparison_placeholder(center_wrap)

	# Right: signing
	var right_wrap = VBoxContainer.new()
	right_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_wrap.size_flags_stretch_ratio = 0.28
	content_hb.add_child(right_wrap)

	if has_fa:
		_build_trade_slot(right_wrap, _selected_fa, true)
	else:
		_build_trade_placeholder(right_wrap, "Select Free Agent", "SIGNING")
	return

func _build_trade_slot(parent: VBoxContainer, p: Resource, is_fa: bool) -> void:
	var accent = Color(0.35, 0.85, 0.45) if is_fa else Color(1.0, 0.48, 0.48)

	var slot_pnl = PanelContainer.new()
	slot_pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ssb = StyleBoxFlat.new()
	ssb.bg_color = Color(0.06, 0.14, 0.08, 0.9) if is_fa else Color(0.14, 0.06, 0.06, 0.9)
	ssb.border_color = accent
	ssb.border_width_left = 3
	ssb.border_width_right = 1
	ssb.border_width_top = 1
	ssb.border_width_bottom = 1
	ssb.set_corner_radius_all(6)
	ssb.content_margin_left = 12; ssb.content_margin_right = 10
	ssb.content_margin_top = 8; ssb.content_margin_bottom = 8
	slot_pnl.add_theme_stylebox_override("panel", ssb)
	parent.add_child(slot_pnl)

	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	slot_pnl.add_child(inner)

	var tag = Label.new()
	tag.text = "SIGNING" if is_fa else "RELEASING"
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", accent)
	inner.add_child(tag)

	var sep = HSeparator.new()
	inner.add_child(sep)

	var name_lbl = Label.new()
	name_lbl.text = "%s  #%d" % [p.name, p.number]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(name_lbl)

	var ovr = _calc_ovr(p)
	var ovr_lbl = Label.new()
	ovr_lbl.text = "OVR  %d" % ovr
	ovr_lbl.add_theme_font_size_override("font_size", 13)
	ovr_lbl.add_theme_color_override("font_color", _ovr_color(ovr))
	inner.add_child(ovr_lbl)

	var money_lbl = Label.new()
	if is_fa:
		money_lbl.text = "− $%s" % _fmt_funds(LeagueManager.get_free_agent_price(p))
		money_lbl.add_theme_color_override("font_color", Color(1.0, 0.48, 0.48))
	else:
		money_lbl.text = "+ $%s" % _fmt_funds(LeagueManager.get_release_value(p))
		money_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))
	money_lbl.add_theme_font_size_override("font_size", 15)
	inner.add_child(money_lbl)

func _build_trade_placeholder(parent: VBoxContainer, text: String, tag_text: String) -> void:
	var slot_pnl = PanelContainer.new()
	slot_pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ssb = StyleBoxFlat.new()
	ssb.bg_color = Color(0.1, 0.1, 0.12, 0.4)
	ssb.border_color = Color(0.3, 0.3, 0.35, 0.5)
	ssb.border_width_left = 2
	ssb.border_width_right = 1
	ssb.border_width_top = 1
	ssb.border_width_bottom = 1
	ssb.set_corner_radius_all(6)
	ssb.content_margin_left = 12; ssb.content_margin_right = 10
	ssb.content_margin_top = 8; ssb.content_margin_bottom = 8
	slot_pnl.add_theme_stylebox_override("panel", ssb)
	parent.add_child(slot_pnl)

	var inner = VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_pnl.add_child(inner)

	var tag = Label.new()
	tag.text = tag_text
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	inner.add_child(tag)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(lbl)

func _build_comparison_placeholder(parent: VBoxContainer) -> void:
	var pnl = PanelContainer.new()
	pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.2)
	sb.set_corner_radius_all(6)
	pnl.add_theme_stylebox_override("panel", sb)
	parent.add_child(pnl)

	var lbl = Label.new()
	lbl.text = "SELECT PLAYERS TO COMPARE"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pnl.add_child(lbl)

func _build_trade_comparison(parent: VBoxContainer, p_out: Resource, p_in: Resource) -> void:
	# Stat rows panel — constrained width so values sit close together
	var stat_pnl = PanelContainer.new()
	stat_pnl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var spb = StyleBoxFlat.new()
	spb.bg_color = Color(0.08, 0.08, 0.13, 0.85)
	spb.border_color = Color(0.22, 0.22, 0.32, 0.7)
	spb.set_border_width_all(1)
	spb.set_corner_radius_all(6)
	spb.set_content_margin_all(8)
	stat_pnl.add_theme_stylebox_override("panel", spb)
	parent.add_child(stat_pnl)

	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	stat_pnl.add_child(rows)

	for i in range(6):
		var key = STAT_KEYS[i]
		var v_out = int(p_out.get(key))
		var v_in = int(p_in.get(key))
		var delta = v_in - v_out
		var dcolor: Color
		if delta > 0: dcolor = Color(0.3, 1.0, 0.5)
		elif delta < 0: dcolor = Color(1.0, 0.42, 0.42)
		else: dcolor = Color(0.65, 0.65, 0.7)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		rows.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = STAT_LABELS[i]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.68))
		name_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(name_lbl)

		var vals_lbl = Label.new()
		vals_lbl.text = "%d → %d" % [v_out, v_in]
		vals_lbl.add_theme_font_size_override("font_size", 13)
		vals_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
		vals_lbl.custom_minimum_size = Vector2(76, 0)
		vals_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(vals_lbl)

		var delta_lbl = Label.new()
		delta_lbl.text = ("+%d" % delta) if delta > 0 else ("—" if delta == 0 else str(delta))
		delta_lbl.add_theme_font_size_override("font_size", 13)
		delta_lbl.add_theme_color_override("font_color", dcolor)
		delta_lbl.custom_minimum_size = Vector2(32, 0)
		delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(delta_lbl)

	# Net cost + confirm
	var sep = HSeparator.new()
	parent.add_child(sep)

	var team = LeagueManager.player_team
	var rel_val = LeagueManager.get_release_value(p_out)
	var sign_cost = LeagueManager.get_free_agent_price(p_in)
	var net_cost = sign_cost - rel_val
	var can_afford = team != null and team.funds >= net_cost

	var cost_hb = HBoxContainer.new()
	cost_hb.add_theme_constant_override("separation", 8)
	cost_hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(cost_hb)

	var cost_lbl = Label.new()
	cost_lbl.text = "NET COST:"
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.82))
	cost_hb.add_child(cost_lbl)

	var cost_val = Label.new()
	if net_cost <= 0:
		cost_val.text = "+ $%s" % _fmt_funds(-net_cost)
		cost_val.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45))
	elif can_afford:
		cost_val.text = "- $%s" % _fmt_funds(net_cost)
		cost_val.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
	else:
		cost_val.text = "- $%s" % _fmt_funds(net_cost)
		cost_val.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22))
	cost_val.add_theme_font_size_override("font_size", 14)
	cost_hb.add_child(cost_val)

	var confirm_btn = Button.new()
	confirm_btn.text = "CONFIRM TRADE"
	confirm_btn.add_theme_font_size_override("font_size", 14)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_btn.disabled = not can_afford
	if can_afford:
		_style_button(confirm_btn, Color(0.1, 0.42, 0.15), Color(0.2, 0.9, 0.4))
	else:
		_style_button(confirm_btn, Color(0.25, 0.1, 0.1), Color(0.5, 0.2, 0.2))
	if not can_afford:
		confirm_btn.tooltip_text = "Insufficient funds"
	confirm_btn.pressed.connect(_on_confirm_trade)
	parent.add_child(confirm_btn)

func _on_confirm_trade() -> void:
	if not _selected_roster or not _selected_fa: return
	var team = LeagueManager.player_team
	if not team: return

	var rel_val = LeagueManager.get_release_value(_selected_roster)
	var sign_cost = LeagueManager.get_free_agent_price(_selected_fa)
	var net_cost = sign_cost - rel_val

	if team.funds < net_cost:
		_show_message("Insufficient funds for this trade.")
		return

	var p_out = _selected_roster
	var p_in = _selected_fa

	var roster_idx = team.roster.find(p_out)
	if roster_idx >= 0:
		team.roster.remove_at(roster_idx)

	var fa_idx = LeagueManager.free_agents.find(p_in)
	if fa_idx >= 0:
		LeagueManager.free_agents.remove_at(fa_idx)

	team.roster.append(p_in)
	team.funds -= net_cost

	_selected_roster = null
	_selected_fa = null

	_refresh_panels()
	LeagueManager.save_season()

# ---------------------------------------------------------------------------
# Player card
# ---------------------------------------------------------------------------

func _create_player_card(p: Resource, is_fa: bool) -> Control:
	var col = _team_color

	var pnl = PanelContainer.new()
	pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.12, 0.12, 0.18, 0.8)
	sb_normal.border_color = col.darkened(0.2) if not is_fa else Color(0.2, 0.3, 0.48, 0.9)
	sb_normal.set_border_width_all(2)
	sb_normal.set_corner_radius_all(4)
	sb_normal.content_margin_left = 12; sb_normal.content_margin_right = 12
	sb_normal.content_margin_top = 8; sb_normal.content_margin_bottom = 8

	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(0.18, 0.18, 0.24, 0.95)
	sb_hover.border_color = col.lightened(0.2) if not is_fa else Color(0.3, 0.6, 1.0)

	pnl.add_theme_stylebox_override("panel", sb_normal)
	pnl.set_meta("sb_normal", sb_normal)
	pnl.set_meta("sb_hover", sb_hover)

	pnl.mouse_entered.connect(func():
		var is_sel = (_selected_roster == p and not is_fa) or (_selected_fa == p and is_fa)
		if not is_sel:
			pnl.add_theme_stylebox_override("panel", sb_hover)
	)
	pnl.mouse_exited.connect(func():
		var is_sel = (_selected_roster == p and not is_fa) or (_selected_fa == p and is_fa)
		if not is_sel:
			pnl.add_theme_stylebox_override("panel", sb_normal)
	)
	pnl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_card_clicked(p, is_fa)
	)

	var pvbox = VBoxContainer.new()
	pnl.add_child(pvbox)

	# Header row
	var header_hb = HBoxContainer.new()
	header_hb.add_theme_constant_override("separation", 8)
	pvbox.add_child(header_hb)

	var num_lbl = Label.new()
	num_lbl.text = "#%d " % p.number if "number" in p else ""
	num_lbl.add_theme_font_size_override("font_size", 18)
	num_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	header_hb.add_child(num_lbl)

	if "portrait" in p and p.portrait:
		var pr = TextureRect.new()
		pr.texture = p.portrait
		pr.custom_minimum_size = Vector2(96, 96)
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header_hb.add_child(pr)

	var n_lbl = Label.new()
	n_lbl.text = p.name
	n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n_lbl.add_theme_font_size_override("font_size", 20)
	header_hb.add_child(n_lbl)

	# OVR badge
	var ovr = _calc_ovr(p)
	header_hb.add_child(_make_badge(
		"OVR  %d" % ovr,
		Color(0.95, 0.82, 0.2),
		Color(0.28, 0.22, 0.04, 0.9),
		Color(0.7, 0.58, 0.1, 0.8)
	))

	# Price badge
	if is_fa:
		header_hb.add_child(_make_badge(
			"SIGN  $%s" % _fmt_funds(LeagueManager.get_free_agent_price(p)),
			Color(0.35, 0.95, 0.5),
			Color(0.05, 0.22, 0.09, 0.9),
			Color(0.2, 0.65, 0.3, 0.75)
		))
	else:
		header_hb.add_child(_make_badge(
			"+$%s" % _fmt_funds(LeagueManager.get_release_value(p)),
			Color(1.0, 0.62, 0.25),
			Color(0.26, 0.12, 0.03, 0.9),
			Color(0.72, 0.38, 0.1, 0.75)
		))

	# Stat panel
	if "speed" in p:
		var stat_panel = PanelContainer.new()
		var stat_bg = StyleBoxFlat.new()
		stat_bg.bg_color = Color(0.08, 0.08, 0.12, 0.7)
		stat_bg.border_color = col.darkened(0.4)
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

		for j in range(6):
			var s_val = float(p.get(STAT_KEYS[j]))
			var s_vbox = VBoxContainer.new()
			s_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_vbox.add_theme_constant_override("separation", 2)

			var s_lbl = Label.new()
			s_lbl.text = STAT_LABELS[j]
			s_lbl.add_theme_font_size_override("font_size", 12)
			s_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			s_vbox.add_child(s_lbl)

			var bar_hb = HBoxContainer.new()
			bar_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_vbox.add_child(bar_hb)

			var bar = ProgressBar.new()
			bar.min_value = 0; bar.max_value = 100; bar.value = s_val
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			var sb_bar_bg = StyleBoxFlat.new()
			sb_bar_bg.bg_color = Color(0.05, 0.05, 0.05, 0.8)
			sb_bar_bg.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("background", sb_bar_bg)

			var c: Color
			if s_val <= 50.0:
				c = Color(0.2, 0.1, 0.4).lerp(Color(0.1, 0.5, 0.9), s_val / 50.0)
			else:
				c = Color(0.1, 0.5, 0.9).lerp(Color(0.5, 1.0, 1.0), (s_val - 50.0) / 50.0)

			var sb_fill = StyleBoxFlat.new()
			sb_fill.bg_color = c
			sb_fill.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("fill", sb_fill)
			bar_hb.add_child(bar)

			var v_lbl = Label.new()
			v_lbl.text = str(int(s_val))
			v_lbl.custom_minimum_size = Vector2(22, 0)
			v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v_lbl.add_theme_font_size_override("font_size", 12)
			v_lbl.add_theme_color_override("font_color", c)
			bar_hb.add_child(v_lbl)

			stat_grid.add_child(s_vbox)

	return pnl

# ---------------------------------------------------------------------------
# Selection logic
# ---------------------------------------------------------------------------

func _on_card_clicked(p: Resource, is_fa: bool) -> void:
	if is_fa:
		_selected_fa = null if _selected_fa == p else p
	else:
		_selected_roster = null if _selected_roster == p else p
	_update_card_highlights()
	_refresh_trade_panel()

func _update_card_highlights() -> void:
	var sel_color = Color(1.0, 0.85, 0.1)
	for p in _roster_cards:
		var card = _roster_cards[p]
		if not is_instance_valid(card): continue
		if _selected_roster == p:
			card.add_theme_stylebox_override("panel", _make_selected_sb(card.get_meta("sb_normal"), sel_color))
		else:
			card.add_theme_stylebox_override("panel", card.get_meta("sb_normal"))
	for p in _fa_cards:
		var card = _fa_cards[p]
		if not is_instance_valid(card): continue
		if _selected_fa == p:
			card.add_theme_stylebox_override("panel", _make_selected_sb(card.get_meta("sb_normal"), sel_color))
		else:
			card.add_theme_stylebox_override("panel", card.get_meta("sb_normal"))

func _make_selected_sb(base: StyleBoxFlat, highlight: Color) -> StyleBoxFlat:
	var sb = base.duplicate()
	sb.bg_color = Color(0.22, 0.18, 0.08, 0.97)
	sb.border_color = highlight
	sb.set_border_width_all(3)
	return sb

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_badge(text: String, text_color: Color, bg_color: Color, border_color: Color) -> Control:
	var pnl = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 9; sb.content_margin_right = 9
	sb.content_margin_top = 3; sb.content_margin_bottom = 3
	pnl.add_theme_stylebox_override("panel", sb)
	pnl.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", text_color)
	pnl.add_child(lbl)
	return pnl

func _show_message(msg: String) -> void:
	if not _trade_inner: return
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_inner.add_child(lbl)
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(lbl): lbl.queue_free()
	)

func _calc_ovr(p: Resource) -> int:
	return int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))

func _ovr_color(ovr: int) -> Color:
	if ovr >= 75: return Color(1.0, 0.85, 0.1)
	if ovr >= 55: return Color(0.7, 0.7, 0.85)
	return Color(0.8, 0.55, 0.35)

func _style_button(btn: Button, bg: Color, border: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg; sb.border_color = border
	sb.set_border_width_all(2); sb.set_corner_radius_all(6)
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.content_margin_left = 16; sb.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", sb)
	var hov = sb.duplicate(); hov.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hov)
	var dis = sb.duplicate()
	dis.bg_color = Color(bg.r * 0.4, bg.g * 0.4, bg.b * 0.4, 0.6)
	dis.border_color = Color(border.r * 0.4, border.g * 0.4, border.b * 0.4, 0.5)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))

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
