extends Control

# --- Team panels ---
@onready var team_a_name: Label = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamA/TeamName
@onready var team_a_rating: Label = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamA/TeamRating
@onready var team_a_logo: TextureRect = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamA/LogoRect
@onready var team_a_container: Control = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamA
@onready var btn_a_up: Button = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamA/BtnUp
@onready var btn_a_down: Button = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamA/BtnDown

@onready var team_b_name: Label = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamB/TeamName
@onready var team_b_rating: Label = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamB/TeamRating
@onready var team_b_logo: TextureRect = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamB/LogoRect
@onready var team_b_container: Control = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamB
@onready var btn_b_up: Button = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamB/BtnUp
@onready var btn_b_down: Button = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamB/BtnDown

@onready var left_roster: VBoxContainer = $MarginContainer/MainHBox/LeftScroll/LeftRoster
@onready var right_roster: VBoxContainer = $MarginContainer/MainHBox/RightScroll/RightRoster

# --- Side selector ---
@onready var zone_a: PanelContainer = $MarginContainer/MainHBox/VBoxContainer/SideSelector/ZoneA
@onready var zone_spec: PanelContainer = $MarginContainer/MainHBox/VBoxContainer/SideSelector/ZoneSpec
@onready var zone_b: PanelContainer = $MarginContainer/MainHBox/VBoxContainer/SideSelector/ZoneB
@onready var zone_a_label: Label = $MarginContainer/MainHBox/VBoxContainer/SideSelector/ZoneA/Label
@onready var zone_spec_label: Label = $MarginContainer/MainHBox/VBoxContainer/SideSelector/ZoneSpec/Label
@onready var zone_b_label: Label = $MarginContainer/MainHBox/VBoxContainer/SideSelector/ZoneB/Label

# --- Options ---
@onready var opt_quarters: OptionButton = $MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Quarters/OptionButton
@onready var opt_team_size: OptionButton = $MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_TeamSize/OptionButton
@onready var btn_items: Button = $MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Items/BtnItems

# --- Court picker ---
@onready var court_cards_container: HBoxContainer = $MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Court/CourtCardsContainer
@onready var btn_court_prev: Button = $MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Court/BtnCourtPrev
@onready var btn_court_next: Button = $MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Court/BtnCourtNext

@onready var btn_start: Button = $MarginContainer/MainHBox/VBoxContainer/BtnStart
@onready var btn_back: Button = $MarginContainer/MainHBox/VBoxContainer/BtnBack

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

# Same palette as franchise setup
const TEAM_COLORS: Array = [
	{"name": "Crimson",  "color": Color(0.85, 0.1,  0.1 )},
	{"name": "Flame",    "color": Color(0.95, 0.4,  0.05)},
	{"name": "Gold",     "color": Color(0.95, 0.8,  0.05)},
	{"name": "Lime",     "color": Color(0.35, 0.82, 0.1 )},
	{"name": "Forest",   "color": Color(0.05, 0.55, 0.25)},
	{"name": "Sky",      "color": Color(0.15, 0.6,  0.95)},
	{"name": "Indigo",   "color": Color(0.3,  0.1,  0.8 )},
	{"name": "Violet",   "color": Color(0.65, 0.1,  0.85)},
	{"name": "Magenta",  "color": Color(0.9,  0.1,  0.6 )},
	{"name": "Silver",   "color": Color(0.6,  0.65, 0.75)},
	{"name": "Black",    "color": Color(0.15, 0.15, 0.15)},
	{"name": "White",    "color": Color(0.95, 0.95, 0.95)},
]

# Per-team selected color indices (-1 = use team's auto color)
var selected_color_a_index: int = -1
var selected_color_b_index: int = -1

# Swatch button refs so we can restyle on selection
var _swatch_btns_a: Array = []
var _swatch_btns_b: Array = []

const LOGO_SIZE = 96

const QUARTERS_VALUES: Array = [15, 30, 60, 120]
const QUARTERS_LABELS: Array = ["15 Sec", "30 Sec", "1 Min", "2 Min"]
const TEAM_SIZE_VALUES: Array = [3, 4, 5]
const TEAM_SIZE_LABELS: Array = ["3v3", "4v4", "5v5"]
var _quarters_index: int = 1   # default: 30 Sec
var _team_size_index: int = 0  # default: 3v3
var _sel_team_size: PanelContainer = null
var _sel_quarters:  PanelContainer = null
var _lbl_team_size: Label = null
var _lbl_quarters:  Label = null
var _last_joy_ms: int = 0
const JOY_COOLDOWN_MS: int = 200

