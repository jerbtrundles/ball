extends Control

signal closed

# The modal will self-construct its UI to ensure consistent premium styling
# and ease of integration across different scenes.

var _rebinding_action: String = ""
var _is_rebinding: bool = false
var _rebind_button: Button = null
var _btn_close: Button = null

@onready var _panel: PanelContainer = null
@onready var _audio_vbox: VBoxContainer = null
@onready var _controls_vbox: VBoxContainer = null
@onready var _overlay: ColorRect = null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS # Modal works even when game is paused
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # Ensure script node fills screen
	_construct_ui()
	_update_audio_sliders()
	_update_control_list()

func _construct_ui() -> void:
	# 1. Full-screen dim overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	
	# 2. Central Modal Panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(780, 600)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.14, 0.95)
	sb.border_color = Color(0.0, 0.8, 1.0, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(30)
	_panel.add_theme_stylebox_override("panel", sb)
	
	# 3. Content Layout
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	main_vbox.add_child(title)
	
	# Tabs logic using a simple HBox for headers and a container for content
	var tab_hbox = HBoxContainer.new()
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hbox.add_theme_constant_override("separation", 40)
	main_vbox.add_child(tab_hbox)
	
	var btn_audio_tab = Button.new()
	btn_audio_tab.text = "AUDIO"
	_style_tab_button(btn_audio_tab)
	tab_hbox.add_child(btn_audio_tab)
	
	var btn_controls_tab = Button.new()
	btn_controls_tab.text = "CONTROLS"
	_style_tab_button(btn_controls_tab)
	tab_hbox.add_child(btn_controls_tab)
	
	# Content Containers
	var content_stack = Control.new()
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_stack)
	
	# Audio Layout
	_audio_vbox = VBoxContainer.new()
	_audio_vbox.add_theme_constant_override("separation", 25)
	_audio_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_stack.add_child(_audio_vbox)
	
	# Controls Layout
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	content_stack.add_child(scroll)
	
	_controls_vbox = VBoxContainer.new()
	_controls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_controls_vbox)
	
	# Close Button
	var btn_close = Button.new()
	btn_close.text = "CLOSE & SAVE"
	btn_close.custom_minimum_size = Vector2(250, 50)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button_neon(btn_close, Color(0.0, 0.5, 0.6), Color(0.0, 0.8, 1.0))
	main_vbox.add_child(btn_close)
	btn_close.pressed.connect(_on_close_pressed)
	_btn_close = btn_close

	# Tab Switching
	btn_audio_tab.pressed.connect(func():
		get_node("/root/GameAudio").play_click()
		_audio_vbox.visible = true
		scroll.visible = false
		_update_tab_highlights(btn_audio_tab, btn_controls_tab)
	)
	btn_controls_tab.pressed.connect(func():
		get_node("/root/GameAudio").play_click()
		_audio_vbox.visible = false
		scroll.visible = true
		_update_tab_highlights(btn_controls_tab, btn_audio_tab)
	)
	
	# Initial highlight
	_update_tab_highlights(btn_audio_tab, btn_controls_tab)
	btn_close.grab_focus()

func _update_audio_sliders() -> void:
	for child in _audio_vbox.get_children(): child.queue_free()
	
	_add_volume_slider("Master Volume", "master", SettingsManager.master_volume)
	_add_volume_slider("Music Volume", "music", SettingsManager.music_volume)
	_add_volume_slider("Sound Effects", "sfx", SettingsManager.sfx_volume)

func _add_volume_slider(label_text: String, bus_name: String, current_val: float) -> void:
	var row = VBoxContainer.new()
	_audio_vbox.add_child(row)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	row.add_child(lbl)
	
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = current_val
	row.add_child(slider)
	
	slider.value_changed.connect(func(val):
		SettingsManager.set_volume(bus_name, val)
	)

