extends Node3D
## Game Manager — controls match state, scoring, clock, tip-off, throw-ins, and game flow.

signal score_changed(team_index: int, new_score: int)
signal clock_changed(time_remaining: float)
signal quarter_changed(quarter: int)
signal game_over(winner_team: int)
signal ball_possession_changed(player: Node3D)
signal throw_in_started(team_index: int)
signal teams_updated(team0_data: Resource, team1_data: Resource)

enum MatchState { PRE_GAME, TIP_OFF, PLAYING, SCORED, THROW_IN, QUARTER_BREAK, GAME_OVER, INBOUND }

# --- Config ---
@export var quarter_duration: float = 30.0  # 30 seconds for testing
@export var total_quarters: int = 4
@export var quarter_break_duration: float = 3.0
@export var throw_in_delay: float = 1.0

# --- State ---
var match_state: MatchState = MatchState.PRE_GAME
var current_quarter: int = 1
var time_remaining: float = 0.0
var scores: Array[int] = [0, 0]
var ball: RigidBody3D = null
var teams: Array = [[], []]
var team_data_store: Array = [null, null] # Store TeamData resources
var possession_team: int = -1
var sides_flipped: bool = false
var tip_off_winner: int = -1   # Team that won the initial tip-off
var possession_arrow: int = -1 # Alternating possession: next inbound goes to this team

# Court geometry
var court_length: float = 30.0
var court_width: float = 16.0
var court_half_w: float = 8.0
var court_half_l: float = 15.0
var three_point_distance: float = 7.5
var hoop_positions: Array[Vector3] = [
	Vector3(0, 3.0, -14.0),
	Vector3(0, 3.0, 14.0),
]

# Tip-off positions (relative to center)
var tip_off_positions_team0: Array[Vector3] = [
	Vector3(0, 0, -2.0),   # Center player (jumper)
	Vector3(-3, 0, -5.0),  # Left wing
	Vector3(3, 0, -5.0),   # Right wing
]
var tip_off_positions_team1: Array[Vector3] = [
	Vector3(0, 0, 2.0),
	Vector3(-3, 0, 5.0),
	Vector3(3, 0, 5.0),
]

func _ready() -> void:
	add_to_group("game_manager")
	time_remaining = quarter_duration
	ball = get_node_or_null("../Ball")
	if ball:
		ball.went_out_of_bounds.connect(_on_ball_out_of_bounds)
	
	# Create hazard spawner
	_create_hazard_spawner()
	
	# Connect screen shake
	var vfx = get_node_or_null("/root/VFX")
	if vfx:
		vfx.screen_shake_requested.connect(_on_screen_shake)
		
	await get_tree().process_frame
	
	# Check for pending match from LeagueManager
	if LeagueManager.pending_match_data.has("team_a"):
		var data = LeagueManager.pending_match_data
		setup_match(data["team_a"], data["team_b"], data.get("config", {}))
		LeagueManager.clear_pending_match()
		return
	
	# If no pending match, verify if we found teams from the scene (debug play in editor)
	_find_teams()
	if teams[0].size() > 0 and teams[1].size() > 0:
		start_match()

func setup_match(team0_data: Resource, team1_data: Resource, config: Dictionary = {}) -> void:
	# Apply Config
	if config.has("quarter_duration"):
		quarter_duration = config["quarter_duration"]
		time_remaining = quarter_duration
	
	var items_enabled = config.get("items_enabled", true)
	var human_team = config.get("human_team_index", 0)
	
	# Clear existing players
	get_tree().call_group("players", "queue_free")
	await get_tree().process_frame # Wait for deletion
	
	# Disable hazard spawner if items disabled
	var hazard_spawner = get_node_or_null("HazardSpawner")
	if hazard_spawner:
		hazard_spawner.process_mode = Node.PROCESS_MODE_INHERIT if items_enabled else Node.PROCESS_MODE_DISABLED
		if not items_enabled:
			# Also clear existing hazards
			get_tree().call_group("hazards", "queue_free")
	
	teams = [[], []]
	team_data_store = [team0_data, team1_data]
	teams_updated.emit(team0_data, team1_data)
	var PlayerScene = load("res://scenes/characters/player.tscn")
	
	# Spawn Team 0
	_spawn_team(team0_data, 0, PlayerScene, human_team)
	# Spawn Team 1
	_spawn_team(team1_data, 1, PlayerScene, human_team)
	
	# Start match
	start_match()

