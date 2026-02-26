extends CharacterBody3D
## Player character — handles movement, state machine, ball possession, and combat.

signal got_ball()
signal lost_ball()
signal was_tackled()
signal scored_basket(points: int)
signal call_for_pass(requester: CharacterBody3D)  # Fired when player wants a teammate to pass

# --- Team ---
@export var team_index: int = 0
@export var roster_index: int = -1
@export var player_name: String = "Player"
@export var is_human: bool = false

# --- Stats ---
@export var move_speed: float = 8.0
@export var sprint_speed: float = 12.0
@export var tackle_force: float = 15.0
@export var tackle_range: float = 2.5
@export var shot_power: float = 12.0
@export var pass_power: float = 14.0
@export var aggressiveness: float = 1.0
@export var strength: float = 1.0  # How fast they recover from tackles
@export var jump_force: float = 10.0

# --- State ---
enum State { IDLE, RUNNING, SPRINTING, SHOOTING, PASSING, TACKLING, KNOCKED_DOWN, CELEBRATING }
var current_state: State = State.IDLE
var has_ball: bool = false
var facing_direction: Vector3 = Vector3.FORWARD
var aim_direction: Vector3 = Vector3.FORWARD
var knockdown_timer: float = 0.0
var knockdown_duration: float = 2.0
var tackle_cooldown: float = 0.0
var tackle_cooldown_duration: float = 1.0
var frozen: bool = false  # When true, player can't move or act (tip-off intro)
var celebrate_timer: float = 0.0

# --- Power-up buff ---
var active_buff: String = ""  # "speed", "accuracy", "tackle", or ""
var buff_timer: float = 0.0
var _base_move_speed: float = 0.0
var _base_sprint_speed: float = 0.0
var _base_tackle_force: float = 0.0
var _base_tackle_range: float = 0.0

# --- Movement input (set by controller or AI) ---
var input_move: Vector2 = Vector2.ZERO
var input_aim: Vector2 = Vector2.ZERO
var input_sprint: bool = false
var input_pass: bool = false
var input_shoot: bool = false
var input_tackle: bool = false
var input_call_pass: bool = false  # Press pass when you don't have the ball
var input_jump: bool = false

# --- References ---
var held_ball: RigidBody3D = null
@onready var mesh: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape
@onready var tackle_area: Area3D = $TackleArea
@onready var ball_pickup_area: Area3D = $BallPickupArea
@onready var team_color_material: StandardMaterial3D = StandardMaterial3D.new()

# Team colors
var team_colors: Array[Color] = [
	Color(0.2, 0.5, 1.0),   # Team 0 — Blue
	Color(1.0, 0.3, 0.2),   # Team 1 — Red
]

func _ready() -> void:
	add_to_group("players")
	_setup_visuals()
	# Connect ball pickup area
	if ball_pickup_area:
		ball_pickup_area.body_entered.connect(_on_ball_entered)
	# Boost human player for testing
	if is_human:
		move_speed = 10.0
		sprint_speed = 15.0
		shot_power = 14.0

@export var jersey_number: int = 0  # Set by game_manager during team setup

# Arm pivot references (for animation)
var _left_arm_pivot: Node3D = null
var _right_arm_pivot: Node3D = null
var _arm_tween: Tween = null
var custom_team_color: Color = Color(0, 0, 0, 0) # If alpha > 0, overrides team_index color

var _buff_indicator_mesh: MeshInstance3D = null
var _buff_indicator_mat: StandardMaterial3D = null

