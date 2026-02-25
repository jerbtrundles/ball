extends Node
## Hazard Spawner — spawns hazards and items during play on a random timer.

var spawn_enabled: bool = false
var spawn_interval_min: float = 4.0
var spawn_interval_max: float = 8.0
var _spawn_timer: float = 0.0
var _next_spawn: float = 5.0  # First spawn after 5 seconds

# Max active limits
var max_mines: int = 5
var max_saw_blades: int = 2
var max_missiles: int = 1
var max_power_ups: int = 3
var max_coins: int = 8

# Court geometry
var court_half_w: float = 8.0
var court_half_l: float = 15.0

# Spawn weights (must sum to 100)
var spawn_weights: Dictionary = {
	"mine": 35,
	"power_up": 25,
	"coin": 15,
	"saw_blade": 12,
	"crowd_throw": 8,
	"missile": 5,
}

func _process(delta: float) -> void:
	if not spawn_enabled:
		return
	
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn:
		_spawn_timer = 0.0
		_next_spawn = randf_range(spawn_interval_min, spawn_interval_max)
		_spawn_random()

func _spawn_random() -> void:
	# Weighted random selection
	var total_weight = 0
	for w in spawn_weights.values():
		total_weight += w
	
	var roll = randi() % total_weight
	var cumulative = 0
	var chosen = "mine"
	
	for type in spawn_weights:
		cumulative += spawn_weights[type]
		if roll < cumulative:
			chosen = type
			break
	
	# Check limits
	match chosen:
		"mine":
			if _count_active("mine") >= max_mines:
				return
			_spawn_mine()
		"saw_blade":
			if _count_active("saw_blade") >= max_saw_blades:
				return
			_spawn_saw_blade()
		"missile":
			if _count_active("missile") >= max_missiles:
				return
			_spawn_missile()
		"power_up":
			if _count_active("power_up") >= max_power_ups:
				return
			_spawn_power_up()
		"coin":
			if _count_active("coin") >= max_coins:
				return
			_spawn_coins()
		"crowd_throw":
			_spawn_crowd_throw()

func _count_active(type_name: String) -> int:
	var count = 0
	for node in get_tree().get_nodes_in_group("hazards"):
		if type_name in node.get_script().resource_path.to_lower():
			count += 1
	return count

func _get_safe_position() -> Vector3:
	## Random position on court, not too close to hoops or players.
	var pos = Vector3.ZERO
	for _attempt in range(10):
		pos = Vector3(
			randf_range(-court_half_w + 1.5, court_half_w - 1.5),
			0,
			randf_range(-court_half_l + 3.0, court_half_l - 3.0)  # Avoid endlines
		)
		# Check distance from players
		var too_close = false
		for p in get_tree().get_nodes_in_group("players"):
			if p.global_position.distance_to(pos) < 2.0:
				too_close = true
				break
		if not too_close:
			return pos
	return pos  # Give up after 10 attempts

func _spawn_mine() -> void:
	var mine = Node3D.new()
	mine.set_script(load("res://scenes/hazards/mine.gd"))
	mine.global_position = _get_safe_position()
	get_tree().current_scene.add_child(mine)

func _spawn_saw_blade() -> void:
	var blade = Node3D.new()
	blade.set_script(load("res://scenes/hazards/saw_blade.gd"))
	
	# Spawn from a random edge
	var side = randi() % 4
	match side:
		0:  # Left edge, moving right
			blade.global_position = Vector3(-court_half_w - 1.0, 0, randf_range(-court_half_l + 3.0, court_half_l - 3.0))
			blade.travel_direction = Vector3.RIGHT
		1:  # Right edge, moving left
			blade.global_position = Vector3(court_half_w + 1.0, 0, randf_range(-court_half_l + 3.0, court_half_l - 3.0))
			blade.travel_direction = Vector3.LEFT
		2:  # Top edge, moving down
			blade.global_position = Vector3(randf_range(-court_half_w + 1.0, court_half_w - 1.0), 0, -court_half_l - 1.0)
			blade.travel_direction = Vector3(0, 0, 1)
		3:  # Bottom edge, moving up
			blade.global_position = Vector3(randf_range(-court_half_w + 1.0, court_half_w - 1.0), 0, court_half_l + 1.0)
			blade.travel_direction = Vector3(0, 0, -1)
	
	get_tree().current_scene.add_child(blade)

func _spawn_missile() -> void:
	var missile = Node3D.new()
	missile.set_script(load("res://scenes/hazards/homing_missile.gd"))
	# Spawn from above the court at a random edge
	var edge_x = [-court_half_w - 2.0, court_half_w + 2.0][randi() % 2]
	missile.global_position = Vector3(edge_x, 1.5, randf_range(-court_half_l + 3.0, court_half_l - 3.0))
	get_tree().current_scene.add_child(missile)

func _spawn_power_up() -> void:
	var pu = Node3D.new()
	pu.set_script(load("res://scenes/items/power_up.gd"))
	pu.power_type = randi() % 3  # Random type
	pu.global_position = _get_safe_position()
	get_tree().current_scene.add_child(pu)

func _spawn_coins() -> void:
	# Spawn a cluster of 3-5 coins
	var center = _get_safe_position()
	var count = randi_range(3, 5)
	for i in range(count):
		var coin = Node3D.new()
		coin.set_script(load("res://scenes/items/coin.gd"))
		var offset = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		coin.global_position = center + offset
		get_tree().current_scene.add_child(coin)

func _spawn_crowd_throw() -> void:
	var throw = Node3D.new()
	throw.set_script(load("res://scenes/hazards/crowd_throw.gd"))
	
	# Start from beyond a random wall
	var side = randi() % 4
	var start_pos: Vector3
	match side:
		0: start_pos = Vector3(-court_half_w - 3.0, 2.0, randf_range(-court_half_l, court_half_l))
		1: start_pos = Vector3(court_half_w + 3.0, 2.0, randf_range(-court_half_l, court_half_l))
		2: start_pos = Vector3(randf_range(-court_half_w, court_half_w), 2.0, -court_half_l - 3.0)
		3: start_pos = Vector3(randf_range(-court_half_w, court_half_w), 2.0, court_half_l + 3.0)
	
	throw.global_position = start_pos
	throw.target_pos = _get_safe_position()
	throw.target_pos.y = 0.1  # Land on ground
	get_tree().current_scene.add_child(throw)

func clear_all_hazards() -> void:
	## Remove all active hazards and items from the court.
	for node in get_tree().get_nodes_in_group("hazards"):
		node.queue_free()
