extends Control

@onready var team_a_name: Label = $VBoxContainer/HBox_Teams/VBox_TeamA/TeamName
@onready var team_a_logo: TextureRect = $VBoxContainer/HBox_Teams/VBox_TeamA/LogoRect
@onready var team_a_container: Control = $VBoxContainer/HBox_Teams/VBox_TeamA

@onready var team_b_name: Label = $VBoxContainer/HBox_Teams/VBox_TeamB/TeamName
@onready var team_b_logo: TextureRect = $VBoxContainer/HBox_Teams/VBox_TeamB/LogoRect
@onready var team_b_container: Control = $VBoxContainer/HBox_Teams/VBox_TeamB

@onready var opt_quarters: OptionButton = $VBoxContainer/HBox_Quarters/OptionButton
@onready var chk_items: CheckBox = $VBoxContainer/HBox_Items/CheckBox

# Side selection replaced by cycling
@onready var lbl_side: Label = $VBoxContainer/HBox_Side/SideLabel
@onready var side_container: Control = $VBoxContainer/HBox_Side

@onready var btn_start: Button = $VBoxContainer/BtnStart
@onready var btn_back: Button = $VBoxContainer/BtnBack

var available_teams: Array = []
var team_a_index: int = 0
var team_b_index: int = 1
var selected_side: int = 0 # 0=TeamA, 1=TeamB, 2=Spectate

func _ready() -> void:
	if LeagueManager.divisions.is_empty():
		LeagueManager.generate_default_league()
	
	for div in LeagueManager.divisions:
		available_teams.append_array(div["teams"])
	
	# Quarter Options
	opt_quarters.add_item("15 Seconds", 15)
	opt_quarters.add_item("30 Seconds", 30)
	opt_quarters.add_item("1 Minute", 60)
	opt_quarters.add_item("2 Minutes", 120)
	opt_quarters.select(1) # Default 30s
	
	btn_start.pressed.connect(_on_start_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	
	# Handle input for Team A container
	team_a_container.focus_mode = Control.FOCUS_ALL
	team_a_container.gui_input.connect(_on_team_a_input)
	
	# Handle input for Team B container
	team_b_container.focus_mode = Control.FOCUS_ALL
	team_b_container.gui_input.connect(_on_team_b_input)
	
	# Handle input for Side container
	side_container.focus_mode = Control.FOCUS_ALL
	side_container.gui_input.connect(_on_side_input)
	
	_update_ui()
	team_a_container.grab_focus()

func _input(event: InputEvent) -> void:
	# Global simple navigation handling if focus is lost or general
	pass

func _on_team_a_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_cycle_team_a(-1)
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_cycle_team_a(1)
		accept_event()

func _on_team_b_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_cycle_team_b(-1)
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_cycle_team_b(1)
		accept_event()

func _on_side_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_cycle_side(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_cycle_side(1)
		accept_event()

func _cycle_team_a(dir: int) -> void:
	team_a_index = (team_a_index + dir) % available_teams.size()
	if team_a_index < 0: team_a_index = available_teams.size() - 1
	_update_ui()

func _cycle_team_b(dir: int) -> void:
	team_b_index = (team_b_index + dir) % available_teams.size()
	if team_b_index < 0: team_b_index = available_teams.size() - 1
	_update_ui()

func _cycle_side(dir: int) -> void:
	selected_side = (selected_side + dir) % 3
	if selected_side < 0: selected_side = 2
	_update_ui()

func _update_ui() -> void:
	if available_teams.size() > 0:
		var t_a = available_teams[team_a_index]
		var t_b = available_teams[team_b_index]
		
		team_a_name.text = t_a.name
		team_a_name.modulate = t_a.color_primary
		team_a_logo.texture = t_a.logo
		
		team_b_name.text = t_b.name
		team_b_name.modulate = t_b.color_primary
		team_b_logo.texture = t_b.logo
		
		# Update Side Label
		if selected_side == 0:
			lbl_side.text = "Play as " + t_a.name
			lbl_side.modulate = t_a.color_primary
		elif selected_side == 1:
			lbl_side.text = "Play as " + t_b.name
			lbl_side.modulate = t_b.color_primary
		else:
			lbl_side.text = "Spectate (AI vs AI)"
			lbl_side.modulate = Color.WHITE

func _on_start_pressed() -> void:
	var t_a = available_teams[team_a_index]
	var t_b = available_teams[team_b_index]
	
	var q_len = opt_quarters.get_selected_metadata()
	if q_len == null: q_len = 30.0
	
	var items = chk_items.button_pressed
	
	var config = {
		"quarter_duration": float(q_len),
		"items_enabled": items,
		"human_team_index": selected_side
	}
	
	LeagueManager.start_quick_match(t_a, t_b, config)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
