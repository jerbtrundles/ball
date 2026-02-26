extends Resource
class_name PlayerData

@export var name: String = "Player"
@export var cost: int = 100
@export var face_seed: int = 0  # For procedural face generation

# Stats (0-10 or 0-100 scale)
@export var speed: float = 5.0
@export var shot: float = 5.0
@export var pass_skill: float = 5.0
@export var tackle: float = 5.0
@export var strength: float = 5.0
@export var aggression: float = 5.0

func _init(p_name: String = "Unknown", p_cost: int = 100):
	name = p_name
	cost = p_cost
	face_seed = randi()

func randomize_stats(tier: int = 1):
	# Tier 1 (Bronze): 3-6 average
	# Tier 2 (Silver): 5-8 average
	# Tier 3 (Gold): 7-10 average
	var base = tier * 2.0 + 1.0
	speed = clampf(base + randf_range(-2, 2), 1, 10)
	shot = clampf(base + randf_range(-2, 2), 1, 10)
	pass_skill = clampf(base + randf_range(-2, 2), 1, 10)
	tackle = clampf(base + randf_range(-2, 2), 1, 10)
	strength = clampf(base + randf_range(-2, 2), 1, 10)
	aggression = clampf(base + randf_range(-2, 2), 1, 10)
