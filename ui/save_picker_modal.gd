extends Control

@onready var saves_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/MarginContainer2/VBoxContainer
@onready var btn_close: Button = $PanelContainer/VBoxContainer/MarginContainer3/BtnClose

func _ready() -> void:
	btn_close.pressed.connect(_on_close_pressed)
	_populate_saves()
	
	# Transition in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _populate_saves() -> void:
	# Clear old
	for child in saves_container.get_children():
		child.queue_free()
		
	var saves = LeagueManager.get_all_saves()
	
	if saves.is_empty():
		var lbl = Label.new()
		lbl.text = "No saved seasons found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		saves_container.add_child(lbl)
		btn_close.grab_focus()
		return
		
	for i in range(saves.size()):
		var s = saves[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		
		# Stylish Button
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.1, 0.15, 0.8)
		sb.border_color = Color(0.3, 0.3, 0.4, 0.5)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", sb)
		
		var sb_h = sb.duplicate()
		sb_h.bg_color = Color(0.15, 0.15, 0.25, 1.0)
		sb_h.border_color = s["color"]
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("focus", sb_h)
		
		var sb_p = sb.duplicate()
		sb_p.bg_color = Color(0.05, 0.05, 0.08, 1.0)
		btn.add_theme_stylebox_override("pressed", sb_p)
		
		# Content
		var hb = HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.add_theme_constant_override("separation", 20)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Add margins manually via a MarginContainer
		var mc = MarginContainer.new()
		mc.set_anchors_preset(Control.PRESET_FULL_RECT)
		mc.add_theme_constant_override("margin_left", 20)
		mc.add_theme_constant_override("margin_right", 20)
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(mc)
		mc.add_child(hb)
		
		# Color square / Logo placeholder
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(40, 40)
		color_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		color_rect.color = s["color"]
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(color_rect)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(vbox)
		
		var title = Label.new()
		title.text = s["team_name"]
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", s["color"])
		vbox.add_child(title)
		
		var sub = Label.new()
		sub.text = "Season %d  |  Record: %d - %d" % [s["season"], s["wins"], s["losses"]]
		sub.add_theme_font_size_override("font_size", 16)
		sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(sub)
		
		# Delete Button
		var del_btn = Button.new()
		del_btn.text = "X"
		del_btn.custom_minimum_size = Vector2(40, 40)
		del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var dsb = StyleBoxFlat.new()
		dsb.bg_color = Color(0.3, 0.1, 0.1, 0.8)
		dsb.set_corner_radius_all(4)
		del_btn.add_theme_stylebox_override("normal", dsb)
		
		var dsb_h = dsb.duplicate()
		dsb_h.bg_color = Color(0.8, 0.2, 0.2, 1.0)
		del_btn.add_theme_stylebox_override("hover", dsb_h)
		del_btn.add_theme_stylebox_override("focus", dsb_h)
		
		# Important: We don't want the container button to steal focus from the delete button
		# But we also don't want clicking the delete button to trigger the main button.
		del_btn.pressed.connect(_on_delete_pressed.bind(s["filename"]))
		hb.add_child(del_btn)
		
		btn.pressed.connect(_on_save_selected.bind(s["filename"]))
		saves_container.add_child(btn)
		
		if i == 0:
			btn.grab_focus()

func _on_save_selected(filename: String) -> void:
	# Disable buttons immediately
	get_tree().root.gui_disable_input = true
	
	if LeagueManager.load_season(filename):
		get_tree().root.gui_disable_input = false
		get_tree().change_scene_to_file("res://ui/season_hub.tscn")
	else:
		get_tree().root.gui_disable_input = false
		print("Failed to load save: ", filename)

func _on_delete_pressed(filename: String) -> void:
	LeagueManager.delete_season_save(filename)
	_populate_saves()

func _on_close_pressed() -> void:
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
