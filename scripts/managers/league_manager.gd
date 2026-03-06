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

var current_save_file: String = ""
var schedule: Array = []
var current_week: int = 0
var is_postseason: bool = false
var playoff_schedule: Array = []
var season_config: Dictionary = {}

# Pending match data for GameManager handshake
var pending_match_data: Dictionary = {}

# For debug/testing: Pre-defined team names
const TEAM_NAMES = [
	"Cobras", "Vipers", "Raptors", "Sharks", 
	"Bulls", "Rhinos", "Tigers", "Lions",
	"Hawks", "Eagles", "Falcons", "Ravens",
	"Titans", "Giants", "Spartans", "Vikings",
	"Panthers", "Bears", "Wolves", "Gators",
	"Dragons", "Griffins", "Stallions", "Mustangs",
	"Wildcats", "Cougars", "Jaguars", "Leopards",
	"Pumas", "Hornets", "Wasps", "Stingers",
	"Pythons", "Scorpions", "Hounds", "Grizzlies"
]

const FIRST_NAMES = [
	"James", "John", "Robert", "Michael", "William",
	"David", "Richard", "Joseph", "Thomas", "Charles",
	"Chris", "Daniel", "Matthew", "Anthony", "Mark",
	"Donald", "Steven", "Paul", "Andrew", "Joshua",
	"Kevin", "Brian", "George", "Edward", "Ronald",
	"Timothy", "Jason", "Jeffrey", "Ryan", "Jacob",
	"Gary", "Nicholas", "Eric", "Jonathan", "Stephen",
	"Larry", "Justin", "Scott", "Brandon", "Ben"
]

const LAST_NAMES = [
	"Smith", "Johnson", "Williams", "Brown", "Jones",
	"Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
	"Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
	"Thomas", "Taylor", "Moore", "Jackson", "Martin",
	"Lee", "Perez", "Thompson", "White", "Harris",
	"Sanchez", "Clark", "Ramirez", "Lewis", "Robinson",
	"Walker", "Young", "Allen", "King", "Wright"
]

func _ready():
	randomize()
	# generate_default_league() # Call manually or from main menu

# Build a lightweight stub for every possible team name so the setup screen
# can show all 36 options before the real league is generated.
func build_all_team_stubs(roster_size: int = 5) -> Array:
	var stubs: Array = []
	for idx in range(TEAM_NAMES.size()):
		var t_name = TEAM_NAMES[idx]
		# Use a neutral placeholder — the player will pick the real color in setup
		var color = Color(0.55, 0.55, 0.7)
		var team = TeamDataScript.new(t_name, color)
		_generate_team_logo(team, t_name, color)
		# Add a minimal bronze-tier roster so the OVR display works
		for k in range(roster_size):
			var f_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
			var l_name = LAST_NAMES[randi() % LAST_NAMES.size()]
			var p = PlayerDataScript.new("%s %s" % [f_name, l_name], 100)
			p.number = randi_range(0, 99)
			p.randomize_stats(1)
			team.add_player(p)
		stubs.append(team)
	return stubs

func generate_default_league(teams_per_division: int = 8, chosen_team_name: String = "", chosen_color: Color = Color(-1,-1,-1), chosen_secondary: Color = Color(-1,-1,-1), roster_size: int = 5):
	divisions = []
	current_season = 1
	var used_names: Array = []
	
	# Build a shuffled pool of all available names
	var name_pool: Array = TEAM_NAMES.duplicate()
	name_pool.shuffle()
	
	# If the player chose a specific team, move it to the front of the pool
	# so it lands as the first team in the Bronze division.
	if chosen_team_name != "" and name_pool.has(chosen_team_name):
		name_pool.erase(chosen_team_name)
		name_pool.push_front(chosen_team_name)
	
	# Create 3 Divisions: Bronze, Silver, Gold
	var division_names = ["Bronze", "Silver", "Gold"]
	
	for i in range(division_names.size()):
		var div_name = division_names[i]
		var teams_in_div: Array[Resource] = []
		
		for j in range(teams_per_division):
			# Pop next unique name from the shuffled pool
			var t_name: String
			if name_pool.size() > 0:
				t_name = name_pool.pop_front()
			else:
				t_name = "Team %d" % (used_names.size() + 1)
			used_names.append(t_name)
			
			var color: Color
			var secondary: Color
			# First team is always the player's team when chosen_team_name is set.
			# Preserve the player's hand-picked color instead of overwriting it.
			if i == 0 and j == 0 and chosen_team_name != "" and chosen_color.r >= 0.0:
				color = chosen_color
				if chosen_secondary.r >= 0.0:
					secondary = chosen_secondary
				else:
					secondary = TeamDataScript.derive_secondary(color)
			else:
				# Auto-generate color for all other (AI) teams
				var hue = float(j) / float(teams_per_division)
				var sat = 0.5 + (float(i) * 0.2)
				var val = 0.8
				color = Color.from_hsv(hue, sat, val)
				secondary = TeamDataScript.derive_secondary(color)
			
			var team = TeamDataScript.new(t_name, color, secondary)
			_generate_team_logo(team, t_name, color)
			
			# Generate Roster
			for k in range(roster_size):
				var f_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
				var l_name = LAST_NAMES[randi() % LAST_NAMES.size()]
				var p_name = "%s %s" % [f_name, l_name]
				
				var p = PlayerDataScript.new(p_name, 100 * (i + 1))
				p.number = randi_range(0, 99)
				p.randomize_stats(i + 1)
				team.add_player(p)
			
			teams_in_div.append(team)
		
		divisions.append({
			"name": div_name,
			"teams": teams_in_div
		})
		
	print("League Structure Generated.")

