extends RigidBody3D
## Ball — basketball with physics, scoring detection, possession tracking, and OOB detection.

signal basket_scored(scoring_team: int, points: int)
signal went_out_of_bounds(last_touch_team: int, oob_position: Vector3)

@export var bounce_damping: float = 0.6
@export var floor_friction: float = 0.98

# Court bounds (must match court_builder.gd)
var court_half_width: float = 8.0   # court_width / 2
var court_half_length: float = 15.0  # court_length / 2
var max_height: float = 8.0

var holder: CharacterBody3D = null
var last_shooter: CharacterBody3D = null
var last_shooter_team: int = -1
var previous_holder: CharacterBody3D = null
var last_touch_team: int = -1  # Tracks which team last touched/held the ball
var _was_shot: bool = false
var _shot_origin: Vector3 = Vector3.ZERO  # Where the shot was taken from (for 3pt detection)
var _oob_cooldown: float = 0.0  # Prevent rapid OOB triggers
var _oob_disabled: bool = false  # Used during inbound passes

@onready var mesh: MeshInstance3D = $Mesh
@onready var collision: CollisionShape3D = $CollisionShape

func _ready() -> void:
	add_to_group("ball")
	contact_monitor = true
	max_contacts_reported = 8
	gravity_scale = 2.04  # Effective gravity ~20.0 to match shot arc math
	_setup_visuals()

func _setup_visuals() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.45, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.45, 0.1) * 0.15
	mat.roughness = 0.7
	mat.metallic = 0.1
	if mesh:
		mesh.material_override = mat

func _physics_process(delta: float) -> void:
	# Skip all checks when ball is frozen (tween-controlled shot in flight)
	if freeze:
		return
	
	if _oob_cooldown > 0:
		_oob_cooldown -= delta
	
	# Don't clamp while held
	if holder != null:
		return
	
	# Floor bounce
	if global_position.y < 0:
		global_position.y = 0.5
		linear_velocity.y = abs(linear_velocity.y) * bounce_damping
	
	# Cap height
	if global_position.y > max_height:
		global_position.y = max_height
		linear_velocity.y = -abs(linear_velocity.y) * 0.3
	
	# Slow down on ground
	if global_position.y < 0.6:
		linear_velocity.x *= floor_friction
		linear_velocity.z *= floor_friction
	
	# --- Out-of-bounds detection (tight — just beyond the walls) ---
	if _oob_cooldown <= 0 and not _oob_disabled:
		var oob = false
		if abs(global_position.x) > court_half_width + 0.5:
			oob = true
		if abs(global_position.z) > court_half_length + 0.5:
			oob = true
		if global_position.y < -1.0:
			oob = true
		
		if oob:
			_oob_cooldown = 2.0  # Don't re-trigger for 2 seconds
			var oob_pos = global_position
			# Stop ball immediately
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			_was_shot = false
			went_out_of_bounds.emit(last_touch_team, oob_pos)

func force_position(pos: Vector3) -> void:
	## Used by game_manager for throw-ins, tip-offs, etc.
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_was_shot = false
	_oob_cooldown = 3.0  # Prevent immediate OOB trigger after repositioning

func is_held() -> bool:
	return holder != null

func set_holder(player: CharacterBody3D) -> void:
	if holder != player:
		previous_holder = holder
	holder = player
	if "team_index" in player:
		last_touch_team = player.team_index
	_was_shot = false

func release(shooter: CharacterBody3D = null, shooter_team: int = -1) -> void:
	holder = null
	if shooter != null:
		last_shooter = shooter
	if shooter_team >= 0:
		last_shooter_team = shooter_team
		last_touch_team = shooter_team
		_was_shot = true

func register_touch(team_index: int) -> void:
	## Call when a player touches/deflects the ball without picking it up
	last_touch_team = team_index

func _on_hoop_entered(hoop_team: int) -> void:
	if not _was_shot:
		return
	var game_mgr = get_tree().get_first_node_in_group("game_manager")
	var sides_flipped = false
	if game_mgr and "sides_flipped" in game_mgr:
		sides_flipped = game_mgr.sides_flipped
	
	var scoring_team = 1 - hoop_team
	if sides_flipped:
		scoring_team = hoop_team
	var points = 2
	if game_mgr and game_mgr.has_method("is_three_pointer"):
		points = 3 if game_mgr.is_three_pointer(_shot_origin, hoop_team) else 2
	
	basket_scored.emit(scoring_team, points)
	_was_shot = false
	
	if game_mgr and game_mgr.has_method("award_score"):
		game_mgr.award_score(scoring_team, points)