func _setup_visuals() -> void:
	var color = team_colors[team_index] if team_index < team_colors.size() else Color.WHITE
	if custom_team_color.a > 0.0:
		color = custom_team_color
	
	team_color_material.albedo_color = color
	team_color_material.albedo_color = color
	team_color_material.emission_enabled = true
	team_color_material.emission = color * 0.3
	team_color_material.metallic = 0.6
	team_color_material.roughness = 0.3
	if mesh:
		mesh.material_override = team_color_material
	
	# Accent color for visor and details
	var accent_color = Color(0.0, 1.0, 1.0) if team_index == 0 else Color(1.0, 1.0, 0.0)
	var accent_mat = StandardMaterial3D.new()
	accent_mat.albedo_color = accent_color
	accent_mat.emission_enabled = true
	accent_mat.emission = accent_color
	accent_mat.emission_energy_multiplier = 3.0
	
	# Skin-tone material for arms
	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.85, 0.65, 0.45)
	skin_mat.roughness = 0.8
	
	# --- Visor (front-facing stripe so you can see direction) ---
	var visor = MeshInstance3D.new()
	visor.name = "Visor"
	var visor_mesh = BoxMesh.new()
	visor_mesh.size = Vector3(0.3, 0.12, 0.05)
	visor.mesh = visor_mesh
	visor.material_override = accent_mat
	visor.position = Vector3(0, 1.2, -0.34)
	add_child(visor)
	
	# --- Arms (left and right with pivot nodes for animation) ---
	for side in [-1, 1]:
		var arm_pivot = Node3D.new()
		arm_pivot.name = "ArmPivot_L" if side == -1 else "ArmPivot_R"
		arm_pivot.position = Vector3(side * 0.38, 1.0, 0)  # Shoulder joint
		add_child(arm_pivot)
		
		if side == -1:
			_left_arm_pivot = arm_pivot
		else:
			_right_arm_pivot = arm_pivot
		
		# Upper arm
		var upper_arm = MeshInstance3D.new()
		upper_arm.name = "UpperArm"
		var ua_mesh = CylinderMesh.new()
		ua_mesh.top_radius = 0.07
		ua_mesh.bottom_radius = 0.06
		ua_mesh.height = 0.35
		upper_arm.mesh = ua_mesh
		upper_arm.material_override = skin_mat
		upper_arm.position = Vector3(0, -0.18, 0)  # Hangs down from pivot
		arm_pivot.add_child(upper_arm)
		
		# Forearm
		var forearm = MeshInstance3D.new()
		forearm.name = "Forearm"
		var fa_mesh = CylinderMesh.new()
		fa_mesh.top_radius = 0.06
		fa_mesh.bottom_radius = 0.05
		fa_mesh.height = 0.3
		forearm.mesh = fa_mesh
		forearm.material_override = skin_mat
		forearm.position = Vector3(0, -0.5, 0)  # Below upper arm
		arm_pivot.add_child(forearm)
		
		# Hand (small sphere)
		var hand = MeshInstance3D.new()
		hand.name = "Hand"
		var hand_mesh = SphereMesh.new()
		hand_mesh.radius = 0.06
		hand_mesh.height = 0.12
		hand.mesh = hand_mesh
		hand.material_override = skin_mat
		hand.position = Vector3(0, -0.68, 0)
		arm_pivot.add_child(hand)
	
	# --- Jersey number (front and back) ---
	if jersey_number > 0:
		for z_side in [-1, 1]:  # front (-1) and back (+1)
			var label = Label3D.new()
			label.name = "JerseyNum_Front" if z_side == -1 else "JerseyNum_Back"
			label.text = str(jersey_number)
			label.font_size = 96
			label.pixel_size = 0.004
			label.position = Vector3(0, 0.85, z_side * 0.36)
			label.rotation.y = PI if z_side == -1 else 0
			label.modulate = Color.WHITE
			label.outline_modulate = Color.BLACK
			label.outline_size = 12
			label.no_depth_test = false
			label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			add_child(label)
	
	# --- Human player ring indicator ---
	if is_human:
		var ring = MeshInstance3D.new()
		ring.name = "HumanRing"
		var ring_mesh = TorusMesh.new()
		ring_mesh.inner_radius = 0.4
		ring_mesh.outer_radius = 0.55
		ring.mesh = ring_mesh
		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = Color(1.0, 1.0, 0.0)
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(1.0, 1.0, 0.0)
		ring_mat.emission_energy_multiplier = 2.0
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color.a = 0.7
		ring.material_override = ring_mat
		ring.position = Vector3(0, 0.05, 0)
		add_child(ring)

	# --- Buff Indicator Ring (hidden by default) ---
	_buff_indicator_mesh = MeshInstance3D.new()
	_buff_indicator_mesh.name = "BuffRing"
	var buff_mesh = TorusMesh.new()
	buff_mesh.inner_radius = 0.5
	buff_mesh.outer_radius = 0.65
	_buff_indicator_mesh.mesh = buff_mesh
	_buff_indicator_mat = StandardMaterial3D.new()
	_buff_indicator_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_buff_indicator_mat.emission_enabled = true
	_buff_indicator_mesh.material_override = _buff_indicator_mat
	_buff_indicator_mesh.position = Vector3(0, 0.06, 0) # Just above human ring
	_buff_indicator_mesh.visible = false
	add_child(_buff_indicator_mesh)