func _spawn_team(team_data: Resource, team_idx: int, player_scene: PackedScene, human_team_idx: int) -> void:
	var roster = team_data.roster
	var tip_off_pos = tip_off_positions_team0 if team_idx == 0 else tip_off_positions_team1
	
	for i in range(roster.size()):
		var p_data = roster[i]
		var player = player_scene.instantiate()
	for i in range(roster.size()):
		var p_data = roster[i]
		var player = player_scene.instantiate()
		player.name = "Player_%d_%d" % [team_idx, i]
		
		# Set properties BEFORE adding to tree
		player.team_index = team_idx
		player.player_name = p_data.name
		player.jersey_number = 10 + i 
		
		# Human Control
		if team_idx == human_team_idx and i == 0:
			player.is_human = true
		else:
			# Add AI Controller
			var ai_script = load("res://scripts/ai_controller.gd")
			if ai_script:
				var ai = ai_script.new()
				ai.name = "AIController"
				player.add_child(ai)
				ai.player = player
		
		# Apply Stats
		player.move_speed = 6.0 + (p_data.speed * 0.4)
		player.shot_power = 10.0 + (p_data.shot * 0.5)
		player.tackle_force = 12.0 + (p_data.tackle * 0.6)
		player.strength = 1.0 + (p_data.strength * 0.1)
		player.aggressiveness = p_data.aggression
		
		# Colors
		if "custom_team_color" in player:
			player.custom_team_color = team_data.color_primary
		
		# Position
		if i < tip_off_pos.size():
			player.global_position = tip_off_pos[i]
		else:
			player.global_position = Vector3(10 * (team_idx * 2 - 1), 0, 10 + i)
		
		add_sibling(player) # Add to scene
			
		teams[team_idx].append(player)
		
		# Add jersey labels
		_add_jersey_labels(player)

	# Update UI with team names?
	pass

func _find_teams() -> void:
	teams = [[], []]
	for player in get_tree().get_nodes_in_group("players"):
		if "team_index" in player:
			teams[player.team_index].append(player)
	
	# Assign jersey numbers (1-based per team)
	for t in range(2):
		var jersey_numbers_pool = [1, 3, 5, 7, 11, 13, 15, 23, 24, 33]
		for i in range(teams[t].size()):
			var p = teams[t][i]
			if "jersey_number" in p:
				p.jersey_number = jersey_numbers_pool[i % jersey_numbers_pool.size()]
				# Add jersey labels since _setup_visuals already ran before we set the number
				_add_jersey_labels(p)

func _add_jersey_labels(player_node: CharacterBody3D) -> void:
	# Remove existing jersey labels (if already there)
	for child in player_node.get_children():
		if child.name.begins_with("JerseyNum_"):
			child.queue_free()
	
	var num = player_node.jersey_number if "jersey_number" in player_node else 0
	if num <= 0:
		return
	
	for z_side in [-1, 1]:
		var label = Label3D.new()
		label.name = "JerseyNum_Front" if z_side == -1 else "JerseyNum_Back"
		label.text = str(num)
		label.font_size = 96
		label.pixel_size = 0.004
		label.position = Vector3(0, 0.85, z_side * 0.36)
		label.rotation.y = PI if z_side == -1 else 0
		label.modulate = Color.WHITE
		label.outline_modulate = Color.BLACK
		label.outline_size = 12
		label.no_depth_test = false
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		player_node.add_child(label)

func _process(delta: float) -> void:
	_apply_screen_shake(delta)
	match match_state:
		MatchState.PLAYING:
			time_remaining -= delta
			clock_changed.emit(time_remaining)
			if time_remaining <= 0:
				_end_quarter()

