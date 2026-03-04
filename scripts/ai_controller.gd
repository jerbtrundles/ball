extends Node
## AI Controller — basketball AI: chase ball, pass, shoot, tackle.
## The `player` variable is assigned externally by court_setup.gd.
## Made deliberately imperfect — prefers passing, hesitates, doesn't always fast break.

@export var decision_interval: float = 0.6  # Slower decisions
@export var reaction_delay: float = 0.3     # Extra delay before acting on new info

var player: CharacterBody3D = null
var decision_timer: float = 0.0
var current_target: Vector3 = Vector3.ZERO
var _pass_requested_by: CharacterBody3D = null
var _hold_ball_timer: float = 0.0  # Time AI has been holding the ball
var _hesitation_timer: float = 0.0 # Brief pause before acting
var _current_shooting_spot: Vector3 = Vector3.ZERO # Cached spot they want to shoot from
var _has_shooting_spot: bool = false

enum AIGoal { CHASE_BALL, GO_TO_HOOP, PASS, SHOOT, TACKLE_CARRIER, DEFEND, IDLE, PASS_TO_REQUESTER, HOLD_POSITION }
var current_goal: AIGoal = AIGoal.IDLE

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_connect_call_for_pass()

func _connect_call_for_pass() -> void:
	if player == null:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if p != player and "team_index" in p and p.team_index == player.team_index:
			if p.has_signal("call_for_pass"):
				p.call_for_pass.connect(_on_teammate_calls_for_pass)

func _on_teammate_calls_for_pass(requester: CharacterBody3D) -> void:
	if player and player.has_ball:
		_pass_requested_by = requester
		current_goal = AIGoal.PASS_TO_REQUESTER

func _process(delta: float) -> void:
	if player == null:
		return
	
	# Don't act while frozen
	if "frozen" in player and player.frozen:
		player.input_move = Vector2.ZERO
		return
	
	# Track how long we've been holding the ball
	if player.has_ball:
		_hold_ball_timer += delta
	else:
		_hold_ball_timer = 0.0
	
	# Hesitation timer
	if _hesitation_timer > 0:
		_hesitation_timer -= delta
		player.input_move = Vector2.ZERO
		return
	
	decision_timer -= delta
	if decision_timer <= 0:
		decision_timer = decision_interval + randf_range(0, 0.3)  # Vary timing
		_make_decision()
	
	_execute_goal(delta)

func _make_decision() -> void:
	# If a pass was requested, honor it
	if _pass_requested_by and player.has_ball:
		current_goal = AIGoal.PASS_TO_REQUESTER
		return
	
	var ball_node = _get_ball()
	if ball_node == null:
		current_goal = AIGoal.IDLE
		return
	
	var game_mgr = get_tree().get_first_node_in_group("game_manager")
	
	if player.current_state == player.State.KNOCKED_DOWN:
		current_goal = AIGoal.IDLE
		return
	
	if player.has_ball:
		_decide_with_ball(game_mgr)
	else:
		_decide_without_ball(ball_node, game_mgr)

