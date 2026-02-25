extends Node3D
## Crowd Throw — object arcs from beyond the walls toward a random court position.
## Light knockback on hit, doesn't drop ball.

var target_pos: Vector3 = Vector3.ZERO
var knockback_force: float = 4.0
var _flight_time: float = 1.5
var _timer: float = 0.0
var _start_pos: Vector3 = Vector3.ZERO
var _landed: bool = false
var _object_mesh: MeshInstance3D = null
var _object_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("hazards")
	_start_pos = global_position
	_build_visuals()

func _build_visuals() -> void:
	_object_mesh = MeshInstance3D.new()
	# Random object shape
	var roll = randi() % 3
	match roll:
		0:  # Shoe
			var box = BoxMesh.new()
			box.size = Vector3(0.15, 0.1, 0.3)
			_object_mesh.mesh = box
		1:  # Bottle
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.05
			cyl.bottom_radius = 0.08
			cyl.height = 0.3
			_object_mesh.mesh = cyl
		2:  # Ball (small)
			var sphere = SphereMesh.new()
			sphere.radius = 0.1
			sphere.height = 0.2
			_object_mesh.mesh = sphere
	
	_object_mat = StandardMaterial3D.new()
	_object_mat.albedo_color = Color(randf_range(0.4, 0.9), randf_range(0.3, 0.7), randf_range(0.2, 0.5))
	_object_mat.roughness = 0.8
	_object_mesh.material_override = _object_mat
	add_child(_object_mesh)

func _process(delta: float) -> void:
	if _landed:
		return
	
	_timer += delta
	var t = clampf(_timer / _flight_time, 0.0, 1.0)
	
	# Parabolic arc from start to target
	var pos = _start_pos.lerp(target_pos, t)
	var peak_height = 6.0
	pos.y = lerp(_start_pos.y, target_pos.y, t) + 4.0 * peak_height * t * (1.0 - t)
	global_position = pos
	
	# Spin the object
	if _object_mesh:
		_object_mesh.rotation.x += delta * 8.0
		_object_mesh.rotation.z += delta * 5.0
	
	# Landing
	if t >= 1.0:
		_land()

func _land() -> void:
	_landed = true
	
	# Check for players in landing zone
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		var dist = global_position.distance_to(p.global_position)
		if dist < 2.0 and p.has_method("receive_hazard_hit"):
			var dir = (p.global_position - global_position).normalized()
			p.receive_hazard_hit(dir, knockback_force, false)  # Don't drop ball
	
	# Impact VFX — dust puff
	if VFX:
		VFX.spawn_sparks(global_position, Vector3.UP, 5)
	
	# Sit on ground briefly, then fade
	var tween = create_tween()
	tween.tween_interval(1.0)
	if _object_mat:
		tween.tween_property(_object_mat, "albedo_color:a", 0.0, 0.5)
		_object_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tween.tween_callback(queue_free)