# --- Arm animations ---

func _play_shoot_animation() -> void:
	## Arms raise overhead for a shot, then return.
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.set_parallel(true)
	# Both arms raise straight up (rotate backward around X)
	_arm_tween.tween_property(_left_arm_pivot, "rotation:x", -2.8, 0.2)
	_arm_tween.tween_property(_right_arm_pivot, "rotation:x", -2.8, 0.2)
	_arm_tween.set_parallel(false)
	# Hold at top briefly
	_arm_tween.tween_interval(0.3)
	# Return to rest
	_arm_tween.set_parallel(true)
	_arm_tween.tween_property(_left_arm_pivot, "rotation:x", 0.0, 0.3)
	_arm_tween.tween_property(_right_arm_pivot, "rotation:x", 0.0, 0.3)

func _play_pass_animation() -> void:
	## Arms extend forward for a pass, then return.
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.set_parallel(true)
	# Both arms push forward (rotate forward around X)
	_arm_tween.tween_property(_left_arm_pivot, "rotation:x", -1.5, 0.15)
	_arm_tween.tween_property(_right_arm_pivot, "rotation:x", -1.5, 0.15)
	_arm_tween.set_parallel(false)
	# Snap back
	_arm_tween.tween_interval(0.15)
	_arm_tween.set_parallel(true)
	_arm_tween.tween_property(_left_arm_pivot, "rotation:x", 0.0, 0.2)
	_arm_tween.tween_property(_right_arm_pivot, "rotation:x", 0.0, 0.2)

func _physics_process(delta: float) -> void:
	# Frozen — no movement or actions
	if frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# Timers
	if tackle_cooldown > 0:
		tackle_cooldown -= delta
	
	# Buff timer and animation
	if _buff_indicator_mesh and _buff_indicator_mesh.visible:
		_buff_indicator_mesh.rotation.y += delta * 2.0
		var pulse = (sin(Time.get_ticks_msec() / 150.0) + 1.0) / 2.0
		_buff_indicator_mat.emission_energy_multiplier = 1.0 + pulse * 2.0
		
	if buff_timer > 0:
		buff_timer -= delta
		if buff_timer <= 0:
			_expire_buff()
	
	match current_state:
		State.IDLE, State.RUNNING, State.SPRINTING:
			_process_movement(delta)
			_process_actions()
		State.TACKLING:
			_process_tackle(delta)
		State.KNOCKED_DOWN:
			_process_knockdown(delta)
		State.SHOOTING:
			_process_movement(delta)
		State.PASSING:
			_process_movement(delta)
		State.CELEBRATING:
			celebrate_timer -= delta
			if celebrate_timer <= 0:
				current_state = State.IDLE
			# Keep floor contact while celebrating
			if not is_on_floor():
				velocity.y -= 20.0 * delta
			move_and_slide()
	
	# Update facing
	if input_aim.length() > 0.1:
		aim_direction = Vector3(input_aim.x, 0, input_aim.y).normalized()
	if input_move.length() > 0.1:
		facing_direction = Vector3(input_move.x, 0, input_move.y).normalized()
	
	# Rotate body to face direction (visor/shoulders will follow)
	var look_dir = aim_direction if input_aim.length() > 0.1 else facing_direction
	if look_dir.length() > 0.1:
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.15)
	
	# Ball follow
	if has_ball and held_ball:
		var ball_offset = facing_direction * 0.8 + Vector3(0, 0.8, 0)
		held_ball.global_position = global_position + ball_offset
		held_ball.linear_velocity = Vector3.ZERO
		held_ball.angular_velocity = Vector3.ZERO
	
	# --- Floor safety: prevent falling through the court ---
	if global_position.y < -1.0:
		global_position.y = 0.5
		velocity.y = 0