func _decide_with_ball(game_mgr: Node) -> void:
	var target_hoop = Vector3(0, 3.0, 14.0)
	if game_mgr and game_mgr.has_method("get_target_hoop"):
		target_hoop = game_mgr.get_target_hoop(player.team_index)
	
	var dist_to_hoop = player.global_position.distance_to(target_hoop)
	
	# Extract stats for personality
	var p_shot = _get_player_stat("shot", 50.0, game_mgr)
	var p_pass = _get_player_stat("pass_skill", 50.0, game_mgr)
	var p_speed = _get_player_stat("speed", 50.0, game_mgr)
	
	# If we just got the ball, hesitate briefly (look around)
	if _hold_ball_timer < 0.4:
		current_goal = AIGoal.HOLD_POSITION
		return
	
	# The better the shooter, the further out they are willing to shoot, and the higher the raw chance
	var max_shot_dist = 5.0 + (p_shot / 100.0) * 8.0 # 5m to 13m range depending on stat
	var shoot_tendency = (p_shot / 100.0)
	
	if dist_to_hoop < max_shot_dist and randf() < shoot_tendency:
		# If they are very close, almost always shoot. If far but within their range, RNG based on stat
		if dist_to_hoop < 4.0 or randf() < shoot_tendency * 0.5:
			current_goal = AIGoal.SHOOT
			return
	
	# Held ball too long? Must do something
	if _hold_ball_timer > 3.0:
		if dist_to_hoop < max_shot_dist:
			current_goal = AIGoal.SHOOT
		else:
			current_goal = AIGoal.PASS
		return
	
	# Medium range — consider passing to an open teammate (60% chance)
	var pass_tendency = (p_pass / 100.0) * 0.8
	if _hold_ball_timer > 1.0 and randf() < pass_tendency:
		current_goal = AIGoal.PASS
		_has_shooting_spot = false
		return
	
	# --- Finding a designated shooting spot ---
	if not _has_shooting_spot or _hold_ball_timer < 0.5:
		_has_shooting_spot = true
		
		# Rim center offset for calculating angles
		var rim_z = 14.0 if target_hoop.z > 0 else -14.0
		var rim_pos = Vector3(0, 0, rim_z)
		
		# Best players want to shoot 3s, average players want mid-range, poor players want paint
		var desired_dist: float
		if p_shot >= 75.0 and randf() < 0.6:
			# Wants to shoot a 3
			desired_dist = randf_range(7.5, 9.0)
		elif p_shot >= 50.0:
			# Wants mid-range
			desired_dist = randf_range(4.0, 7.0)
		else:
			# Wants the paint / post
			desired_dist = randf_range(1.5, 3.5)
		
		# Pick an angle (from the hoop looking out toward center court)
		# 0 is straight out, -PI/2 is left corner, PI/2 is right corner
		var angle = randf_range(-PI/2.5, PI/2.5)
		
		var dir_z = -1.0 if target_hoop.z > 0 else 1.0
		var offset = Vector3(sin(angle), 0, cos(angle) * dir_z) * desired_dist
		
		_current_shooting_spot = rim_pos + offset
		
		# Clamp to court bounds roughly
		if game_mgr:
			_current_shooting_spot.x = clampf(_current_shooting_spot.x, -game_mgr.court_half_w + 1.0, game_mgr.court_half_w - 1.0)
			
	# Otherwise, advance toward the shooting spot
	current_goal = AIGoal.GO_TO_HOOP
	current_target = _current_shooting_spot
	
	# If we reached our spot, maybe we should shoot
	if player.global_position.distance_to(_current_shooting_spot) < 1.0:
		if randf() < shoot_tendency:
			current_goal = AIGoal.SHOOT
			_has_shooting_spot = false
			return
		else:
			# If we chose not to shoot, maybe look for a pass
			current_goal = AIGoal.HOLD_POSITION
			
	# Fast players sprint more often on offense
	if p_speed > 70.0 and randf() < 0.6:
		player.input_sprint = true
	else:
		player.input_sprint = false

func _decide_without_ball(ball_node: RigidBody3D, game_mgr: Node) -> void:
	_has_shooting_spot = false # Clear spot when we don't have ball
	var p_aggression = _get_player_stat("aggression", 50.0, game_mgr)
	
	if ball_node.is_held() and ball_node.holder != null:
		if "team_index" in ball_node.holder and ball_node.holder.team_index != player.team_index:
			# Opponent has ball — High aggression means they tackle more often
			var tackle_tendency = (p_aggression / 100.0) * 0.9 # Up to 90% chance to tackle
			if randf() < tackle_tendency:
				current_goal = AIGoal.TACKLE_CARRIER
				current_target = ball_node.holder.global_position
			else:
				current_goal = AIGoal.DEFEND
				_find_open_position()
		else:
			# Teammate has ball — find an open position
			current_goal = AIGoal.DEFEND
			_find_open_position()
	else:
		# Loose ball — chase it, but don't always sprint
		current_goal = AIGoal.CHASE_BALL
		
		var clamp_x = 8.0
		var clamp_z = 15.0
		if game_mgr:
			clamp_x = game_mgr.court_half_w - 0.5
			clamp_z = game_mgr.court_half_l - 0.5
			
		var target = ball_node.global_position
		# Don't chase ball out of bounds if it's dead/inbound
		if ball_node._oob_disabled or game_mgr.match_state == game_mgr.MatchState.INBOUND or game_mgr.match_state == game_mgr.MatchState.THROW_IN:
			target.x = clampf(target.x, -clamp_x, clamp_x)
			target.z = clampf(target.z, -clamp_z, clamp_z)
			
		current_target = target