# =========================================================
#  MATCH START & TIP-OFF (Q1 only)
# =========================================================

func start_match() -> void:
	current_quarter = 1
	scores = [0, 0]
	sides_flipped = false
	time_remaining = quarter_duration
	match_state = MatchState.TIP_OFF
	quarter_changed.emit(current_quarter)
	score_changed.emit(0, 0)
	score_changed.emit(1, 0)
	clock_changed.emit(time_remaining)
	_do_tip_off()

func _do_tip_off() -> void:
	match_state = MatchState.TIP_OFF
	
	_strip_ball_from_all()
	_freeze_all_players(true)
	
	# Position players in tip-off formation
	for i in range(min(teams[0].size(), tip_off_positions_team0.size())):
		var p = teams[0][i]
		p.global_position = tip_off_positions_team0[i] + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.input_move = Vector2.ZERO
	
	for i in range(min(teams[1].size(), tip_off_positions_team1.size())):
		var p = teams[1][i]
		p.global_position = tip_off_positions_team1[i] + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.input_move = Vector2.ZERO
	
	if ball:
		ball.force_position(Vector3(0, 1.0, 0))
	
	var hud = get_tree().get_first_node_in_group("hud")
	
	# Full intro
	if hud and hud.has_method("show_message"):
		hud.show_message("QUARTER 1", 1.5)
	await get_tree().create_timer(2.0).timeout
	
	if hud and hud.has_method("show_message"):
		hud.show_message("READY...", 1.0)
	await get_tree().create_timer(1.5).timeout
	
	if hud and hud.has_method("show_message"):
		hud.show_message("TIP OFF!", 1.5)
	
	# Toss ball
	if ball:
		ball.linear_velocity = Vector3(0, 10, 0)
		ball.angular_velocity = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	
	# Unfreeze jumpers first
	await get_tree().create_timer(0.6).timeout
	if teams[0].size() > 0:
		teams[0][0].frozen = false
	if teams[1].size() > 0:
		teams[1][0].frozen = false
	
	# Then everyone else
	await get_tree().create_timer(0.6).timeout
	_freeze_all_players(false)
	
	# Track who wins tip-off (whoever gets the ball first)
	# Default: team 0 wins tip-off, so possession arrow starts with team 1
	tip_off_winner = 0
	possession_arrow = 1  # Other team gets next possession
	
	match_state = MatchState.PLAYING
	_set_hazard_spawning(true)

# =========================================================
#  INBOUND PASS (used after scores and quarter changes Q2+)
# =========================================================