func _ready() -> void:
	if LeagueManager.divisions.is_empty():
		LeagueManager.generate_default_league()
	
	for div in LeagueManager.divisions:
		available_teams.append_array(div["teams"])
	
	# Default color indices: closest swatch to each team's auto-color
	if available_teams.size() > 0:
		selected_color_a_index = _nearest_color_index(available_teams[team_a_index].color_primary)
	if available_teams.size() > 1:
		selected_color_b_index = _nearest_color_index(available_teams[team_b_index].color_primary)
	
	# Build compact inline selectors replacing OptionButtons
	opt_quarters.hide()
	opt_team_size.hide()
	var res_sz = _build_arrow_selector(
		opt_team_size.get_parent() as HBoxContainer,
		TEAM_SIZE_LABELS, _team_size_index,
		func(i): _team_size_index = i; _update_ui())
	_sel_team_size = res_sz[0]; _lbl_team_size = res_sz[1]
	var res_q = _build_arrow_selector(
		opt_quarters.get_parent() as HBoxContainer,
		QUARTERS_LABELS, _quarters_index,
		func(i): _quarters_index = i; _update_ui())
	_sel_quarters = res_q[0]; _lbl_quarters = res_q[1]
	
	# Court Picker — single display with ◀/▶ arrows
	_build_court_display()
	btn_court_prev.pressed.connect(func(): _cycle_court(-1))
	btn_court_next.pressed.connect(func(): _cycle_court(1))
	_style_arrow_button(btn_court_prev)
	_style_arrow_button(btn_court_next)
	
	# High-Octane Setup Audio (Chrome Gauntlet)
	var music = AudioStreamPlayer.new()
	var stream = load("res://assets/sounds/Chrome_Gauntlet.mp3")
	if stream is AudioStreamMP3:
		stream.loop = true
	music.stream = stream
	music.bus = "Music"
	add_child(music)
	music.play()
	
	# Connect interaction
	btn_start.pressed.connect(_on_start_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_a_up.pressed.connect(func(): _cycle_team_a(-1))
	btn_a_down.pressed.connect(func(): _cycle_team_a(1))
	btn_b_up.pressed.connect(func(): _cycle_team_b(-1))
	btn_b_down.pressed.connect(func(): _cycle_team_b(1))
	
	# Build swatch strips once — they live inside VBox_TeamA / VBox_TeamB
	_build_swatch_strip(team_a_container, true)
	_build_swatch_strip(team_b_container, false)
	
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
		z.focus_entered.connect(func(): _update_ui())
		z.focus_exited.connect(func(): _update_ui())
	
	# Focus highlight tracking — redraw borders on focus changes
	for item in [team_a_container, team_b_container]:
		item.focus_entered.connect(func(): _update_team_panel_borders())
		item.focus_exited.connect(func(): _update_team_panel_borders())
	
	# Give the court arrow buttons focus so they're reachable by controller
	btn_court_prev.focus_mode = Control.FOCUS_ALL
	btn_court_next.focus_mode = Control.FOCUS_ALL

	# ── Main screen focus chain ─────────────────────────────────────
	# Team cards: A ↔ B, B → right → team size selector
	team_a_container.focus_neighbor_right  = team_a_container.get_path_to(team_b_container)
	team_b_container.focus_neighbor_left   = team_b_container.get_path_to(team_a_container)
	team_b_container.focus_neighbor_right  = team_b_container.get_path_to(_sel_team_size)

	# Down from team cards → zone selector
	team_a_container.focus_neighbor_bottom = team_a_container.get_path_to(zone_a)
	team_b_container.focus_neighbor_bottom = team_b_container.get_path_to(zone_b)

	# Zone selector (left/right cycles within zones, up → team cards)
	zone_a.focus_neighbor_left   = zone_a.get_path_to(team_b_container)
	zone_a.focus_neighbor_right  = zone_a.get_path_to(zone_spec)
	zone_a.focus_neighbor_top    = zone_a.get_path_to(team_a_container)
	zone_spec.focus_neighbor_left  = zone_spec.get_path_to(zone_a)
	zone_spec.focus_neighbor_right = zone_spec.get_path_to(zone_b)
	zone_spec.focus_neighbor_top   = zone_spec.get_path_to(team_a_container)
	zone_b.focus_neighbor_left  = zone_b.get_path_to(zone_spec)
	zone_b.focus_neighbor_top   = zone_b.get_path_to(team_b_container)

	# Down from zones → team size selector
	zone_a.focus_neighbor_bottom    = zone_a.get_path_to(_sel_team_size)
	zone_spec.focus_neighbor_bottom = zone_spec.get_path_to(_sel_team_size)
	zone_b.focus_neighbor_bottom    = zone_b.get_path_to(_sel_team_size)

	# Team Size selector
	_sel_team_size.focus_neighbor_top    = _sel_team_size.get_path_to(zone_spec)
	_sel_team_size.focus_neighbor_bottom = _sel_team_size.get_path_to(_sel_quarters)

	# Quarter Length selector
	_sel_quarters.focus_neighbor_top    = _sel_quarters.get_path_to(_sel_team_size)
	_sel_quarters.focus_neighbor_bottom = _sel_quarters.get_path_to(btn_court_prev)

	# Court row
	btn_court_prev.focus_neighbor_top    = btn_court_prev.get_path_to(_sel_quarters)
	btn_court_next.focus_neighbor_top    = btn_court_next.get_path_to(_sel_quarters)
	btn_court_prev.focus_neighbor_right  = btn_court_prev.get_path_to(btn_court_next)
	btn_court_next.focus_neighbor_left   = btn_court_next.get_path_to(btn_court_prev)
	btn_court_prev.focus_neighbor_bottom = btn_court_prev.get_path_to(btn_items)
	btn_court_next.focus_neighbor_bottom = btn_court_next.get_path_to(btn_items)

	# Items → Start (right OR down), Back
	btn_items.focus_neighbor_top    = btn_items.get_path_to(btn_court_prev)
	btn_items.focus_neighbor_right  = btn_items.get_path_to(btn_start)
	btn_items.focus_neighbor_bottom = btn_items.get_path_to(btn_start)
	btn_start.focus_neighbor_top    = btn_start.get_path_to(btn_items)
	btn_start.focus_neighbor_bottom = btn_start.get_path_to(btn_back)
	btn_back.focus_neighbor_top     = btn_back.get_path_to(btn_start)
	btn_back.focus_neighbor_bottom  = btn_back.get_path_to(team_a_container)

	# ── Items modal internal focus chain ────────────────────────────
	var checks = [chk_mine, chk_saw, chk_missile, chk_powerup, chk_coin, chk_crowd]
	for i in range(checks.size()):
		var cur = checks[i]
		var nxt = checks[(i + 1) % checks.size()]
		var prv = checks[(i - 1 + checks.size()) % checks.size()]
		cur.focus_neighbor_bottom = cur.get_path_to(nxt)
		cur.focus_neighbor_top    = cur.get_path_to(prv)
	chk_crowd.focus_neighbor_bottom = chk_crowd.get_path_to(btn_modal_close)
	btn_modal_close.focus_neighbor_top = btn_modal_close.get_path_to(chk_crowd)
	btn_modal_close.focus_neighbor_bottom = btn_modal_close.get_path_to(chk_mine)

	_apply_styling()
	_update_ui()
	team_a_container.grab_focus()
	SceneManager.notify_scene_ready()

var _starting: bool = false

func _input(event: InputEvent) -> void:
	# ── Items modal: focus trap + close on B/Escape ──────────────────
	if items_modal.visible:
		var focused = get_viewport().gui_get_focus_owner()
		if focused == null or not items_modal.is_ancestor_of(focused):
			btn_modal_close.grab_focus()
		if event.is_action_pressed("ui_cancel"):
			_close_items_modal()
			get_viewport().set_input_as_handled()
		return  # Block all other input while modal is open

	var foc = get_viewport().gui_get_focus_owner()

	# ── Selector panel cycling (left/right) ─────────────────────────
	if foc == _sel_team_size:
		if event.is_action_pressed("ui_left"):
			_team_size_index = (_team_size_index - 1 + TEAM_SIZE_VALUES.size()) % TEAM_SIZE_VALUES.size()
			_update_ui(); get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_team_size_index = (_team_size_index + 1) % TEAM_SIZE_VALUES.size()
			_update_ui(); get_viewport().set_input_as_handled()
	elif foc == _sel_quarters:
		if event.is_action_pressed("ui_left"):
			_quarters_index = (_quarters_index - 1 + QUARTERS_VALUES.size()) % QUARTERS_VALUES.size()
			_update_ui(); get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_quarters_index = (_quarters_index + 1) % QUARTERS_VALUES.size()
			_update_ui(); get_viewport().set_input_as_handled()

	# ── Court cycling via left/right when court row focused ───────────
	elif foc == btn_court_prev or foc == btn_court_next:
		if event.is_action_pressed("ui_left"):
			_cycle_court(-1); get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_cycle_court(1); get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not items_modal.visible:
		_on_back_pressed()
		return
	# Accept only triggers start when btn_start is explicitly focused
	if event.is_action_pressed("ui_accept") and not items_modal.visible and not _starting:
		if get_viewport().gui_get_focus_owner() == btn_start:
			_starting = true
			_on_start_pressed()

func _on_zone_click(event: InputEvent, side: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_side(side)

func _on_side_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") and _joy_ready():
		_cycle_side(-1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") and _joy_ready():
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
		btn_items.text = "All Enabled ▶"
	elif enabled_count == 0:
		btn_items.text = "All Disabled ▶"
	else:
		btn_items.text = "%d / %d Enabled ▶" % [enabled_count, items.size()]

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
	
	# Determine team color to use
	var color = Color(0.2, 0.2, 0.35, 0.25)
	if vbox == team_a_container and available_teams.size() > team_a_index:
		color = available_teams[team_a_index].color_primary
	elif vbox == team_b_container and available_teams.size() > team_b_index:
		color = available_teams[team_b_index].color_primary
	
	if vbox.has_focus():
		# Bright neon border
		vbox.draw_rect(rect, color, false, 2.5)
		# Colored inner glow
		var inner = Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6))
		var fill = color
		fill.a = 0.5
		vbox.draw_rect(inner, fill, true)
	else:
		var fill = color
		fill.a = 0.2
		vbox.draw_rect(rect, fill, true)
		vbox.draw_rect(rect, color.darkened(0.5), false, 1.0)

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
	$MarginContainer/MainHBox/VBoxContainer/Title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	$MarginContainer/MainHBox/VBoxContainer/Title.add_theme_color_override("font_outline_color", Color(0.0, 0.4, 0.6))
	$MarginContainer/MainHBox/VBoxContainer/Title.add_theme_constant_override("outline_size", 4)
	
	# VS
	var vs = $MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VS_Label
	vs.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	vs.add_theme_color_override("font_outline_color", Color(0.5, 0.2, 0.0))
	vs.add_theme_constant_override("outline_size", 5)
	
	# Headers
	for p in ["MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamA/Label_Header","MarginContainer/MainHBox/VBoxContainer/HBox_Teams/VBox_TeamB/Label_Header"]:
		get_node(p).add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	
	# Arrow buttons — no focus (team containers handle team cycling via gui_input)
	var arrow_dim = Color(0.45, 0.45, 0.6)
	for btn in [btn_a_up, btn_a_down, btn_b_up, btn_b_down]:
		btn.add_theme_color_override("font_color", arrow_dim)
		btn.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.9))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.focus_mode = Control.FOCUS_NONE
	# Court arrows keep their focus (set above in _ready)
	
	# Options labels
	for p in ["MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_TeamSize/Label",
			  "MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Quarters/Label",
			  "MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Court/Label",
			  "MarginContainer/MainHBox/VBoxContainer/OptionsPanel/OptionsVBox/HBox_Items/Label"]:
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
	$MarginContainer/MainHBox/VBoxContainer/OptionsPanel.add_theme_stylebox_override("panel", panel_sb)
	
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
	if event.is_action_pressed("ui_up") and _joy_ready():
		_cycle_team_a(-1); accept_event()
	elif event.is_action_pressed("ui_down") and _joy_ready():
		_cycle_team_a(1); accept_event()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_select_color_a((_swatch_btns_a.size() + selected_color_a_index - 1) % _swatch_btns_a.size())
			accept_event()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_select_color_a((selected_color_a_index + 1) % _swatch_btns_a.size())
			accept_event()

