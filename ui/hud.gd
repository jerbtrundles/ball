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
	
	# Initialize
	_on_score_changed(0, 0)
	_on_score_changed(1, 0)
	_on_quarter_changed(1)
	if message_label:
		message_label.visible = false

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
			var team_name = "BLUE" if winner_team == 0 else "RED"
			message_label.text = "%s WINS!" % team_name

func show_message(text: String, duration: float = 2.0) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		await get_tree().create_timer(duration).timeout
		message_label.visible = false
