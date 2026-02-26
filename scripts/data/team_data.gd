extends Resource
class_name TeamData

@export var name: String = "Team"
@export var color_primary: Color = Color.BLUE
@export var color_secondary: Color = Color.WHITE
@export var logo: Texture2D = null
@export var roster: Array[Resource] = []
@export var wins: int = 0
@export var losses: int = 0
@export var division_rank: int = 0

func _init(p_name: String = "New Team", p_color: Color = Color.BLUE):
	name = p_name
	color_primary = p_color
	roster = []

func add_player(player: Resource):
	roster.append(player)

func reset_record():
	wins = 0
	losses = 0