func _on_team_b_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and _joy_ready():
		_cycle_team_b(-1); accept_event()
	elif event.is_action_pressed("ui_down") and _joy_ready():
		_cycle_team_b(1); accept_event()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_select_color_b((_swatch_btns_b.size() + selected_color_b_index - 1) % _swatch_btns_b.size())
			accept_event()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_select_color_b((selected_color_b_index + 1) % _swatch_btns_b.size())
			accept_event()

func _cycle_team_a(dir: int) -> void:
	team_a_index = (team_a_index + dir) % available_teams.size()
	if team_a_index < 0: team_a_index = available_teams.size() - 1
	# When switching team, best-match the new team's color
	selected_color_a_index = _nearest_color_index(available_teams[team_a_index].color_primary)
	_update_ui()

func _cycle_team_b(dir: int) -> void:
	team_b_index = (team_b_index + dir) % available_teams.size()
	if team_b_index < 0: team_b_index = available_teams.size() - 1
	selected_color_b_index = _nearest_color_index(available_teams[team_b_index].color_primary)
	_update_ui()

# Returns the TEAM_COLORS index closest (by rgb distance) to `c`
func _nearest_color_index(c: Color) -> int:
	var best_i = 0
	var best_d = 9999.0
	for i in range(TEAM_COLORS.size()):
		var sc: Color = TEAM_COLORS[i]["color"]
		var d = abs(sc.r - c.r) + abs(sc.g - c.g) + abs(sc.b - c.b)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i