func _do_inbound_pass(inbound_team: int, endline_z: float) -> void:
	## One player stands outside the endline holding the ball.
	## Teammates are positioned on the court.
	## After a pause, the inbounder passes to the nearest teammate.
	match_state = MatchState.INBOUND
	_set_hazard_spawning(false)
	_strip_ball_from_all()
	_freeze_all_players(true)
	if ball:
		ball._oob_disabled = true
	
	# Clamp endline_z to court bounds
	endline_z = clampf(endline_z, -court_half_l, court_half_l)
	
	# Inbounder stands OUTSIDE the court (1.5m beyond the endline)
	var inbound_x = 0.0
	var inbound_z = endline_z + sign(endline_z) * 1.5
	var inbound_pos = Vector3(inbound_x, 0.1, inbound_z)
	
	# Pick the inbounder — use a non-center player if possible
	var inbounder = null
	var receivers = []
	for i in range(teams[inbound_team].size()):
		var p = teams[inbound_team][i]
		if i == 0 and teams[inbound_team].size() > 1:
			# Center player is the inbounder
			inbounder = p
		else:
			receivers.append(p)
	
	if inbounder == null and teams[inbound_team].size() > 0:
		inbounder = teams[inbound_team][0]
	
	if inbounder == null:
		match_state = MatchState.PLAYING
		return
	
	# Position the inbounder outside the endline
	inbounder.global_position = inbound_pos
	inbounder.velocity = Vector3.ZERO
	inbounder.input_move = Vector2.ZERO
	
	# Position receivers on the court near the endline (spread out)
	var recv_positions = [
		Vector3(-3, 0.1, endline_z - sign(endline_z) * 3.0),
		Vector3(3, 0.1, endline_z - sign(endline_z) * 3.0),
	]
	for i in range(min(receivers.size(), recv_positions.size())):
		receivers[i].global_position = recv_positions[i]
		receivers[i].velocity = Vector3.ZERO
		receivers[i].input_move = Vector2.ZERO
	
	# Position opposing team further back
	var other_team = 1 - inbound_team
	var def_positions = [
		Vector3(-2, 0.1, endline_z - sign(endline_z) * 6.0),
		Vector3(0, 0.1, endline_z - sign(endline_z) * 8.0),
		Vector3(2, 0.1, endline_z - sign(endline_z) * 6.0),
	]
	for i in range(min(teams[other_team].size(), def_positions.size())):
		teams[other_team][i].global_position = def_positions[i]
		teams[other_team][i].velocity = Vector3.ZERO
		teams[other_team][i].input_move = Vector2.ZERO
	
	# Give ball directly to inbounder (bypasses physics entirely)
	_force_give_ball_to(inbounder)
	
	# HUD
	var hud = get_tree().get_first_node_in_group("hud")
	var team_name = "BLUE"
	var team_color = Color.BLUE
	if team_data_store[inbound_team]:
		team_name = team_data_store[inbound_team].name
		team_color = team_data_store[inbound_team].color_primary
	elif inbound_team == 1:
		team_name = "RED"
		team_color = Color.RED
		
	if hud and hud.has_method("show_message"):
		hud.show_message("%s BALL" % team_name.to_upper(), 1.5, team_color)
	
	# Pause with everyone frozen, then execute the pass
	await get_tree().create_timer(2.0).timeout
	
	# Find nearest receiver to pass to
	var best_recv = null
	var best_dist = 99999.0
	for r in receivers:
		var d = r.global_position.distance_to(inbounder.global_position)
		if d < best_dist:
			best_dist = d
			best_recv = r
	
	# Unfreeze everyone and auto-pass
	_freeze_all_players(false)
	if ball:
		ball.freeze = false  # Re-enable physics for the pass
	
	if best_recv and inbounder.has_ball:
		inbounder.pass_to_player(best_recv)
	
	# Move inbounder back onto the court after passing
	await get_tree().create_timer(0.3).timeout
	var return_pos = Vector3(inbound_x, 0.1, endline_z - sign(endline_z) * 2.0)
	inbounder.global_position = return_pos
	
	if ball:
		ball._oob_disabled = false
	match_state = MatchState.PLAYING
	_set_hazard_spawning(true)

# =========================================================
#  SCORING
# =========================================================

func award_score(scoring_team: int, points: int, stop_game: bool = true) -> void:
	if match_state != MatchState.PLAYING:
		return
	scores[scoring_team] += points
	score_changed.emit(scoring_team, scores[scoring_team])
	
	if not stop_game:
		# Free points / Bonus logic
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_gaudy_message"):
			hud.show_gaudy_message("FREE POINTS", 2.0)
		return
	
	match_state = MatchState.SCORED
	
	_strip_ball_from_all()
	_freeze_all_players(true)
	
	# Celebrate!
	for p in teams[scoring_team]:
		if "current_state" in p:
			p.current_state = p.State.CELEBRATING
			p.celebrate_timer = 2.5
			p.velocity = Vector3.ZERO
			p.input_move = Vector2.ZERO
	
	# HUD message
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		var team_name = "BLUE"
		var team_color = Color.BLUE
		if team_data_store[scoring_team]:
			team_name = team_data_store[scoring_team].name
			team_color = team_data_store[scoring_team].color_primary
		elif scoring_team == 1:
			team_name = "RED"
			team_color = Color.RED

		var msg = "%s SCORES!" % team_name.to_upper()
		if points == 3:
			msg = "THREE POINTER! %s" % team_name.to_upper()
		hud.show_message(msg, 2.0, team_color)
	
	await get_tree().create_timer(3.0).timeout
	
	# Scored-on team inbounds from behind the basket that was scored on
	var receiving_team = 1 - scoring_team
	var scored_on_hoop = get_target_hoop(scoring_team)
	# The endline is at the hoop's z position
	_do_inbound_pass(receiving_team, scored_on_hoop.z)

