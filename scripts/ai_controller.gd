extends Node
## AI Controller — basketball AI with man-to-man defense, role-based spacing,
## smart passing, fast-break awareness, and stat-driven behaviour.
## The `player` variable is assigned externally by game_manager.gd.

@export var decision_interval: float = 0.25  # Base decision rate (fast)

var player: CharacterBody3D = null
var decision_timer: float = 0.0
var current_target: Vector3 = Vector3.ZERO

var _pass_requested_by: CharacterBody3D = null
var _hold_ball_timer: float = 0.0
var _hesitation_timer: float = 0.0
var _current_shooting_spot: Vector3 = Vector3.ZERO
var _has_shooting_spot: bool = false

# Man-to-man: the specific opponent this AI is assigned to guard
var _assigned_opponent: CharacterBody3D = null

# Role determines preferred off-ball court position (0–4)
# 0 = ball handler (top of key), 1 = wing L, 2 = wing R, 3 = corner, 4 = post/paint
var _role: int = 0

# Cached stats — updated each decision tick to avoid per-frame lookups
var _p_speed: float = 50.0
var _p_shot: float = 50.0
var _p_pass: float = 50.0
var _p_aggression: float = 50.0

enum AIGoal {
	IDLE, HOLD_POSITION,
	CHASE_BALL, GO_TO_HOOP, FAST_BREAK,
	SHOOT, PASS, PASS_TO_REQUESTER,
	TACKLE_CARRIER, DEFEND, OPEN_SPACE
}
var current_goal: AIGoal = AIGoal.IDLE

# ── Initialisation ───────────────────────────────────────────────────────────

func _ready() -> void:
	# Delay so game_manager has time to spawn all players
	await get_tree().create_timer(1.0).timeout
	_assign_role()
	_assign_opponent()
	_connect_call_for_pass()

func _assign_role() -> void:
	if player and "roster_index" in player:
		_role = player.roster_index % 5

func _assign_opponent() -> void:
	## Pick one specific opponent to man-mark throughout the match.
	## Prefer the opponent with the same roster_index (mirror matching).
	if player == null:
		return
	# First pass: exact roster_index match
	for p in get_tree().get_nodes_in_group("players"):
		if not ("team_index" in p) or p.team_index == player.team_index:
			continue
		if "roster_index" in p and p.roster_index == player.roster_index:
			_assigned_opponent = p
			return
	# Fallback: first available opponent
	for p in get_tree().get_nodes_in_group("players"):
		if "team_index" in p and p.team_index != player.team_index:
			_assigned_opponent = p
			return

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

# ── Main loop ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if player == null:
		return
	if "frozen" in player and player.frozen:
		player.input_move = Vector2.ZERO
		return

	if player.has_ball:
		_hold_ball_timer += delta
	else:
		_hold_ball_timer = 0.0

	# Hesitation: player pauses briefly after acting
	if _hesitation_timer > 0:
		_hesitation_timer -= delta
		player.input_move = Vector2.ZERO
		return

	decision_timer -= delta
	if decision_timer <= 0:
		# Faster thinkers react sooner
		var speed_bonus = (_p_speed - 10.0) / 89.0 * 0.1  # 0→0.1 reduction
		decision_timer = decision_interval - speed_bonus + randf_range(0, 0.12)
		_update_cached_stats()
		_make_decision()

	_execute_goal(delta)

# ── Decision making ──────────────────────────────────────────────────────────

func _update_cached_stats() -> void:
	var gm = _get_game_manager()
	_p_speed      = _get_player_stat("speed",      50.0, gm)
	_p_shot       = _get_player_stat("shot",       50.0, gm)
	_p_pass       = _get_player_stat("pass_skill", 50.0, gm)
	_p_aggression = _get_player_stat("aggression", 50.0, gm)

func _make_decision() -> void:
	# Pass request from a teammate takes priority
	if _pass_requested_by and is_instance_valid(_pass_requested_by) and player.has_ball:
		current_goal = AIGoal.PASS_TO_REQUESTER
		return

	var ball_node = _get_ball()
	if ball_node == null:
		current_goal = AIGoal.IDLE
		return

	if player.current_state == player.State.KNOCKED_DOWN:
		current_goal = AIGoal.IDLE
		return

	var game_mgr = _get_game_manager()
	if player.has_ball:
		_decide_with_ball(game_mgr, ball_node)
	else:
		_decide_without_ball(ball_node, game_mgr)