# Returns true if enough time has elapsed since the last joystick input.
func _joy_ready() -> bool:
	var now = Time.get_ticks_msec()
	if now - _last_joy_ms >= JOY_COOLDOWN_MS:
		_last_joy_ms = now
		return true
	return false

# Builds a compact single-element selector  < value >  and adds it to parent.
# Returns [panel, value_label]. The panel is the focusable element;
# left/right input is handled in _input(). Inner < > buttons also work on click.
func _build_arrow_selector(parent: HBoxContainer, labels: Array, initial_idx: int, on_change: Callable) -> Array:
	var panel = PanelContainer.new()
	panel.focus_mode = Control.FOCUS_ALL
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_selector_panel(panel, false)
	panel.focus_entered.connect(func(): _style_selector_panel(panel, true))
	panel.focus_exited.connect(func(): _style_selector_panel(panel, false))

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	panel.add_child(hbox)

	var arrow_l = Button.new()
	arrow_l.text = "◀"
	arrow_l.flat = true
	arrow_l.focus_mode = Control.FOCUS_NONE
	arrow_l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
	arrow_l.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 1.0))
	hbox.add_child(arrow_l)

	var lbl = Label.new()
	lbl.text = labels[initial_idx]
	lbl.custom_minimum_size = Vector2(54, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.focus_mode = Control.FOCUS_NONE
	hbox.add_child(lbl)

	var arrow_r = Button.new()
	arrow_r.text = "▶"
	arrow_r.flat = true
	arrow_r.focus_mode = Control.FOCUS_NONE
	arrow_r.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
	arrow_r.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 1.0))
	hbox.add_child(arrow_r)

	arrow_l.pressed.connect(func():
		var cur = labels.find(lbl.text)
		var new_i = (cur - 1 + labels.size()) % labels.size()
		lbl.text = labels[new_i]
		on_change.call(new_i)
	)
	arrow_r.pressed.connect(func():
		var cur = labels.find(lbl.text)
		var new_i = (cur + 1) % labels.size()
		lbl.text = labels[new_i]
		on_change.call(new_i)
	)

	parent.add_child(panel)
	return [panel, lbl]

