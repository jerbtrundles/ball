extends Resource
class_name TeamData

@export var name: String = "Team"
@export var color_primary: Color = Color.BLUE
@export var color_secondary: Color = Color.WHITE
@export var logo: Texture2D = null
@export var roster: Array[Resource] = []
@export var wins: int = 0
@export var losses: int = 0
@export var pf: int = 0
@export var pa: int = 0
@export var streak: int = 0
@export var division_rank: int = 0
@export var funds: int = 5000

func _init(p_name: String = "New Team", p_color: Color = Color.BLUE, p_secondary: Color = Color(-1,-1,-1)):
	name = p_name
	color_primary = p_color
	# Derive secondary if not explicitly provided
	if p_secondary.r < 0.0:
		color_secondary = derive_secondary(p_color)
	else:
		color_secondary = p_secondary
	roster = []

# Returns a complementary accent color given a primary.
# Shifts hue by ~150°, keeps medium saturation, near-white value.
static func derive_secondary(primary: Color) -> Color:
	var h = primary.h
	var s = primary.s
	var v = primary.v
	# Shift hue by 0.42 (≈150°) for a rich complement; cap saturation for readability
	var h2 = fmod(h + 0.42, 1.0)
	var s2 = clampf(s * 0.55 + 0.25, 0.2, 0.7)
	var v2 = clampf(v * 0.4 + 0.6, 0.75, 1.0)
	return Color.from_hsv(h2, s2, v2)

func add_player(player: Resource):
	roster.append(player)

func reset_record():
	wins = 0
	losses = 0
	pf = 0
	pa = 0
	streak = 0
