extends CanvasLayer
## HUD — displays score, clock, quarter, and mini-map.

@onready var team0_score_label: Label = $MarginContainer/TopBar/Team0Score
@onready var team1_score_label: Label = $MarginContainer/TopBar/Team1Score
@onready var clock_label: Label = $MarginContainer/TopBar/Clock
@onready var quarter_label: Label = $MarginContainer/TopBar/Quarter
@onready var message_label: Label = $CenterMessage
@onready var team0_name_label: Label = $MarginContainer/TopBar/Team0Name
@onready var team1_name_label: Label = $MarginContainer/TopBar/Team1Name

var game_manager: Node = null

func _ready() -> void:
	add_to_group("hud")
	await get_tree().process_frame
	game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.score_changed.connect(_on_score_changed)
		game_manager.clock_changed.connect(_on_clock_changed)
		game_manager.quarter_changed.connect(_on_quarter_changed)
		game_manager.game_over.connect(_on_game_over)
		if game_manager.has_signal("teams_updated"):
			game_manager.teams_updated.connect(_update_team_info)
	
	# Initialize
	_on_score_changed(0, 0)
	_on_score_changed(1, 0)
	_on_quarter_changed(1)
	if message_label:
		message_label.visible = false
		
	# Update team names/colors if game_manager has them
	if game_manager and "team_data_store" in game_manager:
		var store = game_manager.team_data_store
		if store[0] and store[1]:
			_update_team_info(store[0], store[1])

func _update_team_info(t0: Resource, t1: Resource) -> void:
	if team0_name_label:
		team0_name_label.text = t0.name
		team0_name_label.modulate = t0.color_primary
	if team0_score_label:
		team0_score_label.modulate = t0.color_primary
		
	if team1_name_label:
		team1_name_label.text = t1.name
		team1_name_label.modulate = t1.color_primary
	if team1_score_label:
		team1_score_label.modulate = t1.color_primary

func _on_score_changed(team_index: int, new_score: int) -> void:
	if team_index == 0 and team0_score_label:
		team0_score_label.text = str(new_score)
	elif team_index == 1 and team1_score_label:
		team1_score_label.text = str(new_score)

func _on_clock_changed(time_remaining: float) -> void:
	if clock_label == null:
		return
	var mins = int(time_remaining) / 60
	var secs = int(time_remaining) % 60
	clock_label.text = "%d:%02d" % [mins, secs]

func _on_quarter_changed(quarter: int) -> void:
	if quarter_label:
		quarter_label.text = "Q%d" % quarter

func _on_game_over(winner_team: int) -> void:
	if message_label:
		message_label.visible = true
		if winner_team == -1:
			message_label.text = "TIE GAME!"
		else:
			var team_name = "BLUE"
			var team_color = Color.BLUE
			
			if game_manager and "team_data_store" in game_manager:
				var t_data = game_manager.team_data_store[winner_team]
				if t_data:
					team_name = t_data.name
					team_color = t_data.color_primary
			
			var verb = "WIN" if team_name.to_upper().ends_with("S") else "WINS"
			message_label.text = "%s %s!" % [team_name.to_upper(), verb]
			message_label.modulate = team_color

func show_message(text: String, duration: float = 2.0, color: Color = Color.WHITE) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		
		# Reset any previous tweens/transforms
		var tween = create_tween()
		message_label.scale = Vector2.ONE
		message_label.rotation = 0
		message_label.modulate = color
		
		await get_tree().create_timer(duration).timeout
		message_label.visible = false

func show_gaudy_message(text: String, duration: float = 2.0) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		
		# GAUDY EFFECT
		# 1. Scale pulse
		# 2. Color shifts (Rainbow)
		# 3. Shake/Rotation
		
		var tween = create_tween()
		tween.set_loops() # Loop indefinitely until we kill it or hide
		
		# Pulse scale
		tween.tween_property(message_label, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(message_label, "scale", Vector2(1.0, 1.0), 0.2)
		
		# Color cycling (Rainbow-ish)
		var color_tween = create_tween()
		color_tween.set_loops()
		color_tween.tween_property(message_label, "modulate", Color.GOLD, 0.2)
		color_tween.tween_property(message_label, "modulate", Color.CYAN, 0.2)
		color_tween.tween_property(message_label, "modulate", Color.MAGENTA, 0.2)
		color_tween.tween_property(message_label, "modulate", Color.GREEN, 0.2)
		color_tween.tween_property(message_label, "modulate", Color.WHITE, 0.2)
		
		await get_tree().create_timer(duration).timeout
		
		# Cleanup
		tween.kill()
		color_tween.kill()
		message_label.visible = false
		message_label.scale = Vector2.ONE
		message_label.modulate = Color.WHITE
