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
enum State { IDLE, RUNNING, SPRINTING, SHOOTING, PASSING, TACKLING, PUNCHING, KNOCKED_DOWN, CELEBRATING }
var current_state: State = State.IDLE
var has_ball: bool = false
var facing_direction: Vector3 = Vector3.FORWARD
var aim_direction: Vector3 = Vector3.FORWARD
var knockdown_timer: float = 0.0
var knockdown_duration: float = 2.0
var tackle_cooldown: float = 0.0
var tackle_cooldown_duration: float = 1.0
var punch_cooldown: float = 0.0
var punch_cooldown_duration: float = 0.65
var punch_range: float = 1.8
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
var input_punch: bool = false
var input_call_pass: bool = false  # Press pass when you don't have the ball
var input_jump: bool = false
var pickup_cooldown: float = 0.0

# --- References ---
var held_ball: RigidBody3D = null
@onready var mesh: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape
@onready var tackle_area: Area3D = $TackleArea
@onready var ball_pickup_area: Area3D = $BallPickupArea
@onready var floating_text: Label3D = $FloatingText
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
	
	# Tackle Impact Audio
	_hit_sound_player = AudioStreamPlayer3D.new()
	_hit_sound_player.stream = load("res://assets/sounds/hitHurt.wav")
	_hit_sound_player.bus = "SFX"
	add_child(_hit_sound_player)

@export var jersey_number: int = 0  # Set by game_manager during team setup
@export var body_height: float = 1.0   # Scale multiplier — 0.82 short … 1.18 tall
@export var body_build: float  = 1.0   # Scale multiplier — 0.85 lean  … 1.18 heavy
@export var skin_tone: Color   = Color(0.85, 0.65, 0.45)
@export var shot_skill: float  = 50.0  # 0-99, used in CPU shot-accuracy formula
var team_logo: Texture2D = null

# Arm pivot references (for animation)
var _left_arm_pivot: Node3D = null
var _right_arm_pivot: Node3D = null
var _left_elbow: Node3D = null
var _right_elbow: Node3D = null
var _arm_tween: Tween = null
var _model_tween: Tween = null
var custom_team_color: Color = Color(0, 0, 0, 0) # If alpha > 0, overrides team_index color

var _buff_indicator_mesh: MeshInstance3D = null
var _buff_indicator_mat: StandardMaterial3D = null

# Procedural animation nodes
var _model_root: Node3D = null
var _torso: MeshInstance3D = null
var _head: MeshInstance3D = null
var _leg_pivot_l: Node3D = null
var _leg_pivot_r: Node3D = null
var _foot_l: MeshInstance3D = null
var _foot_r: MeshInstance3D = null

var _anim_time: float = 0.0
var _dribble_time: float = 0.0
var _hit_sound_player: AudioStreamPlayer3D = null