func _style_selector_panel(panel: PanelContainer, focused: bool) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color     = Color(0.10, 0.10, 0.18, 0.9) if focused else Color(0.07, 0.07, 0.13, 0.75)
	sb.border_color = Color(0.45, 0.65, 1.0, 0.9)  if focused else Color(0.25, 0.25, 0.45, 0.5)
	sb.set_border_width_all(2 if focused else 1)
	sb.set_corner_radius_all(7)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)

func _regen_player_at(team: Resource, idx: int) -> void:
	if team.roster.size() <= idx: return
	var first_names = ["John","Alex","Chris","Sam","Pat","Mike","David","James","Robert","William","Joseph","Thomas","Charles","Daniel","Matthew","Anthony","Mark","Steven","Paul","Andrew","Kevin","Brian","George","Edward","Ronald","Timothy","Jason","Jeffrey","Ryan","Jacob"]
	var last_names  = ["Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin","Lee","Perez","Thompson","White","Harris","Sanchez","Clark"]
	var p_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	var PlayerDataScript = load("res://scripts/data/player_data.gd")
	var p = PlayerDataScript.new(p_name, 100)
	p.number = randi_range(0, 99)
	p.randomize_with_archetype(1)
	team.roster[idx] = p
	_update_ui()

func _regen_team(team: Resource) -> void:
	var first_names = ["John","Alex","Chris","Sam","Pat","Mike","David","James","Robert","William","Joseph","Thomas","Charles","Daniel","Matthew","Anthony","Mark","Steven","Paul","Andrew","Kevin","Brian","George","Edward","Ronald","Timothy","Jason","Jeffrey","Ryan","Jacob"]
	var last_names  = ["Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin","Lee","Perez","Thompson","White","Harris","Sanchez","Clark"]
	var PlayerDataScript = load("res://scripts/data/player_data.gd")
	for idx in range(team.roster.size()):
		var p_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
		var p = PlayerDataScript.new(p_name, 100)
		p.number = randi_range(0, 99)
		p.randomize_with_archetype(1)
		team.roster[idx] = p
	_update_ui()