func reset_team_roster(team: Resource, roster_size: int = 5) -> void:
	# Find division tier to appropriately scale the generated stats
	var tier = 1
	for i in range(divisions.size()):
		if team in divisions[i]["teams"]:
			tier = i + 1
			break
			
	team.roster.clear()
	for k in range(roster_size):
		var f_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
		var l_name = LAST_NAMES[randi() % LAST_NAMES.size()]
		var p_name = "%s %s" % [f_name, l_name]
		
		var p = PlayerDataScript.new(p_name, 100 * tier)
		p.number = randi_range(0, 99)
		p.randomize_stats(tier)
		team.add_player(p)

func start_new_season(selected_team: Resource, config: Dictionary) -> void:
	season_config = config
	current_week = 0
	is_postseason = false
	playoff_schedule.clear()
	current_save_file = ""
	
	# Resolve player_team to the actual object inside divisions (generate_default_league
	# creates fresh instances, so the stub passed in is a different reference).
	player_team = null
	for div in divisions:
		for t in div["teams"]:
			if t.name == selected_team.name:
				player_team = t
				break
		if player_team:
			break
	# Fallback: keep the stub if no match found (shouldn't happen)
	if not player_team:
		player_team = selected_team
	
	# Copy the stub's roster (what the player saw & customized in setup) into
	# the real team object — generate_default_league creates a fresh random roster
	# that would otherwise silently replace it.
	player_team.roster.clear()
	for p in selected_team.roster:
		player_team.roster.append(p)
	
	_generate_schedule()
	save_season()
	get_tree().change_scene_to_file("res://ui/season_hub.tscn")



func _generate_schedule() -> void:
	schedule.clear()
	
	var repeats = season_config.get("games_per_opponent", 1)
	var max_weeks = 0
	
	# Generate a schedule per division separately
	var division_schedules = []
	for div in divisions:
		var div_teams = div["teams"].duplicate()
		if div_teams.size() % 2 != 0:
			div_teams.append(null) # Dummy team for bye week if odd
			
		var num_teams = div_teams.size()
		var num_weeks = num_teams - 1
		var half_size = num_teams / 2
		
		var teams_copy = div_teams.duplicate()
		teams_copy.remove_at(0) # Keep first team fixed
		
		var div_sched = []
		var div_name_tag = div["name"]
		for r in range(repeats):
			for week in range(num_weeks):
				var week_matches = []
				
				var t1 = div_teams[0]
				var t2 = teams_copy[week % teams_copy.size()]
				if t1 != null and t2 != null:
					# Scramble Home/Away based on a mix of week and repeat index
					if (week + r) % 2 == 0:
						week_matches.append({"home": t1.name, "away": t2.name, "played": false, "home_score": 0, "away_score": 0, "div": div_name_tag})
					else:
						week_matches.append({"home": t2.name, "away": t1.name, "played": false, "home_score": 0, "away_score": 0, "div": div_name_tag})
						
				for i in range(1, half_size):
					var first = (week + i) % teams_copy.size()
					var second = (week + teams_copy.size() - i) % teams_copy.size()
					t1 = teams_copy[first]
					t2 = teams_copy[second]
					if t1 != null and t2 != null:
						if (i + week + r) % 2 == 0:
							week_matches.append({"home": t1.name, "away": t2.name, "played": false, "home_score": 0, "away_score": 0, "div": div_name_tag})
						else:
							week_matches.append({"home": t2.name, "away": t1.name, "played": false, "home_score": 0, "away_score": 0, "div": div_name_tag})
							
				div_sched.append(week_matches)
		
		division_schedules.append(div_sched)
		if div_sched.size() > max_weeks:
			max_weeks = div_sched.size()
			
	# Merge division schedules week by week
	for w in range(max_weeks):
		var merged_week = []
		for ds in division_schedules:
			if w < ds.size():
				merged_week.append_array(ds[w])
		schedule.append(merged_week)
		
	print("Generated schedule for ", max_weeks, " weeks.")

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
		m["from"].erase(m["team"])
		if not m["to"].has(m["team"]):
			m["to"].append(m["team"])

