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
	
	# --- AI prefers to pass rather than drive ---
	
	# If we just got the ball, hesitate briefly (look around)
	if _hold_ball_timer < 0.4:
		current_goal = AIGoal.HOLD_POSITION
		return
	
	# Very close to hoop? Shoot (but not always — 70% chance)
	if dist_to_hoop < 5.0 and randf() < 0.7:
		current_goal = AIGoal.SHOOT
		return
	
	# Held ball too long? Must do something
	if _hold_ball_timer > 3.0:
		if dist_to_hoop < 8.0:
			current_goal = AIGoal.SHOOT
		else:
			current_goal = AIGoal.PASS
		return
	
	# Medium range — consider passing to an open teammate (60% chance)
	if _hold_ball_timer > 1.0 and randf() < 0.6:
		current_goal = AIGoal.PASS
		return
	
	# Otherwise, slowly advance toward the hoop (no sprint!)
	current_goal = AIGoal.GO_TO_HOOP
	current_target = target_hoop

func _decide_without_ball(ball_node: RigidBody3D, game_mgr: Node) -> void:
	if ball_node.is_held() and ball_node.holder != null:
		if "team_index" in ball_node.holder and ball_node.holder.team_index != player.team_index:
			# Opponent has ball — but don't always chase (50% defend, 50% tackle)
			if randf() < 0.5:
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
		current_target = ball_node.global_position

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
		player.input_sprint = sprint
	else:
		player.input_move = Vector2.ZERO
		player.input_sprint = false

func _find_open_position() -> void:
	var game_mgr = get_tree().get_first_node_in_group("game_manager")
	var target_hoop = Vector3(0, 3.0, 14.0)
	if game_mgr and game_mgr.has_method("get_target_hoop"):
		target_hoop = game_mgr.get_target_hoop(player.team_index)
	
	# Find a spot roughly between current position and the hoop, with some randomness
	var offset = Vector3(randf_range(-5, 5), 0, randf_range(-3, 3))
	current_target = (player.global_position + target_hoop) * 0.5 + offset

func _get_ball() -> RigidBody3D:
	var balls = get_tree().get_nodes_in_group("ball")
	return balls[0] if balls.size() > 0 else null