func _decide_with_ball(game_mgr: Node, _ball_node: RigidBody3D) -> void:
	var target_hoop := Vector3(0, 3.0, 14.0)
	if game_mgr and game_mgr.has_method("get_target_hoop"):
		target_hoop = game_mgr.get_target_hoop(player.team_index)

	var dist_to_hoop: float = player.global_position.distance_to(target_hoop)

	# Brief look-around after picking up the ball
	if _hold_ball_timer < 0.3:
		current_goal = AIGoal.HOLD_POSITION
		return

	# ── Fast break: ball just picked up in own half, open court ahead ─────────
	var hoop_z_sign: float = sign(target_hoop.z)
	var in_own_half: bool = player.global_position.z * hoop_z_sign < 0
	if in_own_half and _hold_ball_timer < 1.5 and not _is_hoop_path_blocked(target_hoop):
		current_goal = AIGoal.FAST_BREAK
		current_target = target_hoop
		return

	# ── Shooting decision ─────────────────────────────────────────────────────
	var max_shot_dist := 5.0 + (_p_shot / 100.0) * 8.0   # 5 m (poor) → 13 m (elite)
	var shoot_tendency := _p_shot / 100.0

	if dist_to_hoop < max_shot_dist:
		# Very close: almost always shoot; at range: RNG based on skill
		if dist_to_hoop < 4.0 or randf() < shoot_tendency * 0.6:
			current_goal = AIGoal.SHOOT
			return

	# ── Timeout: held too long ────────────────────────────────────────────────
	if _hold_ball_timer > 2.5:
		current_goal = AIGoal.SHOOT if dist_to_hoop < max_shot_dist else AIGoal.PASS
		return

	# ── Smart pass: find an open teammate moving toward basket ────────────────
	if _hold_ball_timer > 0.8:
		var open_mate = _find_open_teammate(game_mgr)
		var pass_tendency := (_p_pass / 100.0) * 0.65
		if open_mate != null and randf() < pass_tendency:
			_pass_requested_by = open_mate
			current_goal = AIGoal.PASS_TO_REQUESTER
			_has_shooting_spot = false
			return

	# ── Move to a preferred shooting spot ────────────────────────────────────
	if not _has_shooting_spot or _hold_ball_timer < 0.5:
		_has_shooting_spot = true
		var rim_z := 14.0 if target_hoop.z > 0 else -14.0
		var rim_pos := Vector3(0, 0, rim_z)

		var desired_dist: float
		if _p_shot >= 75.0 and randf() < 0.6:
			desired_dist = randf_range(7.5, 9.0)   # Three-point range
		elif _p_shot >= 50.0:
			desired_dist = randf_range(4.0, 7.0)    # Mid-range
		else:
			desired_dist = randf_range(1.5, 3.5)    # Paint

		var angle := randf_range(-PI / 2.5, PI / 2.5)
		var dir_z := -1.0 if target_hoop.z > 0 else 1.0
		_current_shooting_spot = rim_pos + Vector3(sin(angle), 0, cos(angle) * dir_z) * desired_dist
		if game_mgr:
			_current_shooting_spot.x = clampf(
				_current_shooting_spot.x,
				-game_mgr.court_half_w + 1.0,
				game_mgr.court_half_w - 1.0
			)

	current_goal = AIGoal.GO_TO_HOOP
	current_target = _current_shooting_spot

	# At the spot — shoot or hold
	if player.global_position.distance_to(_current_shooting_spot) < 1.0:
		if randf() < shoot_tendency:
			current_goal = AIGoal.SHOOT
			_has_shooting_spot = false
		else:
			current_goal = AIGoal.HOLD_POSITION

	# Speed-based sprint tendency on offense
	player.input_sprint = _p_speed > 60.0 and randf() < 0.5

