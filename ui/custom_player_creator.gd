extends PanelContainer

signal player_created(player_data)
signal menu_closed()

@onready var input_first = $VBox/HBox_Names/VBox_First/InputFirstName
@onready var input_last = $VBox/HBox_Names/VBox_Last/InputLastName
@onready var input_number = $VBox/HBox_Names/VBox_Num/InputNumber
@onready var lbl_total = $VBox/HBox_Totals/TotalStats
@onready var stats_grid = $VBox/StatsGrid

@onready var btn_accept = $VBox/HBox_Actions/BtnAccept
@onready var btn_cancel = $VBox/HBox_Actions/BtnCancel

const STAT_MIN = 10
const STAT_MAX = 99

var stats = {
	"speed": 55,
	"shot": 55,
	"pass_skill": 55,
	"tackle": 55,
	"strength": 55,
	"aggression": 55
}

func _ready() -> void:
	# Build styling
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.98)
	sb.border_color = Color(0.3, 0.9, 0.3, 0.8)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	add_theme_stylebox_override("panel", sb)
	
	_build_stat_grid()
	
	_style_archetype_btn($VBox/HBox_Archetypes/BtnShoot, Color(0.9, 0.3, 0.3))
	_style_archetype_btn($VBox/HBox_Archetypes/BtnPass, Color(0.3, 0.7, 0.9))
	_style_archetype_btn($VBox/HBox_Archetypes/BtnReb, Color(0.3, 0.9, 0.4))
	_style_archetype_btn($VBox/HBox_Archetypes/BtnBal, Color(0.7, 0.3, 0.9))
	
	$VBox/HBox_Archetypes/BtnShoot.pressed.connect(func(): _roll_archetype("shooter"))
	$VBox/HBox_Archetypes/BtnPass.pressed.connect(func(): _roll_archetype("passer"))
	$VBox/HBox_Archetypes/BtnReb.pressed.connect(func(): _roll_archetype("rebounder"))
	$VBox/HBox_Archetypes/BtnBal.pressed.connect(func(): _roll_archetype("balanced"))
	
	btn_accept.pressed.connect(_on_accept)
	btn_cancel.pressed.connect(_on_cancel)
	
	_roll_archetype("balanced") # Initialize with a random spread
	
func _style_archetype_btn(btn: Button, border_color: Color) -> void:
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	sb_n.border_color = border_color.darkened(0.2)
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb_n)
	
	var sb_h = sb_n.duplicate()
	sb_h.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	sb_h.border_color = border_color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", sb_h)
	
func _build_stat_grid() -> void:
	for c in stats_grid.get_children():
		c.queue_free()
		
	var keys = stats.keys()
	for k in keys:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var lbl = Label.new()
		lbl.text = k.to_upper().replace("_", " ")
		lbl.custom_minimum_size = Vector2(120, 0)
		lbl.add_theme_font_size_override("font_size", 18)
		hbox.add_child(lbl)
		
		# Spacing
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)
		
		var bar = ProgressBar.new()
		bar.name = "Bar_" + k
		bar.min_value = 0
		bar.max_value = 100
		bar.value = stats[k]
		bar.custom_minimum_size = Vector2(240, 24)
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var sb_bg = StyleBoxFlat.new()
		sb_bg.bg_color = Color(0.1, 0.1, 0.1)
		sb_bg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", sb_bg)
		
		hbox.add_child(bar)
		
		stats_grid.add_child(hbox)

func _get_total_used() -> int:
	var total = 0
	for v in stats.values(): total += v
	return total

func _roll_archetype(archetype: String) -> void:
	var archetype_profiles = {
		"shooter": {"primary": ["shot", "speed"], "secondary": ["tackle", "strength"]},
		"passer": {"primary": ["pass_skill", "speed"], "secondary": ["strength", "aggression"]},
		"rebounder": {"primary": ["strength", "aggression", "tackle"], "secondary": ["shot", "pass_skill", "speed"]},
	}
	
	if archetype == "balanced":
		for k in stats.keys():
			stats[k] = int(clamp(round(randfn(50.0, 15.0)), STAT_MIN, STAT_MAX))
	else:
		var profile = archetype_profiles.get(archetype, {"primary": [], "secondary": []})
		var primary = profile["primary"]
		var secondary = profile["secondary"]
		
		for k in stats.keys():
			if k in primary:
				stats[k] = int(clamp(round(randfn(75.0, 5.0)), STAT_MIN, STAT_MAX))
			elif k in secondary:
				stats[k] = int(clamp(round(randfn(25.0, 10.0)), STAT_MIN, STAT_MAX))
			else:
				# Middling stat if not explicitly primary or secondary
				stats[k] = int(clamp(round(randfn(40.0, 15.0)), STAT_MIN, STAT_MAX))
				
	_update_ui()

func _update_ui() -> void:
	var used = _get_total_used()
	lbl_total.text = "TOTAL: %d" % used
	
	for k in stats.keys():
		for child in stats_grid.get_children():
			var bar = child.get_node_or_null("Bar_" + k)
			if bar: 
				var val = float(stats[k])
				bar.value = val
				
				var c = Color.WHITE
				if val <= 50.0:
					var pt = val / 50.0
					c = Color(0.2, 0.1, 0.4).lerp(Color(0.1, 0.5, 0.9), pt)
				else:
					var pt = (val - 50.0) / 50.0
					c = Color(0.1, 0.5, 0.9).lerp(Color(0.5, 1.0, 1.0), pt)
					
				var sb_fill = StyleBoxFlat.new()
				sb_fill.bg_color = c
				sb_fill.set_corner_radius_all(4)
				bar.add_theme_stylebox_override("fill", sb_fill)

func _on_accept() -> void:
	var first = input_first.text.strip_edges()
	var last = input_last.text.strip_edges()
	
	if first == "": first = "Rookie"
	if last == "": last = "Unknown"
	
	var p = PlayerData.new()
	p.name = first + " " + last
	p.number = int(input_number.value)
	p.speed = stats["speed"]
	p.shot = stats["shot"]
	p.pass_skill = stats["pass_skill"]
	p.tackle = stats["tackle"]
	p.strength = stats["strength"]
	p.aggression = stats["aggression"]
	
	player_created.emit(p)
	queue_free()

func _on_cancel() -> void:
	menu_closed.emit()
	queue_free()
