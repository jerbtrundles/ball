extends Control

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var stats_panel: Panel = $StatsPanel
@onready var stats_grid: GridContainer = $StatsPanel/VBox/Grid

@onready var btn_resume: Button = $MenuContainer/BtnResume
@onready var btn_stats: Button = $MenuContainer/BtnStats
@onready var btn_quit: Button = $MenuContainer/BtnQuit
@onready var btn_close_stats: Button = $StatsPanel/VBox/BtnCloseStats

func _ready() -> void:
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_stats.pressed.connect(_on_stats_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_close_stats.pressed.connect(_on_close_stats_pressed)
	
	stats_panel.hide()
	menu_container.show()
	btn_resume.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# If we are in the stats screen, back out to menu
		if stats_panel.visible:
			_on_close_stats_pressed()
			get_viewport().set_input_as_handled()
		else:
			# Otherwise resume game
			_on_resume_pressed()
			get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	# Clear the game manager and go to main menu
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		# If we came from quick match
		pass
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _on_stats_pressed() -> void:
	_populate_stats()
	menu_container.hide()
	stats_panel.show()
	btn_close_stats.grab_focus()

func _on_close_stats_pressed() -> void:
	stats_panel.hide()
	menu_container.show()
	btn_resume.grab_focus()

func _populate_stats() -> void:
	# Clear existing children in grid
	for child in stats_grid.get_children():
		child.queue_free()
	
	# Headers
	var headers = ["Player", "PTS", "2PT", "3PT", "REB", "AST", "STL", "COIN", "PWR"]
	stats_grid.columns = headers.size()
	
	for h in headers:
		var lbl = Label.new()
		lbl.text = h
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2)) # Yellow header
		stats_grid.add_child(lbl)
	
	var gm = get_tree().get_first_node_in_group("game_manager")
	if not gm or not "player_stats" in gm:
		return
	
	var teams_stats = gm.player_stats
	var team_data = gm.team_data_store if "team_data_store" in gm else [null, null]
	var free_points = gm.free_points if "free_points" in gm else [0, 0]
	
	for t in range(teams_stats.size()):
		_add_team_header(t, team_data[t])
		
		# Track totals for the team
		var totals = {"points": 0, "2pt": 0, "3pt": 0, "rebounds": 0, "assists": 0, "steals": 0, "coins": 0, "powerups": 0}
		
		for stat_dict in teams_stats[t]:
			_add_stat_row(stat_dict, t, team_data[t])
			for k in totals.keys():
				totals[k] += stat_dict.get(k, 0)
		
		# Add Free Points row if any
		if free_points[t] > 0:
			var dict = {
				"name": "Free Points",
				"points": free_points[t],
				"2pt": "-",
				"3pt": "-",
				"rebounds": "-",
				"assists": "-",
				"steals": "-",
				"coins": "-",
				"powerups": "-"
			}
			_add_stat_row(dict, t, team_data[t], true)
			totals["points"] += free_points[t]
			
		# Team Totals row
		var total_dict = {
			"name": "TOTAL",
			"points": totals["points"],
			"2pt": totals["2pt"],
			"3pt": totals["3pt"],
			"rebounds": totals["rebounds"],
			"assists": totals["assists"],
			"steals": totals["steals"],
			"coins": totals["coins"],
			"powerups": totals["powerups"]
		}
		_add_stat_row(total_dict, t, team_data[t], true)

func _add_team_header(team_idx: int, t_data: Resource) -> void:
	# Add a row that spans across, we accomplish this by just adding one label 
	# and blank labels for the rest, or just rely on the grid
	var team_name = "TEAM %d" % (team_idx + 1)
	var team_color = Color(0.2, 0.5, 1.0) if team_idx == 0 else Color(1.0, 0.3, 0.2)
	
	if t_data != null:
		team_name = t_data.name.to_upper()
		team_color = t_data.color_primary
		
	var lbl = Label.new()
	lbl.text = team_name
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", team_color)
	stats_grid.add_child(lbl)
	
	# Fill remaining columns with empty labels for this row
	for i in range(stats_grid.columns - 1):
		stats_grid.add_child(Label.new())

func _add_stat_row(data: Dictionary, team_idx: int, t_data: Resource, is_summary: bool = false) -> void:
	var name_lbl = Label.new()
	name_lbl.text = data["name"]
	var color = Color(0.2, 0.5, 1.0) if team_idx == 0 else Color(1.0, 0.3, 0.2)
	if t_data != null:
		color = t_data.color_primary
		
	if is_summary:
		# Make summary rows italics or slightly distinct
		name_lbl.modulate.a = 0.8
		
	name_lbl.add_theme_color_override("font_color", color)
	stats_grid.add_child(name_lbl)
	
	for key in ["points", "2pt", "3pt", "rebounds", "assists", "steals", "coins", "powerups"]:
		var lbl = Label.new()
		lbl.text = str(data.get(key, 0))
		lbl.add_theme_color_override("font_color", color)
		if is_summary:
			lbl.modulate.a = 0.8
		stats_grid.add_child(lbl)
