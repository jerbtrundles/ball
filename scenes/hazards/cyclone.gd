extends Node3D
## Cyclone (formerly Saw Blade) — swirling vortex that sweeps across the court.

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
	# Main Cyclone Body (Tornado shape)
	_blade_mesh = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.8
	cone.bottom_radius = 0.0  # Point at ground
	cone.height = 2.0
	cone.radial_segments = 16
	_blade_mesh.mesh = cone
	
	_blade_mat = StandardMaterial3D.new()
	_blade_mat.albedo_color = Color(0.7, 0.9, 0.8, 0.6) # Windy/Cyan-grey
	_blade_mat.emission_enabled = true
	_blade_mat.emission = Color(0.4, 1.0, 0.8)
	_blade_mat.emission_energy_multiplier = 1.5
	_blade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blade_mat.metallic = 0.3
	_blade_mat.roughness = 0.5
	_blade_mesh.material_override = _blade_mat
	_blade_mesh.position.y = 1.0 # Lift half-height
	add_child(_blade_mesh)
	
	# Swirling Rings (Debris/Wind)
	for i in range(3):
		var ring = MeshInstance3D.new()
		var r_mesh = TorusMesh.new()
		var h_percent = float(i) / 2.0  # 0.0 (bottom) to 1.0 (top)
		r_mesh.inner_radius = lerpf(0.1, 0.9, h_percent)
		r_mesh.outer_radius = r_mesh.inner_radius + 0.1
		ring.mesh = r_mesh
		
		var r_mat = StandardMaterial3D.new()
		r_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
		r_mat.emission_enabled = true
		r_mat.emission = Color.WHITE
		r_mat.emission_energy_multiplier = 2.0
		r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = r_mat
		
		# Offset Y position
		ring.position.y = lerpf(-0.8, 0.8, h_percent)
		
		# Slight tilt for chaotic spin
		ring.rotation.x = randf_range(-0.3, 0.3)
		ring.rotation.z = randf_range(-0.3, 0.3)
		
		# Rotate opposite direction over time
		_blade_mesh.add_child(ring)

func _build_trigger() -> void:
	var area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Players
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 2.0
	col.shape = shape
	col.position.y = 1.0
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _process(delta: float) -> void:
	# Move
	global_position += travel_direction * travel_speed * delta
	
	# Spin cone
	_blade_mesh.rotation.y += deg_to_rad(_spin_speed) * delta
	
	# Spin rings faster and somewhat chaotically
	for i in range(_blade_mesh.get_child_count()):
		var ring = _blade_mesh.get_child(i)
		ring.rotation.y -= deg_to_rad(_spin_speed * 1.5) * delta
	
	# Wind trail (puff)
	_trail_timer += delta
	if _trail_timer > 0.15:
		_trail_timer = 0.0
		if VFX:
			# Pass a custom cyan color to sparks if the engine supports it, or just use default sparks
			VFX.spawn_sparks(global_position + Vector3(0, 0.5, 0), -travel_direction, 3)
	
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