func _execute_goal(_delta: float) -> void:
	player.input_pass = false
	player.input_shoot = false
	player.input_tackle = false
	player.input_sprint = false
	
	match current_goal:
		AIGoal.IDLE:
			player.input_move = Vector2.ZERO
		AIGoal.HOLD_POSITION:
			# Stay put, look around
			player.input_move = Vector2.ZERO
		AIGoal.CHASE_BALL:
			_move_toward(current_target, false)  # Don't sprint for loose balls
		AIGoal.GO_TO_HOOP:
			_move_toward(current_target, false)  # Walk, don't sprint!
		AIGoal.SHOOT:
			player.input_shoot = true
			player.input_move = Vector2.ZERO
			_hesitation_timer = 0.5  # Pause after shooting
		AIGoal.PASS:
			player.input_pass = true
			_hesitation_timer = 0.3  # Brief pause after passing
		AIGoal.PASS_TO_REQUESTER:
			if _pass_requested_by and player.has_ball:
				player.pass_to_player(_pass_requested_by)
				_pass_requested_by = null
			current_goal = AIGoal.IDLE
			_hesitation_timer = 0.3
		AIGoal.TACKLE_CARRIER:
			var ball_node = _get_ball()
			if ball_node and ball_node.holder:
				current_target = ball_node.holder.global_position
			_move_toward(current_target, false)  # Don't sprint when tackling
			var dist = player.global_position.distance_to(current_target)
			if dist < player.tackle_range * 1.2:
				player.input_tackle = true
				_hesitation_timer = 0.5  # Recovery after tackle
		AIGoal.DEFEND:
			_move_toward(current_target, false)

func _move_toward(target: Vector3, sprint: bool) -> void:
	var to_target = target - player.global_position
	to_target.y = 0
	if to_target.length() > 0.5:
		var dir = to_target.normalized()
		player.input_move = Vector2(dir.x, dir.z)
		player.input_aim = player.input_move
		
		# Allow the stat-based sprint decision from _decide_with_ball to persist if it was set
		if current_goal == AIGoal.GO_TO_HOOP and player.input_sprint:
			pass # Keep sprint true
		else:
			player.input_sprint = sprint
	else:
		player.input_move = Vector2.ZERO
		player.input_sprint = false

func _find_open_position() -> void:
	var game_mgr = get_tree().get_first_node_in_group("game_manager")
	var target_hoop = Vector3(0, 3.0, 14.0)
	var defend_hoop = Vector3(0, 3.0, -14.0)
	if game_mgr and game_mgr.has_method("get_target_hoop"):
		target_hoop = game_mgr.get_target_hoop(player.team_index)
		defend_hoop = game_mgr.get_target_hoop(1 - player.team_index) # Other team's target is our defense
	
	var ball_node = _get_ball()
	if ball_node and ball_node.is_held():
		if "team_index" in ball_node.holder and ball_node.holder.team_index != player.team_index:
			# Opponent has ball: defend the hoop!
			# Post up halfway between the ball carrier and our defensive hoop
			var offset = Vector3(randf_range(-3, 3), 0, randf_range(-2, 2))
			current_target = (ball_node.holder.global_position + defend_hoop) * 0.4 + offset
			return
			
	# Teammate has ball: find an open offensive spot
	var offset = Vector3(randf_range(-5, 5), 0, randf_range(-3, 3))
	current_target = (player.global_position + target_hoop) * 0.5 + offset

func _get_ball() -> RigidBody3D:
	var balls = get_tree().get_nodes_in_group("ball")
	return balls[0] if balls.size() > 0 else null

func _get_player_stat(stat_name: String, default_val: float, game_mgr: Node) -> float:
	if not game_mgr or not "team_data_store" in game_mgr:
		return default_val
	if player.team_index < 0 or player.team_index >= game_mgr.team_data_store.size():
		return default_val
	var team_data = game_mgr.team_data_store[player.team_index]
	if not team_data or not "roster" in team_data:
		return default_val
	if player.roster_index < 0 or player.roster_index >= team_data.roster.size():
		return default_val
	var p_data = team_data.roster[player.roster_index]
	if p_data and stat_name in p_data:
		return float(p_data.get(stat_name))
	return default_val