func _decide_without_ball(ball_node: RigidBody3D, game_mgr: Node) -> void:
	_has_shooting_spot = false

	if ball_node.is_held() and ball_node.holder != null:
		var holder_team: int = ball_node.holder.team_index if "team_index" in ball_node.holder else -1

		if holder_team != player.team_index:
			# ── OPPONENT HAS BALL ─────────────────────────────────────────
			# Always chase if our assigned man is the carrier
			if ball_node.holder == _assigned_opponent:
				current_goal = AIGoal.TACKLE_CARRIER
				current_target = ball_node.holder.global_position
				return

			# Otherwise, high-aggression players still chase; others defend
			var tackle_tendency := (_p_aggression / 100.0) * 0.7
			if randf() < tackle_tendency:
				current_goal = AIGoal.TACKLE_CARRIER
				current_target = ball_node.holder.global_position
			else:
				current_goal = AIGoal.DEFEND
				_find_defensive_position(ball_node, game_mgr)
		else:
			# ── TEAMMATE HAS BALL — spread out on offense ──────────────────
			current_goal = AIGoal.OPEN_SPACE
			_find_offensive_space(game_mgr)
	else:
		# ── LOOSE BALL — hustle for it ─────────────────────────────────────
		current_goal = AIGoal.CHASE_BALL
		var clamp_x: float = 7.5 if game_mgr == null else float(game_mgr.court_half_w) - 0.5
		var clamp_z: float = 14.5 if game_mgr == null else float(game_mgr.court_half_l) - 0.5
		var target := ball_node.global_position
		# Don't chase the ball out of bounds during dead balls
		if ball_node._oob_disabled:
			target.x = clampf(target.x, -clamp_x, clamp_x)
			target.z = clampf(target.z, -clamp_z, clamp_z)
		elif game_mgr and (game_mgr.match_state == game_mgr.MatchState.INBOUND or
				game_mgr.match_state == game_mgr.MatchState.THROW_IN):
			target.x = clampf(target.x, -clamp_x, clamp_x)
			target.z = clampf(target.z, -clamp_z, clamp_z)
		current_target = target

# ── Positioning helpers ──────────────────────────────────────────────────────

func _find_defensive_position(ball_node: RigidBody3D, game_mgr: Node) -> void:
	## Get between our assigned opponent and our own basket (denial stance).
	var defend_hoop := Vector3(0, 3.0, -14.0)
	if game_mgr and game_mgr.has_method("get_target_hoop"):
		defend_hoop = game_mgr.get_target_hoop(1 - player.team_index)

	if _assigned_opponent != null and is_instance_valid(_assigned_opponent):
		# Guard the assigned man: position 1.5 m between them and our basket
		var opp_pos := _assigned_opponent.global_position
		var to_basket := (defend_hoop - opp_pos)
		to_basket.y = 0
		if to_basket.length() > 0.1:
			to_basket = to_basket.normalized()
		current_target = opp_pos + to_basket * 1.5 + Vector3(randf_range(-0.4, 0.4), 0, 0)
	elif ball_node.holder != null:
		# No valid assigned man: zone defence — block the lane to the basket
		var offset := Vector3(randf_range(-2.0, 2.0), 0, randf_range(-1.0, 1.0))
		current_target = (ball_node.holder.global_position + defend_hoop) * 0.45 + offset
	else:
		current_target = defend_hoop + Vector3(randf_range(-3, 3), 0, randf_range(-2, 2))

