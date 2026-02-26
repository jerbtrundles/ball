extends Control

# --- Team panels ---
@onready var team_a_name: Label = $VBoxContainer/HBox_Teams/VBox_TeamA/TeamName
@onready var team_a_logo: TextureRect = $VBoxContainer/HBox_Teams/VBox_TeamA/LogoRect
@onready var team_a_container: Control = $VBoxContainer/HBox_Teams/VBox_TeamA
@onready var btn_a_up: Button = $VBoxContainer/HBox_Teams/VBox_TeamA/BtnUp
@onready var btn_a_down: Button = $VBoxContainer/HBox_Teams/VBox_TeamA/BtnDown

@onready var team_b_name: Label = $VBoxContainer/HBox_Teams/VBox_TeamB/TeamName
@onready var team_b_logo: TextureRect = $VBoxContainer/HBox_Teams/VBox_TeamB/LogoRect
@onready var team_b_container: Control = $VBoxContainer/HBox_Teams/VBox_TeamB
@onready var btn_b_up: Button = $VBoxContainer/HBox_Teams/VBox_TeamB/BtnUp
@onready var btn_b_down: Button = $VBoxContainer/HBox_Teams/VBox_TeamB/BtnDown

# --- Side selector ---
@onready var zone_a: PanelContainer = $VBoxContainer/SideSelector/ZoneA
@onready var zone_spec: PanelContainer = $VBoxContainer/SideSelector/ZoneSpec
@onready var zone_b: PanelContainer = $VBoxContainer/SideSelector/ZoneB
@onready var zone_a_label: Label = $VBoxContainer/SideSelector/ZoneA/Label
@onready var zone_spec_label: Label = $VBoxContainer/SideSelector/ZoneSpec/Label
@onready var zone_b_label: Label = $VBoxContainer/SideSelector/ZoneB/Label

# --- Options ---
@onready var opt_quarters: OptionButton = $VBoxContainer/OptionsPanel/OptionsVBox/HBox_Quarters/OptionButton
@onready var opt_team_size: OptionButton = $VBoxContainer/OptionsPanel/OptionsVBox/HBox_TeamSize/OptionButton
@onready var btn_items: Button = $VBoxContainer/OptionsPanel/OptionsVBox/HBox_Items/BtnItems

# --- Court picker ---
@onready var court_cards_container: HBoxContainer = $VBoxContainer/OptionsPanel/OptionsVBox/HBox_Court/CourtCardsContainer
@onready var btn_court_prev: Button = $VBoxContainer/OptionsPanel/OptionsVBox/HBox_Court/BtnCourtPrev
@onready var btn_court_next: Button = $VBoxContainer/OptionsPanel/OptionsVBox/HBox_Court/BtnCourtNext

@onready var btn_start: Button = $VBoxContainer/BtnStart
@onready var btn_back: Button = $VBoxContainer/BtnBack

# --- Items modal ---
@onready var items_modal: PanelContainer = $ItemsModal
@onready var chk_mine: CheckBox = $ItemsModal/VBox/Chk_Mine
@onready var chk_saw: CheckBox = $ItemsModal/VBox/Chk_Cyclone
@onready var chk_missile: CheckBox = $ItemsModal/VBox/Chk_Missile
@onready var chk_powerup: CheckBox = $ItemsModal/VBox/Chk_PowerUp
@onready var chk_coin: CheckBox = $ItemsModal/VBox/Chk_Coin
@onready var chk_crowd: CheckBox = $ItemsModal/VBox/Chk_CrowdThrow
@onready var btn_modal_close: Button = $ItemsModal/VBox/BtnClose

var available_teams: Array = []
var team_a_index: int = 0
var team_b_index: int = 1
var selected_side: int = 0  # 0=TeamA, 1=TeamB, 2=Spectate
var _selected_court_index: int = 0
var _court_display: PanelContainer = null
var _court_icon_lbl: Label = null
var _court_name_lbl: Label = null

const LOGO_SIZE = 96

