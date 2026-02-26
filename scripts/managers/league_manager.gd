extends Node

# Signal for UI updates
signal season_advanced()

# Preload scripts to avoid global class cache issues in headless
const TeamDataScript = preload("res://scripts/data/team_data.gd")
const PlayerDataScript = preload("res://scripts/data/player_data.gd")

# Configuration
var divisions: Array[Dictionary] = [] # Array of {name: String, teams: Array[Resource]}
var current_season: int = 1
var player_team: Resource = null # TeamData

# Pending match data for GameManager handshake
var pending_match_data: Dictionary = {}

# For debug/testing: Pre-defined team names
const TEAM_NAMES = [
	"Cobras", "Vipers", "Raptors", "Sharks", 
	"Bulls", "Rhinos", "Tigers", "Lions",
	"Hawks", "Eagles", "Falcons", "Ravens",
	"Titans", "Giants", "Spartans", "Vikings"
]

func _ready():
	randomize()
	# generate_default_league() # Call manually or from main menu

func generate_default_league():
	divisions = []
	current_season = 1
	var used_names = []
	
	# Create 3 Divisions: Bronze, Silver, Gold
	# 4 Teams per division for simplicity initially
	var division_names = ["Bronze", "Silver", "Gold"]
	
	for i in range(division_names.size()):
		var div_name = division_names[i]
		var teams_in_div: Array[Resource] = []
		
		for j in range(4):
			var t_name = _get_unique_name(used_names)
			used_names.append(t_name)
			
			# Generate color based on division + index
			var hue = float(j) / 4.0
			var sat = 0.5 + (float(i) * 0.2) # Higher tier = more saturated?
			var val = 0.8
			var color = Color.from_hsv(hue, sat, val)
			
			var team = TeamDataScript.new(t_name, color)
			
			# Generate Logo
			var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
			img.fill(color)
			# Draw a simple border
			var border_col = Color.WHITE
			for x in range(64):
				for y in range(64):
					if x < 4 or x > 59 or y < 4 or y > 59:
						img.set_pixel(x, y, border_col)
			# Draw a letter (very crude, just a box for now or maybe we can use a Label in a Viewport later)
			# For now, just a distinct color shape in center
			var center_col = Color.from_hsv((hue + 0.5) - floor(hue + 0.5), 1.0, 1.0)
			for x in range(20, 44):
				for y in range(20, 44):
					img.set_pixel(x, y, center_col)
					
			var tex = ImageTexture.create_from_image(img)
			team.logo = tex
			
			# Generate Roster (5 players)
			for k in range(5):
				var p_name = "%s Player %d" % [t_name, k+1]
				var p = PlayerDataScript.new(p_name, 100 * (i+1))
				p.randomize_stats(i + 1) # Tier based on division
				team.add_player(p)
			
			teams_in_div.append(team)
		
		divisions.append({
			"name": div_name,
			"teams": teams_in_div
		})
	
	# Assign player to a Bronze team (first team in Bronze)
	player_team = divisions[0]["teams"][0]
	# player_team.name = "Player's Team" # KEEP ORIGINAL NAME
	print("League Generated. Player Team: ", player_team.name)

func _get_unique_name(used: Array) -> String:
	for n in TEAM_NAMES:
		if not n in used:
			return n
	return "Team " + str(randi() % 1000)

func simulate_season():
	# Simple simulation for testing: Random wins/losses
	for div in divisions:
		for team in div["teams"]:
			team.wins = randi() % 10
			team.losses = randi() % 10
	season_advanced.emit()

func promote_relegate():
	# Logic to move top team up and bottom team down
	# 0=Bronze, 1=Silver, 2=Gold
	
	var moves = []
	
	for i in range(divisions.size() - 1): # 0 and 1
		var lower_div = divisions[i]
		var upper_div = divisions[i+1]
		
		# Sort by wins (descending)
		_sort_division(lower_div)
		_sort_division(upper_div)
		
		var top_team = lower_div["teams"][0]
		var bottom_team = upper_div["teams"][-1]
		
		print("Promoting %s to %s" % [top_team.name, upper_div["name"]])
		print("Relegating %s to %s" % [bottom_team.name, lower_div["name"]])
		
		moves.append({
			"team": top_team,
			"from": lower_div,
			"to": upper_div
		})
		moves.append({
			"team": bottom_team,
			"from": upper_div,
			"to": lower_div
		})
	
	# Apply moves
	for m in moves:
		m["from"]["teams"].erase(m["team"])
		m["to"]["teams"].append(m["team"])

func _sort_division(div: Dictionary):
	div["teams"].sort_custom(func(a, b): return a.wins > b.wins)

func get_next_opponent() -> Resource:
	# For now, just return a random team in the same division that isn't us
	var my_div = _get_division_of_team(player_team)
	if my_div:
		for t in my_div["teams"]:
			if t != player_team:
				return t
	return null

func _get_division_of_team(team: Resource) -> Dictionary:
	for div in divisions:
		if team in div["teams"]:
			return div
	return {}

func start_quick_match(team_a: Resource, team_b: Resource, config: Dictionary = {}) -> void:
	# Set pending data for GameManager to pick up on load
	pending_match_data = {
		"team_a": team_a,
		"team_b": team_b,
		"config": config
	}
	
	# Load the main court scene
	get_tree().change_scene_to_file("res://scenes/court/court.tscn")

func start_debug_match() -> void:
	if divisions.is_empty():
		generate_default_league()
	
	var team_a = divisions[0]["teams"][0]
	var team_b = divisions[0]["teams"][1]
	
	var config = {
		"quarter_duration": 9999.0, # Endless
		"team_size": 1,             # 1v1
		"items_enabled": true,
		"enabled_items": {
			"mine": true, "cyclone": true, "missile": true,
			"power_up": true, "coin": true, "crowd_throw": true
		},
		"human_team_index": 0,
		"is_debug": true            # Flag for GameManager
	}
	
	pending_match_data = {
		"team_a": team_a,
		"team_b": team_b,
		"config": config
	}
	
	get_tree().change_scene_to_file("res://scenes/court/court.tscn")
	
func clear_pending_match() -> void:
	pending_match_data.clear()
