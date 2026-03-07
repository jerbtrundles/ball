extends PanelContainer

signal menu_closed()

@onready var title_name: Label = $CenterContainer/CardPanel/VBox/TitleBox/PlayerName
@onready var title_ovr: Label = $CenterContainer/CardPanel/VBox/TitleBox/PlayerOVR
@onready var portrait_rect: TextureRect = $CenterContainer/CardPanel/VBox/TitleBox/Portrait
@onready var stats_grid: VBoxContainer = $CenterContainer/CardPanel/VBox/StatsGrid
@onready var btn_close: Button = $CenterContainer/CardPanel/VBox/BtnClose

# Setup is called externally to immediately formulate the modal
func setup(player: PlayerData, theme_color: Color = Color(0.3, 0.7, 0.9, 0.8)) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	sb.border_color = theme_color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	$CenterContainer/CardPanel.add_theme_stylebox_override("panel", sb)
	
	btn_close.pressed.connect(_on_close)
	btn_close.grab_focus()
	
	title_name.text = player.name
	var p_ovr = int(round((player.speed + player.shot + player.pass_skill + player.tackle + player.strength + player.aggression) / 6.0))
	title_ovr.text = "%d OVR" % p_ovr
	
	if player.portrait:
		portrait_rect.texture = player.portrait
		portrait_rect.show()
	else:
		portrait_rect.hide()
	
	_build_stat_grid(player)
	
	# Entrance Animation
	var center_node = $CenterContainer
	center_node.pivot_offset = center_node.size / 2.0
	center_node.scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(center_node, "scale", Vector2.ONE, 0.3)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func _build_stat_grid(player: PlayerData) -> void:
	for c in stats_grid.get_children():
		c.queue_free()
		
	var stats = [
		{"name": "SPEED", "val": player.speed},
		{"name": "SHOT", "val": player.shot},
		{"name": "PASS", "val": player.pass_skill},
		{"name": "TACKLE", "val": player.tackle},
		{"name": "STRENGTH", "val": player.strength},
		{"name": "AGGRO", "val": player.aggression}
	]
	
	for stat in stats:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var lbl = Label.new()
		lbl.text = stat["name"]
		lbl.custom_minimum_size = Vector2(100, 0)
		lbl.add_theme_font_size_override("font_size", 16)
		hbox.add_child(lbl)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)
		
		# Value text
		var val_lbl = Label.new()
		val_lbl.text = str(int(stat["val"]))
		val_lbl.custom_minimum_size = Vector2(40, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 16)
		hbox.add_child(val_lbl)
		
		# Generating Progress Bar display element
		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = stat["val"]
		bar.custom_minimum_size = Vector2(200, 20)
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var sb_bg = StyleBoxFlat.new()
		sb_bg.bg_color = Color(0.1, 0.1, 0.1)
		sb_bg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", sb_bg)
		
		var sb_fill = StyleBoxFlat.new()
		sb_fill.bg_color = _get_color_for_stat(stat["val"])
		sb_fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", sb_fill)
		
		hbox.add_child(bar)
		stats_grid.add_child(hbox)

func _get_color_for_stat(val: float) -> Color:
	# Calculate stat heat mapping (Red -> Yellow -> Green boundary)
	var t = clampf(val / 100.0, 0.0, 1.0)
	var c_low = Color(0.9, 0.2, 0.2)
	var c_mid = Color(0.9, 0.8, 0.2)
	var c_high = Color(0.2, 0.9, 0.4)
	
	if t < 0.5:
		return c_low.lerp(c_mid, t * 2.0)
	else:
		return c_mid.lerp(c_high, (t - 0.5) * 2.0)

func _on_close() -> void:
	menu_closed.emit()
	queue_free()