func _process_movement(delta: float) -> void:
	var speed = sprint_speed if input_sprint else move_speed
	var move_dir = Vector3(input_move.x, 0, input_move.y)
	
	if move_dir.length() > 0.1:
		velocity.x = move_dir.normalized().x * speed
		velocity.z = move_dir.normalized().z * speed
		current_state = State.SPRINTING if input_sprint else State.RUNNING
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 10)
		if current_state in [State.RUNNING, State.SPRINTING]:
			current_state = State.IDLE
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	# Jump (used during tip-off or just for fun)
	if input_jump and is_on_floor():
		velocity.y = jump_force
		input_jump = false
	
	move_and_slide()
	
	# --- Slide around other players instead of stopping dead ---
	# After move_and_slide, check if we collided with another player
	# and push our remaining velocity along the collision tangent
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is CharacterBody3D and collider.is_in_group("players"):
			var normal = col.get_normal()
			normal.y = 0
			if normal.length() > 0.01 and move_dir.length() > 0.1:
				# Project desired movement onto the tangent plane of the collision
				var tangent = move_dir.normalized() - normal.normalized() * move_dir.normalized().dot(normal.normalized())
				if tangent.length() > 0.1:
					# Apply slide velocity (slower when rubbing against a player)
					var slide_speed = speed * 0.55
					velocity.x = tangent.normalized().x * slide_speed
					velocity.z = tangent.normalized().z * slide_speed
					move_and_slide()
					break

func _process_actions() -> void:
	if input_shoot and has_ball:
		do_shoot()
		input_shoot = false
	elif input_pass and has_ball:
		do_pass()
		input_pass = false
	elif input_call_pass and not has_ball:
		call_for_pass.emit(self)
		input_call_pass = false
	elif input_tackle and not has_ball and tackle_cooldown <= 0:
		do_tackle()
		input_tackle = false
	
	# Clear stale buffered inputs that couldn't be consumed
	# (e.g. pressed shoot but lost the ball before it fired)
	if not has_ball:
		input_shoot = false
		input_pass = false
	if has_ball:
		input_tackle = false
		input_call_pass = false