func _setup_visuals() -> void:
	if mesh:
		mesh.visible = false

	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	add_child(_model_root)

	var color = team_colors[team_index] if team_index < team_colors.size() else Color.WHITE
	if custom_team_color.a > 0.0:
		color = custom_team_color

	team_color_material.albedo_color = color
	team_color_material.emission_enabled = true
	team_color_material.emission = color * 0.3
	team_color_material.metallic = 0.4
	team_color_material.roughness = 0.6

	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = skin_tone
	skin_mat.roughness = 0.8

	# --- Torso ---
	_torso = MeshInstance3D.new()
	_torso.name = "Torso"
	var torso_mesh = BoxMesh.new()
	torso_mesh.size = Vector3(0.5, 0.7, 0.3)
	_torso.mesh = torso_mesh
	_torso.material_override = team_color_material
	_torso.position = Vector3(0, 0.9, 0)
	_model_root.add_child(_torso)

	# --- Shorts (darker team color, hangs below jersey) ---
	var shorts = MeshInstance3D.new()
	shorts.name = "Shorts"
	var shorts_mesh = BoxMesh.new()
	shorts_mesh.size = Vector3(0.54, 0.26, 0.32)
	shorts.mesh = shorts_mesh
	var shorts_mat = StandardMaterial3D.new()
	shorts_mat.albedo_color = color.darkened(0.35)
	shorts_mat.roughness = 0.8
	shorts.material_override = shorts_mat
	shorts.position = Vector3(0, -0.38, 0)
	_torso.add_child(shorts)

	# --- Neck ---
	var neck = MeshInstance3D.new()
	neck.name = "Neck"
	var neck_mesh = CylinderMesh.new()
	neck_mesh.top_radius = 0.07
	neck_mesh.bottom_radius = 0.08
	neck_mesh.height = 0.10
	neck.mesh = neck_mesh
	neck.material_override = skin_mat
	neck.position = Vector3(0, 0.40, 0)
	_torso.add_child(neck)

	# --- Head (sphere) ---
	_head = MeshInstance3D.new()
	_head.name = "Head"
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	_head.mesh = head_mesh
	_head.material_override = skin_mat
	_head.position = Vector3(0, 0.64, 0)
	_torso.add_child(_head)

	# --- Accent color for visor ---
	var accent_color = Color(0.0, 1.0, 1.0) if team_index == 0 else Color(1.0, 1.0, 0.0)
	var accent_mat = StandardMaterial3D.new()
	accent_mat.albedo_color = accent_color
	accent_mat.emission_enabled = true
	accent_mat.emission = accent_color
	accent_mat.emission_energy_multiplier = 3.0

	var visor = MeshInstance3D.new()
	visor.name = "Visor"
	var visor_mesh = BoxMesh.new()
	visor_mesh.size = Vector3(0.28, 0.07, 0.05)
	visor.mesh = visor_mesh
	visor.material_override = accent_mat
	visor.position = Vector3(0, 0.04, -0.19)
	_head.add_child(visor)

	# --- Jersey side stripes ---
	var stripe_mat = StandardMaterial3D.new()
	stripe_mat.albedo_color = color.lightened(0.38)
	stripe_mat.roughness = 0.65
	stripe_mat.metallic = 0.2
	for side in [-1, 1]:
		var sf = MeshInstance3D.new()
		sf.name = "Stripe_Front_%d" % (side + 2)
		var sfm = BoxMesh.new()
		sfm.size = Vector3(0.055, 0.72, 0.013)
		sf.mesh = sfm
		sf.material_override = stripe_mat
		sf.position = Vector3(side * 0.195, 0, 0.158)
		_torso.add_child(sf)
		var sb = MeshInstance3D.new()
		sb.name = "Stripe_Back_%d" % (side + 2)
		var sbm = BoxMesh.new()
		sbm.size = Vector3(0.055, 0.72, 0.013)
		sb.mesh = sbm
		sb.material_override = stripe_mat
		sb.position = Vector3(side * 0.195, 0, -0.158)
		_torso.add_child(sb)
		var ss = MeshInstance3D.new()
		ss.name = "Stripe_Side_%d" % (side + 2)
		var ssm = BoxMesh.new()
		ssm.size = Vector3(0.013, 0.72, 0.304)
		ss.mesh = ssm
		ss.material_override = stripe_mat
		ss.position = Vector3(side * 0.258, 0, 0)
		_torso.add_child(ss)

	# --- Arms (two segments with elbow joint) ---
	for side in [-1, 1]:
		var arm_pivot = Node3D.new()
		arm_pivot.name = "ArmPivot_L" if side == -1 else "ArmPivot_R"
		arm_pivot.position = Vector3(side * 0.30, 0.25, 0)
		_torso.add_child(arm_pivot)

		if side == -1: _left_arm_pivot = arm_pivot
		else: _right_arm_pivot = arm_pivot

		# Shoulder cap sphere at the pivot point
		var shoulder_cap = MeshInstance3D.new()
		shoulder_cap.name = "ShoulderCap"
		var scm = SphereMesh.new()
		scm.radius = 0.09
		scm.height = 0.18
		shoulder_cap.mesh = scm
		shoulder_cap.material_override = team_color_material
		arm_pivot.add_child(shoulder_cap)

		# Upper arm
		var upper_arm = MeshInstance3D.new()
		upper_arm.name = "UpperArm"
		var uam = CylinderMesh.new()
		uam.top_radius = 0.07
		uam.bottom_radius = 0.06
		uam.height = 0.30
		upper_arm.mesh = uam
		upper_arm.material_override = skin_mat
		upper_arm.position = Vector3(0, -0.15, 0)
		arm_pivot.add_child(upper_arm)

		# Elbow pivot at the bottom of the upper arm — slight natural bend at rest
		var elbow_pivot = Node3D.new()
		elbow_pivot.name = "ElbowPivot"
		elbow_pivot.position = Vector3(0, -0.30, 0)
		elbow_pivot.rotation.x = 0.15
		arm_pivot.add_child(elbow_pivot)

		if side == -1: _left_elbow = elbow_pivot
		else: _right_elbow = elbow_pivot

		# Forearm
		var forearm = MeshInstance3D.new()
		forearm.name = "Forearm"
		var fam = CylinderMesh.new()
		fam.top_radius = 0.06
		fam.bottom_radius = 0.05
		fam.height = 0.28
		forearm.mesh = fam
		forearm.material_override = skin_mat
		forearm.position = Vector3(0, -0.14, 0)
		elbow_pivot.add_child(forearm)

		# Hand
		var hand = MeshInstance3D.new()
		var hm = SphereMesh.new()
		hm.radius = 0.06
		hm.height = 0.12
		hand.mesh = hm
		hand.material_override = skin_mat
		hand.position = Vector3(0, -0.14, 0)
		forearm.add_child(hand)

	# --- Legs (two segments with knee joint) ---
	for side in [-1, 1]:
		var leg_pivot = Node3D.new()
		leg_pivot.name = "LegPivot_L" if side == -1 else "LegPivot_R"
		leg_pivot.position = Vector3(side * 0.15, -0.35, 0)
		_torso.add_child(leg_pivot)

		if side == -1: _leg_pivot_l = leg_pivot
		else: _leg_pivot_r = leg_pivot

		# Thigh
		var thigh = MeshInstance3D.new()
		thigh.name = "Thigh"
		var thm = CylinderMesh.new()
		thm.top_radius = 0.10
		thm.bottom_radius = 0.08
		thm.height = 0.30
		thigh.mesh = thm
		thigh.material_override = skin_mat
		thigh.position = Vector3(0, -0.15, 0)
		leg_pivot.add_child(thigh)

		# Knee pivot at the bottom of the thigh
		var knee_pivot = Node3D.new()
		knee_pivot.name = "KneePivot"
		knee_pivot.position = Vector3(0, -0.30, 0)
		leg_pivot.add_child(knee_pivot)

		# Shin
		var shin = MeshInstance3D.new()
		shin.name = "Shin"
		var shm = CylinderMesh.new()
		shm.top_radius = 0.08
		shm.bottom_radius = 0.06
		shm.height = 0.30
		shin.mesh = shm
		shin.material_override = skin_mat
		shin.position = Vector3(0, -0.15, 0)
		knee_pivot.add_child(shin)

		# Sneaker
		var foot = MeshInstance3D.new()
		foot.name = "Foot"
		var fm = BoxMesh.new()
		fm.size = Vector3(0.12, 0.08, 0.22)
		foot.mesh = fm
		var foot_mat = StandardMaterial3D.new()
		foot_mat.albedo_color = Color(0.1, 0.1, 0.1)
		foot.material_override = foot_mat
		foot.position = Vector3(0, -0.15, -0.05)
		shin.add_child(foot)

	# Body scale (height × build) applied to the whole model root
	_model_root.scale = Vector3(body_build, body_height, body_build)

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

	# --- Buff Indicator Ring ---
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
	_buff_indicator_mesh.position = Vector3(0, 0.06, 0)
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