# Builds a compact swatch strip and appends it to the given parent control.
func _build_swatch_strip(parent: Control, is_team_a: bool) -> void:
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_bottom", 20)
	margin_container.size_flags_vertical = Control.SIZE_SHRINK_END
	
	var row = HBoxContainer.new()
	row.name = "SwatchStrip"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	margin_container.add_child(row)
	parent.add_child(margin_container)
	
	var btns: Array = []
	for ci in range(TEAM_COLORS.size()):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(24, 24)
		btn.tooltip_text = TEAM_COLORS[ci]["name"]
		btn.focus_mode = Control.FOCUS_NONE
		var idx_cap = ci
		if is_team_a:
			btn.pressed.connect(func(): _select_color_a(idx_cap))
		else:
			btn.pressed.connect(func(): _select_color_b(idx_cap))
		row.add_child(btn)
		btns.append(btn)
	if is_team_a:
		_swatch_btns_a = btns
	else:
		_swatch_btns_b = btns

func _select_color_a(ci: int) -> void:
	selected_color_a_index = ci
	team_a_container.grab_focus()
	_update_ui()

func _select_color_b(ci: int) -> void:
	selected_color_b_index = ci
	team_b_container.grab_focus()
	_update_ui()

func _get_effective_color(team_index: int, selected_ci: int) -> Color:
	if selected_ci >= 0 and selected_ci < TEAM_COLORS.size():
		return TEAM_COLORS[selected_ci]["color"]
	if available_teams.size() > team_index:
		return available_teams[team_index].color_primary
	return Color(0.55, 0.55, 0.7)

func _apply_swatch_styles(btns: Array, selected_ci: int) -> void:
	for i in range(btns.size()):
		var btn: Button = btns[i]
		var c: Color = TEAM_COLORS[i]["color"]
		var is_sel = (i == selected_ci)
		var sb = StyleBoxFlat.new()
		sb.bg_color = c
		sb.border_color = Color.WHITE if is_sel else c.darkened(0.3)
		sb.set_border_width_all(3 if is_sel else 1)
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(0)
		btn.add_theme_stylebox_override("normal", sb)
		var h = sb.duplicate()
		h.bg_color = c.lightened(0.15)
		btn.add_theme_stylebox_override("hover", h)

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
	
	# Apply chosen colors to the team data so everything downstream reads them
	var col_a = _get_effective_color(team_a_index, selected_color_a_index)
	var col_b = _get_effective_color(team_b_index, selected_color_b_index)
	t_a.color_primary = col_a
	t_a.color_secondary = TeamData.derive_secondary(col_a)
	t_b.color_primary = col_b
	t_b.color_secondary = TeamData.derive_secondary(col_b)
	
	# Teams
	team_a_name.text = t_a.name
	team_a_name.add_theme_color_override("font_color", col_a)
	team_a_rating.text = "OVR: %d" % _get_team_rating(t_a)
	team_a_rating.add_theme_color_override("font_color", col_a.lightened(0.2))
	team_a_logo.texture = t_a.logo
	
	team_b_name.text = t_b.name
	team_b_name.add_theme_color_override("font_color", col_b)
	team_b_rating.text = "OVR: %d" % _get_team_rating(t_b)
	team_b_rating.add_theme_color_override("font_color", col_b.lightened(0.2))
	team_b_logo.texture = t_b.logo
	
	# Arrow colors
	for btn in [btn_a_up, btn_a_down]:
		btn.add_theme_color_override("font_color", col_a.darkened(0.3))
		btn.add_theme_color_override("font_hover_color", col_a.lightened(0.2))
	for btn in [btn_b_up, btn_b_down]:
		btn.add_theme_color_override("font_color", col_b.darkened(0.3))
		btn.add_theme_color_override("font_hover_color", col_b.lightened(0.2))
	
	# Restyle swatches
	_apply_swatch_styles(_swatch_btns_a, selected_color_a_index)
	_apply_swatch_styles(_swatch_btns_b, selected_color_b_index)

	# Update inline selector labels
	if _lbl_quarters:  _lbl_quarters.text  = QUARTERS_LABELS[_quarters_index]
	if _lbl_team_size: _lbl_team_size.text = TEAM_SIZE_LABELS[_team_size_index]

	# --- Side selector: [P] icon moves between zones ---
	zone_a_label.text = ""
	zone_spec_label.text = "AI vs AI"
	zone_b_label.text = ""
	zone_spec_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))

	match selected_side:
		0: # Play as Team A
			zone_a_label.text = "🎮"
		1: # Play as Team B
			zone_b_label.text = "🎮"
		2: # Spectate
			zone_spec_label.text = "AI vs AI"

	# Zones: active (selected) + focused states
	_style_zone(zone_a,    selected_side == 0, t_a.color_primary)
	_style_zone(zone_spec, selected_side == 2, Color(0.5, 0.5, 0.7))
	_style_zone(zone_b,    selected_side == 1, t_b.color_primary)
	
	_update_team_panel_borders()
	_update_court_display()
	_update_side_rosters(t_a, t_b)

