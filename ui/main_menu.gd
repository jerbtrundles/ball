extends Control

func _ready() -> void:
	# Connect buttons
	var btn_quick = $VBoxContainer/BtnQuickMatch
	var btn_season = $VBoxContainer/BtnNewSeason
	var btn_debug = $VBoxContainer/BtnDebugGame
	var btn_quit = $VBoxContainer/BtnQuit
	
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

func _on_new_season_pressed() -> void:
	print("Starting New Season...")
	LeagueManager.generate_default_league()
	# Transition to Season Hub
	get_tree().change_scene_to_file("res://ui/season_hub.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