func _find_offensive_space(game_mgr: Node) -> void:
	## Move to a role-appropriate court position so the team stays spread out.
	var target_hoop := Vector3(0, 3.0, 14.0)
	if game_mgr and game_mgr.has_method("get_target_hoop"):
		target_hoop = game_mgr.get_target_hoop(player.team_index)

	var hp := Vector3(target_hoop.x, 0.0, target_hoop.z)  # Hoop XZ
	var d: float = sign(target_hoop.z)  # +1 if hoop is south, -1 if north

	# Role-based spots (all relative to the offensive hoop)
	var spot: Vector3
	match _role:
		0:  # Ball handler — top of the key, ~7 m out
			spot = hp + Vector3(0.0, 0.0, -d * 7.0)
		1:  # Left wing — ~4.5 m out, court-left
			spot = hp + Vector3(-4.5, 0.0, -d * 4.5)
		2:  # Right wing — ~4.5 m out, court-right
			spot = hp + Vector3(4.5, 0.0, -d * 4.5)
		3:  # Corner / weak side
			var side := 1.0 if randf() > 0.5 else -1.0
			spot = hp + Vector3(side * 6.0, 0.0, -d * 1.5)
		4:  # Post / paint
			spot = hp + Vector3(randf_range(-1.5, 1.5), 0.0, -d * 1.5)
		_:
			spot = hp + Vector3(randf_range(-5, 5), 0.0, randf_range(-4, 4))

	# Small drift so players don't stand perfectly still
	spot += Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))

	# Clamp within court
	if game_mgr:
		spot.x = clampf(spot.x, -game_mgr.court_half_w + 1.0, game_mgr.court_half_w - 1.0)
		spot.z = clampf(spot.z, -game_mgr.court_half_l + 1.0, game_mgr.court_half_l - 1.0)

	current_target = spot

# ── Goal execution ───────────────────────────────────────────────────────────

func _execute_goal(_delta: float) -> void:
	player.input_pass = false
	player.input_shoot = false
	player.input_tackle = false
	player.input_sprint = false

	match current_goal:
		AIGoal.IDLE:
			player.input_move = Vector2.ZERO

		AIGoal.HOLD_POSITION:
			player.input_move = Vector2.ZERO

		AIGoal.CHASE_BALL:
			# Hustle — sprint if fast enough and ball is some distance away
			var dist := player.global_position.distance_to(current_target)
			_move_toward(current_target, dist > 2.5 and _p_speed > 45.0)

		AIGoal.GO_TO_HOOP:
			# Uses sprint flag set in _decide_with_ball
			_move_toward(current_target, player.input_sprint)

		AIGoal.FAST_BREAK:
			_move_toward(current_target, true)  # Always sprint on fast break

		AIGoal.OPEN_SPACE:
			_move_toward(current_target, false)

		AIGoal.SHOOT:
			player.input_shoot = true
			player.input_move = Vector2.ZERO
			_hesitation_timer = 0.35

		AIGoal.PASS:
			player.input_pass = true
			_hesitation_timer = 0.2

		AIGoal.PASS_TO_REQUESTER:
			if _pass_requested_by != null and is_instance_valid(_pass_requested_by) and player.has_ball:
				player.pass_to_player(_pass_requested_by)
				_pass_requested_by = null
			current_goal = AIGoal.IDLE
			_hesitation_timer = 0.2

		AIGoal.TACKLE_CARRIER:
			# Update target to ball carrier's live position
			var ball_node = _get_ball()
			if ball_node != null and ball_node.holder != null and is_instance_valid(ball_node.holder):
				current_target = ball_node.holder.global_position
			# Sprint when chasing — speed stat determines how hard they chase
			_move_toward(current_target, _p_speed > 40.0)
			var dist := player.global_position.distance_to(current_target)
			if dist < player.tackle_range * 1.2:
				player.input_tackle = true
				_hesitation_timer = 0.35

		AIGoal.DEFEND:
			# Sprint to stay with an opponent who is moving fast
			var should_sprint := false
			if _assigned_opponent != null and is_instance_valid(_assigned_opponent):
				var opp_vel := _assigned_opponent.velocity
				opp_vel.y = 0
				should_sprint = opp_vel.length() > 5.0 and _p_speed > 50.0
			_move_toward(current_target, should_sprint)

# ── Open teammate selection ──────────────────────────────────────────────────

