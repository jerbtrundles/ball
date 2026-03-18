extends Node

# A global manager for non-positional UI sounds
var _click_player: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = load("res://assets/sounds/click.wav")
	_click_player.bus = "SFX"
	add_child(_click_player)

func play_click() -> void:
	if _click_player:
		# Slight pitch randomization for character
		_click_player.pitch_scale = randf_range(0.95, 1.05)
		_click_player.play()

# Useful for playing any one-shot globally
func play_sfx(path: String, volume_db: float = 0.0) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = "SFX"
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