func _ready() -> void:
	if LeagueManager.divisions.is_empty():
		LeagueManager.generate_default_league()
	
	for div in LeagueManager.divisions:
		available_teams.append_array(div["teams"])
	
	_generate_all_logos()
	
	# Quarter Options
	opt_quarters.add_item("15 Seconds", 15)
	opt_quarters.add_item("30 Seconds", 30)
	opt_quarters.add_item("1 Minute", 60)
	opt_quarters.add_item("2 Minutes", 120)
	opt_quarters.select(1)
	
	# Team Size Options
	opt_team_size.add_item("3v3", 3)
	opt_team_size.add_item("4v4", 4)
	opt_team_size.add_item("5v5", 5)
	opt_team_size.select(0)
	
	# Court Picker — single display with ◀/▶ arrows
	_build_court_display()
	btn_court_prev.pressed.connect(func(): _cycle_court(-1))
	btn_court_next.pressed.connect(func(): _cycle_court(1))
	_style_arrow_button(btn_court_prev)
	_style_arrow_button(btn_court_next)
	
	# --- Connections ---
	btn_start.pressed.connect(_on_start_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_a_up.pressed.connect(func(): _cycle_team_a(-1))
	btn_a_down.pressed.connect(func(): _cycle_team_a(1))
	btn_b_up.pressed.connect(func(): _cycle_team_b(-1))
	btn_b_down.pressed.connect(func(): _cycle_team_b(1))
	
	# Side selector — clickable zones
	zone_a.gui_input.connect(func(e): _on_zone_click(e, 0))
	zone_spec.gui_input.connect(func(e): _on_zone_click(e, 2))
	zone_b.gui_input.connect(func(e): _on_zone_click(e, 1))
	
	# Items modal
	btn_items.pressed.connect(_open_items_modal)
	btn_modal_close.pressed.connect(_close_items_modal)
	
	# Keyboard on team containers
	team_a_container.focus_mode = Control.FOCUS_ALL
	team_a_container.gui_input.connect(_on_team_a_input)
	team_b_container.focus_mode = Control.FOCUS_ALL
	team_b_container.gui_input.connect(_on_team_b_input)
	
	# Side selector keyboard — make zones focusable
	for z in [zone_a, zone_spec, zone_b]:
		z.focus_mode = Control.FOCUS_ALL
		z.gui_input.connect(func(e): _on_side_key_input(e))
	
	# Focus highlight tracking — redraw borders on focus changes
	for item in [team_a_container, team_b_container]:
		item.focus_entered.connect(func(): _update_team_panel_borders())
		item.focus_exited.connect(func(): _update_team_panel_borders())
	
	# Set up keyboard-only navigation neighbors
	# Team A → right goes to Team B
	team_a_container.focus_neighbor_right = team_b_container.get_path()
	# Team B → right goes to first side zone
	team_b_container.focus_neighbor_right = zone_a.get_path()
	# Team B → left goes back to Team A
	team_b_container.focus_neighbor_left = team_a_container.get_path()
	# Team A → down goes to side selector
	team_a_container.focus_neighbor_bottom = zone_a.get_path()
	# Team B → down goes to side selector
	team_b_container.focus_neighbor_bottom = zone_b.get_path()
	
	_apply_styling()
	_update_ui()
	team_a_container.grab_focus()

var _starting: bool = false

func _unhandled_input(event: InputEvent) -> void:
	# Enter/Accept starts the match from anywhere (unless modal is open)
	if event.is_action_pressed("ui_accept") and not items_modal.visible and not _starting:
		_starting = true
		_on_start_pressed()

func _on_zone_click(event: InputEvent, side: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_side(side)

func _on_side_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_cycle_side(-1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_cycle_side(1); get_viewport().set_input_as_handled()

# =====================================================================
#  ITEMS MODAL
# =====================================================================

func _open_items_modal() -> void:
	items_modal.visible = true
	btn_modal_close.grab_focus()

func _close_items_modal() -> void:
	items_modal.visible = false
	_update_items_button_text()
	btn_items.grab_focus()

func _get_enabled_items() -> Dictionary:
	return {
		"mine": chk_mine.button_pressed,
		"cyclone": chk_saw.button_pressed,
		"missile": chk_missile.button_pressed,
		"power_up": chk_powerup.button_pressed,
		"coin": chk_coin.button_pressed,
		"crowd_throw": chk_crowd.button_pressed,
	}

func _update_items_button_text() -> void:
	var items = _get_enabled_items()
	var enabled_count = 0
	for v in items.values():
		if v: enabled_count += 1
	
	if enabled_count == items.size():
		btn_items.text = "All Enabled ▸"
	elif enabled_count == 0:
		btn_items.text = "All Disabled ▸"
	else:
		btn_items.text = "%d / %d Enabled ▸" % [enabled_count, items.size()]

# =====================================================================
#  FOCUS HIGHLIGHTS
# =====================================================================

func _update_team_panel_borders() -> void:
	# Draw focus highlights around team containers using draw_rect
	for vbox in [team_a_container, team_b_container]:
		# Use a nested draw approach — connect draw signal
		if not vbox.is_connected("draw", _draw_team_border):
			vbox.connect("draw", _draw_team_border.bind(vbox))
		vbox.queue_redraw()

func _draw_team_border(vbox: Control) -> void:
	var rect = Rect2(Vector2.ZERO, vbox.size)
	if vbox.has_focus():
		# Bright neon cyan border
		vbox.draw_rect(rect, Color(0.0, 1.0, 1.0, 0.7), false, 2.5)
		# Subtle inner glow
		var inner = Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6))
		vbox.draw_rect(inner, Color(0.0, 1.0, 1.0, 0.15), false, 1.0)
	else:
		vbox.draw_rect(rect, Color(0.2, 0.2, 0.35, 0.25), false, 1.0)

# =====================================================================
#  LOGO GENERATION
# =====================================================================

func _generate_all_logos() -> void:
	for team in available_teams:
		team.logo = _generate_team_logo(team.name, team.color_primary)

func _generate_team_logo(team_name: String, color: Color) -> ImageTexture:
	var img = Image.create(LOGO_SIZE, LOGO_SIZE, false, Image.FORMAT_RGBA8)
	var s = LOGO_SIZE; var half = s / 2
	img.fill(Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 1.0))
	var bright = color.lightened(0.2)
	var accent = Color(1.0, 1.0, 1.0, 0.9)
	match team_name.hash() % 7:
		0: _draw_diamond(img, half, half, 34, bright)
		1: _draw_shield(img, half, half, 30, bright)
		2: _draw_star(img, half, half, 32, 5, bright)
		3: _draw_cross(img, half, half, 28, 10, bright)
		4: _draw_circle_emblem(img, half, half, 30, bright)
		5: _draw_triangle(img, half, half, 34, bright)
		6: _draw_hexagon(img, half, half, 30, bright)
	for x in range(s):
		for y in range(s):
			if x < 3 or x >= s - 3 or y < 3 or y >= s - 3:
				img.set_pixel(x, y, Color(bright.r, bright.g, bright.b, 0.8))
	_draw_letter(img, half, half, team_name[0].to_upper(), accent)
	return ImageTexture.create_from_image(img)

