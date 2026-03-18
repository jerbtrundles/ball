extends Control

func _ready() -> void:
	# Ensure the root node fills the screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Build Thematic Background
	var bg_tex = load("res://assets/images/ui/main_menu_bg.png")
	if bg_tex:
		if has_node("ColorRect"):
			$ColorRect.hide()
			
		var bg_rect = TextureRect.new()
		bg_rect.texture = bg_tex
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg_rect)
		move_child(bg_rect, 0)
		
	var vbox = $VBoxContainer
	remove_child(vbox)

	vbox.set_anchor(SIDE_LEFT, 0.5)
	vbox.set_anchor(SIDE_TOP, 0.0)
	vbox.set_anchor(SIDE_RIGHT, 0.5)
	vbox.set_anchor(SIDE_BOTTOM, 1.0)
	vbox.set_offset(SIDE_LEFT, 0)
	vbox.set_offset(SIDE_TOP, 100)
	vbox.set_offset(SIDE_RIGHT, 0)
	vbox.set_offset(SIDE_BOTTOM, -160)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(vbox)
	
	vbox.add_theme_constant_override("separation", 20)
	
	# Cleanup any existing title labels from the .tscn to avoid redundancy
	for child in vbox.get_children():
		if child is Label and ("COMBAT" in child.text.to_upper() or "SUPER" in child.text.to_upper()):
			child.queue_free()
	
	# 1. Ghost Shell (Narrow box to fool the VBox)
	var shell = Control.new()
	shell.custom_minimum_size = Vector2(400, 160) # Slightly shorter
	vbox.add_child(shell)
	vbox.move_child(shell, 0)
	
	# 2. Brand Isolation Card (Overflowing Ghost Version)
	var brand_card = PanelContainer.new()
	var b_width = 1460 # Wide enough for all three words with equal spacing
	var b_height = 180
	brand_card.custom_minimum_size = Vector2(b_width, b_height)
	brand_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var b_sb = StyleBoxFlat.new()
	b_sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	b_sb.set_border_width_all(0)
	b_sb.content_margin_left = 60
	b_sb.content_margin_right = 60
	b_sb.content_margin_top = 20
	b_sb.content_margin_bottom = 20
	brand_card.add_theme_stylebox_override("panel", b_sb)
	
	shell.add_child(brand_card)
	# Robust Centering: Grow both ways from center to ensure perfect balance
	brand_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	brand_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	brand_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 3. Vertical Spacer (Prevent button overlap & add breathing room)
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)
	vbox.move_child(spacer, 1)
	
	# 3. Unified 3D WordArt — COMBAT pinned to exact horizontal center;
	#    JBAX'S and BASKETBALL placed with equal visual gap from COMBAT's text edges.
	var words_container = Control.new()
	brand_card.add_child(words_container)
	words_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_word_stacks.clear()
	var words = ["JBAX'S", "COMBAT", "BASKETBALL"]
	var font_size = 85
	var layers_count = 10

	var edge_font = SystemFont.new()
	edge_font.font_names = PackedStringArray(["Impact", "Arial Black", "sans-serif"])
	edge_font.font_weight = 700
	edge_font.font_italic = true

	# Measure actual rendered text widths so positioning works on every platform
	# (web exports can't access OS fonts; SystemFont falls back to a much narrower face).
	var est_text_w = {}
	for _w in words:
		est_text_w[_w] = edge_font.get_string_size(_w, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var word_gap   = 35.0   # equal visual gap (px) on each side of COMBAT
	var shell_pad  = 20.0   # extra shell width beyond estimated text width
	var shell_h    = font_size * 1.3
	var combat_hw  = est_text_w["COMBAT"] / 2.0  # half-width of COMBAT text
	for w_text in words:
		var tw     = est_text_w[w_text]
		var shell_w = tw + shell_pad
		# cx = horizontal offset of this shell's center from words_container center
		# COMBAT pinned at cx=0 (exact horizontal center)
		var cx: float
		if w_text == "COMBAT":
			cx = 0.0
		elif w_text == "JBAX'S":
			cx = -(combat_hw + word_gap + tw / 2.0)
		else:  # BASKETBALL
			cx = +(combat_hw + word_gap + tw / 2.0)

		var word_shell = Control.new()
		word_shell.set_anchor(SIDE_LEFT,   0.5)
		word_shell.set_anchor(SIDE_RIGHT,  0.5)
		word_shell.set_anchor(SIDE_TOP,    0.5)
		word_shell.set_anchor(SIDE_BOTTOM, 0.5)
		word_shell.set_offset(SIDE_LEFT,   cx - shell_w / 2.0)
		word_shell.set_offset(SIDE_RIGHT,  cx + shell_w / 2.0)
		word_shell.set_offset(SIDE_TOP,    -shell_h / 2.0)
		word_shell.set_offset(SIDE_BOTTOM,  shell_h / 2.0)
		words_container.add_child(word_shell)

		var layers: Array[Label] = []
		for i in range(layers_count):
			var lbl = Label.new()
			lbl.text = w_text
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_override("font", edge_font)
			lbl.add_theme_font_size_override("font_size", font_size)
			word_shell.add_child(lbl)
			lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
			lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
			layers.append(lbl)

		_word_stacks.append(layers)
	
	_title_card = brand_card
	
	# 4. Main Menu Soundtrack (Game Over Funk)
	var music = AudioStreamPlayer.new()
	# var stream = load("res://assets/sounds/Game_Over_Funk.mp3")
	# var stream = load("res://assets/sounds/Post_Apocalyptic_Gridiron.mp3")
	# var stream = load("res://assets/sounds/intro.mp3")
	var stream = load("res://assets/sounds/Chrome_Rim_Rumble.mp3")
	if stream is AudioStreamMP3:
		stream.loop = true
	music.stream = stream
	music.bus = "Music"
	add_child(music)
	music.play()
# Capstone layer for primary logic
	
	# Remove scene-defined buttons, rebuild from scratch
	for child in vbox.get_children():
		if child is Button:
			child.queue_free()

	var flex_top = Control.new()
	flex_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex_top.focus_mode = Control.FOCUS_NONE
	vbox.add_child(flex_top)

	var btn_quick = Button.new()
	btn_quick.text = "🏀  QUICK MATCH"
	btn_quick.pressed.connect(_on_quick_match_pressed)
	_style_menu_button(btn_quick, PINK)
	vbox.add_child(btn_quick)
	_btn_quick = btn_quick

	var btn_tournament = Button.new()
	btn_tournament.text = "🏆  TOURNAMENT"
	btn_tournament.pressed.connect(_on_tournament_pressed)
	_style_menu_button(btn_tournament, ORANGE)
	vbox.add_child(btn_tournament)

	var btn_survival = Button.new()
	btn_survival.text = "💀  SURVIVAL"
	btn_survival.pressed.connect(_on_survival_pressed)
	_style_menu_button(btn_survival, Color(0.15, 0.65, 0.2))
	vbox.add_child(btn_survival)

	var btn_season = Button.new()
	btn_season.text = "🏅  FRANCHISE"
	btn_season.pressed.connect(_on_new_season_pressed)
	_style_menu_button(btn_season, PINK)
	vbox.add_child(btn_season)

	vbox.add_child(_make_separator())

	# Optional: Load Game (hoisted so we can reference it for focus neighbors)
	var btn_load: Button = null
	if LeagueManager.has_any_save():
		btn_load = Button.new()
		btn_load.text = "📂  LOAD GAME"
		btn_load.pressed.connect(_on_load_game_pressed)
		_style_menu_button(btn_load, Color(0.3, 0.8, 1.0))
		vbox.add_child(btn_load)

	vbox.add_child(_make_separator())

	# 2-up row: How to Play + Settings
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	vbox.add_child(row1)

	var btn_howto = Button.new()
	btn_howto.text = "❓  HOW TO PLAY"
	btn_howto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_howto.pressed.connect(_on_rules_pressed)
	_style_small_button(btn_howto, PINK.darkened(0.2))
	row1.add_child(btn_howto)

	var btn_settings = Button.new()
	btn_settings.text = "⚙  SETTINGS"
	btn_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_settings.pressed.connect(_on_settings_pressed)
	_style_small_button(btn_settings, Color(0.2, 0.8, 0.5))
	row1.add_child(btn_settings)

	# 2-up row: Debug + Quit
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	vbox.add_child(row2)

	var btn_debug = Button.new()
	btn_debug.text = "DEBUG"
	btn_debug.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_debug.pressed.connect(_on_debug_pressed)
	_style_small_button(btn_debug, Color(0.4, 0.4, 0.5))
	row2.add_child(btn_debug)

	var btn_quit = Button.new()
	btn_quit.text = "QUIT"
	btn_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quit.pressed.connect(_on_quit_pressed)
	_style_small_button(btn_quit, Color(0.6, 0.2, 0.2))
	row2.add_child(btn_quit)

	var flex_bot = Control.new()
	flex_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex_bot.focus_mode = Control.FOCUS_NONE
	vbox.add_child(flex_bot)

	# Explicit focus neighbors — spatial algorithm can't reliably cross
	# separator nodes or hop from VBox children into nested HBox children.
	var above_rows: Button = btn_load if btn_load else btn_season
	above_rows.focus_neighbor_bottom = above_rows.get_path_to(btn_howto)
	btn_howto.focus_neighbor_top    = btn_howto.get_path_to(above_rows)
	btn_settings.focus_neighbor_top = btn_settings.get_path_to(above_rows)
	btn_howto.focus_neighbor_right   = btn_howto.get_path_to(btn_settings)
	btn_settings.focus_neighbor_left = btn_settings.get_path_to(btn_howto)
	btn_howto.focus_neighbor_bottom  = btn_howto.get_path_to(btn_debug)
	btn_settings.focus_neighbor_bottom = btn_settings.get_path_to(btn_quit)
	btn_debug.focus_neighbor_top  = btn_debug.get_path_to(btn_howto)
	btn_quit.focus_neighbor_top   = btn_quit.get_path_to(btn_settings)
	btn_debug.focus_neighbor_right = btn_debug.get_path_to(btn_quit)
	btn_quit.focus_neighbor_left   = btn_quit.get_path_to(btn_debug)
	if btn_load:
		btn_season.focus_neighbor_bottom = btn_season.get_path_to(btn_load)
		btn_load.focus_neighbor_top      = btn_load.get_path_to(btn_season)
		btn_load.focus_neighbor_bottom   = btn_load.get_path_to(btn_howto)

	# Version label
	var ver = Label.new()
	ver.text = "v0.9.5-PREMIUM"
	ver.add_theme_font_size_override("font_size", 14)
	ver.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(ver)


	# Grab focus
	btn_quick.grab_focus()

	# 5. Credits Ticker (Phase 40) - Direct child with robust anchoring
	var ticker_panel = Panel.new()
	add_child(ticker_panel)
	ticker_panel.move_to_front()
	ticker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var t_sb = StyleBoxFlat.new()
	t_sb.bg_color = Color(0.01, 0.01, 0.02, 0.9)
	t_sb.border_color = Color(1, 0, 1) # Hot Pink / Magenta for visibility
	t_sb.set_border_width_all(3)
	t_sb.border_width_top = 4
	ticker_panel.add_theme_stylebox_override("panel", t_sb)
	
	ticker_panel.set_anchor(SIDE_LEFT, 0.0)
	ticker_panel.set_anchor(SIDE_TOP, 1.0)
	ticker_panel.set_anchor(SIDE_RIGHT, 1.0)
	ticker_panel.set_anchor(SIDE_BOTTOM, 1.0)
	ticker_panel.set_offset(SIDE_LEFT, 0)
	ticker_panel.set_offset(SIDE_TOP, -60)
	ticker_panel.set_offset(SIDE_RIGHT, 0)
	ticker_panel.set_offset(SIDE_BOTTOM, 0)
	
	var ticker_clip = Control.new()
	ticker_clip.clip_contents = true
	ticker_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ticker_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker_panel.add_child(ticker_clip)

	var credits = [
		{"key": "MADE BY:", "value": "JBAX@",    "key_color": Color(0.0, 0.9, 1.0)},
		{"key": "ART BY:",  "value": "AI SLOP",  "key_color": Color(1.0, 0.85, 0.1)},
		{"key": "MUSIC BY:","value": "AI SLOP",  "key_color": Color(0.0, 0.9, 1.0)},
		{"key": "CODE BY:", "value": "AI SLOP",  "key_color": Color(1.0, 0.85, 0.1)},
	]

	var copy_a = HBoxContainer.new()
	copy_a.custom_minimum_size.y = 60
	copy_a.add_theme_constant_override("separation", 10)
	ticker_clip.add_child(copy_a)

	var copy_b = HBoxContainer.new()
	copy_b.custom_minimum_size.y = 60
	copy_b.add_theme_constant_override("separation", 10)
	ticker_clip.add_child(copy_b)

	# Rebind _add_copy to fill the right hbox
	var _fill_copy = func(target: HBoxContainer):
		for d in credits:
			var key_lbl = Label.new()
			key_lbl.text = "  " + d["key"]
			key_lbl.add_theme_font_size_override("font_size", 18)
			key_lbl.add_theme_color_override("font_color", d["key_color"])
			key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			key_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			target.add_child(key_lbl)
			var val_lbl = Label.new()
			val_lbl.text = " " + d["value"]
			val_lbl.add_theme_font_size_override("font_size", 18)
			val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
			val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			val_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			target.add_child(val_lbl)
			var sep = Label.new()
			sep.text = "   |   "
			sep.add_theme_font_size_override("font_size", 18)
			sep.add_theme_color_override("font_color", Color(0.5, 0.4, 0.65))
			sep.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
			target.add_child(sep)

	# Seed copy_a with one raw pass to measure
	_fill_copy.call(copy_a)

	await get_tree().process_frame
	await get_tree().process_frame

	var raw_w = copy_a.get_minimum_size().x
	var screen_w = get_viewport_rect().size.x
	var reps = max(1, int(ceil(screen_w / raw_w)))

	# Fill remaining reps on copy_a, then mirror to copy_b
	for _r in range(reps - 1):
		_fill_copy.call(copy_a)
	for _r in range(reps):
		_fill_copy.call(copy_b)

	_ticker_copy_width = copy_a.get_minimum_size().x
	copy_b.position.x = _ticker_copy_width
	_ticker_copies = [copy_a, copy_b]

var _title_card: PanelContainer
var _btn_quick: Button = null
var _word_stacks: Array = [] # Array of Arrays[Label]
var _anim_time: float = 0.0
var _seq_timer: float = 0.0
var _active_word_idx: int = -1
var _word_pop_progress: float = 0.0

enum WordEffect { DRIBBLE, SPIN, SQUASH, SCATTER }
var _current_effect: int = WordEffect.DRIBBLE

var _ticker_copies: Array = []
var _ticker_copy_width: float = 0.0

const PINK   = Color(0.9, 0.3, 0.5)
const ORANGE = Color(1.0, 0.5, 0.0)

func _process(delta: float) -> void:
	if _word_stacks.is_empty() and _ticker_copies.is_empty(): return

	_anim_time += delta

	# 0. Ticker Animation
	if _ticker_copies.size() == 2 and _ticker_copy_width > 0:
		for c in _ticker_copies:
			c.position.x -= 120.0 * delta
			if c.position.x + _ticker_copy_width <= 0.0:
				var other = _ticker_copies[1] if c == _ticker_copies[0] else _ticker_copies[0]
				c.position.x = other.position.x + _ticker_copy_width


	# 3. Fiery WordArt Animation (Sequential Punch Version)
	if _word_stacks.size() > 0:
		# Hot Color Cycle
		var hot_cycle = [
			Color(1.0, 1.0, 0.5), # Burning Yellow
			Color(1.0, 0.6, 0.2), # Orange
			Color(1.0, 0.2, 0.1)  # Hot Red
		]
		var color_idx = int(_anim_time * 0.8) % hot_cycle.size()
		var n_idx = (color_idx + 1) % hot_cycle.size()
		var l_val = fmod(_anim_time * 0.8, 1.0)
		var top_col = hot_cycle[color_idx].lerp(hot_cycle[n_idx], l_val)
		
		# Sequential Word Pop Logic (Precision Rhythmic 1-2-3)
		if _active_word_idx == -1:
			_seq_timer -= delta
			if _seq_timer <= 0:
				_active_word_idx = 0
				_word_pop_progress = 0.0
				_current_effect = _pick_word_effect()
		else:
			# Progress the individual word's pop animation (spin runs at half rate)
			var anim_speed = 2.5 if _current_effect == WordEffect.SPIN else 5.0
			_word_pop_progress += delta * anim_speed
			if _word_pop_progress >= 1.0:
				# Individual word finished its pop, enter "Small Wait"
				_word_pop_progress = 1.0

				_seq_timer -= delta # Use timer for the 0.5s gap
				if _seq_timer <= -0.5: # 0.5s wait between words
					_word_pop_progress = 0.0
					_active_word_idx += 1
					_seq_timer = 0.0 # Clear gap timer

					if _active_word_idx >= _word_stacks.size():
						_active_word_idx = -1
						_seq_timer = 3.0 # Full recovery delay
					else:
						_current_effect = _pick_word_effect()
		
		# Apply animations to each word stack
		for w_idx in range(_word_stacks.size()):
			var layers = _word_stacks[w_idx]
			var word_shell = layers[0].get_parent()

			var w_y_offset  = 0.0
			var w_scale     = Vector2(1.0, 1.0)
			var w_rotation  = 0.0
			var scatter_amt = 0.0  # 0..1, drives layer burst for SCATTER

			if w_idx == _active_word_idx:
				var p = _word_pop_progress
				match _current_effect:
					WordEffect.DRIBBLE:
						# Asymmetrical gravity curve: slam down, float back
						var y_factor = 0.0
						if p < 0.35:
							var np = p / 0.35
							y_factor = np * np
						else:
							var np = (p - 0.35) / 0.65
							y_factor = 1.0 - (np * (2.0 - np))
						w_y_offset = y_factor * 45.0
					WordEffect.SPIN:
						# 3 full rotations ease-out — lands exactly back at upright
						var np = 1.0 - pow(1.0 - p, 2.0)
						w_rotation = np * 3.0 * TAU
					WordEffect.SQUASH:
						# Flatten → spring tall → micro-wobble settle
						if p < 0.25:
							var np = p / 0.25
							w_scale    = Vector2(1.0 + np * 0.45, 1.0 - np * 0.65)
							w_y_offset = np * 30.0
						elif p < 0.55:
							var np     = (p - 0.25) / 0.30
							var spring = 1.0 + sin(np * PI) * 0.55
							w_scale    = Vector2(2.0 / (1.0 + spring), spring)
							w_y_offset = 30.0 * (1.0 - np)
						else:
							var np     = (p - 0.55) / 0.45
							var wobble = sin(np * PI * 3.0) * (1.0 - np) * 0.08
							w_scale    = Vector2(1.0 + wobble, 1.0 - wobble)
					WordEffect.SCATTER:
						# Layers fan out in a ring then snap back
						scatter_amt = sin(p * PI)

			word_shell.position.y = w_y_offset
			word_shell.scale      = w_scale
			word_shell.rotation   = w_rotation
			word_shell.pivot_offset = word_shell.size / 2.0

			for i in range(layers.size()):
				var layer = layers[i]
				var t = float(i) / float(layers.size() - 1)

				# Billow + 3D depth (unchanged)
				var flicker_y    = sin(_anim_time * (2.0 + i * 0.3 + w_idx * 0.4)) * (1.5 + (1.0 - t) * 5.0)
				var wave_x       = cos(_anim_time * 0.7 + i * 0.1 + w_idx * 0.2) * 4.0
				var depth_offset = (layers.size() - i)
				layer.position   = Vector2(depth_offset + wave_x, depth_offset - flicker_y - (1.0 - t) * 10.0)

				# SCATTER: each layer fans to a unique radial direction
				if scatter_amt > 0.0:
					var angle = float(i) / float(layers.size()) * TAU
					layer.position += Vector2(cos(angle), sin(angle)) * scatter_amt * 40.0

				# Hot Gradient
				if i == layers.size() - 1:
					layer.add_theme_color_override("font_color", top_col)
				else:
					var layer_col = Color(0.1, 0.0, 0.0).lerp(top_col.darkened(0.5), t)
					layer.add_theme_color_override("font_color", layer_col)
		
		# Gentle Heat Pulse & Energetic Wobble
		_title_card.pivot_offset = _title_card.size / 2.0
		var heat_pulse = (sin(_anim_time * 1.0) + 1.0) / 2.0
		_title_card.scale = Vector2(1.0, 1.0) + (Vector2(0.02, 0.02) * heat_pulse)
		_title_card.rotation = deg_to_rad(sin(_anim_time * 1.6) * 2.5) # Energetic Wobble

func _pick_word_effect() -> int:
	var r = randf()
	if   r < 0.50: return WordEffect.DRIBBLE   # 50% — familiar bounce
	elif r < 0.70: return WordEffect.SPIN       # 20% — fast triple spin
	elif r < 0.85: return WordEffect.SQUASH     # 15% — squash & spring
	else:          return WordEffect.SCATTER    # 15% — layer burst

func _style_menu_button(btn: Button, accent: Color) -> void:
	btn.custom_minimum_size = Vector2(350, 55)
	
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.12, 0.16, 0.7)
	sb_n.border_color = accent.darkened(0.5)
	sb_n.border_color.a = 0.5
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(8)
	
	var sb_h = sb_n.duplicate()
	sb_h.bg_color = accent.darkened(0.4)
	sb_h.border_color = accent
	sb_h.border_color.a = 0.8
	sb_h.set_border_width_all(2)
	
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_n)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _style_small_button(btn: Button, accent: Color) -> void:
	btn.custom_minimum_size = Vector2(100, 45)

	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.12, 0.16, 0.7)
	sb_n.border_color = accent.darkened(0.5)
	sb_n.border_color.a = 0.5
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(8)

	var sb_h = sb_n.duplicate()
	sb_h.bg_color = accent.darkened(0.4)
	sb_h.border_color = accent
	sb_h.border_color.a = 0.8
	sb_h.set_border_width_all(2)

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_n)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _make_section_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	return lbl

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = Color(0.9, 0.3, 0.5, 0.55)  # pink stripe
	sep_sb.content_margin_top = 2.0
	sep_sb.content_margin_bottom = 2.0
	sep.add_theme_stylebox_override("separator", sep_sb)
	sep.custom_minimum_size = Vector2(0, 3)
	return sep