func _update_control_list() -> void:
	for child in _controls_vbox.get_children(): child.queue_free()

	# Column headers
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	_controls_vbox.add_child(header_hbox)
	var _spacer_h = Control.new()
	_spacer_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_spacer_h)
	for col_text in ["KEYBOARD", "CONTROLLER"]:
		var h = Label.new()
		h.text = col_text
		h.custom_minimum_size = Vector2(140, 0)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_theme_font_size_override("font_size", 12)
		h.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		header_hbox.add_child(h)
	_controls_vbox.add_child(HSeparator.new())

	var actions = {
		"move_up":      ["Move Up",        "L-Stick U"],
		"move_down":    ["Move Down",      "L-Stick D"],
		"move_left":    ["Move Left",      "L-Stick L"],
		"move_right":   ["Move Right",     "L-Stick R"],
		"aim_up":       ["Aim Up",         "R-Stick U"],
		"aim_down":     ["Aim Down",       "R-Stick D"],
		"aim_left":     ["Aim Left",       "R-Stick L"],
		"aim_right":    ["Aim Right",      "R-Stick R"],
		"action_pass":  ["Pass / Steal",   "A"],
		"action_shoot": ["Shoot / Block",  "B"],
		"action_sprint":["Sprint",         "X"],
		"action_tackle":["Tackle",         "B"],
		"action_punch": ["Punch",          "Y"],
	}

	for action in actions:
		_add_control_row(action, actions[action][0], actions[action][1])

func _add_control_row(action: String, display_name: String, controller_label: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	_controls_vbox.add_child(hbox)

	var lbl = Label.new()
	lbl.text = display_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	hbox.add_child(lbl)

	var btn_rebind = Button.new()
	btn_rebind.custom_minimum_size = Vector2(140, 36)
	_style_button_subtle(btn_rebind)

	var key_text = "None"
	if SettingsManager.keybinds.has(action):
		key_text = OS.get_keycode_string(SettingsManager.keybinds[action])
	btn_rebind.text = key_text
	hbox.add_child(btn_rebind)

	var ctrl_lbl = Label.new()
	ctrl_lbl.text = controller_label
	ctrl_lbl.custom_minimum_size = Vector2(140, 0)
	ctrl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	hbox.add_child(ctrl_lbl)

	btn_rebind.pressed.connect(func():
		get_node("/root/GameAudio").play_click()
		_start_rebind(action, btn_rebind)
	)

func _start_rebind(action: String, btn: Button) -> void:
	if _is_rebinding: return
	
	_is_rebinding = true
	_rebinding_action = action
	_rebind_button = btn
	btn.text = "Press any key..."
	btn.modulate = Color(0, 1, 1) # Cyan highlight when listening

func _input(event: InputEvent) -> void:
	# Trap focus inside modal
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		if _btn_close:
			_btn_close.grab_focus()

	if _is_rebinding and event is InputEventKey and event.pressed:
		var keycode = event.keycode
		SettingsManager.set_keybind(_rebinding_action, keycode)
		_rebind_button.text = OS.get_keycode_string(keycode)
		_rebind_button.modulate = Color.WHITE
		_is_rebinding = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not _is_rebinding:
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	get_node("/root/GameAudio").play_click()
	closed.emit()
	queue_free()

# --- Styling Helpers ---

func _update_tab_highlights(active: Button, inactive: Button) -> void:
	active.add_theme_color_override("font_color", Color(0, 0.9, 1.0))
	inactive.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

func _style_tab_button(btn: Button) -> void:
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _style_button_neon(btn: Button, bg_col: Color, border_col: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate(); h.bg_color = bg_col.lightened(0.1)
	btn.add_theme_stylebox_override("hover", h)
	var f = sb.duplicate(); f.border_color = Color.WHITE; f.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", f)

func _style_button_subtle(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.2, 0.6)
	sb.border_color = Color(0.3, 0.3, 0.5, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate(); h.bg_color = Color(0.15, 0.15, 0.25, 0.8)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