func _play_punch_animation() -> void:
	## Phase 1 — Wind-up: upper arm pulls back and up, elbow bends sharply (fist near ear).
	## Phase 2 — Pitch: arm whips forward, elbow extends through on contact.
	## Phase 3 — Return to rest.
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()

	# Wind-up (0.15s): arm pulls back and up, elbow flares, left arm rises as guard
	_arm_tween.set_parallel(true)
	_arm_tween.tween_property(_right_arm_pivot, "rotation:x", -2.0, 0.15)  # back and up
	_arm_tween.tween_property(_right_arm_pivot, "rotation:z", -0.3, 0.15)  # elbow flares out
	if _right_elbow:
		_arm_tween.tween_property(_right_elbow, "rotation:x", 0.9, 0.15)   # fist folds toward head
	_arm_tween.tween_property(_left_arm_pivot, "rotation:x", 0.3, 0.15)   # guard: arm slightly forward
	_arm_tween.set_parallel(false)

	# Pitch (0.09s): arm whips hard forward, elbow snaps through to full extension
	_arm_tween.set_parallel(true)
	_arm_tween.tween_property(_right_arm_pivot, "rotation:x", 2.2, 0.09)   # forward
	_arm_tween.tween_property(_right_arm_pivot, "rotation:z", 0.0, 0.09)
	if _right_elbow:
		_arm_tween.tween_property(_right_elbow, "rotation:x", -0.1, 0.09)  # full extension
	_arm_tween.tween_property(_left_arm_pivot, "rotation:x", -0.4, 0.09)  # pull back as counterweight
	_arm_tween.set_parallel(false)

	# Hold at full extension briefly
	_arm_tween.tween_interval(0.05)

	# Return (0.22s)
	_arm_tween.set_parallel(true)
	_arm_tween.tween_property(_right_arm_pivot, "rotation:x", 0.0, 0.22)
	_arm_tween.tween_property(_right_arm_pivot, "rotation:z", 0.0, 0.22)
	if _right_elbow:
		_arm_tween.tween_property(_right_elbow, "rotation:x", 0.15, 0.22)
	_arm_tween.tween_property(_left_arm_pivot, "rotation:x", 0.0, 0.22)

