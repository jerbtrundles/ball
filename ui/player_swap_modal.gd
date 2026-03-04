extends PanelContainer

signal player_selected(player)
signal menu_closed()

@onready var player_list = $CenterContainer/VBox/ScrollContainer/PlayerList
@onready var btn_cancel = $CenterContainer/VBox/BtnCancel

func _ready() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.98)
	sb.border_color = Color(0.3, 0.9, 0.3, 0.8)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	$CenterContainer/VBox.add_theme_stylebox_override("panel", sb)
	
	btn_cancel.pressed.connect(_on_cancel)
	_populate_list()

func _populate_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
		
	if LeagueManager.custom_players.is_empty():
		var lbl = Label.new()
		lbl.text = "No custom players created yet."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		player_list.add_child(lbl)
		return
		
	for p in LeagueManager.custom_players:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Build a rich text summary
		var stats_total = p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression
		btn.text = "  #%d %s   |  OVR: %d  |  SPD:%d SHT:%d PAS:%d TCK:%d STR:%d AGG:%d" % [
			p.number, 
			p.name, 
			round(stats_total / 6.0),
			p.speed, p.shot, p.pass_skill, p.tackle, p.strength, p.aggression
		]
		
		btn.pressed.connect(func(): _on_player_selected(p))
		player_list.add_child(btn)

func _on_player_selected(p: PlayerData) -> void:
	player_selected.emit(p)
	queue_free()

func _on_cancel() -> void:
	menu_closed.emit()
	queue_free()
