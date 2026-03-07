extends Resource
class_name PlayerData

@export var name: String = "Player"
@export var number: int = 0
@export var cost: int = 100
@export var face_seed: int = 0  # For procedural face generation
@export var portrait: Texture2D

static var _portrait_files = [
	"portrait_agile_1772877045266.png",
	"portrait_bruiser_1772877032269.png",
	"portrait_mutant_1772877102515.png",
	"portrait_mystic_1772877055763.png",
	"portrait_ninja_1772877090950.png",
	"portrait_punk_1772877021304.png",
	"portrait_scavenger_1772877115262.png",
	"portrait_veteran_1772877077685.png",
	"portrait_snes_cyborg_1772878133252.png",
	"portrait_snes_scavenger_1772878147340.png",
	"portrait_snes_punk_1772878160692.png",
	"portrait_snes_bruiser_1772878174526.png",
	"portrait_snes_mutant_1772878187681.png",
	"portrait_snes_veteran_1772878201019.png",
	"portrait_snes_tech_1772878211447.png",
	"portrait_snes_gasmask_1772878223770.png"
]
static var _portrait_pool: Array[Texture2D] = []

static func _load_portraits():
	if _portrait_pool.size() > 0:
		return
	for f in _portrait_files:
		var tex = load("res://assets/portraits/" + f) as Texture2D
		if tex:
			_portrait_pool.append(tex)

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
@export var fgm: int = 0
@export var fga: int = 0
@export var tpm: int = 0
@export var tpa: int = 0

# History of stats for each game played. Each entry is a dictionary:
# { "opponent": String, "pts": int, "reb": int, "ast": int, "blk": int, "is_win": bool }
@export var game_log: Array = []

func _init(p_name: String = "Unknown", p_cost: int = 100):
	name = p_name
	cost = p_cost
	face_seed = randi()
	PlayerData._load_portraits()
	if PlayerData._portrait_pool.size() > 0:
		portrait = PlayerData._portrait_pool[randi() % PlayerData._portrait_pool.size()]

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

func randomize_with_archetype(tier: int = 1):
	var base = float(tier) * 20.0 + 20.0
	var archetypes = ["shooter", "passer", "rebounder", "balanced"]
	var archetype = archetypes[randi() % archetypes.size()]
	
	var min_stat = 10.0
	var max_stat = min(base + 25.0, 99.0)
	var prim_base = min(base + 15.0, 99.0)
	var sec_base = max(base - 10.0, 10.0)
	
	if archetype == "balanced":
		randomize_stats(tier)
	elif archetype == "shooter":
		var is_great = randf() < 0.2
		if is_great:
			shot = clampf(round(randfn(prim_base + 15.0, 5.0)), prim_base, 99.0)
			for k in ["speed", "pass_skill", "tackle", "strength", "aggression"]:
				set(k, clampf(round(randfn(sec_base - 10.0, 10.0)), min_stat, max_stat))
		else:
			shot = clampf(round(randfn(prim_base, 5.0)), base, max_stat)
			for k in ["speed", "pass_skill", "tackle", "strength", "aggression"]:
				set(k, clampf(round(randfn(sec_base, 15.0)), min_stat, max_stat))
	elif archetype == "passer":
		pass_skill = clampf(round(randfn(prim_base, 5.0)), base, max_stat)
		speed = clampf(round(randfn(prim_base, 5.0)), base, max_stat)
		strength = clampf(round(randfn(sec_base, 10.0)), min_stat, max_stat)
		aggression = clampf(round(randfn(sec_base, 10.0)), min_stat, max_stat)
		shot = clampf(round(randfn(base, 15.0)), min_stat, max_stat)
		tackle = clampf(round(randfn(base, 15.0)), min_stat, max_stat)
	elif archetype == "rebounder":
		strength = clampf(round(randfn(prim_base, 5.0)), base, max_stat)
		aggression = clampf(round(randfn(prim_base, 5.0)), base, max_stat)
		tackle = clampf(round(randfn(prim_base, 5.0)), base, max_stat)
		shot = clampf(round(randfn(sec_base, 10.0)), min_stat, max_stat)
		pass_skill = clampf(round(randfn(sec_base, 10.0)), min_stat, max_stat)
		speed = clampf(round(randfn(sec_base, 10.0)), min_stat, max_stat)