func do_shoot() -> void:
	if not has_ball or held_ball == null:
		return
	current_state = State.SHOOTING
	_play_shoot_animation()
	var game_mgr = _get_game_manager()
	var target_hoop = game_mgr.get_target_hoop(team_index) if game_mgr else Vector3(0, 3.0, 14.0)
	
	# --- Check if facing the hoop; if not, do a turnaround ---
	var to_hoop_flat = Vector3(target_hoop.x - global_position.x, 0, target_hoop.z - global_position.z).normalized()
	var facing_dot = facing_direction.normalized().dot(to_hoop_flat)
	
	if facing_dot < 0.3:
		# Not facing the hoop — quick turnaround spin
		var target_angle = atan2(to_hoop_flat.x, to_hoop_flat.z)
		var spin_tween = create_tween()
		spin_tween.tween_property(self, "rotation:y", target_angle, 0.2)
		facing_direction = to_hoop_flat
		await spin_tween.finished
	
	# --- Calculate shot percentage ---
	var shot_chance = _calculate_shot_percentage(target_hoop)
	var roll = randf() * 100.0
	var made_shot = roll <= shot_chance
	
	var to_hoop = target_hoop - global_position
	var dist = to_hoop.length()
	
	# Rim center (offset toward center court from backboard)
	var rim_z_offset = 0.6 if target_hoop.z < 0 else -0.6
	var rim_center = target_hoop + Vector3(0, -0.1, rim_z_offset)
	
	# Release the ball
	var ball_ref = held_ball
	_release_ball()
	held_ball = null
	
	if ball_ref == null:
		current_state = State.IDLE
		input_shoot = false
		return
	
	if made_shot:
		# === MADE SHOT — Perfect tween arc, bypasses physics ===
		# Target slightly ABOVE the rim so ball drops down through it
		var above_rim = rim_center + Vector3(0, 0.5, 0)
		_animate_perfect_shot(ball_ref, ball_ref.global_position, above_rim, dist)
	else:
		# === MISS — Physics-based launch toward rim with offset ===
		var miss_offset = Vector3(randf_range(-1.5, 1.5), randf_range(-0.3, 0.5), randf_range(-1.0, 1.0))
		var miss_target = rim_center + miss_offset
		var launch_vel = _calc_launch_velocity(ball_ref.global_position, miss_target, dist)
		ball_ref.linear_velocity = launch_vel
		ball_ref._was_shot = false
	
	current_state = State.IDLE
	input_shoot = false

func _animate_perfect_shot(ball_ref: RigidBody3D, from: Vector3, to: Vector3, dist: float) -> void:
	## Animate the ball along a perfect parabolic arc using a tween.
	## The ball bypasses physics entirely, guaranteeing a clean swish.
	
	# Mark as shot
	ball_ref._was_shot = true
	ball_ref.last_shooter_team = team_index
	ball_ref._shot_origin = global_position  # Record where shot was taken for 3pt detection
	
	# Disable physics AND collision on the ball during flight
	ball_ref.freeze = true
	var saved_layer = ball_ref.collision_layer
	var saved_mask = ball_ref.collision_mask
	ball_ref.collision_layer = 0
	ball_ref.collision_mask = 0
	
	# Arc parameters
	var flight_time = clampf(dist * 0.07, 0.5, 1.2)  # Faster for close, slower for far
	var peak_height = clampf(dist * 0.3, 3.0, 7.0)    # Higher arc for longer shots
	
	# Use a tween with a custom method to interpolate along a parabolic path
	var tween = get_tree().create_tween()
	tween.tween_method(
		func(t: float):
			# Clean parabolic arc: linear X/Z interpolation, parabolic Y
			var pos = from.lerp(to, t)
			var base_y = lerp(from.y, to.y, t)
			pos.y = base_y + 4.0 * peak_height * t * (1.0 - t)
			ball_ref.global_position = pos
			ball_ref.linear_velocity = Vector3.ZERO
			ball_ref.angular_velocity = Vector3.ZERO,
		0.0, 1.0, flight_time
	)
	
	# When tween finishes, re-enable physics and collision, let ball drop through the net
	tween.finished.connect(func():
		ball_ref.freeze = false
		ball_ref.collision_layer = saved_layer
		ball_ref.collision_mask = saved_mask
		ball_ref.linear_velocity = Vector3(0, -2.0, 0)  # Gentle drop through net
		ball_ref.angular_velocity = Vector3.ZERO
	)