func _sort_division(div: Dictionary):
	div["teams"].sort_custom(func(a, b): return a.wins > b.wins)

func get_player_division_name() -> String:
	if not player_team: return ""
	for div in divisions:
		if player_team in div["teams"]:
			return div["name"]
	return ""

func get_next_opponent() -> Resource:
	var active_schedule = playoff_schedule if is_postseason else schedule
	if current_week >= active_schedule.size() or not player_team:
		return null
		
	var week_matches = active_schedule[current_week]
	for m in week_matches:
		if m["home"] == player_team.name:
			if m["away"] == "TBD": return null
			return _get_team_by_name(m["away"])
		elif m["away"] == player_team.name:
			if m["home"] == "TBD": return null
			return _get_team_by_name(m["home"])
			
	return null

func get_next_match_is_home() -> bool:
	var active_schedule = playoff_schedule if is_postseason else schedule
	if current_week >= active_schedule.size() or not player_team:
		return true
		
	var week_matches = active_schedule[current_week]
	for m in week_matches:
		if m["home"] == player_team.name:
			return true
		elif m["away"] == player_team.name:
			return false
	return true

func _get_team_by_name(tname: String) -> Resource:
	for div in divisions:
		for t in div["teams"]:
			if t.name == tname: return t
	return null


func simulate_week() -> Dictionary:
	if is_postseason:
		return simulate_playoff_week()
		
	if current_week >= schedule.size():
		start_postseason()
		return {}
		
	var week_matches = schedule[current_week]
	var player_sim_data = {}
	
	for m in week_matches:
		if m["played"]: continue
		
		var t_home = _get_team_by_name(m["home"])
		var t_away = _get_team_by_name(m["away"])
		
		var sim_data = simulate_detailed_match(t_home, t_away)
		
		# Record the player's detailed sim data for the UI
		if m["home"] == player_team.name or m["away"] == player_team.name:
			player_sim_data = sim_data
		
		var h_score = sim_data["home_score"]
		var a_score = sim_data["away_score"]
		
		m["home_score"] = h_score
		m["away_score"] = a_score
		m["top_scorer"] = sim_data["top_scorer"]
		m["top_scorer_pts"] = sim_data["top_scorer_pts"]
		m["top_rebounder"] = sim_data["top_rebounder"]
		m["top_rebounder_reb"] = sim_data["top_rebounder_reb"]
		m["top_assister"] = sim_data["top_assister"]
		m["top_assister_ast"] = sim_data["top_assister_ast"]
		m["played"] = true
		
		t_home.pf += h_score
		t_home.pa += a_score
		t_away.pf += a_score
		t_away.pa += h_score
		
		if h_score > a_score:
			t_home.wins += 1
			t_away.losses += 1
			t_home.streak = t_home.streak + 1 if t_home.streak > 0 else 1
			t_away.streak = t_away.streak - 1 if t_away.streak < 0 else -1
		else:
			t_away.wins += 1
			t_home.losses += 1
			t_away.streak = t_away.streak + 1 if t_away.streak > 0 else 1
			t_home.streak = t_home.streak - 1 if t_home.streak < 0 else -1
			
	current_week += 1
	if current_week >= schedule.size():
		start_postseason()
	else:
		save_season()
		
	return player_sim_data

func start_postseason() -> void:
	is_postseason = true
	current_week = 0
	playoff_schedule.clear()
	
	var sf_matches = []
	var w2_matches = []
	
	# Generate separate brackets per division
	for d_idx in range(divisions.size()):
		var div = divisions[d_idx]
		var div_teams = div["teams"].duplicate()
		div_teams.sort_custom(func(a, b): return a.wins > b.wins)
		
		# Take top 4 from each division
		var top4 = div_teams.slice(0, min(4, div_teams.size()))
		
		if top4.size() >= 4:
			# Week 1: Semifinals for this division
			var match_idx_offset = sf_matches.size() # Match ID for next round tracking
			
			sf_matches.append({"home": top4[0].name, "away": top4[3].name, "played": false, "home_score": 0, "away_score": 0, "next_match": match_idx_offset / 2, "next_slot": "home", "division": div["name"]})
			sf_matches.append({"home": top4[1].name, "away": top4[2].name, "played": false, "home_score": 0, "away_score": 0, "next_match": match_idx_offset / 2, "next_slot": "away", "division": div["name"]})
			
			# Week 2: Championship for this division
			w2_matches.append({"home": "TBD", "away": "TBD", "played": false, "home_score": 0, "away_score": 0, "next_match": -1, "next_slot": "", "division": div["name"]})
		elif top4.size() == 2:
			# If a division only has 2 teams (rare edge case), skip directly to Championship
			w2_matches.append({"home": top4[0].name, "away": top4[1].name, "played": false, "home_score": 0, "away_score": 0, "next_match": -1, "next_slot": "", "division": div["name"]})
	
	if sf_matches.size() > 0:
		playoff_schedule.append(sf_matches)
	if w2_matches.size() > 0:
		playoff_schedule.append(w2_matches)
		
	save_season()
	