func _style_zone(zone: PanelContainer, active: bool, active_color: Color = Color.WHITE) -> void:
	var focused = zone.has_focus()
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	if active:
		sb.bg_color = Color(active_color.r * 0.2, active_color.g * 0.2, active_color.b * 0.2, 0.8)
		sb.border_color = active_color.lightened(0.2 if focused else 0.0)
		sb.set_border_width_all(3 if focused else 2)
	else:
		sb.bg_color = Color(0.06, 0.06, 0.12, 0.55 if focused else 0.4)
		sb.border_color = Color(0.6, 0.6, 0.85, 0.7) if focused else Color(0.15, 0.15, 0.25, 0.3)
		sb.set_border_width_all(2 if focused else 1)
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
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = Color(0.12, 0.12, 0.22, 0.6)
	fsb.border_color = Color(0.5, 0.5, 0.8, 0.6)
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("focus", fsb)

# =====================================================================
#  ACTIONS
# =====================================================================

func _update_side_rosters(team_a: Resource, team_b: Resource) -> void:
	for child in left_roster.get_children(): child.queue_free()
	for child in right_roster.get_children(): child.queue_free()

	var max_size = TEAM_SIZE_VALUES[_team_size_index]
	_build_roster_cards(team_a, left_roster, max_size, team_a.color_primary)
	_build_roster_cards(team_b, right_roster, max_size, team_b.color_primary)

