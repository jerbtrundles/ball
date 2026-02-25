extends Node3D
## Saw Blade — spinning metallic disc that slides across the court.

var travel_direction: Vector3 = Vector3.RIGHT
var travel_speed: float = 6.0
var knockback_force: float = 10.0
var _spin_speed: float = 720.0  # degrees/sec
var _blade_mesh: MeshInstance3D = null
var _blade_mat: StandardMaterial3D = null
var _trail_timer: float = 0.0
var _hit_players: Array = []  # Prevent double-hits

# Court bounds
var court_half_w: float = 8.0
var court_half_l: float = 15.0

func _ready() -> void:
	add_to_group("hazards")
	_build_visuals()
	_build_trigger()

func _build_visuals() -> void:
	# Spinning disc
	_blade_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 0.05
	cyl.radial_segments = 16
	_blade_mesh.mesh = cyl
	_blade_mat = StandardMaterial3D.new()
	_blade_mat.albedo_color = Color(0.7, 0.7, 0.8)
	_blade_mat.emission_enabled = true
	_blade_mat.emission = Color(1.0, 0.6, 0.0)
	_blade_mat.emission_energy_multiplier = 2.0
	_blade_mat.metallic = 0.95
	_blade_mat.roughness = 0.1
	_blade_mesh.material_override = _blade_mat
	_blade_mesh.position.y = 0.5
	add_child(_blade_mesh)
	
	# Teeth (small triangles around the edge)
	for i in range(12):
		var tooth = MeshInstance3D.new()
		var t_mesh = CylinderMesh.new()
		t_mesh.top_radius = 0.0
		t_mesh.bottom_radius = 0.08
		t_mesh.height = 0.12
		tooth.mesh = t_mesh
		tooth.material_override = _blade_mat
		var angle = (float(i) / 12.0) * TAU
		tooth.position = Vector3(cos(angle) * 0.6, 0.5, sin(angle) * 0.6)
		tooth.rotation.z = -PI / 4
		_blade_mesh.add_child(tooth)

func _build_trigger() -> void:
	var area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Players
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 1.2
	col.shape = shape
	col.position.y = 0.5
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _process(delta: float) -> void:
	# Move
	global_position += travel_direction * travel_speed * delta
	
	# Spin
	_blade_mesh.rotation.y += deg_to_rad(_spin_speed) * delta
	
	# Spark trail
	_trail_timer += delta
	if _trail_timer > 0.15:
		_trail_timer = 0.0
		if VFX:
			VFX.spawn_sparks(global_position + Vector3(0, 0.1, 0), -travel_direction, 3)
	
	# Despawn when off court
	if abs(global_position.x) > court_half_w + 3.0 or abs(global_position.z) > court_half_l + 3.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and body not in _hit_players:
		_hit_players.append(body)
		if body.has_method("receive_hazard_hit"):
			body.receive_hazard_hit(travel_direction + Vector3.UP * 0.5, knockback_force, true)
		if VFX:
			VFX.spawn_sparks(body.global_position + Vector3(0, 0.5, 0), travel_direction, 12)
			VFX.request_screen_shake(0.2, 0.15)