func simulate_playoff_week() -> Dictionary:
	if current_week >= playoff_schedule.size():
		return {}
		
	var week_matches = playoff_schedule[current_week]
	var player_sim_data = {}
	
	for m in week_matches:
		if m["played"] or m["home"] == "TBD" or m["away"] == "TBD": continue
		
		var t_home = _get_team_by_name(m["home"])
		var t_away = _get_team_by_name(m["away"])
		
		var sim_data = simulate_detailed_match(t_home, t_away)
		
		if m["home"] == player_team.name or m["away"] == player_team.name:
			player_sim_data = sim_data
			
		var h_score = sim_data["home_score"]
		var a_score = sim_data["away_score"]
		m["home_score"] = h_score
		m["away_score"] = a_score
		m["top_scorer"] = sim_data["top_scorer"]
		m["top_scorer_pts"] = sim_data["top_scorer_pts"]
		m["top_rebounder"] = sim_data["top_rebounder"]
		m["top_rebounder_reb"] = sim_data["top_rebounder_reb"]
		m["top_assister"] = sim_data["top_assister"]
		m["top_assister_ast"] = sim_data["top_assister_ast"]
		m["played"] = true
		
		var winner_name = m["home"] if h_score > a_score else m["away"]
		
		if m.get("next_match", -1) >= 0:
			var next_round = playoff_schedule[current_week + 1]
			var nm = next_round[m["next_match"]]
			nm[m["next_slot"]] = winner_name
			
	current_week += 1
	save_season()
	return player_sim_data

func simulate_detailed_match(t_home: Resource, t_away: Resource) -> Dictionary:
	var h_ovr = _get_team_rating(t_home)
	var a_ovr = _get_team_rating(t_away)
	
	# Add a slight home court advantage and some randomness
	var h_score = max(0, int(randf_range(0.8, 1.2) * (h_ovr / 5.0)) + randi_range(6, 15) + 3)
	var a_score = max(0, int(randf_range(0.8, 1.2) * (a_ovr / 5.0)) + randi_range(6, 15))
	
	if h_score == a_score: h_score += 1 # prevent ties
	
	# Compute quarters
	var h_q = [0, 0, 0, 0]
	var a_q = [0, 0, 0, 0]
	for i in range(h_score): h_q[randi() % 4] += 1
	for i in range(a_score): a_q[randi() % 4] += 1
		
	var win_team = t_home if h_score > a_score else t_away
	
	var all_rosters = t_home.roster.duplicate()
	all_rosters.append_array(t_away.roster)
	
	var pre_stats = {}
	for p in all_rosters:
		pre_stats[p] = {"pts": p.pts, "reb": p.reb, "ast": p.ast, "blk": p.blk, "fga": p.fga, "fgm": p.fgm, "tpa": p.tpa, "tpm": p.tpm}
		
	_simulate_team_player_stats(t_home, h_score)
	_simulate_team_player_stats(t_away, a_score)
	
	var best_scorer = null
	var best_reb = null
	var best_ast = null
	
	var best_pts = -1
	var best_reb_val = -1
	var best_ast_val = -1
	
	for p in all_rosters:
		var g_pts = p.pts - pre_stats[p].pts
		var g_reb = p.reb - pre_stats[p].reb
		var g_ast = p.ast - pre_stats[p].ast
		var g_blk = p.blk - pre_stats[p].blk
		var g_fga = p.fga - pre_stats[p].fga
		var g_fgm = p.fgm - pre_stats[p].fgm
		var g_tpa = p.tpa - pre_stats[p].tpa
		var g_tpm = p.tpm - pre_stats[p].tpm
		
		var is_home = p in t_home.roster
		var is_win = (is_home and h_score > a_score) or (not is_home and a_score > h_score)
		var opp = t_away.name if is_home else t_home.name
		var t_score = h_score if is_home else a_score
		var o_score = a_score if is_home else h_score
		
		p.game_log.append({
			"opp": opp,
			"pts": g_pts,
			"reb": g_reb,
			"ast": g_ast,
			"blk": g_blk,
			"fga": g_fga,
			"fgm": g_fgm,
			"tpa": g_tpa,
			"tpm": g_tpm,
			"win": is_win,
			"team_score": t_score,
			"opp_score": o_score
		})
		
		if p in win_team.roster:
			if g_pts > best_pts:
				best_scorer = p
				best_pts = g_pts
			if g_reb > best_reb_val:
				best_reb = p
				best_reb_val = g_reb
			if g_ast > best_ast_val:
				best_ast = p
				best_ast_val = g_ast
			
	return {
		"home_score": h_score,
		"away_score": a_score,
		"home_quarters": h_q,
		"away_quarters": a_q,
		"top_scorer": best_scorer.name if best_scorer else "Player",
		"top_scorer_pts": best_pts if best_pts >= 0 else 0,
		"top_rebounder": best_reb.name if best_reb else "Player",
		"top_rebounder_reb": best_reb_val if best_reb_val >= 0 else 0,
		"top_assister": best_ast.name if best_ast else "Player",
		"top_assister_ast": best_ast_val if best_ast_val >= 0 else 0,
	}