# =========================================================
#  OUT-OF-BOUNDS / THROW-INS
# =========================================================

func _on_ball_out_of_bounds(last_touch_team: int, oob_position: Vector3) -> void:
	if match_state != MatchState.PLAYING:
		return
	
	match_state = MatchState.THROW_IN
	_strip_ball_from_all()
	_freeze_all_players(true)
	
	var receiving_team = 1 - last_touch_team if last_touch_team >= 0 else 0
	
	var team_name = "BLUE"
	var team_color = Color.BLUE
	if team_data_store[receiving_team]:
		team_name = team_data_store[receiving_team].name
		team_color = team_data_store[receiving_team].color_primary
	elif receiving_team == 1:
		team_name = "RED"
		team_color = Color.RED
	print("[OOB] Team %d last touched. %s ball." % [last_touch_team, team_name])
	
	# Figure out the inbound spot — just inside the court near where it went out
	var inbound_spot = _get_inbound_spot(oob_position)
	
	# HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message("OUT OF BOUNDS — %s BALL" % team_name.to_upper(), 1.5, team_color)
	
	await get_tree().create_timer(1.0).timeout
	
	# Run the inbound pass from that spot
	_do_sideline_inbound(receiving_team, inbound_spot, oob_position)

func _get_inbound_spot(oob_pos: Vector3) -> Vector3:
	## Find a position just inside the court boundary near where the ball went out.
	var pos = oob_pos
	pos.y = 0.1
	# Pull inside the court boundary
	pos.x = clampf(pos.x, -court_half_w + 0.5, court_half_w - 0.5)
	pos.z = clampf(pos.z, -court_half_l + 0.5, court_half_l - 0.5)
	return pos

func _do_sideline_inbound(inbound_team: int, court_spot: Vector3, oob_pos: Vector3) -> void:
	## Inbound pass from near an out-of-bounds location.
	## The inbounder stands just outside the boundary, teammates spread nearby.
	if ball:
		ball._oob_disabled = true
	
	# Determine inbounder position — push them just outside the nearest boundary
	var inbounder_pos = court_spot
	inbounder_pos.y = 0.1
	if abs(oob_pos.x) > abs(oob_pos.z) / (court_half_l / court_half_w):
		# Went out on a sideline (X boundary)
		inbounder_pos.x = sign(oob_pos.x) * (court_half_w + 1.0)
	else:
		# Went out on an endline (Z boundary)
		inbounder_pos.z = sign(oob_pos.z) * (court_half_l + 1.0)
	
	# Pick inbounder (first available player on the team)
	var inbounder = null
	var receivers = []
	for i in range(teams[inbound_team].size()):
		var p = teams[inbound_team][i]
		if inbounder == null:
			inbounder = p
		else:
			receivers.append(p)
	
	if inbounder == null:
		_freeze_all_players(false)
		match_state = MatchState.PLAYING
		return
	
	# Position everyone
	inbounder.global_position = inbounder_pos
	inbounder.velocity = Vector3.ZERO
	inbounder.input_move = Vector2.ZERO
	
	# Receivers spread near the inbound spot on-court
	var perp = Vector3(1, 0, 0) if abs(oob_pos.z) > abs(oob_pos.x) else Vector3(0, 0, 1)
	var recv_positions = [
		court_spot + perp * 2.5 - Vector3(0, 0, sign(oob_pos.z)) * 2.0,
		court_spot - perp * 2.5 - Vector3(0, 0, sign(oob_pos.z)) * 2.0,
	]
	for i in range(min(receivers.size(), recv_positions.size())):
		var rp = recv_positions[i]
		rp.x = clampf(rp.x, -court_half_w + 1.0, court_half_w - 1.0)
		rp.z = clampf(rp.z, -court_half_l + 1.0, court_half_l - 1.0)
		rp.y = 0.1
		receivers[i].global_position = rp
		receivers[i].velocity = Vector3.ZERO
		receivers[i].input_move = Vector2.ZERO
	
	# Opposing team further from the inbound spot
	var other_team = 1 - inbound_team
	for i in range(teams[other_team].size()):
		var away_dir = (Vector3.ZERO - court_spot).normalized()
		var def_pos = court_spot + away_dir * (4.0 + i * 2.0)
		def_pos.x = clampf(def_pos.x, -court_half_w + 1.0, court_half_w - 1.0)
		def_pos.z = clampf(def_pos.z, -court_half_l + 1.0, court_half_l - 1.0)
		def_pos.y = 0.1
		teams[other_team][i].global_position = def_pos
		teams[other_team][i].velocity = Vector3.ZERO
		teams[other_team][i].input_move = Vector2.ZERO
	
	# Give ball directly to inbounder (bypasses physics entirely)
	_force_give_ball_to(inbounder)
	
	# Freeze everyone for a moment
	await get_tree().create_timer(1.5).timeout
	
	# Find best receiver and pass
	var best_recv = null
	var best_dist = 99999.0
	for r in receivers:
		var d = r.global_position.distance_to(inbounder.global_position)
		if d < best_dist:
			best_dist = d
			best_recv = r
	
	# Unfreeze and pass
	_freeze_all_players(false)
	if ball:
		ball.freeze = false  # Re-enable physics for the pass
	
	if best_recv and inbounder.has_ball:
		inbounder.pass_to_player(best_recv)
	
	# Move inbounder back onto court
	await get_tree().create_timer(0.3).timeout
	inbounder.global_position = court_spot
	
	if ball:
		ball._oob_disabled = false
	match_state = MatchState.PLAYING
	_set_hazard_spawning(true)

