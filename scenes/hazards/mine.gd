extends Node3D
## Mine — proximity-detonated explosive placed on the court floor.

var armed: bool = false
var lifetime: float = 15.0
var arm_delay: float = 1.5
var blast_radius: float = 2.5
var knockback_force: float = 12.0
var _timer: float = 0.0
var _pulse_phase: float = 0.0
var _mine_mesh: MeshInstance3D = null
var _mine_mat: StandardMaterial3D = null
var _ring_mesh: MeshInstance3D = null
var _ring_mat: StandardMaterial3D = null
var _inner_disc: MeshInstance3D = null
var _inner_mat: StandardMaterial3D = null
var _trigger_area: Area3D = null

func _ready() -> void:
	add_to_group("hazards")
	_build_visuals()
	_build_trigger()

func _build_visuals() -> void:
	# Main body — dark sphere with metallic look
	_mine_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	_mine_mesh.mesh = sphere
	_mine_mat = StandardMaterial3D.new()
	_mine_mat.albedo_color = Color(0.3, 0.05, 0.05)
	_mine_mat.emission_enabled = true
	_mine_mat.emission = Color(1.0, 0.15, 0.0)
	_mine_mat.emission_energy_multiplier = 0.5
	_mine_mat.metallic = 0.8
	_mine_mat.roughness = 0.25
	_mine_mesh.material_override = _mine_mat
	_mine_mesh.position.y = 0.25
	add_child(_mine_mesh)
	
	# Spikes around the equator
	for i in range(8):
		var spike = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.06
		cone.height = 0.15
		spike.mesh = cone
		spike.material_override = _mine_mat
		var angle = (float(i) / 8.0) * TAU
		spike.position = Vector3(cos(angle) * 0.22, 0.25, sin(angle) * 0.22)
		spike.look_at(spike.position + Vector3(cos(angle), 0, sin(angle)), Vector3.UP)
		spike.rotation.x += PI / 2
		add_child(spike)
	
	# Top indicator light (small bright sphere on top)
	var light_mesh = MeshInstance3D.new()
	var light_sphere = SphereMesh.new()
	light_sphere.radius = 0.06
	light_sphere.height = 0.12
	light_mesh.mesh = light_sphere
	var light_mat = StandardMaterial3D.new()
	light_mat.albedo_color = Color(1.0, 0.8, 0.0)
	light_mat.emission_enabled = true
	light_mat.emission = Color(1.0, 0.6, 0.0)
	light_mat.emission_energy_multiplier = 5.0
	light_mesh.material_override = light_mat
	light_mesh.position.y = 0.5
	add_child(light_mesh)
	
	# --- Blast radius indicator (flat on floor) ---
	# Outer ring — thin flat cylinder
	_ring_mesh = MeshInstance3D.new()
	var ring_cyl = CylinderMesh.new()
	ring_cyl.top_radius = blast_radius
	ring_cyl.bottom_radius = blast_radius
	ring_cyl.height = 0.01
	ring_cyl.radial_segments = 32
	_ring_mesh.mesh = ring_cyl
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(1.0, 0.15, 0.0, 0.0) # Start invisible
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.emission_enabled = true
	_ring_mat.emission = Color(1.0, 0.15, 0.0)
	_ring_mat.emission_energy_multiplier = 2.0
	_ring_mat.no_depth_test = true # Always visible on floor
	_ring_mesh.material_override = _ring_mat
	_ring_mesh.position.y = 0.02 # Just above floor
	add_child(_ring_mesh)
	
	# Inner filled disc — very faint danger zone
	_inner_disc = MeshInstance3D.new()
	var disc_cyl = CylinderMesh.new()
	disc_cyl.top_radius = blast_radius - 0.08
	disc_cyl.bottom_radius = blast_radius - 0.08
	disc_cyl.height = 0.005
	disc_cyl.radial_segments = 32
	_inner_disc.mesh = disc_cyl
	_inner_mat = StandardMaterial3D.new()
	_inner_mat.albedo_color = Color(1.0, 0.1, 0.0, 0.0) # Start invisible
	_inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_inner_mat.emission_enabled = true
	_inner_mat.emission = Color(1.0, 0.05, 0.0)
	_inner_mat.emission_energy_multiplier = 0.5
	_inner_mat.no_depth_test = true
	_inner_disc.material_override = _inner_mat
	_inner_disc.position.y = 0.015
	add_child(_inner_disc)

func _build_trigger() -> void:
	_trigger_area = Area3D.new()
	_trigger_area.collision_layer = 0
	_trigger_area.collision_mask = 2  # Players layer
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = blast_radius
	col.shape = shape
	col.position.y = 0.5
	_trigger_area.add_child(col)
	_trigger_area.body_entered.connect(_on_body_entered)
	add_child(_trigger_area)

func _process(delta: float) -> void:
	_timer += delta
	
	# Arm after delay
	if not armed and _timer >= arm_delay:
		armed = true
		# Fade in the blast radius indicator
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_ring_mat, "albedo_color:a", 0.25, 0.5)
		tween.tween_property(_inner_mat, "albedo_color:a", 0.06, 0.5)
	
	# Pulse glow when armed
	if armed:
		_pulse_phase += delta * 4.0
		var pulse = (sin(_pulse_phase) + 1.0) / 2.0
		_mine_mat.emission_energy_multiplier = 0.5 + pulse * 4.0
		# Pulse the ring opacity too
		if _ring_mat:
			_ring_mat.albedo_color.a = 0.1 + pulse * 0.2
			_ring_mat.emission_energy_multiplier = 1.0 + pulse * 2.0
		if _inner_mat:
			_inner_mat.albedo_color.a = 0.02 + pulse * 0.06
	
	# Lifetime
	if _timer >= lifetime:
		_fade_and_die()

func _on_body_entered(body: Node3D) -> void:
	if not armed:
		return
	if body.is_in_group("players"):
		_detonate()

func _detonate() -> void:
	armed = false  # Prevent re-trigger
	
	# Hit all players in blast radius
	for body in _trigger_area.get_overlapping_bodies():
		if body.is_in_group("players") and body.has_method("receive_hazard_hit"):
			var dir = (body.global_position - global_position).normalized()
			if dir.length() < 0.1:
				dir = Vector3.UP
			body.receive_hazard_hit(dir, knockback_force, true)
	
	# VFX
	if VFX:
		VFX.spawn_explosion(global_position, 1.5)
	
	queue_free()

func _fade_and_die() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	if _mine_mat:
		tween.tween_property(_mine_mat, "albedo_color:a", 0.0, 0.5)
		_mine_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if _ring_mat:
		tween.tween_property(_ring_mat, "albedo_color:a", 0.0, 0.3)
	if _inner_mat:
		tween.tween_property(_inner_mat, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