func _simulate_team_player_stats(t: Resource, total_pts: int) -> void:
	if t.roster.is_empty(): return
	
	# Only distribute stats to the active players (respects team_size setting)
	var team_size = season_config.get("team_size", t.roster.size())
	var active_roster = t.roster.slice(0, min(team_size, t.roster.size()))
	
	# Distribute points weighted by shot attribute
	var shot_pool = 0.0
	for p in active_roster: shot_pool += max(1.0, p.shot)
	
	var pts_remaining = total_pts
	while pts_remaining > 0:
		var roll = randf_range(0, shot_pool)
		var curr = 0.0
		for p in active_roster:
			curr += max(1.0, p.shot)
			if roll <= curr:
				# 2 or 3 pointer
				var is_three = p.shot >= 8 and randf() > 0.6
				var made = 3 if is_three else 2
				made = min(made, pts_remaining)
				
				# Generate realistic attempts (e.g. 40-50% FG)
				var attempt_multiplier = randf_range(1.5, 2.5)
				p.fga += int(1 * attempt_multiplier)
				p.fgm += 1
				
				if is_three and made == 3:
					p.tpa += int(1 * attempt_multiplier)
					p.tpm += 1
					
				p.pts += made
				pts_remaining -= made
				break
				
	# Distribute Rebounds (weighted by strength), Assists (pass_skill), Blocks (tackle)
	var expected_rebounds = randi_range(6, 12)
	var expected_assists = int(total_pts * randf_range(0.3, 0.6))
	var expected_blocks = randi_range(0, 5)
	
	for i in range(expected_rebounds):
		var pool = 0.0
		for p in active_roster: pool += max(1.0, p.strength)
		var roll = randf_range(0, pool)
		var curr = 0.0
		for p in active_roster:
			curr += max(1.0, p.strength)
			if roll <= curr:
				p.reb += 1
				break
				
	for i in range(expected_assists):
		var pool = 0.0
		for p in active_roster: pool += max(1.0, p.pass_skill)
		var roll = randf_range(0, pool)
		var curr = 0.0
		for p in active_roster:
			curr += max(1.0, p.pass_skill)
			if roll <= curr:
				p.ast += 1
				break
				
	for i in range(expected_blocks):
		var pool = 0.0
		for p in active_roster: pool += max(1.0, p.tackle)
		var roll = randf_range(0, pool)
		var curr = 0.0
		for p in active_roster:
			curr += max(1.0, p.tackle)
			if roll <= curr:
				p.blk += 1
				break

func _get_team_rating(team: Resource) -> int:
	if team.roster.is_empty(): return 0
	var total = 0.0
	for p in team.roster:
		var p_rating = (p.speed + p.shot + p.pass_skill + p.tackle + p.strength + p.aggression) / 6.0
		total += p_rating
	return int(round(total / team.roster.size()))

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

func _generate_team_logo(team: Resource, t_name: String, color: Color) -> void:
	var logo_path = "res://assets/images/logos/logo_%s.png" % t_name.to_lower()
	if ResourceLoader.exists(logo_path):
		var tex = load(logo_path)
		if tex is Texture2D:
			var img = tex.get_image()
			if img:
				if img.is_compressed():
					img.decompress()
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				
				for x in range(img.get_width()):
					for y in range(img.get_height()):
						var c = img.get_pixel(x, y)
						# Remove pure magenta (or very close to it)
						if c.r > 0.95 and c.g < 0.05 and c.b > 0.95:
							c.a = 0.0
							img.set_pixel(x, y, c)
				
				team.logo = ImageTexture.create_from_image(img)
			else:
				team.logo = tex
		else:
			team.logo = tex
	else:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(color)
		# Draw a simple border
		var border_col = Color.WHITE
		for x in range(64):
			for y in range(64):
				if x < 4 or x > 59 or y < 4 or y > 59:
					img.set_pixel(x, y, border_col)
					
		# Draw the team's initial letter (crude pixel art)
		var center_col = Color.WHITE
		var initial = t_name.substr(0, 1).to_upper()
		
		var start_x = 22
		var start_y = 22
		var pixel_size = 4
		
		var pattern = []
		if initial == "V":
			pattern = [1,0,0,0,1, 1,0,0,0,1, 0,1,0,1,0, 0,1,0,1,0, 0,0,1,0,0]
		elif initial == "C":
			pattern = [0,1,1,1,0, 1,0,0,0,1, 1,0,0,0,0, 1,0,0,0,1, 0,1,1,1,0]
		else:
			pattern = [1,1,1,1,1, 1,0,0,0,1, 1,0,1,0,1, 1,0,0,0,1, 1,1,1,1,1]
		
		for py in range(5):
			for px in range(5):
				if pattern[py * 5 + px] == 1:
					for ix in range(pixel_size):
						for iy in range(pixel_size):
							img.set_pixel(start_x + px * pixel_size + ix, start_y + py * pixel_size + iy, center_col)
				
		var tex = ImageTexture.create_from_image(img)
		team.logo = tex