# =========================================================
#  SHARED HELPERS
# =========================================================

func _freeze_all_players(frozen_val: bool) -> void:
	for team in teams:
		for p in team:
			if "frozen" in p:
				p.frozen = frozen_val
			if frozen_val:
				p.velocity = Vector3.ZERO
				p.input_move = Vector2.ZERO
			else:
				# When unfreezing, make sure no one is stuck
				if "current_state" in p and p.current_state in [p.State.CELEBRATING, p.State.SHOOTING, p.State.PASSING]:
					p.current_state = p.State.IDLE

func _force_give_ball_to(player_node: CharacterBody3D) -> void:
	## Directly assign ball to a player — no physics, no pickup checks.
	## Used for inbound passes where the ball must be in the player's hands instantly.
	if ball == null or player_node == null:
		return
	
	_strip_ball_from_all()
	
	# Freeze the ball so it doesn't fall
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	
	# Directly set possession
	player_node.has_ball = true
	player_node.held_ball = ball
	ball.holder = player_node
	if "team_index" in player_node:
		ball.last_touch_team = player_node.team_index
	ball._was_shot = false
	
	# Position ball at player's hand
	var hand_pos = player_node.global_position + Vector3(0, 0.8, 0)
	ball.global_position = hand_pos

func _give_ball_to_team(team_index: int, ball_pos: Vector3) -> void:
	if ball == null:
		return
	
	ball.force_position(ball_pos)
	
	var best_player = null
	var best_dist = 99999.0
	for p in teams[team_index]:
		if "current_state" in p and p.current_state == p.State.KNOCKED_DOWN:
			continue
		var d = p.global_position.distance_to(ball_pos)
		if d < best_dist:
			best_dist = d
			best_player = p
	
	if best_player and best_player.has_method("pickup_ball"):
		var offset = (best_player.global_position - ball_pos)
		offset.y = 0
		if offset.length() > 1.5:
			offset = offset.normalized() * 1.0
		best_player.global_position = ball_pos + offset + Vector3(0, 0.1, 0)
		best_player.velocity = Vector3.ZERO
		await get_tree().create_timer(0.2).timeout
		if ball and not ball.is_held():
			best_player.pickup_ball(ball)
	
	match_state = MatchState.PLAYING
	ball_possession_changed.emit(best_player)

