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
var _glow_ring: MeshInstance3D = null
var _trigger_area: Area3D = null

func _ready() -> void:
	add_to_group("hazards")
	_build_visuals()
	_build_trigger()

func _build_visuals() -> void:
	# Main body — spiky sphere
	_mine_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	_mine_mesh.mesh = sphere
	_mine_mat = StandardMaterial3D.new()
	_mine_mat.albedo_color = Color(0.8, 0.1, 0.1)
	_mine_mat.emission_enabled = true
	_mine_mat.emission = Color(1.0, 0.2, 0.0)
	_mine_mat.emission_energy_multiplier = 1.0
	_mine_mat.metallic = 0.7
	_mine_mat.roughness = 0.3
	_mine_mesh.material_override = _mine_mat
	_mine_mesh.position.y = 0.25
	add_child(_mine_mesh)
	
	# Spikes
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
	
	# Warning ring on ground
	_glow_ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = blast_radius - 0.05
	ring_mesh.outer_radius = blast_radius
	_glow_ring.mesh = ring_mesh
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.2, 0.0, 0.15)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.2, 0.0)
	ring_mat.emission_energy_multiplier = 1.0
	_glow_ring.material_override = ring_mat
	_glow_ring.position.y = 0.02
	_glow_ring.rotation.x = PI / 2
	_glow_ring.visible = false
	add_child(_glow_ring)

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
		_glow_ring.visible = true
	
	# Pulse glow when armed
	if armed:
		_pulse_phase += delta * 4.0
		var pulse = (sin(_pulse_phase) + 1.0) / 2.0
		_mine_mat.emission_energy_multiplier = 1.0 + pulse * 3.0
	
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
	if _mine_mat:
		tween.tween_property(_mine_mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