func has_saved_season() -> bool:
	return get_all_saves().size() > 0

func get_all_saves() -> Array:
	var saves = []
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("season_save_") and file_name.ends_with(".json"):
				var full_path = "user://" + file_name
				var file = FileAccess.open(full_path, FileAccess.READ)
				if file:
					var json_str = file.get_as_text()
					file.close()
					var json = JSON.new()
					if json.parse(json_str) == OK:
						var data = json.data
						if typeof(data) == TYPE_DICTIONARY:
							var p_team = data.get("player_team_name", "Unknown Team")
							var c_season = data.get("current_season", 1)
							
							# Find the team to get its record
							var wins = 0
							var losses = 0
							var color = "ffffff"
							for div in data.get("divisions", []):
								for t in div.get("teams", []):
									if t.get("name") == p_team:
										wins = t.get("wins", 0)
										losses = t.get("losses", 0)
										color = t.get("color_primary", "ffffff")
										break
							
							saves.append({
								"filename": full_path,
								"team_name": p_team,
								"season": c_season,
								"wins": wins,
								"losses": losses,
								"color": Color.html(color),
								# We sort by modification time (or parse it from filename). 
								# FileAccess.get_modified_time isn't easy to sort in GDScript without custom logic,
								# but we can sort by filename since it has a timestamp.
								"sort_key": file_name 
							})
			file_name = dir.get_next()
			
	# Sort newest first
	saves.sort_custom(func(a, b): return a["sort_key"] > b["sort_key"])
	return saves

func delete_season_save(filename: String) -> void:
	if FileAccess.file_exists(filename):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(filename.get_file())

