extends Resource
class_name PlayerData

@export var name: String = "Player"
@export var number: int = 0
@export var cost: int = 100
@export var face_seed: int = 0  # For procedural face generation

# Stats (0-10 or 0-100 scale)
@export var speed: float = 5.0
@export var shot: float = 5.0
@export var pass_skill: float = 5.0
@export var tackle: float = 5.0
@export var strength: float = 5.0
@export var aggression: float = 5.0

# Active Season Stats
@export var pts: int = 0
@export var reb: int = 0
@export var ast: int = 0
@export var blk: int = 0

func _init(p_name: String = "Unknown", p_cost: int = 100):
	name = p_name
	cost = p_cost
	face_seed = randi()

func randomize_stats(tier: int = 1):
	# Tier 1 (Bronze): 40 base
	# Tier 2 (Silver): 60 base
	# Tier 3 (Gold): 80 base
	var base = float(tier) * 20.0 + 20.0
	speed = clampf(round(randfn(base, 15.0)), 10.0, 99.0)
	shot = clampf(round(randfn(base, 15.0)), 10.0, 99.0)
	pass_skill = clampf(round(randfn(base, 15.0)), 10.0, 99.0)
	tackle = clampf(round(randfn(base, 15.0)), 10.0, 99.0)
	strength = clampf(round(randfn(base, 15.0)), 10.0, 99.0)
	aggression = clampf(round(randfn(base, 15.0)), 10.0, 99.0)
