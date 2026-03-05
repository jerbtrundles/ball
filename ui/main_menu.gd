extends Control

func _ready() -> void:
	# Build Thematic Background
	var bg_tex = load("res://assets/images/ui/main_menu_bg.png")
	if bg_tex:
		if has_node("ColorRect"):
			$ColorRect.hide()
			
		var bg_rect = TextureRect.new()
		bg_rect.texture = bg_tex
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg_rect)
		move_child(bg_rect, 0)
		
	# Enclose VBoxContainer in a contrasting card
	var vbox = $VBoxContainer
	remove_child(vbox)
	
	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.95) # Dark opaque blue/purple
	sb.border_color = Color(0.9, 0.3, 0.5, 0.8) # Neon pink border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 60
	sb.content_margin_right = 60
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	card.add_theme_stylebox_override("panel", sb)
	
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_child(vbox)
	add_child(card)
	
	# Connect buttons
	var btn_quick = vbox.get_node("BtnQuickMatch")
	var btn_season = vbox.get_node("BtnNewSeason")
	var btn_debug = vbox.get_node("BtnDebugGame")
	var btn_quit = vbox.get_node("BtnQuit")
	
	if LeagueManager.has_saved_season():
		var btn_resume = btn_season.duplicate()
		btn_resume.text = "LOAD FRANCHISE"
		btn_resume.name = "BtnLoadSeason"
		vbox.add_child(btn_resume)
		vbox.move_child(btn_resume, btn_season.get_index())
		btn_resume.pressed.connect(_on_load_season_pressed)
		
	btn_quick.pressed.connect(_on_quick_match_pressed)
	btn_season.pressed.connect(_on_new_season_pressed)
	btn_debug.pressed.connect(_on_debug_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	# Grab focus for gamepad support
	btn_quick.grab_focus()

func _on_debug_pressed() -> void:
	LeagueManager.start_debug_match()

func _on_quick_match_pressed() -> void:
	# Go to Quick Match Setup
	get_tree().change_scene_to_file("res://ui/quick_match_setup.tscn")

func _on_load_season_pressed() -> void:
	var picker = load("res://ui/save_picker_modal.tscn").instantiate()
	add_child(picker)

func _on_new_season_pressed() -> void:
	print("Starting Franchise Setup...")
	get_tree().change_scene_to_file("res://ui/season_setup.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
