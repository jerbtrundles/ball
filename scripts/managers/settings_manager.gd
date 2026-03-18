extends Node

const SETTINGS_FILE = "user://settings.cfg"

# Audio Busses
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8

# Controls (Action Name -> Keycode)
var keybinds: Dictionary = {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"aim_up": KEY_UP,
	"aim_down": KEY_DOWN,
	"aim_left": KEY_LEFT,
	"aim_right": KEY_RIGHT,
	"action_pass": KEY_J,
	"action_shoot": KEY_K,
	"action_sprint": KEY_SPACE,
	"action_tackle": KEY_L,
	"action_punch": KEY_I
}

func _ready() -> void:
	load_settings()
	apply_audio_settings()
	apply_input_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	
	for action in keybinds:
		config.set_value("controls", action, keybinds[action])
	
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err != OK: return
	
	master_volume = config.get_value("audio", "master", master_volume)
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	
	for action in keybinds.keys():
		keybinds[action] = config.get_value("controls", action, keybinds[action])

func apply_audio_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	# Assuming "Music" and "SFX" buses exist or fall back to Master for now
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))
	
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))

func apply_input_settings() -> void:
	for action in keybinds:
		if not InputMap.has_action(action):
			continue
		# Preserve joypad/mouse events; only replace the keyboard binding
		var preserved: Array = []
		for ev in InputMap.action_get_events(action):
			if not ev is InputEventKey:
				preserved.append(ev)
		InputMap.action_erase_events(action)
		for ev in preserved:
			InputMap.action_add_event(action, ev)
		var kb = InputEventKey.new()
		kb.keycode = keybinds[action]
		InputMap.action_add_event(action, kb)

func set_keybind(action: String, keycode: int) -> void:
	keybinds[action] = keycode
	apply_input_settings()
	save_settings()

func set_volume(bus_name: String, value: float) -> void:
	match bus_name.to_lower():
		"master": master_volume = value
		"music": music_volume = value
		"sfx": sfx_volume = value
	apply_audio_settings()
	save_settings()