func _draw_diamond(img: Image, cx: int, cy: int, sz: int, c: Color) -> void:
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			if abs(x-cx) + abs(y-cy) < sz:
				img.set_pixel(x, y, c.darkened(float(abs(x-cx)+abs(y-cy))/sz*0.4))

func _draw_shield(img: Image, cx: int, cy: int, sz: int, c: Color) -> void:
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var dy = y - (cy - sz * 0.6)
			if dy < 0 or dy > sz * 1.6: continue
			var w: float = float(sz) if dy < sz * 0.8 else sz * (1.0 - (dy - sz * 0.8) / (sz * 0.8))
			if abs(x - cx) < w: img.set_pixel(x, y, c.darkened(float(dy)/(sz*1.6)*0.3))

func _draw_star(img: Image, cx: int, cy: int, sz: int, pts: int, c: Color) -> void:
	var inner = sz * 0.4
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var dx = x-cx; var dy = y-cy; var dist = sqrt(dx*dx+dy*dy)
			if dist > sz: continue
			var a = atan2(dy, dx); if a < 0: a += TAU
			var s = fmod(a, TAU/pts)/(TAU/pts)
			var r = lerp(float(sz),float(inner),s*2.0) if s < 0.5 else lerp(float(inner),float(sz),(s-0.5)*2.0)
			if dist < r: img.set_pixel(x, y, c.darkened(dist/sz*0.3))

