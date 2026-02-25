extends Node
## VFX Manager — spawns particle effects, screen shake, and visual feedback.
## Add as autoload singleton named "VFX".

signal screen_shake_requested(intensity: float, duration: float)

func spawn_explosion(pos: Vector3, size: float = 1.0) -> void:
	## Fireball + expanding shockwave ring
	var root = _get_3d_root()
	if not root:
		return
	
	# Core fireball (expanding sphere that fades)
	var fireball = _create_particle_node(pos, root)
	var fb_mesh = SphereMesh.new()
	fb_mesh.radius = 0.3 * size
	fb_mesh.height = 0.6 * size
	fireball.mesh = fb_mesh
	var fb_mat = StandardMaterial3D.new()
	fb_mat.albedo_color = Color(1.0, 0.6, 0.1)
	fb_mat.emission_enabled = true
	fb_mat.emission = Color(1.0, 0.4, 0.0)
	fb_mat.emission_energy_multiplier = 5.0
	fb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fireball.material_override = fb_mat
	
	var fb_tween = root.get_tree().create_tween()
	fb_tween.set_parallel(true)
	fb_tween.tween_property(fireball, "scale", Vector3.ONE * 3.0 * size, 0.4)
	fb_tween.tween_property(fb_mat, "albedo_color:a", 0.0, 0.4)
	fb_tween.set_parallel(false)
	fb_tween.tween_callback(fireball.queue_free)
	
	# Shockwave ring (expanding torus)
	var ring = _create_particle_node(pos, root)
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.4 * size
	ring_mesh.outer_radius = 0.5 * size
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.8)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.6, 0.0)
	ring_mat.emission_energy_multiplier = 3.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	
	var ring_tween = root.get_tree().create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector3.ONE * 4.0 * size, 0.5)
	ring_tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.5)
	ring_tween.set_parallel(false)
	ring_tween.tween_callback(ring.queue_free)
	
	# Debris particles (small boxes flying outward)
	for i in range(12):
		var debris = _create_particle_node(pos + Vector3(0, 0.3, 0), root)
		var d_mesh = BoxMesh.new()
		d_mesh.size = Vector3.ONE * randf_range(0.05, 0.15) * size
		debris.mesh = d_mesh
		var d_mat = StandardMaterial3D.new()
		d_mat.albedo_color = Color(1.0, randf_range(0.3, 0.8), 0.0)
		d_mat.emission_enabled = true
		d_mat.emission = d_mat.albedo_color
		d_mat.emission_energy_multiplier = 2.0
		d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debris.material_override = d_mat
		
		var angle = randf() * TAU
		var speed = randf_range(3.0, 8.0) * size
		var dir = Vector3(cos(angle) * speed, randf_range(3.0, 7.0), sin(angle) * speed)
		var target = pos + dir * 0.5
		
		var d_tween = root.get_tree().create_tween()
		d_tween.set_parallel(true)
		d_tween.tween_property(debris, "position", target, 0.6).set_ease(Tween.EASE_OUT)
		d_tween.tween_property(d_mat, "albedo_color:a", 0.0, 0.6)
		d_tween.set_parallel(false)
		d_tween.tween_callback(debris.queue_free)
	
	# Screen shake
	screen_shake_requested.emit(0.4 * size, 0.3)

func spawn_sparks(pos: Vector3, direction: Vector3 = Vector3.UP, count: int = 8) -> void:
	## Directional spark spray
	var root = _get_3d_root()
	if not root:
		return
	
	for i in range(count):
		var spark = _create_particle_node(pos, root)
		var s_mesh = BoxMesh.new()
		s_mesh.size = Vector3(0.02, 0.02, 0.1)
		spark.mesh = s_mesh
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(1.0, 0.9, 0.3)
		s_mat.emission_enabled = true
		s_mat.emission = Color(1.0, 0.8, 0.0)
		s_mat.emission_energy_multiplier = 4.0
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark.material_override = s_mat
		
		var spread = direction.normalized() + Vector3(
			randf_range(-0.5, 0.5),
			randf_range(0.0, 0.5),
			randf_range(-0.5, 0.5)
		)
		var target = pos + spread.normalized() * randf_range(1.0, 3.0)
		
		var s_tween = root.get_tree().create_tween()
		s_tween.set_parallel(true)
		s_tween.tween_property(spark, "position", target, randf_range(0.2, 0.4))
		s_tween.tween_property(s_mat, "albedo_color:a", 0.0, 0.3)
		s_tween.set_parallel(false)
		s_tween.tween_callback(spark.queue_free)

func spawn_pickup_pop(pos: Vector3, color: Color = Color.GOLD) -> void:
	## Burst of colored particles radiating outward
	var root = _get_3d_root()
	if not root:
		return
	
	for i in range(10):
		var p = _create_particle_node(pos + Vector3(0, 0.5, 0), root)
		var p_mesh = SphereMesh.new()
		p_mesh.radius = 0.04
		p_mesh.height = 0.08
		p.mesh = p_mesh
		var p_mat = StandardMaterial3D.new()
		p_mat.albedo_color = color
		p_mat.emission_enabled = true
		p_mat.emission = color
		p_mat.emission_energy_multiplier = 3.0
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p.material_override = p_mat
		
		var angle = randf() * TAU
		var target = pos + Vector3(cos(angle) * 1.5, randf_range(0.5, 2.0), sin(angle) * 1.5)
		
		var p_tween = root.get_tree().create_tween()
		p_tween.set_parallel(true)
		p_tween.tween_property(p, "position", target, 0.5).set_ease(Tween.EASE_OUT)
		p_tween.tween_property(p_mat, "albedo_color:a", 0.0, 0.5)
		p_tween.set_parallel(false)
		p_tween.tween_callback(p.queue_free)

func request_screen_shake(intensity: float, duration: float) -> void:
	screen_shake_requested.emit(intensity, duration)

# ---- Internal ----

func _get_3d_root() -> Node:
	var tree = get_tree()
	if tree:
		return tree.current_scene
	return null

func _create_particle_node(pos: Vector3, parent: Node) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.position = pos
	parent.add_child(mi)
	return mi