func _on_rules_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	var rules_script = load("res://ui/league_rules_modal.gd")
	var rules_inst = Control.new()
	rules_inst.set_script(rules_script)
	rules_inst.accent_color = Color(0.9, 0.3, 0.5)
	add_child(rules_inst)
	rules_inst.tree_exited.connect(_restore_focus)

func _on_debug_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	LeagueManager.start_debug_match()

func _on_quick_match_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	SceneManager.change_scene("res://ui/quick_match_setup.tscn")

func _on_load_game_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	var picker = load("res://ui/save_picker_modal.tscn").instantiate()
	add_child(picker)
	picker.tree_exited.connect(_restore_focus)

func _on_new_season_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	SceneManager.change_scene("res://ui/season_setup.tscn")

func _restore_focus() -> void:
	if _btn_quick and is_instance_valid(_btn_quick):
		_btn_quick.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()

func _on_quit_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	get_tree().quit()

func _on_settings_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	var modal_script = load("res://ui/settings_modal.gd")
	var modal = modal_script.new()
	add_child(modal)
	modal.tree_exited.connect(_restore_focus)

func _on_tournament_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	SceneManager.change_scene("res://ui/tournament_setup.tscn")

func _on_survival_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	SceneManager.change_scene("res://ui/survival_setup.tscn")