func _build_roster_cards(team: Resource, container: VBoxContainer, max_size: int, theme_color: Color) -> void:
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	var header_lbl = Label.new()
	header_lbl.text = "%s Roster" % team.name
	header_lbl.add_theme_font_size_override("font_size", 18)
	header_lbl.add_theme_color_override("font_color", theme_color.lightened(0.3))
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(header_lbl)

	var count = min(team.roster.size(), max_size)
	for i in range(count):
		var p = team.roster[i]
		var p_idx = i

		var pnl = PanelContainer.new()
		pnl.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_show_player_card(p, theme_color)
		)

		var sb_normal = StyleBoxFlat.new()
		sb_normal.bg_color = Color(0.1, 0.1, 0.15, 0.8)
		sb_normal.border_color = theme_color.darkened(0.3)
		sb_normal.set_border_width_all(2)
		sb_normal.set_corner_radius_all(6)
		sb_normal.set_content_margin_all(8)

		var sb_hover = sb_normal.duplicate()
		sb_hover.bg_color = Color(0.15, 0.15, 0.22, 0.95)
		sb_hover.border_color = theme_color.lightened(0.2)

		pnl.add_theme_stylebox_override("panel", sb_normal)
		pnl.mouse_entered.connect(func(): pnl.add_theme_stylebox_override("panel", sb_hover))
		pnl.mouse_exited.connect(func(): pnl.add_theme_stylebox_override("panel", sb_normal))

		var vbox = VBoxContainer.new()
		pnl.add_child(vbox)

		var header_hbox = HBoxContainer.new()
		vbox.add_child(header_hbox)

		if p.portrait:
			var pr = TextureRect.new()
			pr.texture = p.portrait
			pr.custom_minimum_size = Vector2(96, 96)
			pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			header_hbox.add_child(pr)

		var name_lbl = Label.new()
		name_lbl.text = " #%d %s" % [p.number, p.name]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", theme_color.lightened(0.2))
		header_hbox.add_child(name_lbl)

		var ovr_lbl = Label.new()
		var p_ovr = int(round((p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0))
		ovr_lbl.text = "OVR: %d" % p_ovr
		ovr_lbl.add_theme_font_size_override("font_size", 14)
		ovr_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		header_hbox.add_child(ovr_lbl)

		# Per-player regen button
		var btn_r = Button.new()
		btn_r.text = "R"
		btn_r.tooltip_text = "Regenerate Player"
		btn_r.custom_minimum_size = Vector2(28, 28)
		btn_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn_r.focus_mode = Control.FOCUS_NONE
		var sb_r = StyleBoxFlat.new()
		sb_r.bg_color = Color(0.15, 0.22, 0.35, 0.9)
		sb_r.border_color = Color(0.3, 0.5, 0.9, 0.7)
		sb_r.set_border_width_all(1)
		sb_r.set_corner_radius_all(4)
		btn_r.add_theme_stylebox_override("normal", sb_r)
		var sb_rh = sb_r.duplicate(); sb_rh.bg_color = Color(0.2, 0.35, 0.55, 1.0)
		btn_r.add_theme_stylebox_override("hover", sb_rh)
		btn_r.add_theme_font_size_override("font_size", 12)
		btn_r.pressed.connect(func(): _regen_player_at(team, p_idx))
		header_hbox.add_child(btn_r)
		
		var stat_panel = PanelContainer.new()
		var stat_bg = StyleBoxFlat.new()
		stat_bg.bg_color = Color(0.08, 0.08, 0.12, 0.7)
		stat_bg.border_color = theme_color.darkened(0.4)
		stat_bg.set_border_width_all(1)
		stat_bg.set_corner_radius_all(6)
		stat_bg.set_content_margin_all(8)
		stat_panel.add_theme_stylebox_override("panel", stat_bg)
		vbox.add_child(stat_panel)

		var stat_grid = GridContainer.new()
		stat_grid.columns = 2
		stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_grid.add_theme_constant_override("h_separation", 20)
		stat_grid.add_theme_constant_override("v_separation", 6)
		stat_panel.add_child(stat_grid)
		
		var stats_keys = ["speed", "shot", "pass_skill", "tackle", "strength", "aggression"]
		var stats_labels = ["SPD", "SHT", "PAS", "TCK", "STR", "AGG"]
		
		for j in range(6):
			var s_val = float(p.get(stats_keys[j]))
			var s_hbox = HBoxContainer.new()
			s_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var s_lbl = Label.new()
			s_lbl.text = stats_labels[j]
			s_lbl.custom_minimum_size = Vector2(28, 0)
			s_lbl.add_theme_font_size_override("font_size", 12)
			s_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			s_hbox.add_child(s_lbl)
			
			var bar = ProgressBar.new()
			bar.min_value = 0
			bar.max_value = 100
			bar.value = s_val
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			var sb_bar_bg = StyleBoxFlat.new()
			sb_bar_bg.bg_color = Color(0.05, 0.05, 0.05, 0.8)
			sb_bar_bg.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("background", sb_bar_bg)
			
			var c = Color.WHITE
			if s_val <= 50.0:
				var pt = s_val / 50.0
				c = Color(0.2, 0.1, 0.4).lerp(Color(0.1, 0.5, 0.9), pt)
			else:
				var pt = (s_val - 50.0) / 50.0
				c = Color(0.1, 0.5, 0.9).lerp(Color(0.5, 1.0, 1.0), pt)
					
			var sb_fill = StyleBoxFlat.new()
			sb_fill.bg_color = c
			sb_fill.set_corner_radius_all(3)
			bar.add_theme_stylebox_override("fill", sb_fill)
			s_hbox.add_child(bar)
			
			var v_lbl = Label.new()
			v_lbl.text = str(int(s_val))
			v_lbl.custom_minimum_size = Vector2(22, 0)
			v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v_lbl.add_theme_font_size_override("font_size", 12)
			v_lbl.add_theme_color_override("font_color", c)
			s_hbox.add_child(v_lbl)
			
			stat_grid.add_child(s_hbox)
		
		container.add_child(pnl)

	# Regenerate Team button at bottom of roster
	var btn_regen = Button.new()
	btn_regen.text = "REGENERATE TEAM"
	btn_regen.focus_mode = Control.FOCUS_NONE
	var sb_regen = StyleBoxFlat.new()
	sb_regen.bg_color = Color(0.12, 0.18, 0.30, 0.85)
	sb_regen.border_color = Color(0.3, 0.5, 0.9, 0.5)
	sb_regen.set_border_width_all(1)
	sb_regen.set_corner_radius_all(6)
	sb_regen.set_content_margin_all(8)
	btn_regen.add_theme_stylebox_override("normal", sb_regen)
	var sb_regen_h = sb_regen.duplicate(); sb_regen_h.bg_color = Color(0.18, 0.28, 0.46, 1.0)
	btn_regen.add_theme_stylebox_override("hover", sb_regen_h)
	btn_regen.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	btn_regen.add_theme_font_size_override("font_size", 14)
	btn_regen.pressed.connect(func(): _regen_team(team))
	container.add_child(btn_regen)

func _show_player_card(player: Resource, theme_color: Color) -> void:
	var m_scene = load("res://ui/player_card_modal.tscn")
	var m_inst = m_scene.instantiate()
	add_child(m_inst)
	m_inst.setup(player, theme_color)

func _get_team_rating(team: Resource) -> int:
	if team.roster.is_empty(): return 0
	var total = 0.0
	for p in team.roster:
		var p_rating = (p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0
		total += p_rating
	return int(round(total / team.roster.size()))

func _on_start_pressed() -> void:
	var t_a = available_teams[team_a_index]
	var t_b = available_teams[team_b_index]

	var q_len  = QUARTERS_VALUES[_quarters_index]
	var t_size = TEAM_SIZE_VALUES[_team_size_index]
	
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