func _calculate_shot_percentage(hoop_pos: Vector3) -> float:
	var dist = global_position.distance_to(hoop_pos)
	
	# --- Human player: near-100% from everywhere ---
	if is_human:
		return 99.0
	
	# --- CPU: distance-based with pressure ---
	var base_pct: float
	if dist < 4.0:
		base_pct = 65.0     # Close range
	elif dist < 8.0:
		base_pct = 45.0     # Mid range
	elif dist < 12.0:
		base_pct = 30.0     # Three-point range
	else:
		base_pct = 15.0     # Deep / half court
	
	# Defensive pressure
	var pressure_penalty: float = 0.0
	for p in get_tree().get_nodes_in_group("players"):
		if p == self:
			continue
		if "team_index" in p and p.team_index != team_index:
			var p_dist = global_position.distance_to(p.global_position)
			if p_dist < 2.0:
				pressure_penalty += 20.0
			elif p_dist < 4.0:
				pressure_penalty += 10.0
	
	var final_pct = max(base_pct - pressure_penalty, 5.0)
	print("[Shot] %s | Dist: %.1f | Base: %.0f%% | Pressure: -%.0f%% | Final: %.0f%%" % [
		"HUMAN" if is_human else "CPU", dist, base_pct, pressure_penalty, final_pct])
	return final_pct

func _calc_launch_velocity(from: Vector3, to: Vector3, dist: float) -> Vector3:
	## Simple launch velocity for missed shots (physics-based).
	var gravity: float = 20.0
	var peak_height = clampf(dist * 0.25, 2.0, 5.0)
	var peak_y = to.y + peak_height
	var h_up = max(peak_y - from.y, 1.0)
	var h_down = max(peak_y - to.y, 0.5)
	var vy = sqrt(2.0 * gravity * h_up)
	var t_up = vy / gravity
	var t_down = sqrt(2.0 * h_down / gravity)
	var total_time = t_up + t_down
	var vx = (to.x - from.x) / total_time
	var vz = (to.z - from.z) / total_time
	return Vector3(vx, vy, vz)

func do_pass() -> void:
	if not has_ball or held_ball == null:
		return
	current_state = State.PASSING
	_play_pass_animation()
	
	# Find the best teammate to pass to based on aim direction
	var target_teammate = _find_pass_target()
	var pass_dir: Vector3
	
	if target_teammate:
		# Pass directly toward the chosen teammate, leading them slightly
		var to_mate = (target_teammate.global_position - global_position)
		to_mate.y = 0
		pass_dir = to_mate.normalized()
	else:
		# No teammate found — just throw in aim direction
		if aim_direction.length() > 0.1:
			pass_dir = aim_direction.normalized()
		else:
			pass_dir = facing_direction.normalized()
	
	pass_dir.y = 0.1  # Slight upward angle
	pass_dir = pass_dir.normalized()
	
	_release_ball()
	held_ball = null
	
	var ball_node = get_tree().get_nodes_in_group("ball")
	if ball_node.size() > 0:
		ball_node[0].apply_impulse(pass_dir * pass_power)
	
	current_state = State.IDLE
	input_pass = false

func pass_to_player(target: CharacterBody3D) -> void:
	## Passes directly to the target player with distance-scaled power.
	if not has_ball or held_ball == null:
		return
	current_state = State.PASSING
	_play_pass_animation()
	var to_target = (target.global_position - global_position)
	var pass_dist = to_target.length()
	to_target.y = 0
	var pass_dir = to_target.normalized()
	# More upward angle for longer passes
	pass_dir.y = clampf(pass_dist * 0.03, 0.1, 0.35)
	pass_dir = pass_dir.normalized()
	
	_release_ball()
	held_ball = null
	
	var ball_node = get_tree().get_nodes_in_group("ball")
	if ball_node.size() > 0:
		var b = ball_node[0]
		# Zero residual velocity before applying pass impulse
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
		# Prevent immediate OOB re-trigger when passing from out of bounds
		b._oob_cooldown = 3.0
		# Scale power: at least pass_power, more for longer distances
		var power = max(pass_power, pass_dist * 3.0)
		b.apply_impulse(pass_dir * power)
	
	current_state = State.IDLE

