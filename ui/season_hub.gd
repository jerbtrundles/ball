extends Control

@onready var lbl_season_info: Label = $VBoxContainer/SeasonInfo

func _ready() -> void:
	var btn_play = $VBoxContainer/BtnPlayNext
	var btn_main = $VBoxContainer/BtnMainMenu
	
	btn_play.pressed.connect(_on_play_next_pressed)
	btn_main.pressed.connect(_on_main_menu_pressed)
	
	btn_play.grab_focus()
	
	_update_ui()

func _update_ui() -> void:
	if LeagueManager.player_team:
		var p_team = LeagueManager.player_team
		lbl_season_info.text = "Season %d\nTeam: %s\nRecord: %d-%d" % [
			LeagueManager.current_season,
			p_team.name,
			p_team.wins,
			p_team.losses
		]
	else:
		lbl_season_info.text = "No Season Data"

func _on_play_next_pressed() -> void:
	var opponent = LeagueManager.get_next_opponent()
	if opponent:
		print("Playing against: ", opponent.name)
		LeagueManager.start_quick_match(LeagueManager.player_team, opponent)
	else:
		print("No opponent found!")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
