extends Node3D
## Homing Missile — tracks the ball carrier (or random player), slow turn rate so dodgeable.

var target: Node3D = null
var speed: float = 8.0
var turn_rate: float = 2.0  # radians/sec — slow enough to dodge
var lifetime: float = 8.0
var knockback_force: float = 15.0
var detonation_radius: float = 1.5
var _timer: float = 0.0
var _missile_mesh: MeshInstance3D = null
var _missile_mat: StandardMaterial3D = null
var _trail_timer: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _detonated: bool = false

func _ready() -> void:
	add_to_group("hazards")
	_build_visuals()
	_find_target()
	# Initial velocity toward target
	if target:
		_velocity = (target.global_position - global_position).normalized() * speed
	else:
		_velocity = Vector3.FORWARD * speed
	_velocity.y = 0

func _build_visuals() -> void:
	# Missile body (elongated box)
	_missile_mesh = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.15, 0.15, 0.5)
	_missile_mesh.mesh = body_mesh
	_missile_mat = StandardMaterial3D.new()
	_missile_mat.albedo_color = Color(0.9, 0.3, 0.1)
	_missile_mat.emission_enabled = true
	_missile_mat.emission = Color(1.0, 0.4, 0.0)
	_missile_mat.emission_energy_multiplier = 3.0
	_missile_mat.metallic = 0.8
	_missile_mesh.material_override = _missile_mat
	_missile_mesh.position.y = 1.5
	add_child(_missile_mesh)
	
	# Nose cone
	var nose = MeshInstance3D.new()
	var nose_mesh = CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.08
	nose_mesh.height = 0.15
	nose.mesh = nose_mesh
	nose.material_override = _missile_mat
	nose.position = Vector3(0, 0, -0.3)
	nose.rotation.x = PI / 2
	_missile_mesh.add_child(nose)
	
	# Flame trail (small glowing sphere at back)
	var flame = MeshInstance3D.new()
	var f_mesh = SphereMesh.new()
	f_mesh.radius = 0.1
	f_mesh.height = 0.2
	flame.mesh = f_mesh
	var flame_mat = StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.8, 0.2)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.6, 0.0)
	flame_mat.emission_energy_multiplier = 5.0
	flame.material_override = flame_mat
	flame.position = Vector3(0, 0, 0.3)
	flame.name = "Flame"
	_missile_mesh.add_child(flame)

func _find_target() -> void:
	# Prefer ball carrier
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if "has_ball" in p and p.has_ball:
			target = p
			return
	# Fall back to random player
	if players.size() > 0:
		target = players[randi() % players.size()]

func _process(delta: float) -> void:
	if _detonated:
		return
	
	_timer += delta
	
	# Re-target periodically (every 2 seconds)
	if fmod(_timer, 2.0) < delta:
		_find_target()
	
	# Steer toward target
	if target and is_instance_valid(target):
		var desired = (target.global_position + Vector3(0, 1.5, 0) - global_position).normalized() * speed
		desired.y = 0  # Stay at flight altitude
		_velocity = _velocity.lerp(desired, turn_rate * delta)
		_velocity = _velocity.normalized() * speed
	
	# Move
	global_position += _velocity * delta
	global_position.y = 1.5  # Lock altitude
	
	# Face travel direction
	if _velocity.length() > 0.1:
		var look_target = global_position + _velocity
		look_target.y = global_position.y
		_missile_mesh.look_at(look_target, Vector3.UP)
	
	# Smoke trail
	_trail_timer += delta
	if _trail_timer > 0.1:
		_trail_timer = 0.0
		_spawn_smoke()
	
	# Proximity check
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position + Vector3(0, 0.8, 0))
		if dist < detonation_radius:
			_detonate()
			return
	
	# Lifetime
	if _timer >= lifetime:
		_detonate()

func _spawn_smoke() -> void:
	var root = get_tree().current_scene
	if not root:
		return
	var smoke = MeshInstance3D.new()
	var s_mesh = SphereMesh.new()
	s_mesh.radius = 0.1
	s_mesh.height = 0.2
	smoke.mesh = s_mesh
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.5, 0.5, 0.5, 0.6)
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.emission_enabled = true
	s_mat.emission = Color(0.3, 0.3, 0.3)
	smoke.material_override = s_mat
	smoke.global_position = global_position + Vector3(0, 1.5, 0)
	root.add_child(smoke)
	
	var tween = root.get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(smoke, "scale", Vector3.ONE * 3.0, 0.8)
	tween.tween_property(s_mat, "albedo_color:a", 0.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(smoke.queue_free)

func _detonate() -> void:
	_detonated = true
	
	# Hit nearby players
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		var dist = global_position.distance_to(p.global_position)
		if dist < detonation_radius * 1.5 and p.has_method("receive_hazard_hit"):
			var dir = (p.global_position - global_position).normalized()
			if dir.length() < 0.1:
				dir = Vector3.UP
			p.receive_hazard_hit(dir, knockback_force, true)
	
	if VFX:
		VFX.spawn_explosion(global_position, 1.2)
	
	queue_free()