func _find_pass_target() -> CharacterBody3D:
	## Picks the teammate closest to the current aim direction.
	## If no aim input, picks the nearest teammate.
	var teammates: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		if p != self and "team_index" in p and p.team_index == team_index:
			if p.current_state != State.KNOCKED_DOWN:
				teammates.append(p)
	
	if teammates.is_empty():
		return null
	
	# If we have aim input, pick the teammate closest to the aim direction
	var use_aim = aim_direction.length() > 0.1
	var best_mate: CharacterBody3D = null
	var best_score: float = -1.0
	
	for mate in teammates:
		var to_mate = (mate.global_position - global_position)
		to_mate.y = 0
		var dist = to_mate.length()
		if dist < 0.5:
			continue
		
		if use_aim:
			# Dot product: 1.0 = perfectly aligned, -1.0 = opposite direction
			var dot = to_mate.normalized().dot(aim_direction.normalized())
			# Bias toward alignment but penalize very far teammates slightly
			var score = dot - (dist * 0.01)
			if score > best_score:
				best_score = score
				best_mate = mate
		else:
			# No aim — just pick nearest
			var score = -dist
			if score > best_score:
				best_score = score
				best_mate = mate
	
	return best_mate

func do_tackle() -> void:
	current_state = State.TACKLING
	tackle_cooldown = tackle_cooldown_duration
	# Lunge forward
	var lunge_dir = aim_direction if aim_direction.length() > 0.1 else facing_direction
	velocity = lunge_dir * tackle_force
	
	# Check for hits
	if tackle_area:
		for body in tackle_area.get_overlapping_bodies():
			if body is CharacterBody3D and body != self and body.is_in_group("players"):
				if "team_index" in body and body.team_index != team_index:
					_hit_player(body)

func _hit_player(target: CharacterBody3D) -> void:
	if target.has_method("receive_tackle"):
		target.receive_tackle(self, facing_direction)

func receive_tackle(attacker: CharacterBody3D, direction: Vector3) -> void:
	current_state = State.KNOCKED_DOWN
	knockdown_timer = knockdown_duration / strength
	velocity = direction * 8.0  # Stronger knockback
	velocity.y = 3.0  # Pop up slightly
	if has_ball:
		# Fumble — release ball with some random force
		_release_ball()
		var ball_nodes = get_tree().get_nodes_in_group("ball")
		if ball_nodes.size() > 0:
			var fumble_dir = Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)).normalized()
			ball_nodes[0].apply_impulse(fumble_dir * 5.0)
		
		# Record steal for attacker
		if attacker != null and "team_index" in attacker and "roster_index" in attacker:
			if attacker.team_index != team_index:
				var gm = _get_game_manager()
				if gm and gm.has_method("record_stat"):
					gm.record_stat(attacker.team_index, attacker.roster_index, "steals")
	was_tackled.emit()
	# Visual: flatten mesh to show player is down
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.3, 0.3, 1.3), 0.15)
		tween.tween_interval(knockdown_timer - 0.3)
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.3)

func receive_hazard_hit(knockback_dir: Vector3, force: float, drop_ball: bool = true) -> void:
	## Called when a hazard hits this player.
	current_state = State.KNOCKED_DOWN
	knockdown_timer = knockdown_duration / strength
	velocity = knockback_dir.normalized() * force
	velocity.y = max(velocity.y, force * 0.5)  # Always launch upward
	
	if drop_ball and has_ball:
		_release_ball()
		var ball_nodes = get_tree().get_nodes_in_group("ball")
		if ball_nodes.size() > 0:
			var fumble_dir = Vector3(randf_range(-1, 1), 0.8, randf_range(-1, 1)).normalized()
			ball_nodes[0].apply_impulse(fumble_dir * 6.0)
	
	# Visual knockdown
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.3, 0.3, 1.3), 0.15)
		tween.tween_interval(knockdown_timer - 0.3)
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.3)