func _physics_process(delta: float) -> void:
	# Frozen — no movement or actions
	if frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# Timers
	if tackle_cooldown > 0:
		tackle_cooldown -= delta
	if punch_cooldown > 0:
		punch_cooldown -= delta
	
	if pickup_cooldown > 0:
		pickup_cooldown -= delta
		
	# Continuous check for missed ball pickup (Area3D signals can drop during state/layer changes)
	if not has_ball and current_state != State.KNOCKED_DOWN and not frozen and pickup_cooldown <= 0 and ball_pickup_area:
		for body in ball_pickup_area.get_overlapping_bodies():
			if body.is_in_group("ball"):
				var ball_script = body as RigidBody3D
				if ball_script and ball_script.has_method("is_held") and not ball_script.is_held():
					pickup_ball(body)
					break
	
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
		State.PUNCHING:
			_process_movement(delta)  # Can still move while punching
		State.TACKLING:
			_process_tackle(delta)
		State.KNOCKED_DOWN:
			_process_knockdown(delta)
		State.SHOOTING:
			_process_movement(delta)
		State.PASSING:
			_process_movement(delta)
		State.CELEBRATING:
			_update_animations(delta)
			celebrate_timer -= delta
			if celebrate_timer <= 0:
				current_state = State.IDLE
			# Keep floor contact while celebrating
			if not is_on_floor():
				velocity.y -= 20.0 * delta
			move_and_slide()
	
	_update_animations(delta)
	
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
		# Procedural dribble offset
		var dribble_y = 0.0
		var dribble_fwd = 0.8
		var dribble_side = 0.4
		
		var freq = 10.0 if current_state in [State.RUNNING, State.SPRINTING] else 5.0
		var amp = 0.5
		var bounce = abs(sin(_dribble_time * freq))
		dribble_y = 0.6 + bounce * amp
		
		# Move ball slightly side to side
		var side_swing = sin(_dribble_time * freq * 0.5) * 0.2
		
		var right_vec = facing_direction.cross(Vector3.UP).normalized()
		var ball_offset = facing_direction * dribble_fwd + Vector3(0, dribble_y, 0) + right_vec * (dribble_side + side_swing)
		
		# Safety check: Ghost possession
		# If the player thinks they have the ball, but the ball thinks someone else has it,
		# or the reference is gone, clear local state immediately.
		if not is_instance_valid(held_ball) or held_ball.holder != self:
			_clear_possession_state()
		else:
			held_ball.global_position = global_position + ball_offset
			held_ball.linear_velocity = Vector3.ZERO
			held_ball.angular_velocity = Vector3.ZERO
			
			# Rotate ball slightly as if dribbling
			held_ball.rotation.x += delta * 15.0
	
	# --- Floor safety: prevent falling through the court ---
	if global_position.y < -1.0:
		global_position.y = 0.5
		velocity.y = 0

