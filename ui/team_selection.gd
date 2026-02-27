extends Control

@onready var background: TextureRect = $Background
@onready var team_name_label: Label = $Content/TeamInfo/TeamName
@onready var team_strength_label: Label = $Content/TeamInfo/TeamStrength
@onready var team_logo: TextureRect = $Content/TeamInfo/Logo
@onready var roster_container: Container = $Content/TeamInfo/RosterGrid
@onready var btn_prev: Button = $BtnPrev
@onready var btn_next: Button = $BtnNext
@onready var btn_select: Button = $Content/BtnSelect

var teams: Array[Resource] = []
var current_index: int = 0

func _ready() -> void:
	# Fetch teams from all divisions for selection
	# Using LeagueManager.divisions
	teams = []
	for div in LeagueManager.divisions:
		if div.has("teams"):
			teams.append_array(div["teams"])
	
	if teams.is_empty():
		push_error("No teams found in LeagueManager! Generating default league...")
		LeagueManager.generate_default_league()
		for div in LeagueManager.divisions:
			teams.append_array(div["teams"])
	
	_update_ui()
	
	btn_prev.pressed.connect(_on_prev_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	btn_select.pressed.connect(_on_select_pressed)
	
	# Grab focus
	btn_select.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _update_ui() -> void:
	if teams.is_empty():
		return
		
	var team = teams[current_index]
	
	# Update Text
	team_name_label.text = team.name
	
	# Calculate Team Strength
	var strength = 0
	for p in team.roster:
		strength += _calculate_player_rating(p)
	if team.roster.size() > 0:
		strength = round(strength / float(team.roster.size()))
	
	team_strength_label.text = "Overall Strength: %d | Wins: %d" % [int(strength), team.wins]
	
	# Update Logo
	if team.logo:
		team_logo.texture = team.logo
	else:
		team_logo.texture = null
		
	# Update Background (Court Preview)
	# Use CourtThemes to get a preview if possible, or just a color
	var theme = CourtThemes.get_home_court(team)
	if theme:
		# We can't easily "preview" the 3D court in a TextureRect without a SubViewport,
		# but we can set the background color to the court's floor color for now.
		# A SubViewportContainer would be better for a real preview.
		# For now, let's just use the floor color and maybe a pattern.
		if background:
			# Create a gradient or simple color texture
			var placeholder = GradientTexture2D.new()
			placeholder.width = 1280
			placeholder.height = 720
			placeholder.fill = GradientTexture2D.FILL_RADIAL
			placeholder.fill_from = Vector2(0.5, 0.5)
			placeholder.fill_to = Vector2(1.0, 1.0)
			
			var grad = Gradient.new()
			grad.set_color(0, theme.floor_color)
			grad.set_color(1, theme.ambient_color)
			placeholder.gradient = grad
			
			background.texture = placeholder
	
	# Update Roster
	# Clear existing
	for child in roster_container.get_children():
		child.queue_free()
		
	# Add player cards
	for player in team.roster:
		var card = _create_player_card(player)
		roster_container.add_child(card)

func _create_player_card(player: Resource) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	
	# Add a nice highlight border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.6, 1.0, 0.8) # Highlight blue
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(container)
	
	var lbl_name = Label.new()
	lbl_name.text = player.name
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_name.custom_minimum_size = Vector2(170, 0) # Constrain to force word-wrap instead of growing panel
	lbl_name.add_theme_font_size_override("font_size", 18)
	container.add_child(lbl_name)
	
	var sep = HSeparator.new()
	container.add_child(sep)
	
	if "speed" in player:
		var rating = _calculate_player_rating(player)
		var lbl_ovr = Label.new()
		lbl_ovr.text = "OVR: %d" % rating
		lbl_ovr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_ovr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold
		lbl_ovr.add_theme_font_size_override("font_size", 20)
		container.add_child(lbl_ovr)
		
		# Individual stats grid
		var grid = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 15)
		grid.add_theme_constant_override("v_separation", 2)
		
		var stats = [
			["SPD", player.speed],
			["SHT", player.shot],
			["PAS", player.pass_skill],
			["TCK", player.tackle],
			["STR", player.strength],
			["AGG", player.aggression]
		]
		
		for stat in stats:
			var lbl_stat_name = Label.new()
			lbl_stat_name.text = stat[0]
			lbl_stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_stat_name.add_theme_font_size_override("font_size", 12)
			lbl_stat_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
			var lbl_stat_val = Label.new()
			lbl_stat_val.text = str(int(round(stat[1])))
			lbl_stat_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_stat_val.add_theme_font_size_override("font_size", 12)
			lbl_stat_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			
			grid.add_child(lbl_stat_name)
			grid.add_child(lbl_stat_val)
			
		container.add_child(grid)
	else:
		var lbl_stats = Label.new()
		lbl_stats.text = "OVR: ??"
		lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(lbl_stats)
	
	return panel

func _calculate_player_rating(p: Resource) -> int:
	if not "speed" in p: return 0
	var total = p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression
	return int(round(total / 6.0))

func _on_prev_pressed() -> void:
	current_index -= 1
	if current_index < 0:
		current_index = teams.size() - 1
	_update_ui()

func _on_next_pressed() -> void:
	current_index += 1
	if current_index >= teams.size():
		current_index = 0
	_update_ui()

func _on_select_pressed() -> void:
	var selected_team = teams[current_index]
	LeagueManager.player_team = selected_team
	print("Selected Team: ", selected_team.name)
	
	# Go to Season Hub
	get_tree().change_scene_to_file("res://ui/season_hub.tscn")
