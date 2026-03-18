extends Control
## Generic load modal — shows franchise (season) saves and tournament saves in distinct sections.

@onready var saves_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/MarginContainer2/VBoxContainer
@onready var btn_close: Button = $PanelContainer/VBoxContainer/MarginContainer3/BtnClose

const FRANCHISE_COL  = Color(0.3,  0.75, 1.0)   # Cyan-blue for franchises
const TOURNAMENT_COL = Color(1.0,  0.82, 0.1)   # Gold for tournaments

func _ready() -> void:
	btn_close.pressed.connect(_on_close_pressed)
	_populate_saves()

	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _populate_saves() -> void:
	for child in saves_container.get_children():
		child.queue_free()

	var season_saves     = LeagueManager.get_all_saves()
	var tournament_saves = LeagueManager.get_all_tournament_saves()

	if season_saves.is_empty() and tournament_saves.is_empty():
		var lbl = Label.new()
		lbl.text = "No saves found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		saves_container.add_child(lbl)
		btn_close.grab_focus()
		return

	# ── Franchise Section ─────────────────────────────────────────────────
	if not season_saves.is_empty():
		saves_container.add_child(_section_header("FRANCHISE", FRANCHISE_COL))
		for i in range(season_saves.size()):
			var s = season_saves[i]
			var sub = "Season %d  |  Record: %d - %d" % [s["season"], s["wins"], s["losses"]]
			var btn = _save_button(s["team_name"], sub, s["color"], FRANCHISE_COL)
			btn.pressed.connect(_on_franchise_selected.bind(s["filename"]))
			var del_btn = _delete_button()
			del_btn.pressed.connect(_on_delete_franchise.bind(s["filename"]))
			_attach_del_to_button(btn, del_btn)
			saves_container.add_child(btn)
			if i == 0 and tournament_saves.is_empty():
				btn.grab_focus()

	# ── Tournament Section ────────────────────────────────────────────────
	if not tournament_saves.is_empty():
		if not season_saves.is_empty():
			saves_container.add_child(HSeparator.new())
		saves_container.add_child(_section_header("TOURNAMENT", TOURNAMENT_COL))
		for i in range(tournament_saves.size()):
			var s = tournament_saves[i]
			var status = "In Progress" if s["is_active"] else "Completed"
			var sub = "%d-Team  |  %s  |  %s" % [s["tournament_size"], s["round_name"], status]
			var btn = _save_button(s["team_name"], sub, s["color"], TOURNAMENT_COL)
			btn.pressed.connect(_on_tournament_selected.bind(s["filename"]))
			var del_btn = _delete_button()
			del_btn.pressed.connect(_on_delete_tournament.bind(s["filename"]))
			_attach_del_to_button(btn, del_btn)
			saves_container.add_child(btn)
			if i == 0 and season_saves.is_empty():
				btn.grab_focus()

func _section_header(text: String, col: Color) -> HBoxContainer:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)

	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(4, 24)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = col
	hb.add_child(swatch)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", col)
	hb.add_child(lbl)

	return hb

func _save_button(team_name: String, subtitle: String, team_color: Color, accent: Color) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 72)

	var sb = StyleBoxFlat.new()
	sb.bg_color     = Color(0.09, 0.09, 0.14, 0.85)
	sb.border_color = Color(0.25, 0.25, 0.35, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(7)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_h = sb.duplicate()
	sb_h.bg_color     = Color(0.13, 0.13, 0.20, 1.0)
	sb_h.border_color = accent
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("focus", sb_h)

	var mc = MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left",  14)
	mc.add_theme_constant_override("margin_right", 14)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(mc)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(hb)

	var color_block = ColorRect.new()
	color_block.custom_minimum_size = Vector2(8, 44)
	color_block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	color_block.color = team_color
	color_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(color_block)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = team_name
	title_lbl.add_theme_font_size_override("font_size", 21)
	title_lbl.add_theme_color_override("font_color", team_color)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)

	return btn

func _delete_button() -> Button:
	var del_btn = Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size = Vector2(36, 36)
	del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var dsb = StyleBoxFlat.new()
	dsb.bg_color = Color(0.28, 0.08, 0.08, 0.85)
	dsb.set_corner_radius_all(5)
	del_btn.add_theme_stylebox_override("normal", dsb)

	var dsb_h = dsb.duplicate()
	dsb_h.bg_color = Color(0.75, 0.15, 0.15, 1.0)
	del_btn.add_theme_stylebox_override("hover", dsb_h)
	del_btn.add_theme_stylebox_override("focus", dsb_h)

	return del_btn

func _attach_del_to_button(btn: Button, del_btn: Button) -> void:
	var mc = btn.get_child(0)
	if mc and mc is MarginContainer:
		var hb = mc.get_child(0)
		if hb and hb is HBoxContainer:
			del_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			hb.add_child(del_btn)

# ─────────────────────────────────────────────────────────────────────────────
func _on_franchise_selected(filename: String) -> void:
	get_tree().root.gui_disable_input = true
	if LeagueManager.load_season(filename):
		get_tree().root.gui_disable_input = false
		get_tree().change_scene_to_file("res://ui/season_hub.tscn")
	else:
		get_tree().root.gui_disable_input = false
		push_warning("Failed to load franchise save: " + filename)

func _on_tournament_selected(filename: String) -> void:
	get_tree().root.gui_disable_input = true
	if LeagueManager.load_tournament(filename):
		get_tree().root.gui_disable_input = false
		get_tree().change_scene_to_file("res://ui/tournament_hub.tscn")
	else:
		get_tree().root.gui_disable_input = false
		push_warning("Failed to load tournament save: " + filename)

func _on_delete_franchise(filename: String) -> void:
	LeagueManager.delete_season_save(filename)
	_populate_saves()

func _on_delete_tournament(filename: String) -> void:
	LeagueManager.delete_tournament_save(filename)
	_populate_saves()

func _on_close_pressed() -> void:
	queue_free()

func _input(event: InputEvent) -> void:
	# Trap focus inside modal
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		btn_close.grab_focus()

	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