func _update_animations(delta: float) -> void:
	if not _model_root: return
	
	_anim_time += delta
	
	# Skip procedural animations during dive/knockdown
	if current_state in [State.TACKLING, State.KNOCKED_DOWN]:
		# Still allow arm follow if we have the ball (though we shouldn't during tackle)
		if has_ball:
			_dribble_time += delta
			_right_arm_pivot.rotation.x = 0.5
		return
	
	var horizontal_vel = Vector3(velocity.x, 0, velocity.z).length()
	var is_moving = horizontal_vel > 0.5
	
	if current_state == State.KNOCKED_DOWN:
		# Handled by tween in receive_tackle, but let's reset rotations
		_leg_pivot_l.rotation.x = 0
		_leg_pivot_r.rotation.x = 0
		return
		
	if is_moving:
		# Run cycle
		var speed_mult = clampf(horizontal_vel * 1.5, 5.0, 15.0)
		var cycle = _anim_time * speed_mult
		
		# Leg swing — cap backward swing so the upper leg doesn't hump upward
		# and obscure the jersey number on the back of the torso
		var leg_raw = sin(cycle) * 0.45
		_leg_pivot_l.rotation.x = clamp(leg_raw, -0.35, 0.45)
		_leg_pivot_r.rotation.x = clamp(-leg_raw, -0.35, 0.45)

		# Torso bob & lean
		_torso.position.y = 0.9 + abs(sin(cycle * 2.0)) * 0.08
		_torso.rotation.z = -sin(cycle) * 0.05 # Side to side lean
		_torso.rotation.x = 0.12 # Lean forward (reduced to keep jersey visible)
		
		# Arms swing in opposition to legs (if not shooting/passing)
		if current_state in [State.RUNNING, State.SPRINTING, State.IDLE]:
			_left_arm_pivot.rotation.x = -leg_raw * 0.8
			_right_arm_pivot.rotation.x = leg_raw * 0.8
	else:
		# Idle breathing bob
		var idle_cycle = _anim_time * 2.5
		_torso.position.y = lerp(_torso.position.y, 0.9 + sin(idle_cycle) * 0.03, 0.1)
		_torso.rotation.x = lerp_angle(_torso.rotation.x, 0.0, 0.1)
		_torso.rotation.z = lerp_angle(_torso.rotation.z, 0.0, 0.1)
		
		# Reset legs
		_leg_pivot_l.rotation.x = lerp_angle(_leg_pivot_l.rotation.x, 0.0, 0.1)
		_leg_pivot_r.rotation.x = lerp_angle(_leg_pivot_r.rotation.x, 0.0, 0.1)
		
		# Gentle arm sway
		if current_state == State.IDLE:
			_left_arm_pivot.rotation.x = lerp_angle(_left_arm_pivot.rotation.x, sin(idle_cycle) * 0.1, 0.1)
			_right_arm_pivot.rotation.x = lerp_angle(_right_arm_pivot.rotation.x, sin(idle_cycle) * 0.1, 0.1)
	
	if current_state == State.CELEBRATING:
		# Raise arms!
		_left_arm_pivot.rotation.x = -2.5
		_right_arm_pivot.rotation.x = -2.5
		# Jump logic? 
		_torso.position.y += 0.2 # Float a bit
		
	# --- Dribbling Arm Animation ---
	if has_ball:
		_dribble_time += delta
		# Force right arm to follow the ball
		var freq = 10.0 if current_state in [State.RUNNING, State.SPRINTING] else 5.0
		var bounce = abs(sin(_dribble_time * freq))
		# Simple rotation to make the hand reach down/up with the ball
		_right_arm_pivot.rotation.x = 0.5 - (bounce * 1.2)
		_right_arm_pivot.rotation.z = 0.4 # Reach out to the side
	else:
		_dribble_time = 0.0

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
	elif input_punch and punch_cooldown <= 0:
		do_punch()
		input_punch = false
	
	# Clear stale buffered inputs that couldn't be consumed
	# (e.g. pressed shoot but lost the ball before it fired)
	if not has_ball:
		input_shoot = false
		input_pass = false
	if has_ball:
		input_tackle = false
		input_call_pass = false
	# punch is always clearable — allowed with or without ball
	
	
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
	
	# Record attempt right away
	var is_three = false
	if game_mgr and game_mgr.has_method("is_three_pointer"):
		is_three = game_mgr.is_three_pointer(global_position, 0 if target_hoop.z < 0 else 1)
		
	if game_mgr and game_mgr.has_method("record_stat"):
		game_mgr.record_stat(team_index, roster_index, "fga", 1)
		if is_three:
			game_mgr.record_stat(team_index, roster_index, "tpa", 1)
	
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
		var rim_z_offset = 0.6 if target_hoop.z < 0 else -0.6
		var rim_center = target_hoop + Vector3(0, -0.1, rim_z_offset)
		var above_rim = rim_center + Vector3(0, 0.5, 0)
		# Determine which hoop team index this basket belongs to (0 = north/negative-Z, 1 = south/positive-Z)
		var hoop_team = 0 if target_hoop.z < 0 else 1
		_animate_perfect_shot(ball_ref, ball_ref.global_position, above_rim, dist, hoop_team)
	else:
		# === MISS — Physics-based launch toward rim with offset ===
		
		# Rim center need re-calc here since we removed it globally
		var rim_z_offset = 0.6 if target_hoop.z < 0 else -0.6
		var rim_center = target_hoop + Vector3(0, -0.1, rim_z_offset)
		
		var miss_offset = Vector3(randf_range(-1.5, 1.5), randf_range(-0.3, 0.5), randf_range(-1.0, 1.0))
		var miss_target = rim_center + miss_offset
		var launch_vel = _calc_launch_velocity(ball_ref.global_position, miss_target, dist)
		ball_ref.linear_velocity = launch_vel
		ball_ref._was_shot = false
	
	current_state = State.IDLE
	input_shoot = false