func _strip_ball_from_all() -> void:
	for team in teams:
		for p in team:
			if "has_ball" in p and p.has_ball:
				p.has_ball = false
				p.held_ball = null
	if ball:
		ball.holder = null

func is_three_pointer(shoot_position: Vector3, target_hoop_index: int) -> bool:
	var hoop_pos = hoop_positions[target_hoop_index]
	var dist = shoot_position.distance_to(hoop_pos)
	return dist >= three_point_distance

func get_target_hoop(team_index: int) -> Vector3:
	if sides_flipped:
		return hoop_positions[team_index]
	return hoop_positions[1 - team_index]

# =========================================================
#  QUARTER TRANSITIONS
# =========================================================

func _end_quarter() -> void:
	match_state = MatchState.QUARTER_BREAK
	_set_hazard_spawning(false)
	_clear_hazards()
	_strip_ball_from_all()
	_freeze_all_players(true)
	
	if current_quarter >= total_quarters:
		_end_game()
		return
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message("END OF QUARTER %d" % current_quarter, 2.0)
	
	current_quarter += 1
	quarter_changed.emit(current_quarter)
	
	# Switch sides at halftime (after Q2)
	if current_quarter == 3:
		sides_flipped = not sides_flipped
	
	await get_tree().create_timer(quarter_break_duration).timeout
	time_remaining = quarter_duration
	
	# Q2+ use inbound pass with alternating possession
	var inbound_team = possession_arrow
	# Flip the arrow for next time
	possession_arrow = 1 - possession_arrow
	
	if hud and hud.has_method("show_message"):
		var team_name = "BLUE"
		var team_color = Color.BLUE
		if team_data_store[inbound_team]:
			team_name = team_data_store[inbound_team].name
			team_color = team_data_store[inbound_team].color_primary
		elif inbound_team == 1:
			team_name = "RED"
			team_color = Color.RED
			
		hud.show_message("QUARTER %d — %s BALL" % [current_quarter, team_name.to_upper()], 2.0, team_color)
	
	await get_tree().create_timer(2.0).timeout
	
	# Inbound from the team's defensive endline
	var defensive_hoop = get_target_hoop(1 - inbound_team)
	_do_inbound_pass(inbound_team, defensive_hoop.z)

func _end_game() -> void:
	match_state = MatchState.GAME_OVER
	_set_hazard_spawning(false)
	_clear_hazards()
	var winner = 0 if scores[0] > scores[1] else (1 if scores[1] > scores[0] else -1)
	game_over.emit(winner)

func get_score(team_index: int) -> int:
	return scores[team_index]

func get_formatted_time() -> String:
	var mins = int(time_remaining) / 60
	var secs = int(time_remaining) % 60
	return "%d:%02d" % [mins, secs]

# =========================================================
#  HAZARD SPAWNER
# =========================================================

var hazard_spawner: Node = null
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0

func _create_hazard_spawner() -> void:
	hazard_spawner = Node.new()
	hazard_spawner.set_script(load("res://scripts/hazard_spawner.gd"))
	hazard_spawner.name = "HazardSpawner"
	add_child(hazard_spawner)

func _set_hazard_spawning(enabled: bool) -> void:
	if hazard_spawner and "spawn_enabled" in hazard_spawner:
		hazard_spawner.spawn_enabled = enabled

func _clear_hazards() -> void:
	if hazard_spawner and hazard_spawner.has_method("clear_all_hazards"):
		hazard_spawner.clear_all_hazards()

func _on_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

func _apply_screen_shake(delta: float) -> void:
	if _shake_timer <= 0:
		return
	_shake_timer -= delta
	var camera = get_viewport().get_camera_3d()
	if camera:
		var offset = Vector3(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity),
			0
		)
		camera.h_offset = offset.x
		camera.v_offset = offset.y
		_shake_intensity *= 0.9  # Decay
	if _shake_timer <= 0:
		# Reset camera offsets
		var cam = get_viewport().get_camera_3d()
		if cam:
			cam.h_offset = 0
			cam.v_offset = 0