func _draw_cross(img: Image, cx: int, cy: int, sz: int, w: int, c: Color) -> void:
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var dx=abs(x-cx); var dy=abs(y-cy)
			if (dx<w and dy<sz) or (dy<w and dx<sz):
				img.set_pixel(x, y, c.darkened(max(float(dx),float(dy))/sz*0.3))

func _draw_circle_emblem(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var d = sqrt((x-cx)*(x-cx)+(y-cy)*(y-cy))
			if d < r: img.set_pixel(x,y,c.darkened(d/r*0.3))
			elif d < r+4: img.set_pixel(x,y,c.lightened(0.3))

func _draw_triangle(img: Image, cx: int, cy: int, sz: int, c: Color) -> void:
	var top = cy-sz; var bot = cy+int(sz*0.8)
	for y in range(max(0,top), min(img.get_height(),bot+1)):
		var t = float(y-top)/(bot-top); var hw = t*sz
		for x in range(img.get_width()):
			if abs(x-cx) < hw: img.set_pixel(x,y,c.darkened(t*0.3))

func _draw_hexagon(img: Image, cx: int, cy: int, sz: int, c: Color) -> void:
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var dx=abs(x-cx); var dy=abs(y-cy)
			if dx<sz and dy<sz*0.9 and (dx+dy*0.577)<sz:
				img.set_pixel(x,y,c.darkened((dx+dy)/(sz*2.0)*0.4))

func _draw_letter(img: Image, cx: int, cy: int, letter: String, color: Color) -> void:
	var g = {
		"A":[0x04,0x0A,0x11,0x1F,0x11,0x11,0x11],"B":[0x1E,0x11,0x11,0x1E,0x11,0x11,0x1E],
		"C":[0x0E,0x11,0x10,0x10,0x10,0x11,0x0E],"D":[0x1C,0x12,0x11,0x11,0x11,0x12,0x1C],
		"E":[0x1F,0x10,0x10,0x1E,0x10,0x10,0x1F],"F":[0x1F,0x10,0x10,0x1E,0x10,0x10,0x10],
		"G":[0x0E,0x11,0x10,0x17,0x11,0x11,0x0E],"H":[0x11,0x11,0x11,0x1F,0x11,0x11,0x11],
		"I":[0x0E,0x04,0x04,0x04,0x04,0x04,0x0E],"J":[0x07,0x02,0x02,0x02,0x02,0x12,0x0C],
		"K":[0x11,0x12,0x14,0x18,0x14,0x12,0x11],"L":[0x10,0x10,0x10,0x10,0x10,0x10,0x1F],
		"M":[0x11,0x1B,0x15,0x15,0x11,0x11,0x11],"N":[0x11,0x19,0x15,0x13,0x11,0x11,0x11],
		"O":[0x0E,0x11,0x11,0x11,0x11,0x11,0x0E],"P":[0x1E,0x11,0x11,0x1E,0x10,0x10,0x10],
		"Q":[0x0E,0x11,0x11,0x11,0x15,0x12,0x0D],"R":[0x1E,0x11,0x11,0x1E,0x14,0x12,0x11],
		"S":[0x0E,0x11,0x10,0x0E,0x01,0x11,0x0E],"T":[0x1F,0x04,0x04,0x04,0x04,0x04,0x04],
		"U":[0x11,0x11,0x11,0x11,0x11,0x11,0x0E],"V":[0x11,0x11,0x11,0x11,0x0A,0x0A,0x04],
		"W":[0x11,0x11,0x11,0x15,0x15,0x1B,0x11],"X":[0x11,0x11,0x0A,0x04,0x0A,0x11,0x11],
		"Y":[0x11,0x11,0x0A,0x04,0x04,0x04,0x04],"Z":[0x1F,0x01,0x02,0x04,0x08,0x10,0x1F],
	}
	if not g.has(letter): return
	var glyph = g[letter]; var sc = 3
	var sx = cx-(5*sc)/2; var sy = cy-(7*sc)/2
	for row in range(7):
		for col in range(5):
			if glyph[row] & (1 << (4-col)):
				for dx in range(sc):
					for dy in range(sc):
						var px=sx+col*sc+dx; var py=sy+row*sc+dy
						if px>=0 and px<img.get_width() and py>=0 and py<img.get_height():
							img.set_pixel(px, py, color)

# =====================================================================
#  STYLING
# =====================================================================

func _apply_styling() -> void:
	# Background gradient
	var bg = $Background
	var shader_mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float t = UV.y;
	vec3 top = vec3(0.04, 0.04, 0.12);
	vec3 mid = vec3(0.06, 0.02, 0.14);
	vec3 bot = vec3(0.03, 0.03, 0.08);
	vec3 col = mix(top, mid, smoothstep(0.0, 0.5, t));
	col = mix(col, bot, smoothstep(0.5, 1.0, t));
	vec2 center = vec2(0.5, 0.35);
	float glow = 1.0 - smoothstep(0.0, 0.6, distance(UV, center));
	col += vec3(0.0, 0.04, 0.08) * glow;
	COLOR = vec4(col, 1.0);
}
"""
	shader_mat.shader = shader
	bg.material = shader_mat
	
	# Title
	$VBoxContainer/Title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	$VBoxContainer/Title.add_theme_color_override("font_outline_color", Color(0.0, 0.4, 0.6))
	$VBoxContainer/Title.add_theme_constant_override("outline_size", 4)
	
	# VS
	var vs = $VBoxContainer/HBox_Teams/VS_Label
	vs.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	vs.add_theme_color_override("font_outline_color", Color(0.5, 0.2, 0.0))
	vs.add_theme_constant_override("outline_size", 5)
	
	# Headers
	for p in ["VBoxContainer/HBox_Teams/VBox_TeamA/Label_Header","VBoxContainer/HBox_Teams/VBox_TeamB/Label_Header"]:
		get_node(p).add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	
	# Arrow buttons
	var arrow_dim = Color(0.45, 0.45, 0.6)
	for btn in [btn_a_up, btn_a_down, btn_b_up, btn_b_down]:
		btn.add_theme_color_override("font_color", arrow_dim)
		btn.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.9))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.focus_mode = Control.FOCUS_NONE
	
	# Options labels
	for p in ["VBoxContainer/OptionsPanel/OptionsVBox/HBox_TeamSize/Label",
			  "VBoxContainer/OptionsPanel/OptionsVBox/HBox_Quarters/Label",
			  "VBoxContainer/OptionsPanel/OptionsVBox/HBox_Court/Label",
			  "VBoxContainer/OptionsPanel/OptionsVBox/HBox_Items/Label"]:
		get_node(p).add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	
	# Start button
	_style_button_neon(btn_start, Color(0.0, 0.6, 0.8), Color(0.0, 1.0, 1.0))
	btn_start.add_theme_color_override("font_color", Color.WHITE)
	
	# Back button
	_style_button_subtle(btn_back)
	
	# Items button
	_style_button_subtle(btn_items)
	
	# Options panel
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.06, 0.12, 0.7)
	panel_sb.border_color = Color(0.15, 0.15, 0.3, 0.5)
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(10)
	panel_sb.set_content_margin_all(14)
	$VBoxContainer/OptionsPanel.add_theme_stylebox_override("panel", panel_sb)
	
	# Items modal panel
	var modal_sb = StyleBoxFlat.new()
	modal_sb.bg_color = Color(0.06, 0.06, 0.14, 0.95)
	modal_sb.border_color = Color(0.0, 0.8, 1.0, 0.6)
	modal_sb.set_border_width_all(2)
	modal_sb.set_corner_radius_all(12)
	modal_sb.set_content_margin_all(20)
	items_modal.add_theme_stylebox_override("panel", modal_sb)
	
	# Modal title
	$ItemsModal/VBox/ModalTitle.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	
	# Modal close button
	_style_button_neon(btn_modal_close, Color(0.0, 0.5, 0.6), Color(0.0, 0.8, 1.0))

func _style_button_neon(btn: Button, bg_col: Color, border_col: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(bg_col.r, bg_col.g, bg_col.b, 0.9)
	sb.border_color = Color(border_col.r, border_col.g, border_col.b, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate(); h.bg_color = bg_col.lightened(0.1)
	btn.add_theme_stylebox_override("hover", h)
	var p = sb.duplicate(); p.bg_color = bg_col.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", p)
	var f = sb.duplicate(); f.border_color = border_col; f.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", f)

func _style_button_subtle(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.2, 0.6)
	sb.border_color = Color(0.3, 0.3, 0.5, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate(); h.bg_color = Color(0.15, 0.15, 0.25, 0.8)
	btn.add_theme_stylebox_override("hover", h)
	var f = sb.duplicate(); f.border_color = Color(0.5, 0.5, 0.7, 0.6); f.set_border_width_all(2)
	btn.add_theme_stylebox_override("focus", f)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.9))

# =====================================================================
#  INPUT
# =====================================================================

func _on_team_a_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_cycle_team_a(-1); accept_event()
	elif event.is_action_pressed("ui_down"):
		_cycle_team_a(1); accept_event()

func _on_team_b_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_cycle_team_b(-1); accept_event()
	elif event.is_action_pressed("ui_down"):
		_cycle_team_b(1); accept_event()

func _cycle_team_a(dir: int) -> void:
	team_a_index = (team_a_index + dir) % available_teams.size()
	if team_a_index < 0: team_a_index = available_teams.size() - 1
	_update_ui()

func _cycle_team_b(dir: int) -> void:
	team_b_index = (team_b_index + dir) % available_teams.size()
	if team_b_index < 0: team_b_index = available_teams.size() - 1
	_update_ui()

func _set_side(side: int) -> void:
	selected_side = side
	_update_ui()

func _cycle_side(dir: int) -> void:
	var order = [0, 2, 1] # TeamA → Spectate → TeamB
	var cur = order.find(selected_side)
	cur = (cur + dir) % order.size()
	if cur < 0: cur = order.size() - 1
	selected_side = order[cur]
	_update_ui()

# =====================================================================
#  UI UPDATE
# =====================================================================

func _update_ui() -> void:
	if available_teams.size() == 0: return
	var t_a = available_teams[team_a_index]
	var t_b = available_teams[team_b_index]
	
	# Teams
	team_a_name.text = t_a.name
	team_a_name.add_theme_color_override("font_color", t_a.color_primary)
	team_a_logo.texture = t_a.logo
	team_b_name.text = t_b.name
	team_b_name.add_theme_color_override("font_color", t_b.color_primary)
	team_b_logo.texture = t_b.logo
	
	# Arrow colors
	for btn in [btn_a_up, btn_a_down]:
		btn.add_theme_color_override("font_color", t_a.color_primary.darkened(0.3))
		btn.add_theme_color_override("font_hover_color", t_a.color_primary.lightened(0.2))
	for btn in [btn_b_up, btn_b_down]:
		btn.add_theme_color_override("font_color", t_b.color_primary.darkened(0.3))
		btn.add_theme_color_override("font_hover_color", t_b.color_primary.lightened(0.2))
	
	# --- Side selector: 🎮 icon moves between zones ---
	zone_a_label.text = ""
	zone_spec_label.text = "AI vs AI"
	zone_b_label.text = ""
	
	# Reset all zones to inactive
	_style_zone_inactive(zone_a)
	_style_zone_inactive(zone_spec)
	_style_zone_inactive(zone_b)
	zone_spec_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	
	match selected_side:
		0: # Play as Team A
			zone_a_label.text = "🎮"
			_style_zone_active(zone_a, t_a.color_primary)
		1: # Play as Team B
			zone_b_label.text = "🎮"
			_style_zone_active(zone_b, t_b.color_primary)
		2: # Spectate
			zone_spec_label.text = "🎮  AI vs AI"
			_style_zone_active(zone_spec, Color(0.5, 0.5, 0.7))
	
	_update_team_panel_borders()
	_update_court_display()

func _style_zone_inactive(zone: PanelContainer) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.12, 0.4)
	sb.border_color = Color(0.15, 0.15, 0.25, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	zone.add_theme_stylebox_override("panel", sb)

func _style_zone_active(zone: PanelContainer, color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.8)
	sb.border_color = Color(color.r, color.g, color.b, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	zone.add_theme_stylebox_override("panel", sb)

# =====================================================================
#  ACTIONS
# =====================================================================

# =====================================================================
#  COURT PICKER
# =====================================================================

func _build_court_display() -> void:
	_court_display = PanelContainer.new()
	_court_display.custom_minimum_size = Vector2(220, 48)
	
	var hbox = HBoxContainer.new()
	hbox.name = "CourtHBox"
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 6)
	_court_display.add_child(hbox)
	
	_court_icon_lbl = Label.new()
	_court_icon_lbl.name = "IconLabel"
	_court_icon_lbl.add_theme_font_size_override("font_size", 18)
	_court_icon_lbl.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(_court_icon_lbl)
	
	_court_name_lbl = Label.new()
	_court_name_lbl.name = "NameLabel"
	_court_name_lbl.add_theme_font_size_override("font_size", 15)
	_court_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	_court_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_court_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_court_name_lbl)
	
	court_cards_container.add_child(_court_display)
	_update_court_display()

func _cycle_court(dir: int) -> void:
	_selected_court_index = (_selected_court_index + dir + CourtThemes.PRESET_COUNT) % CourtThemes.PRESET_COUNT
	_update_court_display()

func _set_court(index: int) -> void:
	_selected_court_index = index
	_update_court_display()

func _update_court_display() -> void:
	if _court_display == null:
		return
	
	var t_a = available_teams[team_a_index] if available_teams.size() > 0 else null
	var i = _selected_court_index
	
	# Swatch color: live from team for Home Court
	var swatch_col: Color
	if i == CourtThemes.ID_HOME_COURT and t_a != null:
		swatch_col = t_a.color_primary
	else:
		swatch_col = CourtThemes.get_preset(i).swatch_color
	
	# Panel style
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(swatch_col.r * 0.18, swatch_col.g * 0.18, swatch_col.b * 0.18, 0.85)
	sb.border_color = swatch_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	_court_display.add_theme_stylebox_override("panel", sb)
	
	# Labels — use stored refs, no path lookup needed
	if _court_icon_lbl:
		_court_icon_lbl.text = CourtThemes.PRESET_ICONS[i]
	if _court_name_lbl:
		_court_name_lbl.text = CourtThemes.PRESET_NAMES[i]
		_court_name_lbl.add_theme_color_override("font_color", swatch_col.lightened(0.2))

func _style_arrow_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.9))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.focus_mode = Control.FOCUS_NONE

# =====================================================================
#  ACTIONS
# =====================================================================

func _on_start_pressed() -> void:
	var t_a = available_teams[team_a_index]
	var t_b = available_teams[team_b_index]
	
	var q_len = opt_quarters.get_selected_id()
	if q_len <= 0: q_len = 30
	
	var t_size = opt_team_size.get_selected_id()
	if t_size <= 0: t_size = 3
	
	var enabled_items = _get_enabled_items()
	var any_items = false
	for v in enabled_items.values():
		if v: any_items = true; break
	
	var config = {
		"quarter_duration": float(q_len),
		"team_size": int(t_size),
		"court_theme_index": _selected_court_index,
		"items_enabled": any_items,
		"enabled_items": enabled_items,
		"human_team_index": selected_side
	}
	
	LeagueManager.start_quick_match(t_a, t_b, config)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