func _animate_perfect_shot(ball_ref: RigidBody3D, from: Vector3, to: Vector3, dist: float, hoop_team: int = 0) -> void:
	## Animate the ball along a perfect parabolic arc using a tween.
	## The ball bypasses physics entirely, guaranteeing a clean swish.
	## hoop_team: the basket's team index (0 = north hoop, 1 = south hoop).
	## Scoring is triggered directly here — NOT via the Area3D body_entered signal —
	## because the ball's collision is disabled during flight and re-enabled while the
	## ball is already inside the trigger zone, so body_entered would never fire.
	
	# Mark as shot — must be true so award_score guard passes
	ball_ref._was_shot = true
	ball_ref.last_shooter_team = team_index
	ball_ref.last_shooter = self
	ball_ref._shot_origin = global_position  # Record where shot was taken for 3pt detection
	
	# Disable physics AND collision on the ball during flight
	ball_ref.freeze = true
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
	
	# When tween finishes: re-enable physics, drop the ball through the net,
	# and directly trigger scoring (bypassing the unreliable Area3D signal).
	tween.finished.connect(func():
		ball_ref.freeze = false
		ball_ref.collision_layer = 4
		ball_ref.collision_mask = 1
		ball_ref.linear_velocity = Vector3(0, -2.0, 0)  # Gentle drop through net
		ball_ref.angular_velocity = Vector3.ZERO
		# Directly award the score — _was_shot is still true at this point
		ball_ref._on_hoop_entered(hoop_team)
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

	# Shot skill modifier: ±15% swing across the 10-99 stat range
	# A 99-shot player gains ~+14.8%, a 10-shot player loses ~-12%
	var shot_modifier: float = (shot_skill - 50.0) * 0.30

	var final_pct = maxf(base_pct + shot_modifier - pressure_penalty, 5.0)
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
		if input_aim.length() > 0.1:
			pass_dir = aim_direction.normalized()
		else:
			pass_dir = facing_direction.normalized()
	
	pass_dir.y = 0.1  # Slight upward angle
	pass_dir = pass_dir.normalized()
	
	var flat_dir = Vector3(pass_dir.x, 0, pass_dir.z).normalized()
	facing_direction = flat_dir
	aim_direction = flat_dir
	if held_ball:
		var ball_offset = flat_dir * 1.0 + Vector3(0, 0.8, 0)
		held_ball.global_position = global_position + ball_offset
	
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
	
	var flat_dir = Vector3(pass_dir.x, 0, pass_dir.z).normalized()
	facing_direction = flat_dir
	aim_direction = flat_dir
	if held_ball:
		var ball_offset = flat_dir * 1.0 + Vector3(0, 0.8, 0)
		held_ball.global_position = global_position + ball_offset
	
	_release_ball()
	held_ball = null
	
	var ball_node = get_tree().get_nodes_in_group("ball")
	if ball_node.size() > 0:
		var b = ball_node[0]
		# Zero residual velocity before applying pass impulse
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
		# Short grace so the ball doesn't trigger OOB at the exact release point
		b._oob_cooldown = 0.4
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
	var use_aim = input_aim.length() > 0.1
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
	# Lunge forward with a faster, horizontal thrust
	var lunge_dir = aim_direction if input_aim.length() > 0.1 else facing_direction
	velocity = lunge_dir * (tackle_force * 1.4) 
	
	# FORCE horizontal-only if on floor to prevent any "jump" from previous states
	if is_on_floor():
		velocity.y = 0
	
	# Explicitly call move_and_slide once to ensure the movement starts immediately
	move_and_slide()
	
	# Visual: Tilt model forward and push arms
	if _model_root:
		if _arm_tween: _arm_tween.kill()
		if _model_tween: _model_tween.kill()
		_model_tween = create_tween()
		_model_tween.set_parallel(true)
		# Tilt torso forward
		_model_tween.tween_property(_model_root, "rotation:x", 0.6, 0.15)
		# Rapid arm push!
		_model_tween.tween_property(_left_arm_pivot, "rotation:x", -1.8, 0.1)
		_model_tween.tween_property(_right_arm_pivot, "rotation:x", -1.8, 0.1)
		
		# Recover
		_model_tween.set_parallel(false)
		_model_tween.tween_interval(0.15)
		_model_tween.set_parallel(true)
		_model_tween.tween_property(_model_root, "rotation:x", 0.0, 0.2)
		_model_tween.tween_property(_left_arm_pivot, "rotation:x", 0.0, 0.2)
		_model_tween.tween_property(_right_arm_pivot, "rotation:x", 0.0, 0.2)
	
	# Check for hits
	if tackle_area:
		for body in tackle_area.get_overlapping_bodies():
			if body is CharacterBody3D and body != self and body.is_in_group("players"):
				if "team_index" in body and body.team_index != team_index:
					_hit_player(body)

func do_punch() -> void:
	current_state = State.PUNCHING
	punch_cooldown = punch_cooldown_duration
	_play_punch_animation()

	# Wait for wind-up to finish before checking hits — fist connects at the start of the pitch
	await get_tree().create_timer(0.15).timeout
	if current_state != State.PUNCHING:
		return  # Got knocked down during wind-up

	var punch_dir = aim_direction if input_aim.length() > 0.1 else facing_direction
	for body in get_tree().get_nodes_in_group("players"):
		if body == self:
			continue
		if not ("team_index" in body) or body.team_index == team_index:
			continue
		var to_target = body.global_position - global_position
		to_target.y = 0
		if to_target.length() > punch_range:
			continue
		if to_target.normalized().dot(punch_dir.normalized()) < 0.3:
			continue
		_punch_player(body, punch_dir)

	# Return to idle after pitch + hold + return phases (0.09 + 0.05 + 0.22 + small buffer)
	await get_tree().create_timer(0.38).timeout
	if current_state == State.PUNCHING:
		current_state = State.IDLE

func _punch_player(target: CharacterBody3D, direction: Vector3) -> void:
	if _hit_sound_player:
		_hit_sound_player.pitch_scale = randf_range(1.1, 1.3)  # Higher pitch than tackle
		_hit_sound_player.play()
	if target.has_method("receive_punch"):
		target.receive_punch(self, direction)
	elif target.has_method("receive_tackle"):
		target.receive_tackle(self, direction)

func _hit_player(target: CharacterBody3D) -> void:
	if target.has_method("receive_tackle"):
		target.receive_tackle(self, facing_direction)

func receive_tackle(attacker: CharacterBody3D, direction: Vector3) -> void:
	current_state = State.KNOCKED_DOWN
	knockdown_timer = knockdown_duration / strength
	velocity = direction * 12.0  # Stronger horizontal pushback
	velocity.y = 3.0  # Lower upward pop for a faster "slide"
	
	# Play impact sound with slight pitch randomization
	if _hit_sound_player:
		_hit_sound_player.pitch_scale = randf_range(0.9, 1.1)
		_hit_sound_player.play()
	
	if has_ball:
		# Fumble — release ball in direction of tackle with random arc
		_release_ball()
		var ball_nodes = get_tree().get_nodes_in_group("ball")
		if ball_nodes.size() > 0:
			var rand_angle = randf_range(-0.4, 0.4) # ~23 degree arc
			var fumble_dir = direction.rotated(Vector3.UP, rand_angle).normalized()
			fumble_dir.y = 0.5 # Upward pop
			fumble_dir = fumble_dir.normalized()
			ball_nodes[0].apply_impulse(fumble_dir * 7.5) # Directed force
		
		# Record steal for attacker
		if attacker != null and "team_index" in attacker and "roster_index" in attacker:
			if attacker.team_index != team_index:
				var gm = _get_game_manager()
				if gm and gm.has_method("record_stat"):
					gm.record_stat(attacker.team_index, attacker.roster_index, "steals")
	was_tackled.emit()
	# Visual knockdown with "stumble"
	if _model_root:
		if _model_tween: _model_tween.kill()
		_model_tween = create_tween()
		# Stumble backward first
		_model_tween.tween_property(_model_root, "rotation:x", -0.4, 0.1)
		# Then flatten/land
		_model_tween.tween_property(_model_root, "scale", Vector3(1.3, 0.3, 1.3), 0.15)
		_model_tween.parallel().tween_property(_model_root, "rotation:x", 0.0, 0.15)
		
		_model_tween.tween_interval(knockdown_timer - 0.3)
		_model_tween.tween_property(_model_root, "scale", Vector3.ONE, 0.3)
	

func receive_punch(attacker: CharacterBody3D, direction: Vector3) -> void:
	## Shorter stun than a tackle — quick stumble, smaller knockback.
	current_state = State.KNOCKED_DOWN
	knockdown_timer = (knockdown_duration * 0.5) / strength  # Half the tackle knockdown
	velocity = direction * 6.0   # Less force than tackle (tackle uses 12.0)
	velocity.y = 1.5

	if has_ball:
		_release_ball()
		var ball_nodes = get_tree().get_nodes_in_group("ball")
		if ball_nodes.size() > 0:
			var rand_angle = randf_range(-0.5, 0.5)
			var fumble_dir = direction.rotated(Vector3.UP, rand_angle).normalized()
			fumble_dir.y = 0.4
			ball_nodes[0].apply_impulse(fumble_dir * 5.0)

		if attacker != null and "team_index" in attacker and "roster_index" in attacker:
			if attacker.team_index != team_index:
				var gm = _get_game_manager()
				if gm and gm.has_method("record_stat"):
					gm.record_stat(attacker.team_index, attacker.roster_index, "steals")
	was_tackled.emit()

	if _model_root:
		if _model_tween: _model_tween.kill()
		_model_tween = create_tween()
		# Stagger: quick lean in punch direction, then settle
		_model_tween.tween_property(_model_root, "rotation:z", direction.x * 0.5, 0.1)
		_model_tween.parallel().tween_property(_model_root, "scale", Vector3(1.1, 0.7, 1.1), 0.1)
		_model_tween.tween_interval(knockdown_timer - 0.2)
		_model_tween.set_parallel(true)
		_model_tween.tween_property(_model_root, "scale", Vector3.ONE, 0.2)
		_model_tween.tween_property(_model_root, "rotation:z", 0.0, 0.2)

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
	if _model_root:
		var tween = create_tween()
		tween.tween_property(_model_root, "scale", Vector3(1.3, 0.3, 1.3), 0.15)
		tween.tween_interval(knockdown_timer - 0.3)
		tween.tween_property(_model_root, "scale", Vector3.ONE, 0.3)

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
	velocity.x = move_toward(velocity.x, 0, 60.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 60.0 * delta)
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
	if has_ball: return
	if knockdown_timer > 0: return # Can't pick up while down

	# Lock logic...
	ball_body.set_holder(self)

	held_ball = ball_body
	has_ball = true
	ball_body.freeze = true
	ball_body.linear_velocity = Vector3.ZERO
	ball_body.angular_velocity = Vector3.ZERO
	# Removed collision layer/mask zeroing because it breaks releasing/passing

	got_ball.emit()

func show_floating_text(msg: String, color: Color = Color.WHITE) -> void:
	if not floating_text:
		return
	floating_text.text = msg
	floating_text.modulate = color
	floating_text.position = Vector3(0, 2.2, 0)
	floating_text.visible = true
	
	# Animate float up and fade out
	var tween = create_tween()
	tween.tween_property(floating_text, "position:y", 3.2, 1.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(floating_text, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): floating_text.visible = false)


func _release_ball() -> void:
	if has_ball:
		if held_ball and is_instance_valid(held_ball):
			held_ball.freeze = false # CRITICAL: Ensure ball physics resume
			if held_ball.has_method("release"):
				held_ball.release(self, team_index)
		_clear_possession_state()
		lost_ball.emit()

func _clear_possession_state() -> void:
	## Internal helper to reset local variables without triggering full release logic.
	has_ball = false
	held_ball = null
	pickup_cooldown = 0.5 # Prevent instant re-grab

func _on_ball_entered(body: Node3D) -> void:
	if body.is_in_group("ball") and not has_ball and current_state != State.KNOCKED_DOWN and not frozen and pickup_cooldown <= 0:
		# Check if any other player already has the ball
		var ball_script = body as RigidBody3D
		if ball_script and ball_script.has_method("is_held") and ball_script.is_held():
			return
		pickup_ball(body)

func _get_game_manager() -> Node:
	return get_tree().get_first_node_in_group("game_manager")

func get_aim_direction_3d() -> Vector3:
	return aim_direction

func force_reset_state() -> void:
	## Manually clears any active tackle/knockdown state and resets visual scale/rotation.
	## Used during possession resets (tip-off, inbounds) to prevent "stuck" animations.
	current_state = State.IDLE
	knockdown_timer = 0.0
	tackle_cooldown = 0.0
	punch_cooldown = 0.0
	pickup_cooldown = 0.0

	# Clear buffered inputs
	input_pass = false
	input_shoot = false
	input_tackle = false
	input_punch = false
	input_call_pass = false
	input_jump = false
	
	if _model_tween:
		_model_tween.kill()
	if _arm_tween:
		_arm_tween.kill()
	
	if _model_root:
		_model_root.scale = Vector3.ONE
		_model_root.rotation = Vector3.ZERO
	
	if _left_arm_pivot:
		_left_arm_pivot.rotation = Vector3.ZERO
	if _right_arm_pivot:
		_right_arm_pivot.rotation = Vector3.ZERO
	if _left_elbow:
		_left_elbow.rotation = Vector3(0.15, 0.0, 0.0)
	if _right_elbow:
		_right_elbow.rotation = Vector3(0.15, 0.0, 0.0)
	
	velocity = Vector3.ZERO