func _find_open_teammate(game_mgr: Node) -> CharacterBody3D:
	## Returns the best teammate to pass to: open (low defender pressure) and
	## preferably closer to the basket than the ball carrier.
	var target_hoop := Vector3(0, 3.0, 14.0)
	if game_mgr and game_mgr.has_method("get_target_hoop"):
		target_hoop = game_mgr.get_target_hoop(player.team_index)

	var best_mate: CharacterBody3D = null
	var best_score: float = -999.0

	for mate in get_tree().get_nodes_in_group("players"):
		if mate == player:
			continue
		if not ("team_index" in mate) or mate.team_index != player.team_index:
			continue
		if "current_state" in mate and mate.current_state == mate.State.KNOCKED_DOWN:
			continue

		# Reject if pass lane is blocked by a defender
		if _is_pass_lane_blocked(mate):
			continue

		# Count defender pressure on this teammate
		var pressure := 0.0
		for def in get_tree().get_nodes_in_group("players"):
			if not ("team_index" in def) or def.team_index == player.team_index:
				continue
			var def_dist: float = mate.global_position.distance_to(def.global_position)
			if def_dist < 2.0:
				pressure += 3.0
			elif def_dist < 4.0:
				pressure += 1.0

		# Bonus for being closer to the basket (good scoring position)
		var dist_to_hoop: float = mate.global_position.distance_to(target_hoop)
		var position_bonus := maxf(0.0, 10.0 - dist_to_hoop)

		# Forward pass bonus: prefer teammates ahead of us (toward the basket)
		var to_mate_flat: Vector3 = mate.global_position - player.global_position
		to_mate_flat.y = 0
		var to_hoop_flat := target_hoop - player.global_position
		to_hoop_flat.y = 0
		var forward_dot := 0.0
		if to_mate_flat.length() > 0.1 and to_hoop_flat.length() > 0.1:
			forward_dot = to_mate_flat.normalized().dot(to_hoop_flat.normalized())
		var forward_bonus := forward_dot * 3.0  # Up to +3 for a perfectly forward pass

		var score := position_bonus + forward_bonus - pressure
		if score > best_score:
			best_score = score
			best_mate = mate

	# Only pass if the best option is genuinely open (positive overall score)
	return best_mate if best_score > 0.5 else null

func _is_pass_lane_blocked(target: CharacterBody3D) -> bool:
	## Returns true if a defender stands in the direct passing lane.
	var to_target := target.global_position - player.global_position
	var dist := to_target.length()
	if dist < 1.0:
		return false
	var dir := to_target.normalized()

	for p in get_tree().get_nodes_in_group("players"):
		if p == player or p == target:
			continue
		if not ("team_index" in p) or p.team_index == player.team_index:
			continue
		var to_p: Vector3 = p.global_position - player.global_position
		var proj: float = to_p.dot(dir)
		# Only check defenders actually between us and the target
		if proj < 0.5 or proj > dist - 0.5:
			continue
		var lateral: float = (to_p - dir * proj).length()
		if lateral < 1.2:
			return true
	return false

func _is_hoop_path_blocked(hoop: Vector3) -> bool:
	## Returns true if an opponent stands between us and the hoop (fast-break check).
	var to_hoop := hoop - player.global_position
	var dist := to_hoop.length()
	if dist < 1.0:
		return false
	var dir := to_hoop.normalized()

	for p in get_tree().get_nodes_in_group("players"):
		if not ("team_index" in p) or p.team_index == player.team_index:
			continue
		var to_p: Vector3 = p.global_position - player.global_position
		var proj: float = to_p.dot(dir)
		if proj < 1.0 or proj > dist:
			continue
		var lateral: float = (to_p - dir * proj).length()
		if lateral < 2.5:
			return true
	return false

# ── Movement ─────────────────────────────────────────────────────────────────

func _move_toward(target: Vector3, sprint: bool) -> void:
	var to_target := target - player.global_position
	to_target.y = 0
	if to_target.length() > 0.5:
		var dir := to_target.normalized()
		player.input_move = Vector2(dir.x, dir.z)
		player.input_aim  = player.input_move
		player.input_sprint = sprint
	else:
		player.input_move = Vector2.ZERO
		player.input_sprint = false

# ── Utilities ─────────────────────────────────────────────────────────────────

func _get_ball() -> RigidBody3D:
	var balls := get_tree().get_nodes_in_group("ball")
	return balls[0] if balls.size() > 0 else null

func _get_game_manager() -> Node:
	return get_tree().get_first_node_in_group("game_manager")

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
		var v = p_data.get(stat_name)
		return float(v) if v != null else default_val
	return default_val