func save_season() -> void:
	var save_data = {
		"current_season": current_season,
		"player_team_name": player_team.name if player_team else "",
		"current_week": current_week,
		"is_postseason": is_postseason,
		"playoff_schedule": playoff_schedule,
		"season_config": season_config,
		"schedule": schedule,
		"divisions": []
	}
	for div in divisions:
		var div_data = {
			"name": div["name"],
			"teams": []
		}
		for team in div["teams"]:
			var t_data = {
				"name": team.name,
				"color_primary": team.color_primary.to_html(),
				"color_secondary": team.color_secondary.to_html(),
				"wins": team.wins,
				"losses": team.losses,
				"pf": team.pf,
				"pa": team.pa,
				"streak": team.streak,
				"roster": []
			}
			for p in team.roster:
				t_data["roster"].append({
					"name": p.name,
					"number": p.number,
					"speed": p.speed,
					"shot": p.shot,
					"pass_skill": p.pass_skill,
					"tackle": p.tackle,
					"strength": p.strength,
					"aggression": p.aggression,
					"pts": p.pts,
					"reb": p.reb,
					"ast": p.ast,
					"blk": p.blk,
					"fgm": p.fgm,
					"fga": p.fga,
					"tpm": p.tpm,
					"tpa": p.tpa
				})
			div_data["teams"].append(t_data)
		save_data["divisions"].append(div_data)
		
	if current_save_file == "":
		current_save_file = "user://season_save_%d.json" % Time.get_unix_time_from_system()
		
	var file = FileAccess.open(current_save_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_season(filename: String) -> bool:
	if not FileAccess.file_exists(filename):
		return false
		
	var file = FileAccess.open(filename, FileAccess.READ)
	if not file:
		return false
		
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		print("Failed to parse season save")
		return false
		
	var save_data = json.data
	if typeof(save_data) != TYPE_DICTIONARY:
		return false
		
	current_season = save_data.get("current_season", 1)
	current_week = save_data.get("current_week", 0)
	is_postseason = save_data.get("is_postseason", false)
	playoff_schedule = save_data.get("playoff_schedule", [])
	season_config = save_data.get("season_config", {})
	schedule = save_data.get("schedule", [])
	var p_team_name = save_data.get("player_team_name", "")
	
	divisions.clear()
	player_team = null
	var raw_divs = save_data.get("divisions", [])
	for raw_div in raw_divs:
		var div_name = raw_div.get("name", "Unknown")
		var teams_in_div: Array[Resource] = []
		
		var raw_teams = raw_div.get("teams", [])
		for raw_t in raw_teams:
			var t_name = raw_t.get("name", "Team")
			var color = Color.html(raw_t.get("color_primary", "ffffff"))
			# Restore secondary; derive it if missing (old saves)
			var secondary_str = raw_t.get("color_secondary", "")
			var secondary: Color
			if secondary_str != "":
				secondary = Color.html(secondary_str)
			else:
				secondary = TeamDataScript.derive_secondary(color)
			
			var team = TeamDataScript.new(t_name, color, secondary)
			team.wins = raw_t.get("wins", 0)
			team.losses = raw_t.get("losses", 0)
			team.pf = raw_t.get("pf", 0)
			team.pa = raw_t.get("pa", 0)
			team.streak = raw_t.get("streak", 0)
			
			_generate_team_logo(team, t_name, color)
			
			var raw_roster = raw_t.get("roster", [])
			for raw_p in raw_roster:
				var p = PlayerDataScript.new(raw_p.get("name", "Player"))
				p.number = raw_p.get("number", 0)
				p.speed = raw_p.get("speed", 5.0)
				p.shot = raw_p.get("shot", 5.0)
				p.pass_skill = raw_p.get("pass_skill", 5.0)
				p.tackle = raw_p.get("tackle", 5.0)
				p.strength = raw_p.get("strength", 5.0)
				p.aggression = raw_p.get("aggression", 5.0)
				p.pts = raw_p.get("pts", 0)
				p.reb = raw_p.get("reb", 0)
				p.ast = raw_p.get("ast", 0)
				p.blk = raw_p.get("blk", 0)
				p.fga = raw_p.get("fga", 0)
				p.fgm = raw_p.get("fgm", 0)
				p.tpa = raw_p.get("tpa", 0)
				p.tpm = raw_p.get("tpm", 0)
				team.add_player(p)
				
			teams_in_div.append(team)
			if t_name == p_team_name:
				player_team = team
				
		divisions.append({
			"name": div_name,
			"teams": teams_in_div
		})
		
	if not player_team and divisions.size() > 0 and divisions[0]["teams"].size() > 0:
		player_team = divisions[0]["teams"][0]
		
	current_save_file = filename
	print("Loaded Season from %s. Player Team: %s" % [filename, player_team.name])
	return true

func record_season_match_result(player_score: int, opponent_score: int, opponent: Resource) -> void:
	if not player_team or not opponent:
		return
		
	var p_won = player_score > opponent_score
	
	if p_won:
		player_team.wins += 1
		opponent.losses += 1
		player_team.streak = player_team.streak + 1 if player_team.streak > 0 else 1
		opponent.streak = opponent.streak - 1 if opponent.streak < 0 else -1
	elif player_score < opponent_score:
		player_team.losses += 1
		opponent.wins += 1
		opponent.streak = opponent.streak + 1 if opponent.streak > 0 else 1
		player_team.streak = player_team.streak - 1 if player_team.streak < 0 else -1
		
	player_team.pf += player_score
	player_team.pa += opponent_score
	opponent.pf += opponent_score
	opponent.pa += player_score
	
	var all_players = player_team.roster.duplicate()
	all_players.append_array(opponent.roster)
	
	var pre_stats = {}
	for p in all_players:
		pre_stats[p] = {"pts": p.pts, "reb": p.reb, "ast": p.ast, "blk": p.blk, "fga": p.fga, "fgm": p.fgm, "tpa": p.tpa, "tpm": p.tpm}
		
	# Mock-generate player stats for the played game until real box scores are active
	_simulate_team_player_stats(player_team, player_score)
	_simulate_team_player_stats(opponent, opponent_score)
		
	# Find the top performers across BOTH teams to assign match MVPs
	var best_scorer = null
	var best_reb = null
	var best_ast = null
	
	var best_pts = -1
	var best_reb_val = -1
	var best_ast_val = -1
	
	for p in all_players:
		var g_pts = p.pts - pre_stats[p].pts
		var g_reb = p.reb - pre_stats[p].reb
		var g_ast = p.ast - pre_stats[p].ast
		var g_blk = p.blk - pre_stats[p].blk
		var g_fga = p.fga - pre_stats[p].fga
		var g_fgm = p.fgm - pre_stats[p].fgm
		var g_tpa = p.tpa - pre_stats[p].tpa
		var g_tpm = p.tpm - pre_stats[p].tpm
		
		# For actual played games, update the player's game_log
		var is_home = p in player_team.roster
		var is_win = (is_home and player_score > opponent_score) or (not is_home and opponent_score > player_score)
		var opp_name = opponent.name if is_home else player_team.name
		var t_score = player_score if is_home else opponent_score
		var o_score = opponent_score if is_home else player_score
		
		if not ("game_log" in p): p.game_log = []
		p.game_log.append({
			"opp": opp_name,
			"pts": g_pts,
			"reb": g_reb,
			"ast": g_ast,
			"blk": g_blk,
			"fga": g_fga,
			"fgm": g_fgm,
			"tpa": g_tpa,
			"tpm": g_tpm,
			"win": is_win,
			"team_score": t_score,
			"opp_score": o_score
		})
		
		if g_pts > best_pts:
			best_scorer = p
			best_pts = g_pts
		if g_reb > best_reb_val:
			best_reb = p
			best_reb_val = g_reb
		if g_ast > best_ast_val:
			best_ast = p
			best_ast_val = g_ast
		
	# Find our match in the schedule and mark it played
	var active_schedule = playoff_schedule if is_postseason else schedule
	var played_match = false
	if current_week < active_schedule.size():
		var week_matches = active_schedule[current_week]
		for m in week_matches:
			if (m["home"] == player_team.name and m["away"] == opponent.name) or (m["away"] == player_team.name and m["home"] == opponent.name):
				if m["home"] == player_team.name:
					m["home_score"] = player_score
					m["away_score"] = opponent_score
				else:
					m["home_score"] = opponent_score
					m["away_score"] = player_score
				m["top_scorer"] = best_scorer.name if best_scorer else "Player"
				m["top_scorer_pts"] = best_pts if best_pts >= 0 else 0
				m["top_rebounder"] = best_reb.name if best_reb else "Player"
				m["top_rebounder_reb"] = best_reb_val if best_reb_val >= 0 else 0
				m["top_assister"] = best_ast.name if best_ast else "Player"
				m["top_assister_ast"] = best_ast_val if best_ast_val >= 0 else 0
				m["played"] = true
				played_match = true
				
				if is_postseason and m.get("next_match", -1) >= 0:
					var winner_name = player_team.name if p_won else opponent.name
					var next_round = playoff_schedule[current_week + 1]
					var nm = next_round[m["next_match"]]
					nm[m["next_slot"]] = winner_name
				break
				
	# If we successfully recorded our match into the schedule, simulate the rest of the week's games for other teams
	if played_match:
		simulate_week()
	else:
		save_season()

func get_champion_name() -> String:
	# Get the championship for the player's division
	var p_div = _get_division_of_team(player_team)
	var d_name = p_div.get("name", "")
	
	if playoff_schedule.size() > 0: # Check the last week of playoffs
		var final_week = playoff_schedule[playoff_schedule.size() - 1]
		for m in final_week:
			if m.get("division", "") == d_name:
				if m["played"]:
					return m["home"] if m["home_score"] > m["away_score"] else m["away"]
	return ""

func process_season_rollover(champion_name: String) -> void:
	var moves = []
	
	# Relegate the lowest team in each division (excluding lowest div)
	for i in range(1, divisions.size()):
		var div = divisions[i]
		if div["teams"].size() > 0:
			var div_teams = div["teams"].duplicate()
			div_teams.sort_custom(func(a, b): return a.wins > b.wins)
			var lowest = div_teams[-1]
			moves.append({"team": lowest, "from": div["teams"], "to": divisions[i-1]["teams"]})
			
	# Promote the champion of each division (excluding top div)
	for i in range(divisions.size() - 1):
		var div_name = divisions[i]["name"]
		var div_champ_name = ""
		
		# Find the winner of this division's championship match
		if playoff_schedule.size() > 0:
			var final_week = playoff_schedule[playoff_schedule.size() - 1]
			for m in final_week:
				if m.get("division", "") == div_name and m["played"]:
					div_champ_name = m["home"] if m["home_score"] > m["away_score"] else m["away"]
					break
					
		if div_champ_name != "":
			var champ_team = _get_team_by_name(div_champ_name)
			if champ_team:
				moves.append({"team": champ_team, "from": divisions[i]["teams"], "to": divisions[i+1]["teams"]})
	var champ = _get_team_by_name(champion_name)
	var champ_div_idx = -1
	for i in range(divisions.size()):
		if champ in divisions[i]["teams"]:
			champ_div_idx = i
			break
			
	if champ_div_idx >= 0 and champ_div_idx < divisions.size() - 1:
		moves.append({"team": champ, "from": divisions[champ_div_idx]["teams"], "to": divisions[champ_div_idx+1]["teams"]})
		
	for m in moves:
		m["from"].erase(m["team"])
		if not m["to"].has(m["team"]):
			m["to"].append(m["team"])
			
	# Reset stats
	for div in divisions:
		for t in div["teams"]:
			t.wins = 0; t.losses = 0; t.pf = 0; t.pa = 0; t.streak = 0
			for p in t.roster:
				p.pts = 0; p.reb = 0; p.ast = 0; p.blk = 0; p.fga = 0; p.fgm = 0; p.tpa = 0; p.tpm = 0
				if "game_log" in p: p.game_log.clear()
				
	current_season += 1
	is_postseason = false
	playoff_schedule.clear()
	current_week = 0
	_generate_schedule()
	save_season()