func apply_buff(buff_type: String, duration: float = 8.0) -> void:
	## Apply a power-up buff. Reverts previous buff if any.
	if active_buff != "":
		_expire_buff()
	
	# Store base stats on first buff
	if _base_move_speed == 0:
		_base_move_speed = move_speed
		_base_sprint_speed = sprint_speed
		_base_tackle_force = tackle_force
		_base_tackle_range = tackle_range
	
	active_buff = buff_type
	buff_timer = duration
	
	if _buff_indicator_mesh and _buff_indicator_mat:
		_buff_indicator_mesh.visible = true
	
	match buff_type:
		"speed":
			move_speed = _base_move_speed * 1.5
			sprint_speed = _base_sprint_speed * 1.5
			if _buff_indicator_mat:
				_buff_indicator_mat.albedo_color = Color(0.1, 1.0, 0.3, 0.6)
				_buff_indicator_mat.emission = Color(0.1, 1.0, 0.3)
		"accuracy":
			# Accuracy checked in _calculate_shot_percentage
			if _buff_indicator_mat:
				_buff_indicator_mat.albedo_color = Color(1.0, 0.8, 0.1, 0.6)
				_buff_indicator_mat.emission = Color(1.0, 0.8, 0.1)
		"tackle":
			tackle_force = _base_tackle_force * 2.0
			tackle_range = _base_tackle_range * 1.5
			if _buff_indicator_mat:
				_buff_indicator_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
				_buff_indicator_mat.emission = Color(1.0, 0.2, 0.2)
		"freeze":
			# Slows down the player
			move_speed = _base_move_speed * 0.5
			sprint_speed = _base_sprint_speed * 0.5
			if _buff_indicator_mat:
				_buff_indicator_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.6) # Icy cyan
				_buff_indicator_mat.emission = Color(0.3, 0.8, 1.0)

func _expire_buff() -> void:
	if _base_move_speed > 0:
		move_speed = _base_move_speed
		sprint_speed = _base_sprint_speed
		tackle_force = _base_tackle_force
		tackle_range = _base_tackle_range
	active_buff = ""
	buff_timer = 0.0
	
	if _buff_indicator_mesh:
		_buff_indicator_mesh.visible = false

func _process_tackle(delta: float) -> void:
	# Decelerate during tackle
	velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()
	if velocity.length() < 1.0:
		current_state = State.IDLE

func _process_knockdown(delta: float) -> void:
	knockdown_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()
	if knockdown_timer <= 0:
		current_state = State.IDLE

func pickup_ball(ball_body: RigidBody3D) -> void:
	if has_ball or current_state == State.KNOCKED_DOWN or frozen:
		return
	has_ball = true
	held_ball = ball_body
	
	# Check for rebound before resetting was_shot
	if ball_body.get("_was_shot") == true:
		var gm = _get_game_manager()
		if gm and gm.has_method("record_stat"):
			gm.record_stat(team_index, roster_index, "rebounds")
			
	ball_body.linear_velocity = Vector3.ZERO
	ball_body.angular_velocity = Vector3.ZERO
	if ball_body.has_method("set_holder"):
		ball_body.set_holder(self)
	got_ball.emit()

func _release_ball() -> void:
	has_ball = false
	if held_ball:
		held_ball.freeze = false  # Always unfreeze when releasing
		if held_ball.has_method("release"):
			held_ball.release(self, team_index)
	lost_ball.emit()

func _on_ball_entered(body: Node3D) -> void:
	if body.is_in_group("ball") and not has_ball and current_state != State.KNOCKED_DOWN and not frozen:
		# Check if any other player already has the ball
		var ball_script = body as RigidBody3D
		if ball_script and ball_script.has_method("is_held") and ball_script.is_held():
			return
		pickup_ball(body)

func _get_game_manager() -> Node:
	return get_tree().get_first_node_in_group("game_manager")

func get_aim_direction_3d() -> Vector3:
	return aim_direction
